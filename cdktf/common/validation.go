// --------------------------------------------------------------------
// Metadata Validation for Nomad Jobs
// File: common/validation.go
//
// Purpose:
//   - Validates that all Nomad job files contain required metadata
//   - Ensures metadata fields are properly formatted
//   - Provides clear error messages for missing or invalid metadata
//
// Validation Rules:
//   Required fields:
//     - version: Must be present and non-empty
//     - updated: Must be present in YYYY-MM-DD format
//     - owner: Must be present and non-empty
//     - category: Must be present and non-empty
//     - tier: Must be present and match tier-0, tier-1, tier-2, or tier-3
//     - description: Must be present and non-empty
// --------------------------------------------------------------------

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
//   - updated: Last update date (YYYY-MM-DD format)
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
		"updated",
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

	// Validate date format if present
	if err := validateDateFormat(hcl); err != nil {
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
// Date Format Validation
// ============================================================================

// validateDateFormat ensures the updated field contains a valid ISO date.
//
// Expected format: YYYY-MM-DD (e.g., "2025-10-03")
//
// Parameters:
//   - hcl: HCL content to validate
//
// Returns:
//   - error: nil if valid, error if date format is invalid
func validateDateFormat(hcl string) error {
	datePattern := regexp.MustCompile(`updated\s*=\s*"([^"]+)"`)
	matches := datePattern.FindStringSubmatch(hcl)

	if len(matches) > 1 {
		date := matches[1]

		// Validate YYYY-MM-DD format
		validDatePattern := regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
		if !validDatePattern.MatchString(date) {
			return fmt.Errorf("invalid date format for 'updated' field: %s (expected YYYY-MM-DD)", date)
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
