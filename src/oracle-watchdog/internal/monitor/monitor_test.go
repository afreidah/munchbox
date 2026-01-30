// -------------------------------------------------------------------------------
// Oracle Watchdog - Monitor Tests
//
// Project: Munchbox / Author: Alex Freidah
// -------------------------------------------------------------------------------

package monitor

import (
	"os"
	"testing"
)

func TestState_String(t *testing.T) {
	tests := []struct {
		state state
		want  string
	}{
		{stateDisconnected, "disconnected"},
		{stateConnecting, "connecting"},
		{stateActive, "active"},
		{state(99), "unknown"},
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
	monitor, err := New("test-node")
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}

	if monitor.nodeName != "test-node" {
		t.Errorf("expected nodeName = test-node, got %s", monitor.nodeName)
	}
	if monitor.state != stateDisconnected {
		t.Errorf("expected initial state = disconnected, got %v", monitor.state)
	}
}

func TestNew_UsesEnvVar(t *testing.T) {
	// Set custom consul address
	originalAddr := os.Getenv("CONSUL_HTTP_ADDR")
	defer os.Setenv("CONSUL_HTTP_ADDR", originalAddr)

	os.Setenv("CONSUL_HTTP_ADDR", "custom-consul:8500")

	monitor, err := New("test-node")
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}

	if monitor.consulAddress != "custom-consul:8500" {
		t.Errorf("expected consulAddress = custom-consul:8500, got %s", monitor.consulAddress)
	}
}

func TestNew_DefaultConsulAddress(t *testing.T) {
	// Ensure env var is not set
	originalAddr := os.Getenv("CONSUL_HTTP_ADDR")
	defer os.Setenv("CONSUL_HTTP_ADDR", originalAddr)

	os.Unsetenv("CONSUL_HTTP_ADDR")

	monitor, err := New("test-node")
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}

	if monitor.consulAddress != "consul.service.consul:8500" {
		t.Errorf("expected default consulAddress, got %s", monitor.consulAddress)
	}
}
