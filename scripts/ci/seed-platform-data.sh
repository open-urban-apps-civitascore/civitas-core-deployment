#!/usr/bin/env bash
# =============================================================================
# seed-platform-data.sh
#
# Imports baseline platform seed data into a Kubernetes cluster that already
# has the civitas-core platform (keycloak, apisix, …) deployed.
#
# Callable from:
#   * GitLab CI (`seed-branch`/`seed-mr` job) — parameters via job env

#     (incl. PIPELINE_SLUG + SMOKE_TEST_BASE_DOMAIN, which together yield
#     KEYCLOAK_URL).
#   * Locally via `just seed <keycloak-url> [kubeconfig] [seed-input]` —
#     the recipe exports KEYCLOAK_URL / SEED_INPUT, all remaining knobs
#     are read from the top-level `.env` (see `.env.example`).
#
# Flow:
#   1. Resolve parameters from env (with sensible civitas defaults).
#   2. If AUTH_PASSWORD is set, trust it and skip the keycloak reset.
#      Otherwise generate an ephemeral password and kcadm.sh-force-set it
#      (plus clear requiredActions), so the seed container can obtain an
#      OIDC token via the ROPC grant.
#   3. Stash credentials in a short-lived k8s Secret consumed by the Job.
#   4. Launch the seed-platform-data container as a Job, stream logs, wait
#      for completion, and delete the Job + Secret on exit.
#
# Usage:  scripts/ci/seed-platform-data.sh [--kubeconfig PATH]
# =============================================================================
set -Eeuo pipefail

# -----------------------------------------------------------------------------
# Argument parsing — only --kubeconfig is accepted; it is exported as
# KUBECONFIG so every subsequent kubectl call picks it up automatically.
# -----------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --kubeconfig)    export KUBECONFIG="$2"; shift 2 ;;
    --kubeconfig=*)  export KUBECONFIG="${1#*=}"; shift ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

# -----------------------------------------------------------------------------
# Resolve parameters
#
# PIPELINE_SLUG is set by the CI job (branches: $CI_COMMIT_REF_SLUG, MRs:
# mr-$CI_MERGE_REQUEST_IID) and matches the smoke-test vcluster created by
# deploy-branch/deploy-mr. Locally (via `just seed`) it is unset and KEYCLOAK_URL

# is supplied directly as a recipe argument.
# -----------------------------------------------------------------------------
NAMESPACE="${NAMESPACE:-civitas}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-civitas}"
API_BASE_URL="${API_BASE_URL:-http://apisix-gateway.${NAMESPACE}.svc.cluster.local/v1}"
SEED_IMAGE="${SEED_IMAGE:-registry.gitlab.com/civitas-connect/civitas-core/docker-images/seed-platform-data:1.0.0}"
SEED_INPUT="${SEED_INPUT:-exports/1bf03aa3-3d9a-4291-8589-b888aa684c05.json}"
AUTH_USER="${AUTH_USER:-${GITLAB_USER_EMAIL:-admin@civitas.test}}"

if [ -z "${KEYCLOAK_URL:-}" ]; then
  if [ -n "${PIPELINE_SLUG:-}" ] && [ -n "${SMOKE_TEST_BASE_DOMAIN:-}" ]; then
    KEYCLOAK_URL="https://idm.${PIPELINE_SLUG}.${SMOKE_TEST_BASE_DOMAIN}"
  else
    echo "ERROR: KEYCLOAK_URL must be set (or run in CI with both PIPELINE_SLUG and SMOKE_TEST_BASE_DOMAIN)" >&2
    exit 1
  fi
fi

# JOB_NAME: PIPELINE_SLUG-based in CI, timestamp-based locally.
if [ -z "${JOB_NAME:-}" ]; then
  if [ -n "${PIPELINE_SLUG:-}" ]; then
    JOB_NAME="seed-data-${PIPELINE_SLUG}"
  else
    JOB_NAME="seed-data-local-$(date +%s)"
  fi
fi

# Disable command tracing — AUTH_PASSWORD and KC_ADMIN_PASSWORD must not hit
# the job log.
set +x

