// --------------------------------------------------------------------
// Shared utilities for Nomad CDKTF stacks
// File: common/common.go
//
// Key Functions:
//   - SetupNomadProvider(): Configure Nomad provider for Terraform
//   - RegisterNomadJobs(): Register jobs with auto metadata injection
//   - RegisterNomadPolicies(): Register ACL policies
//   - RegisterNomadTokens(): Register ACL tokens
//   - SetupConsulProvider(): Configure Consul provider
//   - RegisterConsulPolicies(): Register Consul ACL policies
//   - RegisterConsulTokens(): Register Consul ACL tokens with KV sync
//   - SetupVaultProvider(): Configure Vault provider
//   - RegisterVaultPolicies(): Register Vault policies
//   - RegisterVaultJwtAuth(): Configure JWT auth for Nomad workloads
// --------------------------------------------------------------------

package common

// ============================================================================
// Imports — CDKTF core + Generated Providers (Nomad, Consul, Vault)
// ============================================================================
import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/aws/jsii-runtime-go"
	"github.com/hashicorp/terraform-cdk-go/cdktf"

	// --- Nomad (generated) ---
	"cdk.tf/go/stack/generated/hashicorp/nomad/aclpolicy"
	"cdk.tf/go/stack/generated/hashicorp/nomad/acltoken"
	"cdk.tf/go/stack/generated/hashicorp/nomad/job"
	"cdk.tf/go/stack/generated/hashicorp/nomad/provider"

	// --- Consul (generated) ---
	consulaclpolicy "cdk.tf/go/stack/generated/hashicorp/consul/aclpolicy"
	consulacltoken "cdk.tf/go/stack/generated/hashicorp/consul/acltoken"
	consulprovider "cdk.tf/go/stack/generated/hashicorp/consul/provider"

	// --- Null (generated) for local-exec automation ---
	nullprovider "cdk.tf/go/stack/generated/hashicorp/null/provider"
	nullresource "cdk.tf/go/stack/generated/hashicorp/null/resource"

	// --- Vault (generated) ---
	vaultjwtauthbackend "cdk.tf/go/stack/generated/hashicorp/vault/jwtauthbackend"
	vaultjwtauthbackendrole "cdk.tf/go/stack/generated/hashicorp/vault/jwtauthbackendrole"
	vaultmount "cdk.tf/go/stack/generated/hashicorp/vault/mount"
	vaultpolicy "cdk.tf/go/stack/generated/hashicorp/vault/policy"
	vaultprovider "cdk.tf/go/stack/generated/hashicorp/vault/provider"

	// YAML for Consul token descriptors
	"gopkg.in/yaml.v3"
)

