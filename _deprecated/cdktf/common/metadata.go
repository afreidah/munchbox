// -------------------------------------------------------------------------------
// Metadata Management for Nomad Jobs
//
// Project: Munchbox / Author: Alex Freidah
//
// Defines standard metadata schema for Nomad jobs with automatic category
// inference from directory structure, Git branch population, and HCL generation.
// -------------------------------------------------------------------------------

package common

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// ============================================================================
// Metadata Schema
// ============================================================================

// StandardMetadata defines the complete metadata schema for Nomad jobs.
// All fields are included in the generated HCL meta block.
type StandardMetadata struct {
	// Version tracking - identifies what version of the service is deployed
	Version  string // Semantic version (e.g., "2.54.1") or "dev" for development
	ImageTag string // Docker image tag, preferably

	// Ownership - identifies who owns and maintains this job
	Owner string // Owner name (e.g., "alex.freidah")

	// Classification - categorizes the job for organization and querying
	Category    string // Service category (monitoring, infrastructure, media, etc.)
	Tier        string // Service tier: tier-0 (critical), tier-1, tier-2, tier-3
	Environment string // Deployment environment (production, staging, development)

	// Technical information
	Description string // Human-readable description of what this job does
	Repository  string // Optional: Source code repository URL

	// Auto-populated deployment tracking - filled automatically at deploy time
	DeployedAt string // ISO 8601 timestamp of when this was deployed
	GitBranch  string // Git branch at deployment time
}

// ============================================================================
// Git Integration
// ============================================================================

// GetGitMetadata retrieves current branch information.
// This is used to automatically populate deployment tracking fields.
//
// Returns:
//   - branch: Current branch name (e.g., "main", "feature/new-service")
//
// If Git commands fail (not in a Git repo, Git not installed), returns empty strings.
func GetGitMetadata() (branch string) {
	// Get current branch name
	if out, err := exec.Command("git", "rev-parse", "--abbrev-ref", "HEAD").Output(); err == nil {
		branch = strings.TrimSpace(string(out))
		return branch
	}

	return branch
}

// ============================================================================
// HCL Generation
// ============================================================================

// ToHCL converts the StandardMetadata struct into a formatted HCL meta block.
// This block can be injected directly into a Nomad job specification.
//
// Example output:
//
//	meta {
//	  # Version tracking
//	  version     = "2.54.1"
//	  image_tag   = "abc123f"
//
//	  # Ownership
//	  owner       = "alex.freidah"
//
//	  # Classification
//	  category    = "monitoring"
//	  tier        = "tier-1"
//	  environment = "production"
//
//	  # Description
//	  description = "Prometheus metrics collection"
//	  repository  = "https://github.com/prometheus/prometheus"
//
//	  # Deployment info (auto-populated)
//	  git_branch  = "main"
//	}
func (m StandardMetadata) ToHCL() string {
	// Only include repository field if it's set
	repoField := ""
	if m.Repository != "" {
		repoField = fmt.Sprintf(`    repository  = "%s"`, m.Repository)
	}

	return fmt.Sprintf(`  meta {
    # Version tracking
    version     = "%s"
    image_tag   = "%s"
    
    # Ownership
    owner       = "%s"
    
    # Classification
    category    = "%s"
    tier        = "%s"
    environment = "%s"
    
    # Description
    description = "%s"
%s
    
    # Deployment info (auto-populated)
    git_branch  = "%s"
  }`,
		m.Version, m.ImageTag,
		m.Owner,
		m.Category, m.Tier, m.Environment,
		m.Description,
		repoField,
		m.GitBranch,
	)
}

// ============================================================================
// Default Metadata
// ============================================================================

// DefaultMetadata creates a StandardMetadata instance with sensible defaults
// and auto-populated Git information.
//
// Default values:
//   - version: "dev"
//   - image_tag:
//   - owner: "alex.freidah"
//   - category: "infrastructure" (should be overridden with InferCategoryFromPath)
//   - tier: "tier-2" (should be overridden with InferTierFromCategory)
//   - environment: "production"
//   - git_branch: Current Git branch
//
// Usage:
//
//	metadata := DefaultMetadata()
//	metadata.Category = InferCategoryFromPath(jobPath)
//	metadata.Tier = InferTierFromCategory(metadata.Category)
//	metadata.Description = "Custom description"
func DefaultMetadata() StandardMetadata {
	branch := GetGitMetadata()

	return StandardMetadata{
		Version:     "dev",
		ImageTag:    branch, // Use Git branch as default image tag
		Owner:       "alex.freidah",
		Category:    "infrastructure", // Default, should be overridden
		Tier:        "tier-2",         // Default, should be overridden
		Environment: "production",
		DeployedAt:  time.Now().Format(time.RFC3339),
		GitBranch:   branch,
	}
}

// ============================================================================
// Category Inference
// ============================================================================

func InferCategoryFromPath(jobPath string) string {
	clean := filepath.Clean(jobPath)

	known := map[string]struct{}{
		"infrastructure": {},
		"monitoring":     {},
		"logging":        {},
		"media":          {},
		"development":    {},
		"backup":         {},
		"utility":        {},
	}

	dir := filepath.Dir(clean)
	for {
		base := filepath.Base(dir)
		if _, ok := known[base]; ok {
			return base
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break // reached filesystem root
		}
		dir = parent
	}
	return "infrastructure"
}

// ============================================================================
// Tier Inference
// ============================================================================

// InferTierFromCategory maps service categories to appropriate service tiers.
//
// Category to Tier mapping:
//
//	monitoring     -> tier-1  (Important but not critical)
//	logging        -> tier-1  (Important but not critical)
//	infrastructure -> tier-0  (Critical - traefik, consul, etc.)
//	media          -> tier-3  (Nice to have)
//	development    -> tier-2  (Important tools)
//	backup         -> tier-2  (Important but not real-time)
//	utility        -> tier-3  (Placeholder jobs)
//
// Parameters:
//   - category: Service category (from InferCategoryFromPath)
//
// Returns:
//   - tier: Service tier string (e.g., "tier-0", "tier-1", etc.)
//   - If category unknown, returns "tier-2" as safe default
//
// Example:
//
//	tier := InferTierFromCategory("monitoring")
//	// Returns: "tier-1"
func InferTierFromCategory(category string) string {
	tierMapping := map[string]string{
		"monitoring":     "tier-1", // Important but not critical
		"logging":        "tier-1", // Important but not critical
		"infrastructure": "tier-0", // Critical - traefik, consul, etc.
		"media":          "tier-3", // Nice to have
		"development":    "tier-2", // Important tools
		"backup":         "tier-2", // Important but not real-time
		"utility":        "tier-3", // Placeholder jobs
	}

	if tier, exists := tierMapping[category]; exists {
		return tier
	}

	return "tier-2" // Safe default for unknown categories
}
