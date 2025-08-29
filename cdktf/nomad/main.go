// --------------------------------------------------------------------
// Program: Nomad CDKTF Stack
// File: main.go
//
// Registers Nomad jobs from HCL files using the Terraform CDK for Go.
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

	"cdk.tf/go/stack/generated/hashicorp/nomad/job"
	"cdk.tf/go/stack/generated/hashicorp/nomad/provider"
)

// --------------------------------------------------------------------
// Register a Nomad job resource from HCL
// --------------------------------------------------------------------
func register_job(stack cdktf.TerraformStack, id string, hcl string) {
	job.NewJob(stack, jsii.String(id), &job.JobConfig{
		Jobspec:             jsii.String(hcl),
		DeregisterOnDestroy: jsii.Bool(true),
		PurgeOnDestroy:      jsii.Bool(true),
	})
}

// --------------------------------------------------------------------
// Main entrypoint: parses flags, loads jobs, and synthesizes the stack
// --------------------------------------------------------------------
func main() {
	// --- CLI Flags ---
	jobsEnv := os.Getenv("JOBS")
	jobsFlag := flag.String("jobs", jobsEnv, "Comma-separated list of jobs to process, or 'all'")
	flag.Parse()

	// --- Stack Initialization ---
	app := cdktf.NewApp(nil)
	stack := cdktf.NewTerraformStack(app, jsii.String("nomad"))

	// --- Provider Configuration (from env, with sane defaults) ---
	addr := os.Getenv("NOMAD_ADDR")
	if addr == "" {
		addr = "https://192.168.68.63:4646"
	}
	token := os.Getenv("NOMAD_TOKEN")   // SecretID
	cacert := os.Getenv("NOMAD_CACERT") // path to CA PEM

	cfg := &provider.NomadProviderConfig{
		Address: jsii.String(addr),
	}
	if token != "" {
		cfg.SecretId = jsii.String(token)
	}
	if cacert != "" {
		cfg.CaFile = jsii.String(cacert)
	}
	provider.NewNomadProvider(stack, jsii.String("nomad-provider"), cfg)

	// --- Job Registration ---
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
