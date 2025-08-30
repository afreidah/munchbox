// --------------------------------------------------------------------
// Program: Nomad CDKTF Stack
// File: main.go
//
// Registers Nomad policies from HCL files using the
// Terraform CDK for Go. Uses shared library for common logic.
// --------------------------------------------------------------------

package main

import (
	"cdk.tf/go/stack/common"
	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"
)

func main() {
	// --- Stack Initialization ---
	app := cdktf.NewApp(nil)
	stack := cdktf.NewTerraformStack(app, jsii.String("nomad-ops-read-policy"))

	// --- Provider Configuration (shared) ---
	common.SetupProvider(stack)

	// --- Policy Registration (shared) ---
	common.RegisterPolicies(stack, ".")

	app.Synth()
}
