// --------------------------------------------------------------------
// Program: Nomad CDKTF Stack
// File: main.go
//
// Registers Nomad jobs, policies, and tokens from HCL files using the
// Terraform CDK for Go. Uses shared library for common logic.
//
// Environment Variables:
//   JOBS                - Comma-separated list of jobs to deploy, or 'all' (default: all)
//   CONSUL_HTTP_TOKEN   - Consul management token for backend state storage (required)
//   NOMAD_CACERT        - Path to Nomad CA certificate (default: $HOME/.nomad/nomad-agent-ca.pem)
//   VAULT_TOKEN         - Vault token for authentication (required)
//   VAULT_ADDR          - Vault address (default: https://mccoy:8200)
//   NOMAD_ADDR          - Nomad address (default: https://192.168.68.63:4646)
//   CONSUL_HTTP_ADDR    - Consul address (default: http://127.0.0.1:8500)
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
	common.SetupConsulProvider(stack) // enable Consul resources
	common.SetupVaultProvider(stack)

	// --- Nomad resources ---
	common.RegisterNomadPolicies(stack, "nomad-policy")
	common.RegisterNomadTokens(stack, "nomad-token")
	common.RegisterNomadJobs(stack, "nomad-jobs", *jobsFlag)

	// --- Consul resources (policies + tokens) ---
	common.RegisterConsulPolicies(stack, "consul-policy")
	common.RegisterConsulTokens(stack, "consul-tokens")

	// --- Vault resources ---
	common.RegisterVaultPolicies(stack, "vault-policy")
	common.RegisterVaultKvMount(stack, "kv", "secret")

	// --- Vault JWT Auth for Nomad Workload Identity ---
	// Read the Nomad CA certificate for JWKS endpoint verification.
	// Checks NOMAD_CACERT env var first, falls back to default location.
	nomadCaCertPath := os.Getenv("NOMAD_CACERT")
	if nomadCaCertPath == "" {
		nomadCaCertPath = os.ExpandEnv("$HOME/.nomad/nomad-agent-ca.pem")
	}

	nomadCaCert, err := os.ReadFile(nomadCaCertPath)
	if err != nil {
		log.Fatalf("failed to read Nomad CA cert from %s (set NOMAD_CACERT env var if different): %v", nomadCaCertPath, err)
	}

	// Configure JWT auth backend with Nomad's JWKS endpoint.
	// Uses IP address (not hostname) to avoid DNS resolution issues.
	common.RegisterVaultJwtAuth(stack, "https://192.168.68.63:4646", string(nomadCaCert))

	app.Synth()
}
