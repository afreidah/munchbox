// --------------------------------------------------------------------
// Vault provider utilities for CDKTF
// File: common/vault.go
//
// Functions:
//   - SetupVaultProvider(): Configure Vault provider for Terraform
//   - RegisterVaultPolicies(): Register Vault policies
//   - RegisterVaultKvMount(): Create KV v2 secrets engine mount
//   - RegisterVaultJwtAuth(): Configure JWT auth for Nomad workloads
// --------------------------------------------------------------------

package common

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"

	vaultjwtauthbackend "cdk.tf/go/stack/generated/hashicorp/vault/jwtauthbackend"
	vaultjwtauthbackendrole "cdk.tf/go/stack/generated/hashicorp/vault/jwtauthbackendrole"
	vaultmount "cdk.tf/go/stack/generated/hashicorp/vault/mount"
	vaultpolicy "cdk.tf/go/stack/generated/hashicorp/vault/policy"
	vaultprovider "cdk.tf/go/stack/generated/hashicorp/vault/provider"
)

// ============================================================================
// Vault Provider Setup
// ============================================================================

// SetupVaultProvider configures the Vault provider for Terraform CDK.
//
// Configuration sources:
//  1. Environment variables (VAULT_ADDR, VAULT_TOKEN)
//  2. Default address: https://mccoy:8200
//
// Parameters:
//   - stack: CDKTF Terraform stack
func SetupVaultProvider(stack cdktf.TerraformStack) {
	addr := os.Getenv("VAULT_ADDR")
	if addr == "" {
		addr = "https://mccoy:8200"
	}
	tokenEnv := os.Getenv("VAULT_TOKEN")
	cfg := &vaultprovider.VaultProviderConfig{
		Address:       jsii.String(addr),
		SkipTlsVerify: jsii.Bool(true),
	}
	if tokenEnv != "" {
		cfg.Token = jsii.String(tokenEnv)
	}
	vaultprovider.NewVaultProvider(stack, jsii.String("vault-provider"), cfg)
}

// ============================================================================
// Vault Policy Registration
// ============================================================================

// RegisterVaultPolicies registers Vault policies from HCL files.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - dir: Directory containing policy HCL files
func RegisterVaultPolicies(stack cdktf.TerraformStack, dir string) {
	policyFiles, err := filepath.Glob(filepath.Join(dir, "*.hcl"))
	if err != nil {
		log.Fatalf("failed to glob vault policy files: %v", err)
	}
	for _, f := range policyFiles {
		id := strings.TrimSuffix(filepath.Base(f), ".hcl")
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read vault policy file %s: %v", f, err)
			continue
		}
		vaultpolicy.NewPolicy(stack, jsii.String(id), &vaultpolicy.PolicyConfig{
			Name:   jsii.String(id),
			Policy: jsii.String(string(raw)),
		})
	}
}

// ============================================================================
// Vault KV Mount
// ============================================================================

// RegisterVaultKvMount creates a KV v2 secrets engine mount in Vault.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - id: Unique identifier for the mount resource
//   - path: Mount path in Vault
//
// Returns:
//   - vaultmount.Mount: The created mount resource
func RegisterVaultKvMount(stack cdktf.TerraformStack, id string, path string) vaultmount.Mount {
	return vaultmount.NewMount(stack, jsii.String(id), &vaultmount.MountConfig{
		Path: jsii.String(path),
		Type: jsii.String("kv"),
		Options: &map[string]*string{
			"version": jsii.String("2"),
		},
	})
}

// ============================================================================
// Vault JWT Auth Configuration
// ============================================================================

// RegisterVaultJwtAuth configures JWT authentication for Nomad workload identity.
//
// Creates a JWT auth backend and two roles:
//   - nomad-workloads: Generic role for all Nomad workloads
//   - nomad-grafana: Specific role for Grafana with additional policies
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - nomadUrl: Nomad server URL (for JWKS and issuer validation)
//   - nomadCaCert: CA certificate for Nomad TLS verification
func RegisterVaultJwtAuth(stack cdktf.TerraformStack, nomadUrl string, nomadCaCert string) {
	backend := vaultjwtauthbackend.NewJwtAuthBackend(stack,
		jsii.String("jwt-auth-backend"),
		&vaultjwtauthbackend.JwtAuthBackendConfig{
			Path:        jsii.String("jwt-nomad"),
			Description: jsii.String("JWT auth for Nomad workload identity"),
			JwksUrl:     jsii.String(nomadUrl + "/.well-known/jwks.json"),
			JwksCaPem:   jsii.String(nomadCaCert),
			BoundIssuer: jsii.String(nomadUrl),
			DefaultRole: jsii.String("nomad-workloads"),
		},
	)

	vaultjwtauthbackendrole.NewJwtAuthBackendRole(
		stack,
		jsii.String("jwt-nomad-workloads-role"),
		&vaultjwtauthbackendrole.JwtAuthBackendRoleConfig{
			Backend:              backend.Path(),
			RoleName:             jsii.String("nomad-workloads"),
			RoleType:             jsii.String("jwt"),
			BoundAudiences:       &[]*string{jsii.String("vault.io")},
			UserClaim:            jsii.String("/nomad_job_id"),
			UserClaimJsonPointer: jsii.Bool(true),
			ClaimMappings: &map[string]*string{
				"nomad_job_id":    jsii.String("nomad_job_id"),
				"nomad_namespace": jsii.String("nomad_namespace"),
				"nomad_task":      jsii.String("nomad_task"),
			},
			TokenType: jsii.String("service"),
			TokenPolicies: &[]*string{
				jsii.String("default"),
				jsii.String("docker-registry-read"),
			},
			TokenPeriod: jsii.Number(3600),
		},
	)

	vaultjwtauthbackendrole.NewJwtAuthBackendRole(
		stack,
		jsii.String("jwt-nomad-grafana-role"),
		&vaultjwtauthbackendrole.JwtAuthBackendRoleConfig{
			Backend:              backend.Path(),
			RoleName:             jsii.String("nomad-grafana"),
			RoleType:             jsii.String("jwt"),
			BoundAudiences:       &[]*string{jsii.String("vault.io")},
			UserClaim:            jsii.String("/nomad_job_id"),
			UserClaimJsonPointer: jsii.Bool(true),
			BoundClaims: &map[string]*string{
				"nomad_namespace": jsii.String("default"),
				"nomad_job_id":    jsii.String("grafana"),
			},
			ClaimMappings: &map[string]*string{
				"nomad_job_id":    jsii.String("nomad_job_id"),
				"nomad_namespace": jsii.String("nomad_namespace"),
				"nomad_task":      jsii.String("nomad_task"),
			},
			TokenType:     jsii.String("service"),
			TokenPolicies: &[]*string{jsii.String("default"), jsii.String("cdktf-grafana-read")},
			TokenPeriod:   jsii.Number(3600),
		},
	)
}
