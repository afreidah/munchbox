// -------------------------------------------------------------------------------
// Configuration Tests
//
// Author: Alex Freidah
//
// Validates config loading, environment variable expansion, default application,
// and required field validation.
// -------------------------------------------------------------------------------

package config

import (
	"log/slog"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// validConfig returns a minimal valid Config for test cases that need to
// modify one field at a time.
func validConfig() Config {
	return Config{
		Cloudflare: CloudflareConfig{
			APIToken: "test-token",
			ZoneID:   "test-zone-id",
		},
		Loki: LokiConfig{
			Endpoint: "http://localhost:3100",
		},
	}
}

// writeConfigFile writes YAML content to a temp file and returns the path.
func writeConfigFile(t *testing.T, content string) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	return path
}

// -------------------------------------------------------------------------
// LOADING
// -------------------------------------------------------------------------

func TestLoadConfig_ValidMinimal(t *testing.T) {
	path := writeConfigFile(t, `
cloudflare:
  api_token: "tok"
  zone_id: "zid"
loki:
  endpoint: "http://localhost:3100"
`)

	cfg, err := LoadConfig(path)
	if err != nil {
		t.Fatalf("LoadConfig() error = %v", err)
	}

	if cfg.Cloudflare.APIToken != "tok" {
		t.Errorf("api_token = %q, want %q", cfg.Cloudflare.APIToken, "tok")
	}
	if cfg.Cloudflare.ZoneID != "zid" {
		t.Errorf("zone_id = %q, want %q", cfg.Cloudflare.ZoneID, "zid")
	}
}

func TestLoadConfig_EnvVarExpansion(t *testing.T) {
	t.Setenv("CF_TEST_TOKEN", "expanded-token")
	t.Setenv("CF_TEST_ZONE", "expanded-zone")

	path := writeConfigFile(t, `
cloudflare:
  api_token: "${CF_TEST_TOKEN}"
  zone_id: "${CF_TEST_ZONE}"
loki:
  endpoint: "http://localhost:3100"
`)

	cfg, err := LoadConfig(path)
	if err != nil {
		t.Fatalf("LoadConfig() error = %v", err)
	}

	if cfg.Cloudflare.APIToken != "expanded-token" {
		t.Errorf("api_token = %q, want %q", cfg.Cloudflare.APIToken, "expanded-token")
	}
	if cfg.Cloudflare.ZoneID != "expanded-zone" {
		t.Errorf("zone_id = %q, want %q", cfg.Cloudflare.ZoneID, "expanded-zone")
	}
}

func TestLoadConfig_FileNotFound(t *testing.T) {
	_, err := LoadConfig("/nonexistent/config.yaml")
	if err == nil {
		t.Error("LoadConfig() should fail for missing file")
	}
}

func TestLoadConfig_InvalidYAML(t *testing.T) {
	path := writeConfigFile(t, `{{{invalid yaml`)

	_, err := LoadConfig(path)
	if err == nil {
		t.Error("LoadConfig() should fail for invalid YAML")
	}
}

// -------------------------------------------------------------------------
// DEFAULTS
// -------------------------------------------------------------------------

func TestDefaults_PollInterval(t *testing.T) {
	cfg := validConfig()
	if err := cfg.setDefaultsAndValidate(); err != nil {
		t.Fatalf("setDefaultsAndValidate() error = %v", err)
	}

	if cfg.Cloudflare.PollInterval != 5*time.Minute {
		t.Errorf("poll_interval = %v, want %v", cfg.Cloudflare.PollInterval, 5*time.Minute)
	}
}

func TestDefaults_BackfillWindow(t *testing.T) {
	cfg := validConfig()
	if err := cfg.setDefaultsAndValidate(); err != nil {
		t.Fatalf("setDefaultsAndValidate() error = %v", err)
	}

	if cfg.Cloudflare.BackfillWindow != 1*time.Hour {
		t.Errorf("backfill_window = %v, want %v", cfg.Cloudflare.BackfillWindow, 1*time.Hour)
	}
}

func TestDefaults_LokiTenantID(t *testing.T) {
	cfg := validConfig()
	if err := cfg.setDefaultsAndValidate(); err != nil {
		t.Fatalf("setDefaultsAndValidate() error = %v", err)
	}

	if cfg.Loki.TenantID != "fake" {
		t.Errorf("tenant_id = %q, want %q", cfg.Loki.TenantID, "fake")
	}
}

func TestDefaults_LokiBatchSize(t *testing.T) {
	cfg := validConfig()
	if err := cfg.setDefaultsAndValidate(); err != nil {
		t.Fatalf("setDefaultsAndValidate() error = %v", err)
	}

	if cfg.Loki.BatchSize != 100 {
		t.Errorf("batch_size = %d, want %d", cfg.Loki.BatchSize, 100)
	}
}

