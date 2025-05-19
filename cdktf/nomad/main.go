package main

import (
	"os"
	"strings"
	"path/filepath"
	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"

	"cdk.tf/go/stack/generated/hashicorp/nomad/provider"
	"cdk.tf/go/stack/generated/hashicorp/nomad/job"
)

func main() {
	app := cdktf.NewApp(nil)
	stack := cdktf.NewTerraformStack(app, jsii.String("nomad"))
	provider.NewNomadProvider(stack, jsii.String("nomad-provider"), &provider.NomadProviderConfig{
		Address: jsii.String("http://192.168.1.225:4646"),
	})

	// files, err := filepath.Glob("../../nomad-jobs/*.nomad.hcl")
	files, err := filepath.Glob("*.nomad.hcl")
	if err != nil {
		panic(err)
	}

	for _, f := range files {
		// read the file
		raw, err := os.ReadFile(f)
		if err != nil {
			panic(err)
		}

		hcl := strings.ReplaceAll(string(raw), "${", "$${")
		id := strings.TrimSuffix(filepath.Base(f), ".nomad.hcl")

		// register the job
		job.NewJob(stack, jsii.String(id), &job.JobConfig{
			Jobspec: jsii.String(string(hcl)),
			DeregisterOnDestroy: true,
			PurgeOnDestroy:      true,
		})
	}


	app.Synth()
}
