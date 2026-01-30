// -------------------------------------------------------------------------------
// Oracle Watchdog - Configuration Tests
//
// Project: Munchbox / Author: Alex Freidah
// -------------------------------------------------------------------------------

package config

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestLoad_ValidConfig(t *testing.T) {
	content := `
timeout: 5m
check_interval: 30s
consul_address: "localhost:8500"
oci:
  config_path: "/home/user/.oci/config"
  profile: "DEFAULT"
nodes:
  - name: "oracle-node-1"
    instance_id: "ocid1.instance.oc1.phx.test1"
    compartment_id: "ocid1.compartment.oc1..test1"
  - name: "oracle-node-2"
    instance_id: "ocid1.instance.oc1.phx.test2"
    compartment_id: "ocid1.compartment.oc1..test2"
`
	cfg := writeAndLoad(t, content)

	if cfg.Timeout != 5*time.Minute {
		t.Errorf("expected timeout 5m, got %v", cfg.Timeout)
	}
	if cfg.CheckInterval != 30*time.Second {
		t.Errorf("expected check_interval 30s, got %v", cfg.CheckInterval)
	}
	if cfg.ConsulAddress != "localhost:8500" {
		t.Errorf("expected consul_address localhost:8500, got %s", cfg.ConsulAddress)
	}
	if len(cfg.Nodes) != 2 {
		t.Errorf("expected 2 nodes, got %d", len(cfg.Nodes))
	}
	if cfg.Nodes[0].Name != "oracle-node-1" {
		t.Errorf("expected first node name oracle-node-1, got %s", cfg.Nodes[0].Name)
	}
}

func TestLoad_Defaults(t *testing.T) {
	content := `
nodes:
  - name: "test-node"
    instance_id: "ocid1.instance.oc1.phx.test"
    compartment_id: "ocid1.compartment.oc1..test"
`
	cfg := writeAndLoad(t, content)

	if cfg.Timeout != 5*time.Minute {
		t.Errorf("expected default timeout 5m, got %v", cfg.Timeout)
	}
	if cfg.CheckInterval != 30*time.Second {
		t.Errorf("expected default check_interval 30s, got %v", cfg.CheckInterval)
	}
	if cfg.ConsulAddress != "consul.service.consul:8500" {
		t.Errorf("expected default consul_address, got %s", cfg.ConsulAddress)
	}
}

func TestLoad_ValidationErrors(t *testing.T) {
	tests := []struct {
		name    string
		content string
		wantErr string
	}{
		{
			name:    "no nodes",
			content: `timeout: 5m`,
			wantErr: "no nodes configured",
		},
		{
			name: "missing node name",
			content: `
nodes:
  - instance_id: "ocid1.instance.test"
    compartment_id: "ocid1.compartment.test"
`,
			wantErr: "missing name",
		},
		{
			name: "missing instance_id",
			content: `
nodes:
  - name: "test"
    compartment_id: "ocid1.compartment.test"
`,
			wantErr: "missing instance_id",
		},
		{
			name: "missing compartment_id",
			content: `
nodes:
  - name: "test"
    instance_id: "ocid1.instance.test"
`,
			wantErr: "missing compartment_id",
		},
		{
			name: "timeout too short",
			content: `
timeout: 30s
nodes:
  - name: "test"
    instance_id: "ocid1.instance.test"
    compartment_id: "ocid1.compartment.test"
`,
			wantErr: "timeout must be at least 1 minute",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			configPath := filepath.Join(tmpDir, "config.yaml")
			if err := os.WriteFile(configPath, []byte(tt.content), 0644); err != nil {
				t.Fatalf("failed to write config: %v", err)
			}

			_, err := Load(configPath)
			if err == nil {
				t.Fatal("expected error, got nil")
			}
			if !contains(err.Error(), tt.wantErr) {
				t.Errorf("expected error containing %q, got %q", tt.wantErr, err.Error())
			}
		})
	}
}

func TestLoad_FileNotFound(t *testing.T) {
	_, err := Load("/nonexistent/path/config.yaml")
	if err == nil {
		t.Fatal("expected error for nonexistent file")
	}
}

func TestLoad_InvalidYAML(t *testing.T) {
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "config.yaml")
	if err := os.WriteFile(configPath, []byte("invalid: yaml: content: ["), 0644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	_, err := Load(configPath)
	if err == nil {
		t.Fatal("expected error for invalid YAML")
	}
}

// writeAndLoad is a test helper that writes config content and loads it.
func writeAndLoad(t *testing.T, content string) *Config {
	t.Helper()
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "config.yaml")
	if err := os.WriteFile(configPath, []byte(content), 0644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}

	cfg, err := Load(configPath)
	if err != nil {
		t.Fatalf("failed to load config: %v", err)
	}
	return cfg
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(substr) == 0 ||
		(len(s) > 0 && len(substr) > 0 && searchString(s, substr)))
}

func searchString(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
