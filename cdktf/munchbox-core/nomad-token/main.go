// --------------------------------------------------------------------
// Program: Nomad CDKTF Stack
// File: main.go
//
// Registers Nomad tokens from HCL files using the
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
	app := cdktf.NewApp(nil)
	stack := cdktf.NewTerraformStack(app, jsii.String("cdktf-nomad-tokens"))
	common.SetupProvider(stack)

	tokenFiles, err := filepath.Glob("*.hcl")
	if err != nil {
		panic(err)
	}
	for _, f := range tokenFiles {
		common.RegisterTokens(stack, f)
	}

	app.Synth()
}
