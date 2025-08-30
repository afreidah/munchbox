// --------------------------------------------------------------------
// Program: Nomad CDKTF Stack
// File: main.go
//
// Registers Nomad policies from HCL files using the
// Terraform CDK for Go. Uses shared library for common logic.
// --------------------------------------------------------------------

package main

import (
	"path/filepath"

	"cdk.tf/go/stack/common"
	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"
)

func main() {
	// --- Stack Initialization ---
	app := cdktf.NewApp(nil)
	stack := cdktf.NewTerraformStack(app, jsii.String("cdktf-nomad-policies"))

	// --- Provider Configuration (shared) ---
	common.SetupProvider(stack)

	// --- Policy Registration (shared) ---
	policyFiles, err := filepath.Glob("*.hcl")
	if err != nil {
		panic(err)
	}
	for _, f := range policyFiles {
		common.RegisterPolicies(stack, f)
	}

	app.Synth()
}
