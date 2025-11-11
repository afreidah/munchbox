#!/bin/bash
# -------------------------------------------------------------------------------
# Nomad Pack Test Script
# Author: Alex Freidah
# 
# Quick testing script for nomad-service pack against all job files
# -------------------------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PACK_PATH="./packs/registry/nomad-service"
DEFAULTS="defaults.hcl"
FAILED_JOBS=()
PASSED_JOBS=()

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [JOB_PATH]

Test nomad-service pack rendering against job files.

OPTIONS:
    -r, --render     Render only (don't run)
    -v, --verbose    Show full output
    -h, --help       Show this help message

EXAMPLES:
    $0                                      # Test all jobs (render only)
    $0 jobs/monitoring/grafana/grafana.hcl  # Test specific job
    $0 -v jobs/media/                       # Test all media jobs with output
    $0 --run jobs/backup/                   # Actually deploy backup jobs

EOF
    exit 0
}

# Parse arguments
MODE="render"
VERBOSE=false
TARGET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--render)
            MODE="render"
            shift
            ;;
        --run)
            MODE="run"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

# Find job files
find_jobs() {
    local path="${1:-jobs}"
    if [[ -f "$path" ]]; then
        echo "$path"
    elif [[ -d "$path" ]]; then
        find "$path" -name "*.hcl" -type f | grep -v "files/" | sort
    else
        echo "Error: Path not found: $path" >&2
        exit 1
    fi
}

# Test a single job
test_job() {
    local job_file="$1"
    local job_name=$(basename "$job_file" .hcl)
    
    printf "Testing %-50s " "$job_file"
    
    local output
    local exit_code=0
    
    if $VERBOSE; then
        echo ""
        nomad-pack $MODE "$PACK_PATH" -f "$job_file" -f "$DEFAULTS" || exit_code=$?
    else
        output=$(nomad-pack $MODE "$PACK_PATH" -f "$job_file" -f "$DEFAULTS" 2>&1) || exit_code=$?
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        printf "${GREEN}✓ PASS${NC}\n"
        PASSED_JOBS+=("$job_file")
        return 0
    else
        printf "${RED}✗ FAIL${NC}\n"
        FAILED_JOBS+=("$job_file")
        if ! $VERBOSE; then
            echo "$output" | tail -20
        fi
        return 1
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "Nomad Pack Test Suite"
    echo "=========================================="
    echo "Mode: $MODE"
    echo "Pack: $PACK_PATH"
    echo ""
    
    local jobs
    jobs=$(find_jobs "${TARGET:-jobs}")
    local total=$(echo "$jobs" | wc -l)
    
    echo "Found $total job(s) to test"
    echo ""
    
    for job in $jobs; do
        test_job "$job" || true
    done
    
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total:  $total"
    echo -e "${GREEN}Passed: ${#PASSED_JOBS[@]}${NC}"
    echo -e "${RED}Failed: ${#FAILED_JOBS[@]}${NC}"
    
    if [[ ${#FAILED_JOBS[@]} -gt 0 ]]; then
        echo ""
        echo "Failed jobs:"
        for job in "${FAILED_JOBS[@]}"; do
            echo "  - $job"
        done
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
}

main
