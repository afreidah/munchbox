// -------------------------------------------------------------------------------
// Metadata Validation for Nomad Jobs
//
// Project: Munchbox / Author: Alex Freidah
//
// Validates that all Nomad job files contain required metadata fields (version,
// owner, category, tier) and ensures proper formatting with clear error messages.
// -------------------------------------------------------------------------------

package common

import (
	"fmt"
	"regexp"
	"strings"
)

// ============================================================================
// Metadata Validation
// ============================================================================

// ValidateMetadata checks that a Nomad job HCL file contains all required
// metadata fields with valid values.
//
// Required fields:
//   - version: Service version (e.g., "2.54.1" or "dev")
//   - owner: Owner identifier (e.g., "alex.freidah")
//   - category: Service category (monitoring, infrastructure, etc.)
//   - tier: Service tier (tier-0, tier-1, tier-2, tier-3)
//   - description: Human-readable service description
//
// Parameters:
//   - hcl: Complete HCL content of the Nomad job file
//
// Returns:
//   - error: nil if validation passes, error describing the problem if it fails
func ValidateMetadata(hcl string) error {
	// Define required metadata fields
	required := []string{
		"version",
		"owner",
		"category",
		"tier",
		"description",
	}

	// Check each required field
	for _, field := range required {
		// Pattern matches: field_name = "any_value"
		pattern := fmt.Sprintf(`%s\s*=\s*"[^"]+"`, field)

		matched, err := regexp.MatchString(pattern, hcl)
		if err != nil {
			return fmt.Errorf("regex error for field %s: %w", field, err)
		}

		if !matched {
			return fmt.Errorf("missing required metadata field: %s", field)
		}
	}

	// Validate tier value if present
	if err := validateTierValue(hcl); err != nil {
		return err
	}

	return nil
}

// ============================================================================
// Tier Validation
// ============================================================================

// validateTierValue ensures the tier field contains a valid tier level.
//
// Valid tier values:
//   - tier-0: Critical services
//   - tier-1: Important services
//   - tier-2: Standard services
//   - tier-3: Nice-to-have services
//
// Parameters:
//   - hcl: HCL content to validate
//
// Returns:
//   - error: nil if valid, error if tier value is invalid
func validateTierValue(hcl string) error {
	tierPattern := regexp.MustCompile(`tier\s*=\s*"([^"]+)"`)
	matches := tierPattern.FindStringSubmatch(hcl)

	if len(matches) > 1 {
		tier := matches[1]
		validTiers := []string{"tier-0", "tier-1", "tier-2", "tier-3"}

		isValid := false
		for _, valid := range validTiers {
			if tier == valid {
				isValid = true
				break
			}
		}

		if !isValid {
			return fmt.Errorf("invalid tier value: %s (must be one of: %s)",
				tier, strings.Join(validTiers, ", "))
		}
	}

	return nil
}

// ============================================================================
// Metadata Existence Check
// ============================================================================

// HasMetadata checks if a job HCL file contains any metadata block.
//
// This is a simple check to determine if metadata injection is needed.
// It does not validate the metadata content - use ValidateMetadata for that.
//
// Parameters:
//   - hcl: Complete HCL content of the Nomad job file
//
// Returns:
//   - bool: true if a meta block exists, false otherwise
func HasMetadata(hcl string) bool {
	return strings.Contains(hcl, "meta {")
}
