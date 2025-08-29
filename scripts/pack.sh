#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Nomad Pack Wrapper (clean jobspec)
#
# Usage:
#   scripts/pack.sh render  <pack> <env>
#   scripts/pack.sh validate <pack> <env>
#   scripts/pack.sh run     <pack> <env>
#   scripts/pack.sh stop    <pack> [--ref REF]
#   scripts/pack.sh status  <pack> [--ref REF]
#
# Notes:
# - Renders the pack, then STRIPS any prolog lines before the first `job "..." {`
# - Writes the cleaned jobspec to nomad/.tmp.<pack>.nomad.hcl
# - `run` uses `nomad job run` on the cleaned file to avoid pack’s internal validate noise
# ------------------------------------------------------------------------------

set -euo pipefail

CMD=${1:-}
PACK=${2:-}
ENV=${3:-pi-dc}   # default env if not provided

PACK_DIR="nomad/packs/community/${PACK}"
VALS="${PACK_DIR}/values.${ENV}.hcl"
OUT="nomad/.tmp.${PACK}.nomad.hcl"

clean_jobspec() {
  # Print from the first `job "<name>" {` line through EOF (drop any prolog headers)
  awk 'found{print} /^job "[^"]+"[[:space:]]*\{/ {found=1; print}'
}

case "$CMD" in
  render)
    echo "==> Rendering pack '$PACK' with $VALS"
    nomad-pack render -var-file "$VALS" "$PACK" | clean_jobspec > "$OUT"
    echo "Rendered cleaned jobspec to $OUT"
    head -1 "$OUT"
    ;;
  validate)
    echo "==> Rendering + validating cleaned jobspec"
    nomad-pack render -var-file "$VALS" "$PACK" | clean_jobspec | tee "$OUT" | nomad job validate -
    ;;
  run)
    echo "==> Rendering + validating + running cleaned jobspec"
    nomad-pack render -var-file "$VALS" "$PACK" | clean_jobspec | tee "$OUT" | nomad job validate -
    nomad job run "$OUT"
    ;;
  stop)
    # still support pack-level stop if you deployed via `nomad-pack run`
    REF=${ENV:-latest}
    echo "==> Stopping pack '$PACK' (ref: $REF)"
    nomad-pack stop "$PACK" --ref="$REF"
    ;;
  status)
    REF=${ENV:-latest}
    echo "==> Status for pack '$PACK' (ref: $REF)"
    nomad-pack status "$PACK" --ref="$REF" || true
    ;;
  *)
    echo "Usage: $0 {render|validate|run|stop|status} <pack> [env]"
    exit 1
    ;;
esac
