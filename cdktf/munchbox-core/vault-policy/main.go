// --------------------------------------------------------------------
// Program: Vault CDKTF Stack
// File: main.go
//
// Registers Vault policies from HCL files using the
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
	stack := cdktf.NewTerraformStack(app, jsii.String("cdktf-vault-policies"))

	// --- Provider Configuration (shared) ---
	common.SetupVaultProvider(stack) // You need to implement this if not already present

	// --- Policy Registration (shared) ---
	policyFiles, err := filepath.Glob("*.hcl")
	if err != nil {
		panic(err)
	}
	for _, f := range policyFiles {
		common.RegisterVaultPolicies(stack, f) // You need to implement this function
	}

	app.Synth()
}
