// --------------------------------------------------------------------
// Shared utilities for Nomad CDKTF stacks
// File: common.go
// --------------------------------------------------------------------

package common

// ============================================================================
// Imports — CDKTF core + Generated Providers (Nomad, Consul, Vault)
// ============================================================================
import (
	"log"
	"os"
	"path/filepath"
	"strings"

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

// RegisterNomadJobs from *.nomad.hcl, with ${...} escaped to $${...}
func RegisterNomadJobs(stack cdktf.TerraformStack, dir string, jobsFlag string) {
	files, err := filepath.Glob(filepath.Join(dir, "*.nomad.hcl"))
	if err != nil {
		log.Fatalf("failed to glob job files: %v", err)
	}

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

	for _, f := range files {
		id := strings.TrimSuffix(filepath.Base(f), ".nomad.hcl")
		if jobsFlag != "all" && !selected[id] {
			continue
		}
		raw, err := os.ReadFile(f)
		if err != nil {
			log.Printf("failed to read job file %s: %v", f, err)
			continue
		}
		// Escape ${...} so Terraform doesn't try to template Nomad HCL
		hcl := strings.ReplaceAll(string(raw), "${", "$${")
		registerJob(stack, id, hcl)
	}
}

func registerJob(stack cdktf.TerraformStack, id string, hcl string) {
	job.NewJob(stack, jsii.String(id), &job.JobConfig{
		Jobspec:             jsii.String(hcl),
		DeregisterOnDestroy: jsii.Bool(true),
		PurgeOnDestroy:      jsii.Bool(true),
	})
}

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

func SetupConsulProvider(stack cdktf.TerraformStack) {
	addr := os.Getenv("CONSUL_HTTP_ADDR")
	if addr == "" {
		addr = "http://127.0.0.1:8500"
	}
	token := os.Getenv("CONSUL_HTTP_TOKEN") // must be mgmt/admin to create policies/tokens
	cfg := &consulprovider.ConsulProviderConfig{
		Address: jsii.String(addr),
		// If your Consul is HTTPS with self-signed, set InsecureHttps = true
	}
	if token != "" {
		cfg.Token = jsii.String(token)
	}
	consulprovider.NewConsulProvider(stack, jsii.String("consul-provider"), cfg)
}

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

// ConsulTokenSpec describes files in consul-tokens/*.nomad.yml
type ConsulTokenSpec struct {
	Name        string   `yaml:"name"`
	Description string   `yaml:"description"`
	Local       bool     `yaml:"local"`
	Policies    []string `yaml:"policies"`
	Roles       []string `yaml:"roles"`
	KvPath      string   `yaml:"kv_path"` // optional: where to persist SecretID
}

// RegisterConsulTokens reads *.yml in the folder and creates consul_acl_token.
// If KvPath is set, a null_resource with local-exec writes SecretID to that KV path.
func RegisterConsulTokens(stack cdktf.TerraformStack, dir string) {
	// Ensure the null provider exists (needed for null_resource below)
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

		// Create the ACL token (provider returns accessor_id; secret_id not exposed)
		t := consulacltoken.NewAclToken(
			stack,
			jsii.String("consul-token-"+spec.Name),
			&consulacltoken.AclTokenConfig{
				Description: jsii.String(spec.Description),
				Local:       jsii.Bool(spec.Local),
				Policies:    &pols,
			},
		)

		// If requested, persist the SecretID into Consul KV via local-exec
		if spec.KvPath != "" {
			nr := nullresource.NewResource(
				stack,
				jsii.String("consul-token-sync-"+spec.Name),
				&nullresource.ResourceConfig{
					Triggers: &map[string]*string{
						"accessor": t.AccessorId(), // forces re-run if token changes
						"kv_path":  jsii.String(spec.KvPath),
					},
				},
			)

			// Use only standard tools: /bin/sh, consul CLI, awk. No jq dependency.
			// Inherits CONSUL_HTTP_ADDR / CONSUL_HTTP_TOKEN from the environment.
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

func SetupVaultProvider(stack cdktf.TerraformStack) {
	addr := os.Getenv("VAULT_ADDR")
	if addr == "" {
		addr = "https://mccoy:8200"
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

func RegisterVaultKvMount(stack cdktf.TerraformStack, id string, path string) vaultmount.Mount {
	return vaultmount.NewMount(stack, jsii.String(id), &vaultmount.MountConfig{
		Path: jsii.String(path),
		Type: jsii.String("kv"),
		Options: &map[string]*string{
			"version": jsii.String("2"),
		},
	})
}

// RegisterVaultJwtAuth configures Vault JWT auth for Nomad Workload Identity.
// nomadAddress: e.g. "https://mccoy:4646"
// nomadCaCert:  contents of /opt/nomad/tls/nomad-agent-ca.pem (or a path you read beforehand)
func RegisterVaultJwtAuth(stack cdktf.TerraformStack, nomadAddress, nomadCaCert string) {
	// JWT auth backend (mount)
	backend := vaultjwtauthbackend.NewJwtAuthBackend(stack,
		jsii.String("jwt-auth-backend"),
		&vaultjwtauthbackend.JwtAuthBackendConfig{
			Path:        jsii.String("jwt-nomad"),
			Description: jsii.String("JWT auth for Nomad workload identity"),
			JwksUrl:     jsii.String(nomadAddress + "/.well-known/jwks.json"),
			JwksCaPem:   jsii.String(nomadCaCert),
			BoundIssuer: jsii.String("nomad"), // <-- add this
			DefaultRole: jsii.String("nomad-workloads"),
		},
	)

	// Default, minimal role for workloads that don't set a role in their job
	vaultjwtauthbackendrole.NewJwtAuthBackendRole(
		stack,
		jsii.String("jwt-nomad-workloads-role"),
		&vaultjwtauthbackendrole.JwtAuthBackendRoleConfig{
			Backend:              backend.Path(),
			RoleName:             jsii.String("nomad-workloads"),
			RoleType:             jsii.String("jwt"),
			BoundAudiences:       &[]*string{jsii.String("vault.io")}, // must match Nomad default_identity.aud
			UserClaim:            jsii.String("/nomad_job_id"),        // use JSON pointer to claim
			UserClaimJsonPointer: jsii.Bool(true),
			// No strict bound_claims here: it's truly a generic default
			TokenType:     jsii.String("service"),
			TokenPolicies: &[]*string{jsii.String("default")},
			TokenPeriod:   jsii.Number(3600), // 1h
		},
	)

	// Least-privileged role bound to the Grafana job only
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
			// Bind to *this* job in *this* namespace so only Grafana can use this role
			BoundClaims: &map[string]*string{
				"nomad_namespace": jsii.String("default"),
				"nomad_job_id":    jsii.String("grafana"),
			},
			TokenType:     jsii.String("service"),
			TokenPolicies: &[]*string{jsii.String("default"), jsii.String("cdktf-grafana-read")},
			TokenPeriod:   jsii.Number(3600),
		},
	)
}
