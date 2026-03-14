// -------------------------------------------------------------------------------
// Configuration - Cloudflare Log Collector Settings
//
// Author: Alex Freidah
//
// YAML configuration loader with environment variable expansion using ${VAR}
// syntax. Validates required fields and applies defaults for optional settings.
// -------------------------------------------------------------------------------

package config

import (
	"fmt"
	"log/slog"
	"os"
	"time"

	"gopkg.in/yaml.v3"
)

// -------------------------------------------------------------------------
// CONFIGURATION TYPES
// -------------------------------------------------------------------------

// Config holds the complete service configuration.
type Config struct {
	Cloudflare CloudflareConfig `yaml:"cloudflare"`
	Loki       LokiConfig       `yaml:"loki"`
	Metrics    MetricsConfig    `yaml:"metrics"`
	Tracing    TracingConfig    `yaml:"tracing"`
	Logging    LoggingConfig    `yaml:"logging"`
}

// CloudflareConfig holds Cloudflare API connection settings.
type CloudflareConfig struct {
	APIToken       string        `yaml:"api_token"`
	ZoneID         string        `yaml:"zone_id"`
	PollInterval   time.Duration `yaml:"poll_interval"`
	BackfillWindow time.Duration `yaml:"backfill_window"`
}

// LokiConfig holds Loki push API settings.
type LokiConfig struct {
	Endpoint  string `yaml:"endpoint"`
	TenantID  string `yaml:"tenant_id"`
	BatchSize int    `yaml:"batch_size"`
}

// MetricsConfig holds Prometheus metrics endpoint settings.
type MetricsConfig struct {
	Listen string `yaml:"listen"`
}

// TracingConfig holds OpenTelemetry tracing settings.
type TracingConfig struct {
	Enabled    bool    `yaml:"enabled"`
	Endpoint   string  `yaml:"endpoint"`
	SampleRate float64 `yaml:"sample_rate"`
	Insecure   bool    `yaml:"insecure"`
}

// LoggingConfig holds structured logging settings.
type LoggingConfig struct {
	Level  string `yaml:"level"`
	Format string `yaml:"format"`
}

// -------------------------------------------------------------------------
// LOADING
// -------------------------------------------------------------------------

// LoadConfig reads the YAML file at path, expands environment variables, and
// returns a validated Config.
func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	// --- Expand environment variables ---
	expanded := os.Expand(string(data), os.Getenv)

	var cfg Config
	if err := yaml.Unmarshal([]byte(expanded), &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse config: %w", err)
	}

	if err := cfg.setDefaultsAndValidate(); err != nil {
		return nil, fmt.Errorf("invalid config: %w", err)
	}

	return &cfg, nil
}

// -------------------------------------------------------------------------
// VALIDATION
// -------------------------------------------------------------------------

// setDefaultsAndValidate applies default values for optional fields and checks
// that all required configuration values are present.
func (c *Config) setDefaultsAndValidate() error {
	var errors []string

	// --- Cloudflare defaults and validation ---
	if c.Cloudflare.APIToken == "" {
		errors = append(errors, "cloudflare.api_token is required")
	}
	if c.Cloudflare.ZoneID == "" {
		errors = append(errors, "cloudflare.zone_id is required")
	}
	if c.Cloudflare.PollInterval == 0 {
		c.Cloudflare.PollInterval = 5 * time.Minute
	}
	if c.Cloudflare.BackfillWindow == 0 {
		c.Cloudflare.BackfillWindow = 1 * time.Hour
	}

	// --- Loki defaults and validation ---
	if c.Loki.Endpoint == "" {
		errors = append(errors, "loki.endpoint is required")
	}
	if c.Loki.TenantID == "" {
		c.Loki.TenantID = "fake"
	}
	if c.Loki.BatchSize == 0 {
		c.Loki.BatchSize = 100
	}

	// --- Metrics defaults ---
	if c.Metrics.Listen == "" {
		c.Metrics.Listen = ":9101"
	}

	// --- Logging defaults ---
	if c.Logging.Level == "" {
		c.Logging.Level = "info"
	}
	if c.Logging.Format == "" {
		c.Logging.Format = "json"
	}

	if len(errors) > 0 {
		return fmt.Errorf("%d validation error(s): %v", len(errors), errors)
	}

	return nil
}

// ParseLogLevel maps a config string to an slog.Level.
func ParseLogLevel(s string) slog.Level {
	switch s {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
