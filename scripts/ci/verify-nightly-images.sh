#!/usr/bin/env bash
# =============================================================================
# verify-nightly-images.sh
#
# Pre-flight check for the nightly pipeline: verifies that every platform image
# we are about to deploy actually exists for the requested NIGHTLY_IMAGE_TAG
# *before* we spend time provisioning a vcluster.
#
# Checks are done against the GitLab Container Registry v2 API over HTTP
# (curl + jq), so no Docker daemon is required in the CI image.
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

REGISTRY_HOST="registry.gitlab.com"
# GitLab issues registry pull tokens from its JWT auth service.
AUTH_SERVICE="container_registry"
AUTH_URL="https://gitlab.com/jwt/auth"

# Repositories that get the per-environment NIGHTLY_IMAGE_TAG applied
REPOSITORIES=(
  "registry.gitlab.com/civitas-connect/civitas-core/civitas-core-v2/civitas-core-platform/authz-repo-service"
  "registry.gitlab.com/civitas-connect/civitas-core/civitas-core-v2/civitas-core-platform/opa"
  "registry.gitlab.com/civitas-connect/civitas-core/civitas-core-v2/civitas-core-platform/config-adapter"
  "registry.gitlab.com/civitas-connect/civitas-core/civitas-core-v2/civitas-core-platform/backend-portal"
  "registry.gitlab.com/civitas-connect/civitas-core/civitas-core-v2/civitas-core-platform/frontend-portal"
)

# Query the registry over HTTP; requires curl and jq (both in the cicd image).
for tool in curl jq; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERROR: ${tool} is not available to inspect image manifests" >&2
    exit 2
  fi
done

# Manifest media types accepted when probing a tag (schema2 + OCI, single + list).
ACCEPT_HEADER="application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.oci.image.index.v1+json"

# Strip the registry host prefix to get the bare repository path used by the
# registry v2 API and the JWT auth scope.
repo_path() {
  local repo="$1"
  echo "${repo#"${REGISTRY_HOST}"/}"
}

# Fetch a short-lived Bearer token scoped to pull the given repository.
# Prints the token on stdout (empty string if none could be obtained).
get_token() {
  local path="$1"
  local auth_args=()
  if [ -n "${REGISTRY_USER}" ] && [ -n "${REGISTRY_PASSWORD}" ]; then
    auth_args=(--user "${REGISTRY_USER}:${REGISTRY_PASSWORD}")
  fi
  curl -fsSL "${auth_args[@]}" \
    "${AUTH_URL}?service=${AUTH_SERVICE}&scope=repository:${path}:pull" 2>/dev/null \
    | jq -r '.token // .access_token // empty' 2>/dev/null || true
}

# Return 0 if the manifest for the given repo:tag exists (HTTP 200), else 1.
inspect_exists() {
  local repo="$1"
  local path token status
  path="$(repo_path "${repo}")"
  token="$(get_token "${path}")"

  local auth_args=()
  if [ -n "${token}" ]; then
    auth_args=(-H "Authorization: Bearer ${token}")
  fi

  status="$(curl -s -o /dev/null -w '%{http_code}' -I \
    -H "Accept: ${ACCEPT_HEADER}" \
    "${auth_args[@]}" \
    "https://${REGISTRY_HOST}/v2/${path}/manifests/${NIGHTLY_IMAGE_TAG}" 2>/dev/null || true)"

  [ "${status}" = "200" ]
}

echo "Verifying platform images exist for tag '${NIGHTLY_IMAGE_TAG}'..."

MISSING=()
for repo in "${REPOSITORIES[@]}"; do
  ref="${repo}:${NIGHTLY_IMAGE_TAG}"
  if inspect_exists "${repo}"; then
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
