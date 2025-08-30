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
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"

	"cdk.tf/go/stack/common"

	"cdk.tf/go/stack/generated/hashicorp/nomad/job"
)

// Register a Nomad job resource from HCL
func register_job(stack cdktf.TerraformStack, id string, hcl string) {
	job.NewJob(stack, jsii.String(id), &job.JobConfig{
		Jobspec:             jsii.String(hcl),
		DeregisterOnDestroy: jsii.Bool(true),
		PurgeOnDestroy:      jsii.Bool(true),
	})
}

func main() {
	// --- CLI Flags for jobs ---
	jobsEnv := os.Getenv("JOBS")
	jobsFlag := flag.String("jobs", jobsEnv, "Comma-separated list of jobs to process, or 'all'")
	flag.Parse()

	// --- Stack Initialization ---
	app := cdktf.NewApp(nil)
	stack := cdktf.NewTerraformStack(app, jsii.String("nomad"))

	// --- Provider Configuration (shared) ---
	common.SetupProvider(stack)

	// --- Policy Registration (shared) ---
	common.RegisterPolicies(stack, "ops-read/policy")

	// --- Token Registration (shared) ---
	common.RegisterTokens(stack, "ops-read/token")

	// --- Job Registration (local) ---
	files, err := filepath.Glob("../../nomad/jobs/*.nomad.hcl")
	if err != nil {
		log.Fatalf("failed to glob job files: %v", err)
	}

	selected := map[string]bool{}
	if *jobsFlag != "all" {
		for _, name := range strings.Split(*jobsFlag, ",") {
			name = strings.TrimSpace(name)
			if name != "" {
				selected[name] = true
			}
		}
	}

	for _, f := range files {
		id := strings.TrimSuffix(filepath.Base(f), ".nomad.hcl")
		if *jobsFlag != "all" && !selected[id] {
			continue
		}
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read file %s: %v", f, err)
			continue
		}
		// Escape ${...} so Terraform doesn't try to template Nomad HCL
		hcl := strings.ReplaceAll(string(raw), "${", "$${")
		register_job(stack, id, hcl)
	}

	app.Synth()
}
