#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# nomad-test.sh: Start Nomad dev agent, run/validate/purge all jobs, then shutdown
#
# - Starts a Nomad dev agent in the background
# - Validates, runs, checks, and purges each job file in nomad-jobs/
# - Strips out constraint blocks for local/dev testing so jobs can be placed
# - Skips server jobs (not supported in dev mode)
# - Handles batch jobs by checking for completion
# - Cleans up by killing the Nomad dev agent at the end
# -------------------------------------------------------------------------------

set -e

NOMAD_JOBS=$(find nomad-jobs -name "*.nomad.hcl" -o -name "*.hcl" | sort)
NOMAD=${NOMAD:-nomad}

echo "Starting Nomad dev agent..."
NOMAD_DEV_PID=""
nomad agent -dev > /tmp/nomad-dev.log 2>&1 &
NOMAD_DEV_PID=$!
sleep 3
echo "Nomad dev agent started with PID $NOMAD_DEV_PID"

RET=0

for file in $NOMAD_JOBS; do
  JOB_TYPE=$(grep -m1 'type *=' "$file" | awk -F'"' '{print $2}')
  JOB_NAME=$(basename "$file" .nomad.hcl | sed 's/\.hcl$//')
  echo "Validating $file..."
  $NOMAD job validate "$file" || { RET=1; break; }
  if [ "$JOB_TYPE" = "server" ]; then
    echo "Skipping $file (server jobs can't be tested in dev mode)"
    continue
  fi
  # Strip out constraint blocks for dev testing
  TMPFILE=$(mktemp)
  awk '
    BEGIN { skip=0 }
    /^\s*constraint\s*{/ { skip=1 }
    skip && /^\s*}/ { skip=0; next }
    skip { next }
    { print }
  ' "$file" > "$TMPFILE"
  echo "Running $file (constraints removed for dev)..."
  $NOMAD job run "$TMPFILE" || { RET=1; rm -f "$TMPFILE"; break; }
  echo "Waiting for job $JOB_NAME to be running..."
  sleep 5
  if [ "$JOB_TYPE" = "batch" ]; then
    $NOMAD job status "$JOB_NAME" | grep -q "complete" || { echo "Batch job $JOB_NAME did not complete"; RET=1; rm -f "$TMPFILE"; break; }
  else
    $NOMAD job status "$JOB_NAME" || { RET=1; rm -f "$TMPFILE"; break; }
  fi
  echo "Stopping and purging job $JOB_NAME..."
  $NOMAD job stop -purge "$JOB_NAME" || { RET=1; rm -f "$TMPFILE"; break; }
  rm -f "$TMPFILE"
done

echo "Killing Nomad dev agent..."
kill $NOMAD_DEV_PID
exit $RET
