#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Validate SBOM output from generate-artifact-inventory.sh.

Usage:
  scripts/validate-sbom-output.sh [--out-dir <path>] [--deployment-repo <path>]

Options:
  --out-dir <path>          Output directory to validate (default: latest in <deployment>/out/sbom-*)
  --deployment-repo <path>  Deployment repo path (default: cwd)
  --help                    Show this help

Exit codes:
  0  All checks passed
  1  Validation failed
USAGE
}

die() {
  echo "FAIL: $*" >&2
  exit 1
}

DEPLOYMENT_REPO="$(pwd)"
OUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --deployment-repo) DEPLOYMENT_REPO="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(ls -1dt "$DEPLOYMENT_REPO"/out/sbom-* 2>/dev/null | head -n 1)"
  [[ -n "$OUT_DIR" ]] || die "No sbom output directories found in $DEPLOYMENT_REPO/out/"
fi

echo "Validating: $OUT_DIR"

errors=0

for f in \
  SUMMARY.md \
  sources/deployment.source.cdx.json \
  sources/deployment.source.spdx.json \
  sources/platform.source.cdx.json \
  sources/platform.source.spdx.json \
  images/image-file-map.txt; do
  if [[ -f "$OUT_DIR/$f" ]]; then
    echo "  OK   $f"
  else
    echo "  MISSING   $f"
    errors=$((errors + 1))
  fi
done

echo ""
echo "Scan status:"
for f in images/images.txt images/scanned-images.txt images/failed-images.txt images/pending-images.txt; do
  if [[ -f "$OUT_DIR/$f" ]]; then
    count="$(wc -l < "$OUT_DIR/$f" | tr -d ' ')"
    echo "  $count	$f"
  else
    echo "  -	$f (missing)"
  fi
done

pending="$OUT_DIR/images/pending-images.txt"
if [[ -s "$pending" ]]; then
  echo ""
  echo "WARNING: $(wc -l < "$pending" | tr -d ' ') images still pending"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then
  echo "All checks passed."
else
  echo "$errors check(s) failed."
  exit 1
fi
