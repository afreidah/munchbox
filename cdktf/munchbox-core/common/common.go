// --------------------------------------------------------------------
// Shared utilities for Nomad CDKTF stacks
// File: common.go
// --------------------------------------------------------------------

// Package common provides shared utilities for Nomad CDKTF stacks.
package common

// ============================================================================
// Imports — CDKTF core + Generated Providers (Nomad, Consul, Vault)
// - Use unique aliases to avoid collisions between Nomad and Consul resources.
// - If you don't need Vault yet, drop the vault* lines and related code.
// ============================================================================
import (
	// Standard lib

	"log"
	"os"
	"path/filepath"
	"strings"

	// CDKTF core
	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"

	// --- Consul (generated) ---
	//consulacltoken "cdk.tf/go/stack/generated/hashicorp/consul/acltoken"
	//consulprovider "cdk.tf/go/stack/generated/hashicorp/consul/provider"
	"cdk.tf/go/stack/generated/hashicorp/nomad/aclpolicy"
	"cdk.tf/go/stack/generated/hashicorp/nomad/acltoken"
	"cdk.tf/go/stack/generated/hashicorp/nomad/job"
	"cdk.tf/go/stack/generated/hashicorp/nomad/provider"

	// --- Vault (generated) ---
	vaultmount "cdk.tf/go/stack/generated/hashicorp/vault/mount"
	vaultpolicy "cdk.tf/go/stack/generated/hashicorp/vault/policy"
	vaultprovider "cdk.tf/go/stack/generated/hashicorp/vault/provider"
)

// SetupNomadProvider configures the Nomad provider for a stack using env vars.
func SetupNomadProvider(stack cdktf.TerraformStack) {
	addr := os.Getenv("NOMAD_ADDR")
	if addr == "" {
		addr = "https://192.168.68.63:4646"
	}
	tokenEnv := os.Getenv("NOMAD_TOKEN")
	cacert := os.Getenv("NOMAD_CACERT")
	cfg := &provider.NomadProviderConfig{
		Address: jsii.String(addr),
	}
	if tokenEnv != "" {
		cfg.SecretId = jsii.String(tokenEnv)
	}
	if cacert != "" {
		cfg.CaFile = jsii.String(cacert)
	}
	provider.NewNomadProvider(stack, jsii.String("nomad-provider"), cfg)
}

// SetupVaultProvider configures the Vault provider for a stack using env vars.
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

// RegisterNomadJobs loads and registers Nomad jobs from a directory, filtered by jobsFlag.
func RegisterNomadJobs(stack cdktf.TerraformStack, dir string, jobsFlag string) {
	files, err := filepath.Glob(filepath.Join(dir, "*.nomad.hcl"))
	if err != nil {
		log.Fatalf("failed to glob job files: %v", err)
	}

	selected := map[string]bool{}
	if jobsFlag == "" {
		jobsFlag = "all" // default to all when empty
	}

	if jobsFlag != "all" {
		for _, name := range strings.Split(jobsFlag, ",") {
			name = strings.TrimSpace(name)
			if name != "" {
				selected[name] = true
			}
		}
	}

	for _, f := range files {
		id := strings.TrimSuffix(filepath.Base(f), ".nomad.hcl")
		if jobsFlag != "all" && !selected[id] {
			continue
		}
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read file %s: %v", f, err)
			continue
		}
		// Escape ${...} so Terraform doesn't try to template Nomad HCL
		hcl := strings.ReplaceAll(string(raw), "${", "$${")
		registerJob(stack, id, hcl)
	}
}

// Register a Nomad job resource from HCL
func registerJob(stack cdktf.TerraformStack, id string, hcl string) {
	job.NewJob(stack, jsii.String(id), &job.JobConfig{
		Jobspec:             jsii.String(hcl),
		DeregisterOnDestroy: jsii.Bool(true),
		PurgeOnDestroy:      jsii.Bool(true),
	})
}

// RegisterNomadPolicies loads and registers all policies from a directory.
func RegisterNomadPolicies(stack cdktf.TerraformStack, dir string) {
	policyFiles, err := filepath.Glob(filepath.Join(dir, "*.hcl"))
	if err != nil {
		log.Fatalf("failed to glob policy files: %v", err)
	}
	for _, f := range policyFiles {
		id := strings.TrimSuffix(filepath.Base(f), ".hcl")
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read policy file %s: %v", f, err)
			continue
		}
		hcl := strings.ReplaceAll(string(raw), "${", "$${")
		uniqueID := id + "-policy"
		aclpolicy.NewAclPolicy(stack, jsii.String(uniqueID), &aclpolicy.AclPolicyConfig{
			Name:     jsii.String(id),
			RulesHcl: jsii.String(hcl),
		})
	}
}

// RegisterNomadTokens loads and registers all tokens from a directory.
func RegisterNomadTokens(stack cdktf.TerraformStack, dir string) {
	tokenFiles, err := filepath.Glob(filepath.Join(dir, "*.hcl"))
	if err != nil {
		log.Fatalf("failed to glob token files: %v", err)
	}
	for _, f := range tokenFiles {
		id := strings.TrimSuffix(filepath.Base(f), ".hcl")
		uniqueID := id + "-token"
		acltoken.NewAclToken(stack, jsii.String(uniqueID), &acltoken.AclTokenConfig{
			Type:     jsii.String("client"),
			Name:     jsii.String(id),
			Policies: &[]*string{jsii.String(id)},
		})
	}
}

// RegisterVaultPolicies loads and registers all Vault policies from a directory.
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

// RegisterVaultKvMount registers a KV v2 secrets engine at the given path.
func RegisterVaultKvMount(stack cdktf.TerraformStack, id string, path string) vaultmount.Mount {
	return vaultmount.NewMount(stack, jsii.String(id), &vaultmount.MountConfig{
		Path: jsii.String(path),
		Type: jsii.String("kv"),
		Options: &map[string]*string{
			"version": jsii.String("2"),
		},
	})
}
