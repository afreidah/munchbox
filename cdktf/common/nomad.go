// --------------------------------------------------------------------
// Nomad provider utilities for CDKTF
// File: common/nomad.go
//
// Functions:
//   - SetupNomadProvider(): Configure Nomad provider for Terraform
//   - RegisterNomadJobs(): Register jobs with auto metadata injection
//   - RegisterNomadPolicies(): Register ACL policies
//   - RegisterNomadTokens(): Register ACL tokens
// --------------------------------------------------------------------

package common

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"

	"cdk.tf/go/stack/generated/hashicorp/nomad/aclpolicy"
	"cdk.tf/go/stack/generated/hashicorp/nomad/acltoken"
	"cdk.tf/go/stack/generated/hashicorp/nomad/job"
	"cdk.tf/go/stack/generated/hashicorp/nomad/provider"
)

// ============================================================================
// Nomad Provider Setup
// ============================================================================

// SetupNomadProvider configures the Nomad provider for Terraform CDK.
//
// Configuration sources (in priority order):
//  1. Environment variables (NOMAD_ADDR, NOMAD_TOKEN, NOMAD_CACERT)
//  2. Default values (https://192.168.68.63:4646)
//
// Environment Variables:
//   - NOMAD_ADDR: Nomad server address
//   - NOMAD_TOKEN: Nomad ACL token for authentication
//   - NOMAD_CACERT: Path to CA certificate for TLS verification
//
// Parameters:
//   - stack: CDKTF Terraform stack
func SetupNomadProvider(stack cdktf.TerraformStack) {
	addr := os.Getenv("NOMAD_ADDR")
	if addr == "" {
		addr = "https://192.168.68.63:4646"
	}
	tokenEnv := os.Getenv("NOMAD_TOKEN")
	cacert := os.Getenv("NOMAD_CACERT")
	cfg := &provider.NomadProviderConfig{
		Address: jsii.String(addr),
	}
	if tokenEnv != "" {
		cfg.SecretId = jsii.String(tokenEnv)
	}
	if cacert != "" {
		cfg.CaFile = jsii.String(cacert)
	}
	provider.NewNomadProvider(stack, jsii.String("nomad-provider"), cfg)
}

// ============================================================================
// Job File Discovery
// ============================================================================

// findJobFiles recursively searches for Nomad job files (.nomad.hcl) in the
// specified directory, excluding the do-not-run directory.
//
// Parameters:
//   - dir: Root directory to search (e.g., "infra/nomad-jobs")
//
// Returns:
//   - []string: List of full paths to job files
//   - error: Any error encountered during directory traversal
func findJobFiles(dir string) ([]string, error) {
	var files []string

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && info.Name() == "do-not-run" {
			return filepath.SkipDir
		}
		if !info.IsDir() && strings.HasSuffix(path, ".nomad.hcl") {
			files = append(files, path)
		}
		return nil
	})

	return files, err
}

// ============================================================================
// Job Registration with Metadata Injection
// ============================================================================

