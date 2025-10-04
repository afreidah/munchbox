// --------------------------------------------------------------------
// Program: Nomad CDKTF Stack
// File: main.go
//
// UPDATES:
//   - Uses enhanced RegisterNomadJobs with automatic metadata injection
//   - No changes required - common functions handle all the work
//
// Registers Nomad jobs, policies, and tokens from HCL files using the
// Terraform CDK for Go. Uses shared library for common logic.
// --------------------------------------------------------------------

package main

import (
	"flag"
	"log"
	"os"
	"strings"

	"cdk.tf/go/stack/common"

	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"
)

func main() {
	// --- CLI Flags for jobs ---
	jobsEnv := strings.TrimSpace(os.Getenv("JOBS"))
	if jobsEnv == "" {
		jobsEnv = "all"
	}
	jobsFlag := flag.String("jobs", jobsEnv, "Comma-separated list of jobs to process, or 'all'")
	flag.Parse()

	// --- Stack Initialization ---
	app := cdktf.NewApp(&cdktf.AppConfig{
		Context: &map[string]interface{}{
			"disableDefaultBackend": true,
		},
	})
	stack := cdktf.NewTerraformStack(app, jsii.String("nomad"))

	// --- Backend configuration ---
	stack.AddOverride(jsii.String("terraform.backend.local"), cdktf.Token_NullValue())
	cdkftConsulToken := os.Getenv("CONSUL_HTTP_TOKEN") // mgmt/admin token for backend
	cdktf.NewConsulBackend(stack, &cdktf.ConsulBackendConfig{
		Address:     jsii.String("mccoy:8500"),
		Path:        jsii.String("cdktf/terraform.tfstate"),
		Scheme:      jsii.String("http"),
		AccessToken: jsii.String(cdkftConsulToken),
	})

	// --- Providers ---
	common.SetupNomadProvider(stack)
	common.SetupConsulProvider(stack)
	common.SetupVaultProvider(stack)

	// --- Nomad resources ---
	// Policies and tokens remain unchanged
	common.RegisterNomadPolicies(stack, "infra/nomad-policy")
	common.RegisterNomadTokens(stack, "infra/nomad-token")

	// Jobs now use enhanced function with automatic metadata injection
	// The function automatically:
	//   - Discovers jobs recursively in subdirectories
	//   - Infers category from directory structure
	//   - Injects metadata for jobs without meta blocks
	//   - Updates deployment info for jobs with existing metadata
	//   - Validates all metadata before registration
	common.RegisterNomadJobs(stack, "infra/nomad-jobs", *jobsFlag)

	// --- Consul resources (policies + tokens) ---
	common.RegisterConsulPolicies(stack, "infra/consul-policy")
	common.RegisterConsulTokens(stack, "infra/consul-tokens")

	// --- Vault resources ---
	common.RegisterVaultPolicies(stack, "infra/vault-policy")
	common.RegisterVaultKvMount(stack, "kv", "secret")

	// Configure JWT auth for Nomad workload identity
	nomadCaCert, err := os.ReadFile(os.Getenv("VAULT_CACERT"))
	if err != nil {
		log.Fatalf("failed to read Nomad CA cert: %v", err)
	}
	common.RegisterVaultJwtAuth(stack, "https://192.168.68.63:4646", string(nomadCaCert))

	app.Synth()
}
