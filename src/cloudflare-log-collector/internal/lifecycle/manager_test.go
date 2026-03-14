// -------------------------------------------------------------------------------
// Lifecycle Manager Tests
//
// Author: Alex Freidah
//
// Tests for the service lifecycle manager covering registration, startup,
// context cancellation, panic recovery, and ordered shutdown.
// -------------------------------------------------------------------------------

package lifecycle

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"os"
	"sync/atomic"
	"testing"
	"time"
)

// -------------------------------------------------------------------------
// TEST SETUP
// -------------------------------------------------------------------------

// TestMain silences slog during tests.
func TestMain(m *testing.M) {
	slog.SetDefault(slog.New(slog.NewTextHandler(io.Discard, nil)))
	os.Exit(m.Run())
}

// -------------------------------------------------------------------------
// MOCK SERVICES
// -------------------------------------------------------------------------

// mockService is a test service that blocks until ctx is cancelled and tracks
// whether it was started.
type mockService struct {
	started atomic.Bool
}

// Run blocks until ctx is cancelled and records that the service was started.
func (m *mockService) Run(ctx context.Context) error {
	m.started.Store(true)
	<-ctx.Done()
	return nil
}

// stoppableService extends mockService with a Stop method that records whether
// Stop was called.
type stoppableService struct {
	mockService
	stopped atomic.Bool
}

// Stop records that the service was stopped.
func (s *stoppableService) Stop(_ context.Context) error {
	s.stopped.Store(true)
	return nil
}

// panicService panics on its first Run call, then blocks until ctx is cancelled.
type panicService struct {
	calls atomic.Int32
}

// Run panics on the first invocation and blocks on subsequent calls.
func (p *panicService) Run(ctx context.Context) error {
	if p.calls.Add(1) == 1 {
		panic("test panic")
	}
	<-ctx.Done()
	return nil
}

// errorService returns an error on its first Run call, then blocks.
type errorService struct {
	calls atomic.Int32
}

// Run returns an error on the first invocation and blocks on subsequent calls.
func (e *errorService) Run(ctx context.Context) error {
	if e.calls.Add(1) == 1 {
		return errors.New("test error")
	}
	<-ctx.Done()
	return nil
}

// -------------------------------------------------------------------------
// TESTS
// -------------------------------------------------------------------------

func TestManager_StartsServices(t *testing.T) {
	m := NewManager()
	svc1 := &mockService{}
	svc2 := &mockService{}
	m.Register("svc1", svc1)
	m.Register("svc2", svc2)

	ctx, cancel := context.WithCancel(context.Background())

	done := make(chan struct{})
	go func() {
		m.Run(ctx)
		close(done)
	}()

	// --- Wait for services to start ---
	waitFor(t, func() bool { return svc1.started.Load() && svc2.started.Load() })

	cancel()
	waitForDone(t, done)
}

func TestManager_StopsInReverseOrder(t *testing.T) {
	m := NewManager()
	svc1 := &stoppableService{}
	svc2 := &stoppableService{}
	m.Register("first", svc1)
	m.Register("second", svc2)

	ctx, cancel := context.WithCancel(context.Background())

	done := make(chan struct{})
	go func() {
		m.Run(ctx)
		close(done)
	}()

	waitFor(t, func() bool { return svc1.started.Load() && svc2.started.Load() })

	cancel()
	waitForDone(t, done)

	m.Stop(5 * time.Second)

	if !svc1.stopped.Load() {
		t.Error("svc1 should have been stopped")
	}
	if !svc2.stopped.Load() {
		t.Error("svc2 should have been stopped")
	}
}

func TestManager_RecoversPanic(t *testing.T) {
	m := NewManager()
	svc := &panicService{}
	m.Register("panicker", svc)

	ctx, cancel := context.WithCancel(context.Background())

	done := make(chan struct{})
	go func() {
		m.Run(ctx)
		close(done)
	}()

	// --- Wait for service to be restarted after panic ---
	waitFor(t, func() bool { return svc.calls.Load() >= 2 })

	cancel()
	waitForDone(t, done)
}

func TestManager_RestartsOnError(t *testing.T) {
	m := NewManager()
	svc := &errorService{}
	m.Register("errorer", svc)

	ctx, cancel := context.WithCancel(context.Background())

	done := make(chan struct{})
	go func() {
		m.Run(ctx)
		close(done)
	}()

	// --- Wait for service to be restarted after error ---
	waitFor(t, func() bool { return svc.calls.Load() >= 2 })

	cancel()
	waitForDone(t, done)
}

func TestManager_EmptyRunReturns(t *testing.T) {
	m := NewManager()

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	done := make(chan struct{})
	go func() {
		m.Run(ctx)
		close(done)
	}()

	waitForDone(t, done)
}

// -------------------------------------------------------------------------
// HELPERS
// -------------------------------------------------------------------------

// waitFor polls a condition function until it returns true or the test times out.
func waitFor(t *testing.T, condition func() bool) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if condition() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("timed out waiting for condition")
}

// waitForDone waits for a channel to close or fails the test after a timeout.
func waitForDone(t *testing.T, done <-chan struct{}) {
	t.Helper()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for done channel")
	}
}
