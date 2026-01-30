// -------------------------------------------------------------------------------
// Oracle Watchdog - Configuration
//
// Project: Munchbox / Author: Alex Freidah
//
// Loads and validates agent configuration from YAML. Defines node mappings
// between Consul session names and OCI instance identifiers for restart
// orchestration.
// -------------------------------------------------------------------------------

package config

import (
	"fmt"
	"os"
	"time"

	"gopkg.in/yaml.v3"
)

// Config holds agent configuration for monitoring Oracle nodes.
type Config struct {
	// Timeout defines how long a node must be unresponsive before restart.
	Timeout time.Duration `yaml:"timeout"`

	// CheckInterval defines how often to scan for missing sessions.
	CheckInterval time.Duration `yaml:"check_interval"`

	// Consul connection settings.
	ConsulAddress string `yaml:"consul_address"`

	// OCI authentication settings.
	OCI OCIConfig `yaml:"oci"`

	// Nodes lists Oracle instances to monitor.
	Nodes []NodeConfig `yaml:"nodes"`

	// DryRun logs restart actions without executing them.
	DryRun bool `yaml:"-"`

	// MaxRestartAttempts limits consecutive restarts before giving up.
	// Zero means unlimited. Counter resets when node recovers.
	MaxRestartAttempts int `yaml:"max_restart_attempts"`
}

// OCIConfig holds Oracle Cloud authentication settings.
type OCIConfig struct {
	ConfigPath string `yaml:"config_path"` // Path to OCI config file
	Profile    string `yaml:"profile"`     // OCI config profile name
}

// NodeConfig maps a Consul session name to an OCI instance.
type NodeConfig struct {
	Name          string `yaml:"name"`           // Consul session/node name
	InstanceID    string `yaml:"instance_id"`    // OCI instance OCID
	CompartmentID string `yaml:"compartment_id"` // OCI compartment OCID
}

// Load reads and validates configuration from a YAML file.
func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read config: %w", err)
	}

	cfg := &Config{
		// Defaults
		Timeout:       5 * time.Minute,
		CheckInterval: 30 * time.Second,
		ConsulAddress: "consul.service.consul:8500",
		OCI: OCIConfig{
			ConfigPath: "~/.oci/config",
			Profile:    "DEFAULT",
		},
	}

	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}

	if err := cfg.validate(); err != nil {
		return nil, fmt.Errorf("validate config: %w", err)
	}

	return cfg, nil
}

func (c *Config) validate() error {
	if len(c.Nodes) == 0 {
		return fmt.Errorf("no nodes configured")
	}

	for i, n := range c.Nodes {
		if n.Name == "" {
			return fmt.Errorf("node[%d]: missing name", i)
		}
		if n.InstanceID == "" {
			return fmt.Errorf("node[%d] %q: missing instance_id", i, n.Name)
		}
		if n.CompartmentID == "" {
			return fmt.Errorf("node[%d] %q: missing compartment_id", i, n.Name)
		}
	}

	if c.Timeout < time.Minute {
		return fmt.Errorf("timeout must be at least 1 minute")
	}

	return nil
}
