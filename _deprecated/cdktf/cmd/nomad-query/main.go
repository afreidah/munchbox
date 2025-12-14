// -------------------------------------------------------------------------------
// Nomad Job Metadata Query Tool
//
// Project: Munchbox / Author: Alex Freidah
//
// Queries and displays Nomad job metadata across the cluster with filtering by
// category and tier, showing versions, update dates, and owner information.
// -------------------------------------------------------------------------------
//
// Environment Variables:
//   NOMAD_ADDR    - Nomad server address (default: http://localhost:4646)
//   NOMAD_TOKEN   - Nomad ACL token for authentication
//   NOMAD_REGION  - Nomad region (default: global)
//
// Usage:
//   # List all jobs
//   go run cmd/nomad-query/main.go
//
//   # Filter by category
//   go run cmd/nomad-query/main.go -category monitoring
//
//   # Filter by tier
//   go run cmd/nomad-query/main.go -tier tier-0
//
//   # Combine filters
//   go run cmd/nomad-query/main.go -category infrastructure -tier tier-0
//
// Example Output:
//   JOB                       CATEGORY        TIER       VERSION    UPDATED      OWNER
//   ---------------------------------------------------------------------------------------
//   prometheus                monitoring      tier-1     2.54.1     2025-10-03   alex.freidah
//   grafana                   monitoring      tier-1     12.2.0     2025-10-03   alex.freidah
//   traefik                   infrastructure  tier-0     3.5.3      2025-10-03   alex.freidah
// --------------------------------------------------------------------

package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/hashicorp/nomad/api"
)

func main() {
	category := flag.String("category", "", "Filter by job category")
	jobName := flag.String("job", "", "Query specific job")
	all := flag.Bool("all", false, "Show all jobs")
	jobsDir := flag.String("dir", "infra/nomad-jobs", "Jobs directory")

	flag.Parse()

	client, err := api.NewClient(api.DefaultConfig())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating Nomad client: %v\n", err)
		os.Exit(1)
	}

	switch {
	case *jobName != "":
		queryJob(client, *jobName)
	case *category != "":
		queryCategory(client, *jobsDir, *category)
	case *all:
		queryAllJobs(client)
	default:
		flag.Usage()
		os.Exit(1)
	}
}

func queryJob(client *api.Client, jobID string) {
	jobs := client.Jobs()

	job, _, err := jobs.Info(jobID, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error querying job %s: %v\n", jobID, err)
		os.Exit(1)
	}

	// job.ID, job.Name, job.Type, job.Status are all *string from Info()
	fmt.Printf("Job: %s\n", safeString(job.Name))
	fmt.Printf("  ID: %s\n", safeString(job.ID))
	fmt.Printf("  Type: %s\n", safeString(job.Type))
	fmt.Printf("  Status: %s\n", safeString(job.Status))

	if job.Meta != nil {
		fmt.Println("  Metadata:")
		for k, v := range job.Meta {
			fmt.Printf("    %s: %s\n", k, v)
		}
	}
}

func queryCategory(client *api.Client, jobsDir, category string) {
	categoryPath := filepath.Join(jobsDir, category)
	if _, err := os.Stat(categoryPath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Category %s does not exist\n", category)
		os.Exit(1)
	}

	files, err := filepath.Glob(filepath.Join(categoryPath, "*.nomad.hcl"))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading category: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Category: %s\n", category)
	fmt.Printf("  Jobs found: %d\n\n", len(files))

	jobs := client.Jobs()
	for _, file := range files {
		jobName := strings.TrimSuffix(filepath.Base(file), ".nomad.hcl")

		job, _, err := jobs.Info(jobName, nil)
		if err != nil {
			fmt.Printf("  [NOT DEPLOYED] %s (error: %v)\n", jobName, err)
			continue
		}

		// Use helper function to safely dereference
		fmt.Printf("  [OK] %s (Status: %s)\n", safeString(job.ID), safeString(job.Status))
	}
}

func queryAllJobs(client *api.Client) {
	jobs := client.Jobs()

	jobList, _, err := jobs.List(nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error listing jobs: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Total jobs: %d\n\n", len(jobList))

	statusGroups := make(map[string][]string)
	for _, job := range jobList {
		// job.ID and job.Status are plain strings from List(), not pointers
		statusGroups[job.Status] = append(statusGroups[job.Status], job.ID)
	}

	for status, jobIDs := range statusGroups {
		fmt.Printf("Status: %s (%d)\n", status, len(jobIDs))
		for _, jobID := range jobIDs {
			fmt.Printf("  - %s\n", jobID)
		}
		fmt.Println()
	}
}

// Helper function to safely dereference string pointers
func safeString(s *string) string {
	if s == nil {
		return "<nil>"
	}
	return *s
}
