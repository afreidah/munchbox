// --------------------------------------------------------------------
// Program: Nomad CDKTF Stack
// File: main.go
//
// Registers Nomad jobs, policies, and tokens from HCL files using the
// Terraform CDK for Go. Uses shared library for common logic.
// --------------------------------------------------------------------

package main

import (
	"flag"
	"os"
	"strings"

	"cdk.tf/go/stack/common"

	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"
)

// ============================================================================
// Imports — CDKTF core + Generated Providers (Nomad, Consul, Vault)
// ============================================================================

func main() {
	// --- CLI Flags for jobs ---
	jobsEnv := strings.TrimSpace(os.Getenv("JOBS"))
	if jobsEnv == "" {
		jobsEnv = "all" // default to all when JOBS is unset/empty
	}
	jobsFlag := flag.String("jobs", jobsEnv, "Comma-separated list of jobs to process, or 'all'")
	flag.Parse()

	// --- Stack Initialization ---
	app := cdktf.NewApp(&cdktf.AppConfig{
		Context: &map[string]interface{}{
			"disableDefaultBackend": true, // <- stops CDKTF from adding "local"
		},
	})
	stack := cdktf.NewTerraformStack(app, jsii.String("nomad"))

	// --- Backend configuration (ONLY changes below) ---
	// Ensure any default "local" backend is removed, then set Consul backend.
	stack.AddOverride(jsii.String("terraform.backend.local"), cdktf.Token_NullValue())
	cdktf.NewConsulBackend(stack, &cdktf.ConsulBackendConfig{
		Address:     jsii.String("mccoy:8500"),
		Path:        jsii.String("cdktf/terraform.tfstate"),
		Scheme:      jsii.String("http"),
		AccessToken: jsii.String(os.Getenv("CONSUL_HTTP_TOKEN")), // required by construct
	})

	// --- Nomad Job, Policy, and Token Registration ---
	common.SetupNomadProvider(stack)
	common.RegisterNomadPolicies(stack, "nomad-policy")
	common.RegisterNomadTokens(stack, "nomad-token")
	common.RegisterNomadJobs(stack, "nomad-jobs/jobs", *jobsFlag)

	// --- Vault Policy Registration (shared) ---
	common.SetupVaultProvider(stack)
	common.RegisterVaultPolicies(stack, "vault-policy")
	common.RegisterVaultKvMount(stack, "kv", "secret")

	// --- Consul Policy and Token Registration ---
	//common.SetupConsulProvider(stack)
	//common.Register

	app.Synth()
}
