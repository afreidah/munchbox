// -------------------------------------------------------------------------------
// Trivy Scan Trigger - Main Entry Point
//
// Project: Munchbox / Author: Alex Freidah
//
// Initiates Trivy vulnerability scan workflow execution. Connects to Temporal
// server and starts the TrivyScanWorkflow to scan all running container images.
// -------------------------------------------------------------------------------

package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"go.temporal.io/sdk/client"
)

func main() {
	temporalAddress := os.Getenv("TEMPORAL_ADDRESS")
	if temporalAddress == "" {
		temporalAddress = "localhost:7233"
	}

	c, err := client.Dial(client.Options{
		HostPort: temporalAddress,
	})
	if err != nil {
		log.Fatalf("Failed to create Temporal client: %v", err)
	}
	defer c.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Start trivy scan workflow
	workflowOptions := client.StartWorkflowOptions{
		ID:        fmt.Sprintf("trivy-scan-%d", time.Now().Unix()),
		TaskQueue: "trivy-task-queue",
	}

	we, err := c.ExecuteWorkflow(ctx, workflowOptions, "TrivyScanWorkflow")
	if err != nil {
		log.Fatalf("Failed to start workflow: %v", err)
	}

	log.Printf("Workflow started: %s", we.GetID())
}
