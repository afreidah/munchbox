// --------------------------------------------------------------------
// Shared utilities for Nomad CDKTF stacks
// File: common.go
// --------------------------------------------------------------------

// Package common provides shared utilities for Nomad CDKTF stacks.
package common

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"cdk.tf/go/stack/generated/hashicorp/nomad/aclpolicy"
	"cdk.tf/go/stack/generated/hashicorp/nomad/acltoken"
	"cdk.tf/go/stack/generated/hashicorp/nomad/provider"
	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"
)

// SetupProvider configures the Nomad provider for a stack using env vars.
func SetupProvider(stack cdktf.TerraformStack) {
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

// RegisterPolicies loads and registers all policies from a directory.
func RegisterPolicies(stack cdktf.TerraformStack, dir string) {
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
		aclpolicy.NewAclPolicy(stack, jsii.String(id), &aclpolicy.AclPolicyConfig{
			Name:     jsii.String(id),
			RulesHcl: jsii.String(hcl),
		})
	}
}

// RegisterTokens loads and registers all tokens from a directory.
func RegisterTokens(stack cdktf.TerraformStack, dir string) {
	tokenFiles, err := filepath.Glob(filepath.Join(dir, "*.hcl"))
	if err != nil {
		log.Fatalf("failed to glob token files: %v", err)
	}
	for _, f := range tokenFiles {
		id := strings.TrimSuffix(filepath.Base(f), ".hcl")
		// Use a sanitized version of the relative path for uniqueness
		relPath := strings.ReplaceAll(strings.TrimPrefix(f, dir), string(os.PathSeparator), "-")
		uniqueID := id + relPath
		acltoken.NewAclToken(stack, jsii.String(uniqueID), &acltoken.AclTokenConfig{
			Type:     jsii.String("client"),
			Policies: &[]*string{jsii.String(id)},
		})
	}
}
