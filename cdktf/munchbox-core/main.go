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
  //common.SetupConsulProvider(stack) // NEW: enable Consul resources
  common.SetupVaultProvider(stack)

  // --- Nomad resources ---
  common.RegisterNomadPolicies(stack, "nomad-policy")
  common.RegisterNomadTokens(stack, "nomad-token")
  common.RegisterNomadJobs(stack, "nomad-jobs/jobs", *jobsFlag)

  // --- Consul resources (policies + tokens) ---
  //common.RegisterConsulPolicies(stack, "consul-policy")
  //common.RegisterConsulTokens(stack, "consul-tokens")

  // --- Vault resources ---
  common.RegisterVaultPolicies(stack, "vault-policy")
  common.RegisterVaultKvMount(stack, "kv", "secret")

  app.Synth()
}

