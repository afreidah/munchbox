// filepath: /path/to/your/file.go
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

// Package common
package common

import (
	"io/ioutil"
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
func RegisterVaultJwtAuth(stack cdktf.TerraformStack, nomadUrl string, nomadCaCert string) {
	backend := vaultjwtauthbackend.NewJwtAuthBackend(stack,
		jsii.String("jwt-auth-backend"),
		&vaultjwtauthbackend.JwtAuthBackendConfig{
			Path:        jsii.String("jwt-nomad"),
			Description: jsii.String("JWT auth for Nomad workload identity"),
			JwksUrl:     jsii.String(nomadUrl + "/.well-known/jwks.json"),
			JwksCaPem:   jsii.String(nomadCaCert),
			BoundIssuer: jsii.String(nomadUrl),
			DefaultRole: jsii.String("nomad-workloads"), // This should remain as 'nomad-workloads'
		},
	)

	policies, err := loadVaultPolicies("infra/vault-policy")
	if err != nil {
		log.Printf("failed to load vault policies: %v", err)
		return
	}

	// Create the roles with the correct names
	createJwtAuthBackendRole(stack, *backend.Path(), "nomad-workloads", nil, policies) // Correct role name for workloads
	createJwtAuthBackendRole(stack, *backend.Path(), "nomad-grafana", &map[string]*string{
		"nomad_namespace": jsii.String("default"),
		"nomad_job_id":    jsii.String("grafana"),
	}, []*string{
		jsii.String("cdktf-grafana-read"),
		jsii.String("default"),
	}) // Correct role name for Grafana
}

// LoadVaultPolicies dynamically loads policies from the specified directory.
func loadVaultPolicies(directory string) ([]*string, error) {
	var policies []*string

	files, err := ioutil.ReadDir(directory)
	if err != nil {
		return nil, err
	}

	for _, file := range files {
		if filepath.Ext(file.Name()) == ".hcl" {
			policyName := strings.TrimSuffix(file.Name(), ".hcl")
			policies = append(policies, jsii.String(policyName)) // Use original policy name
		}
	}
	return policies, nil
}

// CreateJwtAuthBackendRole creates a JWT auth backend role.
func createJwtAuthBackendRole(stack cdktf.TerraformStack, backendPath string, roleName string, boundClaims *map[string]*string, tokenPolicies []*string) {
	vaultjwtauthbackendrole.NewJwtAuthBackendRole(
		stack,
		jsii.String("jwt-"+roleName+"-role"), // Use the correct name
		&vaultjwtauthbackendrole.JwtAuthBackendRoleConfig{
			Backend:              jsii.String(backendPath),
			RoleName:             jsii.String(roleName), // This should match existing roles
			RoleType:             jsii.String("jwt"),
			BoundAudiences:       &[]*string{jsii.String("vault.io")},
			UserClaim:            jsii.String("/nomad_job_id"),
			UserClaimJsonPointer: jsii.Bool(true),
			BoundClaims:          boundClaims,
			ClaimMappings: &map[string]*string{
				"nomad_job_id":    jsii.String("nomad_job_id"),
				"nomad_namespace": jsii.String("nomad_namespace"),
				"nomad_task":      jsii.String("nomad_task"),
			},
			TokenType:     jsii.String("service"),
			TokenPolicies: &tokenPolicies,
			TokenPeriod:   jsii.Number(3600),
		},
	)
}