# -----------------------------------------------------------------------------
# Cleanup: kill log follower, remove Job + Secret on exit
# -----------------------------------------------------------------------------
cleanup() {
  local rc=$?
  if [ -n "${LOG_PID:-}" ] && kill -0 "${LOG_PID}" 2>/dev/null; then
    kill "${LOG_PID}" 2>/dev/null || true
    wait "${LOG_PID}" 2>/dev/null || true
  fi
  if [ "${SKIP_CLEANUP:-0}" != "1" ]; then
    kubectl -n "${NAMESPACE}" delete job "${JOB_NAME}" --ignore-not-found >/dev/null 2>&1 || true
    kubectl -n "${NAMESPACE}" delete secret seed-data-auth --ignore-not-found >/dev/null 2>&1 || true
  fi
  exit "${rc}"
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
cat <<EOF
Seeding platform data
  context        : $(kubectl config current-context 2>/dev/null || echo '(unknown)')
  kubeconfig     : ${KUBECONFIG:-<default>}
  namespace      : ${NAMESPACE}
  realm          : ${KEYCLOAK_REALM}
  keycloak URL   : ${KEYCLOAK_URL}
  api base URL   : ${API_BASE_URL}
  auth user      : ${AUTH_USER}
  auth password  : $([ -n "${AUTH_PASSWORD:-}" ] && echo "<from env, skipping kcadm reset>" || echo "<will be generated>")
  seed image     : ${SEED_IMAGE}
  seed input     : ${SEED_INPUT}
  job name       : ${JOB_NAME}
EOF

# -----------------------------------------------------------------------------
# 1. Establish AUTH_PASSWORD (use provided one, or generate + kcadm reset)
#    Delegates to the shared set-initial-user-password.sh, which also writes
#    AUTH_DOTENV_FILE when set. Sourced so AUTH_USER/AUTH_PASSWORD are exported.
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NAMESPACE KEYCLOAK_REALM AUTH_USER KEYCLOAK_URL
# shellcheck source=scripts/ci/set-initial-user-password.sh
source "${SCRIPT_DIR}/set-initial-user-password.sh"


# -----------------------------------------------------------------------------
# 2. Stash credentials in a short-lived Secret consumed by the Job.
#    The secret keys (AUTH_EMAIL / AUTH_PASSWORD) match the env-var names the
#    seed-platform-data container expects — those are external contracts.
# -----------------------------------------------------------------------------
kubectl -n "${NAMESPACE}" create secret generic seed-data-auth \
  --from-literal=AUTH_EMAIL="${AUTH_USER}" \
  --from-literal=AUTH_PASSWORD="${AUTH_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "seed-data-auth secret ensured"

# -----------------------------------------------------------------------------
# 3. Create and launch the seed-data Job
# -----------------------------------------------------------------------------
kubectl -n "${NAMESPACE}" delete job "${JOB_NAME}" --ignore-not-found

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: seed-platform-data
    app.kubernetes.io/instance: ${JOB_NAME}
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: seed-data
    app.kubernetes.io/part-of: civitas-platform
    app.kubernetes.io/managed-by: civitas-seed-script
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app.kubernetes.io/name: seed-platform-data
        app.kubernetes.io/instance: ${JOB_NAME}
        app.kubernetes.io/version: "1.0.0"
        app.kubernetes.io/component: seed-data
        app.kubernetes.io/part-of: civitas-platform
        app.kubernetes.io/managed-by: civitas-seed-script
    spec:
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: seed
          image: ${SEED_IMAGE}
          imagePullPolicy: Always
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
          args:
            - import
            - --input
            - ${SEED_INPUT}
          env:
            - name: KEYCLOAK_URL
              value: "${KEYCLOAK_URL}"
            - name: KEYCLOAK_REALM
              value: "${KEYCLOAK_REALM}"
            - name: KEYCLOAK_CLIENT_ID
              value: "portal-frontend"
            - name: KEYCLOAK_CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: keycloak-client-portal-frontend
                  key: client-secret
            - name: AUTH_EMAIL
              valueFrom:
                secretKeyRef:
                  name: seed-data-auth
                  key: AUTH_EMAIL
            - name: AUTH_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: seed-data-auth
                  key: AUTH_PASSWORD
            - name: API_BASE_URL
              value: "${API_BASE_URL}"
EOF

# -----------------------------------------------------------------------------
# 4. Stream logs + wait for completion
# -----------------------------------------------------------------------------
echo "Waiting for Job ${JOB_NAME} to finish (timeout 10m)..."

# Tail logs in the background so the CI log is live.
(
  if kubectl -n "${NAMESPACE}" wait --for=condition=Ready pod \
       -l "job-name=${JOB_NAME}" --timeout=120s >/dev/null 2>&1; then
    kubectl -n "${NAMESPACE}" logs -f -l "job-name=${JOB_NAME}" --tail=-1 || true
  fi
) &
LOG_PID=$!

# `kubectl wait` for job completion
set +e
kubectl -n "${NAMESPACE}" wait --for=condition=complete \
  "job/${JOB_NAME}" --timeout=600s
COMPLETE_RC=$?
set -e

if [ "${COMPLETE_RC}" -ne 0 ]; then
  if kubectl -n "${NAMESPACE}" get "job/${JOB_NAME}" \
      -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' \
      | grep -q True; then
    echo "Seed-data Job failed. Last logs:" >&2
    kubectl -n "${NAMESPACE}" logs -l "job-name=${JOB_NAME}" --tail=-1 >&2 || true
    exit 1
  fi
  echo "Timed out waiting for seed-data Job to complete" >&2
  kubectl -n "${NAMESPACE}" describe "job/${JOB_NAME}" >&2 || true
  exit 1
fi

echo "Seed-data Job completed successfully"
