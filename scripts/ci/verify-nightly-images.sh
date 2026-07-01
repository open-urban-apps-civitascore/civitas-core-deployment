#!/usr/bin/env bash
# =============================================================================
# verify-nightly-images.sh
#
# Pre-flight check for the nightly pipeline: verifies that every platform image
# we are about to deploy actually exists for the requested NIGHTLY_IMAGE_TAG
# *before* we spend time provisioning a vcluster.
#
# Required environment:
#   NIGHTLY_IMAGE_TAG   the tag to check (e.g. develop-nightly-20260628)
#
# Optional environment (registry auth — defaults to GitLab CI predefined vars):
#   REGISTRY_USER       (default: $CI_REGISTRY_USER)
#   REGISTRY_PASSWORD   (default: $CI_REGISTRY_PASSWORD, falls back to $CI_JOB_TOKEN)
#
# Exits non-zero (hard fail) if any image:tag is missing.
# =============================================================================
set -Eeuo pipefail

: "${NIGHTLY_IMAGE_TAG:?NIGHTLY_IMAGE_TAG must be set}"

REGISTRY_USER="${REGISTRY_USER:-${CI_REGISTRY_USER:-}}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-${CI_REGISTRY_PASSWORD:-${CI_JOB_TOKEN:-}}}"

# Repositories that get the per-environment NIGHTLY_IMAGE_TAG applied
REPOSITORIES=(
  "registry.gitlab.com/civitas-connect/civitas-core/civitas-core-v2/civitas-core-platform/authz-repo-service"
  "registry.gitlab.com/civitas-connect/civitas-core/civitas-core-v2/civitas-core-platform/opa"
  "registry.gitlab.com/civitas-connect/civitas-core/civitas-core-v2/civitas-core-platform/config-adapter"
  "registry.gitlab.com/civitas-connect/civitas-core/civitas-core-v2/civitas-core-platform/backend-portal"
  "registry.gitlab.com/civitas-connect/civitas-core/civitas-core-v2/civitas-core-platform/frontend-portal"
)

# Check whether an image reference exists in the registry using Docker.
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not available to inspect image manifests" >&2
  exit 2
fi

# Authenticate once against the registry so manifest inspection works for
# private repositories. Failures are non-fatal (public images still work).
if [ -n "${REGISTRY_USER}" ] && [ -n "${REGISTRY_PASSWORD}" ]; then
  echo "${REGISTRY_PASSWORD}" \
    | docker login registry.gitlab.com -u "${REGISTRY_USER}" --password-stdin >/dev/null 2>&1 || true
fi

inspect_exists() {
  local ref="$1"
  docker manifest inspect "${ref}" >/dev/null 2>&1
}

echo "Verifying platform images exist for tag '${NIGHTLY_IMAGE_TAG}'..."

MISSING=()
for repo in "${REPOSITORIES[@]}"; do
  ref="${repo}:${NIGHTLY_IMAGE_TAG}"
  if inspect_exists "${ref}"; then
    echo "  OK      ${ref}"
  else
    echo "  MISSING ${ref}"
    MISSING+=("${ref}")
  fi
done

if [ "${#MISSING[@]}" -ne 0 ]; then
  echo "" >&2
  echo "ERROR: ${#MISSING[@]} image(s) missing for tag '${NIGHTLY_IMAGE_TAG}'. Aborting before vcluster setup:" >&2
  for ref in "${MISSING[@]}"; do
    echo "  - ${ref}" >&2
  done
  exit 1
fi

echo "All ${#REPOSITORIES[@]} images present for tag '${NIGHTLY_IMAGE_TAG}'."