func TestDefaults_MetricsListen(t *testing.T) {
	cfg := validConfig()
	if err := cfg.setDefaultsAndValidate(); err != nil {
		t.Fatalf("setDefaultsAndValidate() error = %v", err)
	}

	if cfg.Metrics.Listen != ":9101" {
		t.Errorf("metrics.listen = %q, want %q", cfg.Metrics.Listen, ":9101")
	}
}

func TestDefaults_LoggingLevel(t *testing.T) {
	cfg := validConfig()
	if err := cfg.setDefaultsAndValidate(); err != nil {
		t.Fatalf("setDefaultsAndValidate() error = %v", err)
	}

	if cfg.Logging.Level != "info" {
		t.Errorf("logging.level = %q, want %q", cfg.Logging.Level, "info")
	}
}

func TestDefaults_LoggingFormat(t *testing.T) {
	cfg := validConfig()
	if err := cfg.setDefaultsAndValidate(); err != nil {
		t.Fatalf("setDefaultsAndValidate() error = %v", err)
	}

	if cfg.Logging.Format != "json" {
		t.Errorf("logging.format = %q, want %q", cfg.Logging.Format, "json")
	}
}

func TestDefaults_PreserveExplicitValues(t *testing.T) {
	cfg := validConfig()
	cfg.Cloudflare.PollInterval = 10 * time.Minute
	cfg.Loki.TenantID = "custom"
	cfg.Loki.BatchSize = 50

	if err := cfg.setDefaultsAndValidate(); err != nil {
		t.Fatalf("setDefaultsAndValidate() error = %v", err)
	}

	if cfg.Cloudflare.PollInterval != 10*time.Minute {
		t.Errorf("explicit poll_interval overwritten: got %v", cfg.Cloudflare.PollInterval)
	}
	if cfg.Loki.TenantID != "custom" {
		t.Errorf("explicit tenant_id overwritten: got %q", cfg.Loki.TenantID)
	}
	if cfg.Loki.BatchSize != 50 {
		t.Errorf("explicit batch_size overwritten: got %d", cfg.Loki.BatchSize)
	}
}

// -------------------------------------------------------------------------
// VALIDATION
// -------------------------------------------------------------------------

func TestValidation_MissingAPIToken(t *testing.T) {
	cfg := validConfig()
	cfg.Cloudflare.APIToken = ""

	err := cfg.setDefaultsAndValidate()
	if err == nil {
		t.Error("validation should fail when api_token is empty")
	}
}

func TestValidation_MissingZoneID(t *testing.T) {
	cfg := validConfig()
	cfg.Cloudflare.ZoneID = ""

	err := cfg.setDefaultsAndValidate()
	if err == nil {
		t.Error("validation should fail when zone_id is empty")
	}
}

func TestValidation_MissingLokiEndpoint(t *testing.T) {
	cfg := validConfig()
	cfg.Loki.Endpoint = ""

	err := cfg.setDefaultsAndValidate()
	if err == nil {
		t.Error("validation should fail when loki.endpoint is empty")
	}
}

func TestValidation_MultipleErrors(t *testing.T) {
	cfg := Config{}

	err := cfg.setDefaultsAndValidate()
	if err == nil {
		t.Fatal("validation should fail with multiple errors")
	}

	// --- Should report all three missing required fields ---
	errStr := err.Error()
	if !contains(errStr, "api_token") || !contains(errStr, "zone_id") || !contains(errStr, "loki.endpoint") {
		t.Errorf("error should mention all missing fields, got: %v", err)
	}
}

// -------------------------------------------------------------------------
// LOG LEVEL
// -------------------------------------------------------------------------

func TestParseLogLevel(t *testing.T) {
	tests := []struct {
		input string
		want  slog.Level
	}{
		{"debug", slog.LevelDebug},
		{"info", slog.LevelInfo},
		{"warn", slog.LevelWarn},
		{"error", slog.LevelError},
		{"unknown", slog.LevelInfo},
		{"", slog.LevelInfo},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := ParseLogLevel(tt.input)
			if got != tt.want {
				t.Errorf("ParseLogLevel(%q) = %v, want %v", tt.input, got, tt.want)
			}
		})
	}
}

// -------------------------------------------------------------------------
// HELPERS
// -------------------------------------------------------------------------

// contains checks if s contains substr.
func contains(s, substr string) bool {
	return len(s) >= len(substr) && searchString(s, substr)
}

// searchString performs a naive substring search.
func searchString(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