// ============================== NOMAD ========================================

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
//   - updated: Current date (YYYY-MM-DD)
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

		hcl := string(raw)

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
    updated     = "%s"

    # Ownership
    owner       = "%s"

    # Classification
    category    = "%s"
    tier        = "%s"
    environment = "production"

    # Description
    description = "%s service"
  }`,
		time.Now().Format("2006-01-02"), // Just date, not timestamp
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

// ============================== CONSUL =======================================

// ============================================================================
// Consul Provider Setup
// ============================================================================

// SetupConsulProvider configures the Consul provider for Terraform CDK.
//
// Configuration sources:
//  1. Environment variables (CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN)
//  2. Default address: http://127.0.0.1:8500
//
// Parameters:
//   - stack: CDKTF Terraform stack
func SetupConsulProvider(stack cdktf.TerraformStack) {
	addr := os.Getenv("CONSUL_HTTP_ADDR")
	if addr == "" {
		addr = "http://127.0.0.1:8500"
	}
	token := os.Getenv("CONSUL_HTTP_TOKEN")
	cfg := &consulprovider.ConsulProviderConfig{
		Address: jsii.String(addr),
	}
	if token != "" {
		cfg.Token = jsii.String(token)
	}
	consulprovider.NewConsulProvider(stack, jsii.String("consul-provider"), cfg)
}

// ============================================================================
// Consul Policy Registration
// ============================================================================

// RegisterConsulPolicies registers Consul ACL policies from HCL files.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - dir: Directory containing policy HCL files
func RegisterConsulPolicies(stack cdktf.TerraformStack, dir string) {
	files, err := filepath.Glob(filepath.Join(dir, "*.hcl"))
	if err != nil {
		log.Fatalf("failed to glob consul policy files: %v", err)
	}
	for _, f := range files {
		if strings.HasSuffix(f, ".nomad.hcl") {
			continue
		}
		id := strings.TrimSuffix(filepath.Base(f), ".hcl")
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read consul policy %s: %v", f, err)
			continue
		}
		consulaclpolicy.NewAclPolicy(
			stack,
			jsii.String("consul-policy-"+id),
			&consulaclpolicy.AclPolicyConfig{
				Name:  jsii.String(id),
				Rules: jsii.String(string(raw)),
			},
		)
	}
}

// ============================================================================
// Consul Token Specification
// ============================================================================

// ConsulTokenSpec defines the structure for Consul token YAML files.
type ConsulTokenSpec struct {
	Name        string   `yaml:"name"`
	Description string   `yaml:"description"`
	Local       bool     `yaml:"local"`
	Policies    []string `yaml:"policies"`
	Roles       []string `yaml:"roles"`
	KvPath      string   `yaml:"kv_path"`
}

// ============================================================================
// Consul Token Registration
// ============================================================================

// RegisterConsulTokens registers Consul ACL tokens from YAML files and
// optionally syncs token secrets to Consul KV.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - dir: Directory containing token YAML files
func RegisterConsulTokens(stack cdktf.TerraformStack, dir string) {
	nullprovider.NewNullProvider(stack, jsii.String("null-provider"), &nullprovider.NullProviderConfig{})

	files, err := filepath.Glob(filepath.Join(dir, "*.yml"))
	if err != nil {
		log.Fatalf("failed to glob consul token files: %v", err)
	}
	for _, f := range files {
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read consul token file %s: %v", f, err)
			continue
		}
		var spec ConsulTokenSpec
		if err := yaml.Unmarshal(raw, &spec); err != nil {
			log.Printf("failed to parse yaml %s: %v", f, err)
			continue
		}
		if spec.Name == "" {
			spec.Name = strings.TrimSuffix(filepath.Base(f), ".yml")
		}
		var pols []*string
		for _, p := range spec.Policies {
			pols = append(pols, jsii.String(p))
		}

		t := consulacltoken.NewAclToken(
			stack,
			jsii.String("consul-token-"+spec.Name),
			&consulacltoken.AclTokenConfig{
				Description: jsii.String(spec.Description),
				Local:       jsii.Bool(spec.Local),
				Policies:    &pols,
			},
		)

		if spec.KvPath != "" {
			nr := nullresource.NewResource(
				stack,
				jsii.String("consul-token-sync-"+spec.Name),
				&nullresource.ResourceConfig{
					Triggers: &map[string]*string{
						"accessor": t.AccessorId(),
						"kv_path":  jsii.String(spec.KvPath),
					},
				},
			)

			nr.AddOverride(jsii.String("provisioner"), []interface{}{
				map[string]interface{}{
					"local-exec": map[string]interface{}{
						"interpreter": []string{"/bin/sh", "-c"},
						"command":     "SECRET=$(consul acl token read -id ${self.triggers.accessor} -format=json | awk -F\\\" '/SecretID/{print $4; exit}'); test -n \"$SECRET\" && consul kv put ${self.triggers.kv_path} \"$SECRET\"",
					},
				},
			})
		}
	}
}

// ============================== VAULT ========================================

// ============================================================================
// Vault Provider Setup
// ============================================================================

// SetupVaultProvider configures the Vault provider for Terraform CDK.
//
// Configuration sources:
//  1. Environment variables (VAULT_ADDR, VAULT_TOKEN)
//  2. Default address: https://192.168.68.63:4646
//
// Parameters:
//   - stack: CDKTF Terraform stack
func SetupVaultProvider(stack cdktf.TerraformStack) {
	addr := os.Getenv("VAULT_ADDR")
	if addr == "" {
		addr = "https://192.168.68.63:4646"
	}
	tokenEnv := os.Getenv("VAULT_TOKEN")
	cfg := &vaultprovider.VaultProviderConfig{
		Address:       jsii.String(addr),
		SkipTlsVerify: jsii.Bool(true),
	}
	if tokenEnv != "" {
		cfg.Token = jsii.String(tokenEnv)
	}
	vaultprovider.NewVaultProvider(stack, jsii.String("vault-provider"), cfg)
}

// ============================================================================
// Vault Policy Registration
// ============================================================================

// RegisterVaultPolicies registers Vault policies from HCL files.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - dir: Directory containing policy HCL files
func RegisterVaultPolicies(stack cdktf.TerraformStack, dir string) {
	policyFiles, err := filepath.Glob(filepath.Join(dir, "*.hcl"))
	if err != nil {
		log.Fatalf("failed to glob vault policy files: %v", err)
	}
	for _, f := range policyFiles {
		id := strings.TrimSuffix(filepath.Base(f), ".hcl")
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read vault policy file %s: %v", f, err)
			continue
		}
		vaultpolicy.NewPolicy(stack, jsii.String(id), &vaultpolicy.PolicyConfig{
			Name:   jsii.String(id),
			Policy: jsii.String(string(raw)),
		})
	}
}

// ============================================================================
// Vault KV Mount
// ============================================================================

// RegisterVaultKvMount creates a KV v2 secrets engine mount in Vault.
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - id: Unique identifier for the mount resource
//   - path: Mount path in Vault
//
// Returns:
//   - vaultmount.Mount: The created mount resource
func RegisterVaultKvMount(stack cdktf.TerraformStack, id string, path string) vaultmount.Mount {
	return vaultmount.NewMount(stack, jsii.String(id), &vaultmount.MountConfig{
		Path: jsii.String(path),
		Type: jsii.String("kv"),
		Options: &map[string]*string{
			"version": jsii.String("2"),
		},
	})
}

// ============================================================================
// Vault JWT Auth Configuration
// ============================================================================

// RegisterVaultJwtAuth configures JWT authentication for Nomad workload identity.
//
// Creates a JWT auth backend and two roles:
//   - nomad-workloads: Generic role for all Nomad workloads
//   - nomad-grafana: Specific role for Grafana with additional policies
//
// Parameters:
//   - stack: CDKTF Terraform stack
//   - nomadUrl: Nomad server URL (for JWKS and issuer validation)
//   - nomadCaCert: CA certificate for Nomad TLS verification
func RegisterVaultJwtAuth(stack cdktf.TerraformStack, nomadUrl string, nomadCaCert string) {
	backend := vaultjwtauthbackend.NewJwtAuthBackend(stack,
		jsii.String("jwt-auth-backend"),
		&vaultjwtauthbackend.JwtAuthBackendConfig{
			Path:        jsii.String("jwt-nomad"),
			Description: jsii.String("JWT auth for Nomad workload identity"),
			JwksUrl:     jsii.String(nomadUrl + "/.well-known/jwks.json"),
			JwksCaPem:   jsii.String(nomadCaCert),
			BoundIssuer: jsii.String(nomadUrl),
			DefaultRole: jsii.String("nomad-workloads"),
		},
	)

	vaultjwtauthbackendrole.NewJwtAuthBackendRole(
		stack,
		jsii.String("jwt-nomad-workloads-role"),
		&vaultjwtauthbackendrole.JwtAuthBackendRoleConfig{
			Backend:              backend.Path(),
			RoleName:             jsii.String("nomad-workloads"),
			RoleType:             jsii.String("jwt"),
			BoundAudiences:       &[]*string{jsii.String("vault.io")},
			UserClaim:            jsii.String("/nomad_job_id"),
			UserClaimJsonPointer: jsii.Bool(true),
			ClaimMappings: &map[string]*string{
				"nomad_job_id":    jsii.String("nomad_job_id"),
				"nomad_namespace": jsii.String("nomad_namespace"),
				"nomad_task":      jsii.String("nomad_task"),
			},
			TokenType:     jsii.String("service"),
			TokenPolicies: &[]*string{jsii.String("default")},
			TokenPeriod:   jsii.Number(3600),
		},
	)

	vaultjwtauthbackendrole.NewJwtAuthBackendRole(
		stack,
		jsii.String("jwt-nomad-grafana-role"),
		&vaultjwtauthbackendrole.JwtAuthBackendRoleConfig{
			Backend:              backend.Path(),
			RoleName:             jsii.String("nomad-grafana"),
			RoleType:             jsii.String("jwt"),
			BoundAudiences:       &[]*string{jsii.String("vault.io")},
			UserClaim:            jsii.String("/nomad_job_id"),
			UserClaimJsonPointer: jsii.Bool(true),
			BoundClaims: &map[string]*string{
				"nomad_namespace": jsii.String("default"),
				"nomad_job_id":    jsii.String("grafana"),
			},
			ClaimMappings: &map[string]*string{
				"nomad_job_id":    jsii.String("nomad_job_id"),
				"nomad_namespace": jsii.String("nomad_namespace"),
				"nomad_task":      jsii.String("nomad_task"),
			},
			TokenType:     jsii.String("service"),
			TokenPolicies: &[]*string{jsii.String("default"), jsii.String("cdktf-grafana-read")},
			TokenPeriod:   jsii.Number(3600),
		},
	)
}
