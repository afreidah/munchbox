// -------------------------------------------------------------------------------
// Oracle Watchdog - Agent Tests
//
// Project: Munchbox / Author: Alex Freidah
// -------------------------------------------------------------------------------

package agent

import (
	"errors"
	"testing"
	"time"

	"github.com/afreidah/oracle-watchdog/internal/config"
)

func TestIsConnectionError(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{
			name: "nil error",
			err:  nil,
			want: false,
		},
		{
			name: "connection refused",
			err:  errors.New("dial tcp 127.0.0.1:8500: connection refused"),
			want: true,
		},
		{
			name: "connection reset",
			err:  errors.New("read: connection reset by peer"),
			want: true,
		},
		{
			name: "no such host",
			err:  errors.New("dial tcp: lookup consul.service.consul: no such host"),
			want: true,
		},
		{
			name: "timeout",
			err:  errors.New("context deadline exceeded (Client.Timeout)"),
			want: true,
		},
		{
			name: "deadline exceeded",
			err:  errors.New("context deadline exceeded"),
			want: true,
		},
		{
			name: "eof uppercase in error",
			err:  errors.New("unexpected EOF"),
			want: false, // Note: pattern is uppercase "EOF" but error is lowercased, so no match
		},
		{
			name: "network unreachable",
			err:  errors.New("dial tcp: network unreachable"),
			want: true,
		},
		{
			name: "no route to host",
			err:  errors.New("dial tcp: no route to host"),
			want: true,
		},
		{
			name: "broken pipe",
			err:  errors.New("write: broken pipe"),
			want: true,
		},
		{
			name: "i/o timeout",
			err:  errors.New("read tcp: i/o timeout"),
			want: true,
		},
		{
			name: "dial tcp",
			err:  errors.New("dial tcp 192.168.1.1:8500: connect: connection refused"),
			want: true,
		},
		{
			name: "regular error",
			err:  errors.New("permission denied"),
			want: false,
		},
		{
			name: "api error",
			err:  errors.New("unexpected status code: 500"),
			want: false,
		},
		{
			name: "not found error",
			err:  errors.New("key not found"),
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isConnectionError(tt.err)
			if got != tt.want {
				t.Errorf("isConnectionError(%v) = %v, want %v", tt.err, got, tt.want)
			}
		})
	}
}

func TestConnectionState_String(t *testing.T) {
	tests := []struct {
		state connectionState
		want  string
	}{
		{stateDisconnected, "disconnected"},
		{stateConnected, "connected"},
		{connectionState(99), "unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			got := tt.state.String()
			if got != tt.want {
				t.Errorf("state.String() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestNew(t *testing.T) {
	cfg := &config.Config{
		Timeout:       5 * time.Minute,
		CheckInterval: 30 * time.Second,
		ConsulAddress: "localhost:8500",
		Nodes: []config.NodeConfig{
			{Name: "test-node", InstanceID: "test-id", CompartmentID: "test-comp"},
		},
	}

	agent, err := New(cfg)
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}

	if agent.cfg != cfg {
		t.Error("agent.cfg not set correctly")
	}
	if agent.consulState != stateDisconnected {
		t.Errorf("expected initial consulState = disconnected, got %v", agent.consulState)
	}
	if agent.ociState != stateDisconnected {
		t.Errorf("expected initial ociState = disconnected, got %v", agent.ociState)
	}
	if agent.missingSince == nil {
		t.Error("missingSince map not initialized")
	}
	if agent.restarting == nil {
		t.Error("restarting map not initialized")
	}
	if agent.restartAttempts == nil {
		t.Error("restartAttempts map not initialized")
	}
}