// RegisterNomadJobs discovers and registers Nomad job files with automatic
// metadata injection and validation.
//
// Features:
//   - Recursive job file discovery
//   - Automatic category inference from directory structure
//   - Auto-injection of metadata for jobs without meta blocks
//   - Metadata validation before registration
//   - Selective deployment via jobsFlag parameter
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - dir: Directory containing job files (e.g., "infra/nomad-jobs")
//   - jobsFlag: Comma-separated list of job names, or "all"/"" for all jobs
//
// Metadata Injection (static fields only):
//   - version: "1.0.0"
//   - owner: "alex.freidah"
//   - category: Inferred from directory structure
//   - tier: Inferred from category
//   - environment: "production"
func RegisterNomadJobs(stack cdktf.TerraformStack, dir string, jobsFlag string) {
	// Find all job files recursively
	files, err := findJobFiles(dir)
	if err != nil {
		log.Fatalf("failed to find job files: %v", err)
	}

	// Parse job selection flag
	selected := map[string]bool{}
	if jobsFlag == "" {
		jobsFlag = "all"
	}
	if jobsFlag != "all" {
		for _, name := range strings.Split(jobsFlag, ",") {
			name = strings.TrimSpace(name)
			if name != "" {
				selected[name] = true
			}
		}
	}

	// Process each job file
	for _, f := range files {
		id := strings.TrimSuffix(filepath.Base(f), ".nomad.hcl")

		// Skip if not in selection
		if jobsFlag != "all" && !selected[id] {
			continue
		}

		// Read job file
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read job file %s: %v", f, err)
			continue
		}

		hcl := injectTemplates(string(raw), filepath.Dir(f))

		// Infer metadata from directory structure
		category := InferCategoryFromPath(f)
		tier := InferTierFromCategory(category)

		// Check if job already has metadata
		if !HasMetadata(hcl) {
			log.Printf("[INJECT] Job %s: category=%s, tier=%s (injecting metadata)", id, category, tier)
			hcl = injectMetadata(hcl, id, category, tier)
		} else {
			log.Printf("[MERGE] Job %s: category=%s, tier=%s (merging missing fields)", id, category, tier)
			hcl = mergeMissingMetadata(hcl, id, category, tier)
		}

		// Validate metadata
		if err := ValidateMetadata(hcl); err != nil {
			log.Printf("[ERROR] Job %s failed metadata validation: %v", id, err)
			continue
		}

		// Escape ${...} so Terraform doesn't try to template Nomad HCL
		hcl = strings.ReplaceAll(hcl, "${", "$${")

		// Register the job
		registerJob(stack, id, hcl)
	}
}

// ============================================================================
// Metadata Merging
// ============================================================================

// mergeMissingMetadata injects missing required metadata fields into an
// existing metadata block without overwriting present values.
//
// Required fields checked and injected if missing:
//   - version: Default "1.0.0"
//   - owner: "alex.freidah"
//   - category: Inferred from directory structure
//   - tier: Inferred from category mapping
//   - environment: "production"
//
// Parameters:
//   - hcl: Original HCL content with existing meta block
//   - jobName: Name of the job
//   - category: Service category from directory structure
//   - tier: Service tier from category mapping
//
// Returns:
//   - Updated HCL content with all required metadata fields present
func mergeMissingMetadata(hcl string, jobName string, category string, tier string) string {
	owner := "alex.freidah"

	// Required static fields only (no timestamps or auto-updating fields)
	requiredFields := map[string]string{
		"version":     `"1.0.0"`,
		"owner":       fmt.Sprintf(`"%s"`, owner),
		"category":    fmt.Sprintf(`"%s"`, category),
		"tier":        fmt.Sprintf(`"%s"`, tier),
		"environment": `"production"`,
	}

	// Check each required field and inject if missing
	for field, value := range requiredFields {
		fieldRegex := regexp.MustCompile(fmt.Sprintf(`(?m)^\s*%s\s*=`, field))
		if !fieldRegex.MatchString(hcl) {
			metaBlockRegex := regexp.MustCompile(`(?m)(meta\s*\{)`)
			replacement := fmt.Sprintf("$1\n    %s = %s", field, value)
			hcl = metaBlockRegex.ReplaceAllString(hcl, replacement)
		}
	}

	return hcl
}

// ============================================================================
// Metadata Injection
// ============================================================================

// injectMetadata creates and injects a complete metadata block into a Nomad job.
//
// The metadata block is inserted immediately after the job declaration line,
// before any other configuration.
//
// Parameters:
//   - hcl: Original HCL content
//   - jobName: Name of the job (used for description)
//   - category: Service category from directory structure
//   - tier: Service tier from category mapping
//
// Returns:
//   - Updated HCL content with metadata block injected
func injectMetadata(hcl string, jobName string, category string, tier string) string {
	owner := "alex.freidah"

	// Build static metadata block (no auto-updating timestamps)
	metaBlock := fmt.Sprintf(`  meta {
    # Version tracking
    version     = "1.0.0"

    # Ownership
    owner       = "%s"

    # Classification
    category    = "%s"
    tier        = "%s"
    environment = "production"

    # Description
    description = "%s service"
  }`,
		owner,
		category,
		tier,
		jobName,
	)

	// Extract actual job name from HCL
	jobNameRegex := regexp.MustCompile(`job\s+"([^"]+)"\s+{`)
	matches := jobNameRegex.FindStringSubmatch(hcl)
	if len(matches) < 2 {
		log.Printf("[WARN] Could not inject metadata into job %s: job declaration not found", jobName)
		return hcl
	}

	// Insert metadata after job declaration
	actualJobName := matches[1]
	jobDecl := fmt.Sprintf(`job "%s" {`, actualJobName)
	if idx := strings.Index(hcl, jobDecl); idx != -1 {
		insertPoint := idx + len(jobDecl)
		return hcl[:insertPoint] + "\n" + metaBlock + "\n" + hcl[insertPoint:]
	}

	return hcl
}

