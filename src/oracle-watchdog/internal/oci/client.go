// -------------------------------------------------------------------------------
// Oracle Watchdog - OCI Client
//
// Project: Munchbox / Author: Alex Freidah
//
// Wraps the OCI Go SDK for instance lifecycle management. Provides stop/start
// operations with proper state waiting for the restart cycle required to
// recover reclaimed free-tier instances.
// -------------------------------------------------------------------------------

package oci

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/oracle/oci-go-sdk/v65/common"
	"github.com/oracle/oci-go-sdk/v65/core"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"

	"github.com/afreidah/oracle-watchdog/internal/tracing"
)

const (
	pollInterval = 10 * time.Second
	maxWaitTime  = 5 * time.Minute
)

// Client provides OCI instance management operations.
type Client struct {
	compute *core.ComputeClient
}

// NewClient creates an OCI client using the specified config file and profile.
func NewClient(configPath, profile string) (*Client, error) {
	provider, err := common.ConfigurationProviderFromFileWithProfile(configPath, profile, "")
	if err != nil {
		return nil, fmt.Errorf("create config provider: %w", err)
	}

	compute, err := core.NewComputeClientWithConfigurationProvider(provider)
	if err != nil {
		return nil, fmt.Errorf("create compute client: %w", err)
	}

	return &Client{compute: &compute}, nil
}

// RestartInstance performs a stop-then-start cycle on the given instance.
// Waits for STOPPED state before initiating start.
func (c *Client) RestartInstance(ctx context.Context, instanceID, compartmentID string) error {
	ctx, span := tracing.StartSpan(ctx, "oci.restart_instance",
		tracing.InstanceAttr(instanceID),
	)
	defer span.End()

	slog.Info("stopping instance", "instance_id", instanceID)

	// --- Issue stop command ---
	if err := c.stopInstance(ctx, instanceID); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return fmt.Errorf("stop instance: %w", err)
	}

	// --- Wait for STOPPED state ---
	if err := c.waitForState(ctx, instanceID, core.InstanceLifecycleStateStopped); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return fmt.Errorf("wait for stopped: %w", err)
	}

	slog.Info("instance stopped, starting", "instance_id", instanceID)

	// --- Issue start command ---
	if err := c.startInstance(ctx, instanceID); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return fmt.Errorf("start instance: %w", err)
	}

	// --- Wait for RUNNING state ---
	if err := c.waitForState(ctx, instanceID, core.InstanceLifecycleStateRunning); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return fmt.Errorf("wait for running: %w", err)
	}

	slog.Info("instance restarted successfully", "instance_id", instanceID)
	span.SetStatus(codes.Ok, "restart completed")
	return nil
}

func (c *Client) stopInstance(ctx context.Context, instanceID string) error {
	ctx, span := tracing.StartSpan(ctx, "oci.stop_instance",
		tracing.InstanceAttr(instanceID),
	)
	defer span.End()

	_, err := c.compute.InstanceAction(ctx, core.InstanceActionRequest{
		InstanceId: common.String(instanceID),
		Action:     core.InstanceActionActionStop,
	})
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return err
	}

	span.SetStatus(codes.Ok, "stop command sent")
	return nil
}

func (c *Client) startInstance(ctx context.Context, instanceID string) error {
	ctx, span := tracing.StartSpan(ctx, "oci.start_instance",
		tracing.InstanceAttr(instanceID),
	)
	defer span.End()

	_, err := c.compute.InstanceAction(ctx, core.InstanceActionRequest{
		InstanceId: common.String(instanceID),
		Action:     core.InstanceActionActionStart,
	})
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return err
	}

	span.SetStatus(codes.Ok, "start command sent")
	return nil
}

func (c *Client) waitForState(ctx context.Context, instanceID string, targetState core.InstanceLifecycleStateEnum) error {
	ctx, span := tracing.StartSpan(ctx, "oci.wait_for_state",
		tracing.InstanceAttr(instanceID),
		tracing.StateAttr(string(targetState)),
	)
	defer span.End()

	startTime := time.Now()
	deadline := startTime.Add(maxWaitTime)
	pollCount := 0

	for time.Now().Before(deadline) {
		select {
		case <-ctx.Done():
			span.RecordError(ctx.Err())
			span.SetStatus(codes.Error, "context cancelled")
			return ctx.Err()
		default:
		}

		resp, err := c.compute.GetInstance(ctx, core.GetInstanceRequest{
			InstanceId: common.String(instanceID),
		})
		if err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
			return fmt.Errorf("get instance: %w", err)
		}

		pollCount++

		if resp.LifecycleState == targetState {
			elapsed := time.Since(startTime)
			span.SetAttributes(
				tracing.DurationAttr("wait_duration_seconds", elapsed.Seconds()),
			)
			span.AddEvent("state_reached", trace.WithAttributes(
				tracing.StateAttr(string(targetState)),
			))
			span.SetStatus(codes.Ok, "target state reached")
			return nil
		}

		slog.Debug("waiting for state",
			"instance_id", instanceID,
			"current", resp.LifecycleState,
			"target", targetState,
		)

		time.Sleep(pollInterval)
	}

	err := fmt.Errorf("timeout waiting for state %s after %d polls", targetState, pollCount)
	span.RecordError(err)
	span.SetStatus(codes.Error, err.Error())
	return err
}
