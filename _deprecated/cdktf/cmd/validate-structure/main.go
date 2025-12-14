// -------------------------------------------------------------------------------
// Job Structure Validation Tool
//
// Project: Munchbox / Author: Alex Freidah
//
// Validates Nomad job organization into category directories, scanning structure
// and reporting job counts per category with tier inference and root warnings.
// -------------------------------------------------------------------------------
// Usage:
//   go run cmd/validate-structure/main.go
//   go run cmd/validate-structure/main.go -dir path/to/nomad-jobs
//
// Example Output:
//   📊 Job Organization Report
//   ============================================================
//
//   📁 monitoring (5 jobs) - tier-1
//      - prometheus
//      - grafana
//      - alertmanager
//      - prometheus-node-exporter
//      - blackbox-exporter
//
//   📁 infrastructure (3 jobs) - tier-0 (critical)
//      - traefik
//      - cloudflared-tunnel
//      - nginx-resume
//
//   Total: 15 jobs across 6 categories
// --------------------------------------------------------------------

package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// ============================================================================
// Main Function
// ============================================================================

func main() {
	// Command-line flags
	jobsDir := flag.String("dir", "cdktf/infra/nomad-jobs", "Jobs directory to validate")
	flag.Parse()

	// Validate structure
	categories := scanJobStructure(*jobsDir)

	// Print report
	printReport(categories)

	// Check for warnings
	checkWarnings(categories)
}

// ============================================================================
// Directory Scanning
// ============================================================================

// scanJobStructure walks the jobs directory and organizes jobs by category.
//
// Returns a map of category names to job names within that category.
func scanJobStructure(jobsDir string) map[string][]string {
	categories := make(map[string][]string)

	filepath.Walk(jobsDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return err
		}

		// Only process .nomad.hcl files
		if !strings.HasSuffix(path, ".nomad.hcl") {
			return nil
		}

		// Skip do-not-run directory
		if strings.Contains(path, "do-not-run") {
			return nil
		}

		// Get relative path from jobs directory
		rel, _ := filepath.Rel(jobsDir, path)
		parts := strings.Split(rel, string(filepath.Separator))

		// Determine category
		category := "root"
		if len(parts) > 1 {
			category = parts[0]
		}

		// Extract job name
		jobName := strings.TrimSuffix(filepath.Base(path), ".nomad.hcl")
		categories[category] = append(categories[category], jobName)

		return nil
	})

	return categories
}

// ============================================================================
// Reporting
// ============================================================================

// printReport generates and displays a formatted job organization report.
func printReport(categories map[string][]string) {
	fmt.Println("📊 Job Organization Report")
	fmt.Println(strings.Repeat("=", 60))
	fmt.Println()

	// Sort categories for consistent output
	categoryNames := make([]string, 0, len(categories))
	for cat := range categories {
		categoryNames = append(categoryNames, cat)
	}
	sort.Strings(categoryNames)

	totalJobs := 0

	// Print each category
	for _, category := range categoryNames {
		jobs := categories[category]
		tier := inferTier(category)

		fmt.Printf("📁 %s (%d jobs) - %s\n", category, len(jobs), tier)

		// Sort jobs alphabetically
		sort.Strings(jobs)

		for _, job := range jobs {
			fmt.Printf("   - %s\n", job)
		}

		fmt.Println()
		totalJobs += len(jobs)
	}

	// Print summary
	fmt.Printf("Total: %d jobs across %d categories\n", totalJobs, len(categories))
}

// checkWarnings identifies potential issues in the job organization.
func checkWarnings(categories map[string][]string) {
	// Check for jobs in root directory
	if rootJobs, exists := categories["root"]; exists && len(rootJobs) > 0 {
		fmt.Println()
		fmt.Println("⚠️  WARNING: Jobs in root directory (should be categorized):")
		for _, job := range rootJobs {
			fmt.Printf("   - %s\n", job)
		}
		fmt.Println()
		fmt.Println("💡 Suggestion: Move these jobs to appropriate category directories")
	}
}

// ============================================================================
// Tier Inference (Duplicated from metadata.go for standalone tool)
// ============================================================================

// inferTier maps category names to service tiers.
//
// Returns a human-readable tier description.
func inferTier(category string) string {
	tierMapping := map[string]string{
		"monitoring":     "tier-1",
		"infrastructure": "tier-0 (critical)",
		"media":          "tier-3",
		"development":    "tier-2",
		"backup":         "tier-2",
		"utility":        "tier-3",
		"root":           "uncategorized",
	}

	if tier, exists := tierMapping[category]; exists {
		return tier
	}

	return "tier-2 (unknown category)"
}