// ============================================================================
// Job Registration (Internal)
// ============================================================================

// registerJob creates a Nomad job resource in the Terraform stack.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - id: Unique identifier for the job resource
//   - hcl: Complete HCL job specification (with ${...} already escaped)
//
// Configuration:
//   - DeregisterOnDestroy: true
//   - PurgeOnDestroy: true
func registerJob(stack cdktf.TerraformStack, id string, hcl string) {
	job.NewJob(stack, jsii.String(id), &job.JobConfig{
		Jobspec:             jsii.String(hcl),
		DeregisterOnDestroy: jsii.Bool(true),
		PurgeOnDestroy:      jsii.Bool(true),
	})
}

// ============================================================================
// Nomad Policy Registration
// ============================================================================

// RegisterNomadPolicies registers Nomad ACL policies from HCL files.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - dir: Directory containing policy HCL files
func RegisterNomadPolicies(stack cdktf.TerraformStack, dir string) {
	policyFiles, err := filepath.Glob(filepath.Join(dir, "*.hcl"))
	if err != nil {
		log.Fatalf("failed to glob policy files: %v", err)
	}
	for _, f := range policyFiles {
		id := strings.TrimSuffix(filepath.Base(f), ".hcl")
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read policy file %s: %v", f, err)
			continue
		}
		hcl := strings.ReplaceAll(string(raw), "${", "$${")
		uniqueID := id + "-policy"
		aclpolicy.NewAclPolicy(stack, jsii.String(uniqueID), &aclpolicy.AclPolicyConfig{
			Name:     jsii.String(id),
			RulesHcl: jsii.String(hcl),
		})
	}
}

// injectTemplates replaces placeholder markers in a Nomad job HCL string with
// the contents of local files.
//
// Placeholders must use the format <<INJECT:relative/path/to/file>> and are
// resolved relative to the job file's directory.
//
// This enables dynamic file injection (e.g., scripts, templates) without using
// Terraform's file() function, which is disabled in remote execution contexts.
//
// Parameters:
//   - hcl: Original HCL string with <<INJECT:...>> placeholders
//   - baseDir: Directory path to resolve relative file references
//
// Returns:
//   - string: Updated HCL with file contents inlined in place of placeholders
func injectTemplates(hcl string, baseDir string) string {
	re := regexp.MustCompile(`<<INJECT:([^>]+)>>`)
	return re.ReplaceAllStringFunc(hcl, func(match string) string {
		fileMatch := re.FindStringSubmatch(match)
		if len(fileMatch) < 2 {
			return match
		}
		contentPath := filepath.Join(baseDir, fileMatch[1])
		content, err := os.ReadFile(contentPath)
		if err != nil {
			log.Printf("warning: could not read file for placeholder %s: %v", match, err)
			return match
		}
		return string(content)
	})
}

// ============================================================================
// Nomad Token Registration
// ============================================================================

// RegisterNomadTokens registers Nomad ACL tokens from HCL files.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - dir: Directory containing token HCL files
func RegisterNomadTokens(stack cdktf.TerraformStack, dir string) {
	tokenFiles, err := filepath.Glob(filepath.Join(dir, "*.hcl"))
	if err != nil {
		log.Fatalf("failed to glob token files: %v", err)
	}
	for _, f := range tokenFiles {
		id := strings.TrimSuffix(filepath.Base(f), ".hcl")
		uniqueID := id + "-token"
		acltoken.NewAclToken(stack, jsii.String(uniqueID), &acltoken.AclTokenConfig{
			Type:     jsii.String("client"),
			Name:     jsii.String(id),
			Policies: &[]*string{jsii.String(id)},
		})
	}
}
