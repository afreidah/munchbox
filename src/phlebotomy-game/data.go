// -------------------------------------------------------------------------------
// Tube Data Model
//
// Project: Munchbox / Author: Alex Freidah
//
// Defines the blood collection tube data structure and the canonical list of
// tubes used in phlebotomy order of draw. Supports loading custom data from an
// external JSON file (set TUBES_FILE env var or mount to /data/tubes.json).
// -------------------------------------------------------------------------------

package main

import (
	"encoding/json"
	"log"
	"os"
)

// Tube represents a blood collection tube with its draw order, color, name,
// and contents (additives).
type Tube struct {
	Order    int    `json:"order"`
	Color    string `json:"color"`
	Name     string `json:"name"`
	Contents string `json:"contents"`
}

// Tubes contains the order of draw for blood collection tubes.
// Loaded from external file if available, otherwise uses defaults.
var Tubes []Tube

// defaultTubes contains the built-in tube data.
var defaultTubes = []Tube{
	{1, "blue and red bottles", "blood culture", "sodium polyanethol sulfonate (SPS)"},
	{2, "light blue", "coagulation tube", "sodium citrate"},
	{3, "red", "non-additive tube", "none"},
	{4, "gold/tiger top", "SST", "clot activator and gel"},
	{5, "light green", "PST", "lithium heparin"},
	{5, "dark green", "heparin tube", "sodium heparin"},
	{6, "lavender", "EDTA tube", "potassium EDTA"},
	{7, "grey", "glycolytic inhibitor tube", "potassium oxalate and sodium fluoride"},
}

// LoadTubeData loads tube data from an external JSON file if available,
// otherwise uses the embedded defaults.
func LoadTubeData() {
	// Check for custom data file
	dataFile := os.Getenv("TUBES_FILE")
	if dataFile == "" {
		dataFile = "/data/tubes.json"
	}

	data, err := os.ReadFile(dataFile)
	if err != nil {
		// File not found or unreadable, use defaults
		log.Printf("Using default tube data (no custom file at %s)", dataFile)
		Tubes = defaultTubes
		return
	}

	var customTubes []Tube
	if err := json.Unmarshal(data, &customTubes); err != nil {
		log.Printf("Error parsing %s: %v - using defaults", dataFile, err)
		Tubes = defaultTubes
		return
	}

	log.Printf("Loaded %d tubes from %s", len(customTubes), dataFile)
	Tubes = customTubes
}

// TubesByOrder returns tubes grouped by their draw order number.
func TubesByOrder() map[int][]Tube {
	result := make(map[int][]Tube)
	for _, t := range Tubes {
		result[t.Order] = append(result[t.Order], t)
	}
	return result
}

// UniqueOrders returns the distinct order numbers in sequence.
func UniqueOrders() []int {
	seen := make(map[int]bool)
	var orders []int
	for _, t := range Tubes {
		if !seen[t.Order] {
			seen[t.Order] = true
			orders = append(orders, t.Order)
		}
	}
	return orders
}
