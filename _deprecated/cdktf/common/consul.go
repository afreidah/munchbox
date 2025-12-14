// -------------------------------------------------------------------------------
// Consul Provider Utilities for CDKTF
//
// Project: Munchbox / Author: Alex Freidah
//
// Provides Consul provider setup and resource registration functions including
// ACL policies and tokens with KV synchronization support.
// -------------------------------------------------------------------------------

package common

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"

	consulaclpolicy "cdk.tf/go/stack/generated/hashicorp/consul/aclpolicy"
	consulacltoken "cdk.tf/go/stack/generated/hashicorp/consul/acltoken"
	consulprovider "cdk.tf/go/stack/generated/hashicorp/consul/provider"

	nullprovider "cdk.tf/go/stack/generated/hashicorp/null/provider"
	nullresource "cdk.tf/go/stack/generated/hashicorp/null/resource"

	"gopkg.in/yaml.v3"
)

// ============================================================================
// Consul Provider Setup
// ============================================================================

// SetupConsulProvider configures the Consul provider for Terraform CDK.
//
// Configuration sources:
//  1. Environment variables (CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN)
//  2. Default address: http://127.0.0.1:8500
//
// Parameters:
//   - stack: CDKTF Terraform stack
func SetupConsulProvider(stack cdktf.TerraformStack) {
	addr := os.Getenv("CONSUL_HTTP_ADDR")
	if addr == "" {
		addr = "http://127.0.0.1:8500"
	}
	token := os.Getenv("CONSUL_HTTP_TOKEN")
	cfg := &consulprovider.ConsulProviderConfig{
		Address: jsii.String(addr),
	}
	if token != "" {
		cfg.Token = jsii.String(token)
	}
	consulprovider.NewConsulProvider(stack, jsii.String("consul-provider"), cfg)
}

// ============================================================================
// Consul Policy Registration
// ============================================================================

// RegisterConsulPolicies registers Consul ACL policies from HCL files.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - dir: Directory containing policy HCL files
func RegisterConsulPolicies(stack cdktf.TerraformStack, dir string) {
	files, err := filepath.Glob(filepath.Join(dir, "*.hcl"))
	if err != nil {
		log.Fatalf("failed to glob consul policy files: %v", err)
	}
	for _, f := range files {
		if strings.HasSuffix(f, ".nomad.hcl") {
			continue
		}
		id := strings.TrimSuffix(filepath.Base(f), ".hcl")
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read consul policy %s: %v", f, err)
			continue
		}
		consulaclpolicy.NewAclPolicy(
			stack,
			jsii.String("consul-policy-"+id),
			&consulaclpolicy.AclPolicyConfig{
				Name:  jsii.String(id),
				Rules: jsii.String(string(raw)),
			},
		)
	}
}

// ============================================================================
// Consul Token Specification
// ============================================================================

// ConsulTokenSpec defines the structure for Consul token YAML files.
type ConsulTokenSpec struct {
	Name        string   `yaml:"name"`
	Description string   `yaml:"description"`
	Local       bool     `yaml:"local"`
	Policies    []string `yaml:"policies"`
	Roles       []string `yaml:"roles"`
	KvPath      string   `yaml:"kv_path"`
}

// ============================================================================
// Consul Token Registration
// ============================================================================

// RegisterConsulTokens registers Consul ACL tokens from YAML files and
// optionally syncs token secrets to Consul KV.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - dir: Directory containing token YAML files
func RegisterConsulTokens(stack cdktf.TerraformStack, dir string) {
	nullprovider.NewNullProvider(stack, jsii.String("null-provider"), &nullprovider.NullProviderConfig{})

	files, err := filepath.Glob(filepath.Join(dir, "*.yml"))
	if err != nil {
		log.Fatalf("failed to glob consul token files: %v", err)
	}
	for _, f := range files {
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read consul token file %s: %v", f, err)
			continue
		}
		var spec ConsulTokenSpec
		if err := yaml.Unmarshal(raw, &spec); err != nil {
			log.Printf("failed to parse yaml %s: %v", f, err)
			continue
		}
		if spec.Name == "" {
			spec.Name = strings.TrimSuffix(filepath.Base(f), ".yml")
		}
		var pols []*string
		for _, p := range spec.Policies {
			pols = append(pols, jsii.String(p))
		}

		t := consulacltoken.NewAclToken(
			stack,
			jsii.String("consul-token-"+spec.Name),
			&consulacltoken.AclTokenConfig{
				Description: jsii.String(spec.Description),
				Local:       jsii.Bool(spec.Local),
				Policies:    &pols,
			},
		)

		if spec.KvPath != "" {
			nr := nullresource.NewResource(
				stack,
				jsii.String("consul-token-sync-"+spec.Name),
				&nullresource.ResourceConfig{
					Triggers: &map[string]*string{
						"accessor": t.AccessorId(),
						"kv_path":  jsii.String(spec.KvPath),
					},
				},
			)

			nr.AddOverride(jsii.String("provisioner"), []interface{}{
				map[string]interface{}{
					"local-exec": map[string]interface{}{
						"interpreter": []string{"/bin/sh", "-c"},
						"command":     "SECRET=$(consul acl token read -id ${self.triggers.accessor} -format=json | awk -F\\\" '/SecretID/{print $4; exit}'); test -n \"$SECRET\" && consul kv put ${self.triggers.kv_path} \"$SECRET\"",
					},
				},
			})
		}
	}
}
