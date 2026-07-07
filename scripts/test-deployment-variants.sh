#!/usr/bin/env bash
#
# This work is licensed under [EU PL 1.2]
# (https://gitlab.com/civitas-connect/civitas-core/civitas-core/-/blob/main/LICENSE)
# by Civitas Connect e. V., Hafenweg 7, 48155 Münster, Germany, and [other authors].
#
# You may not use this work except in compliance with the Licence.
#
# -----------------------------------------------------------------------------
# Deploy every deployment variant into its own fresh k3d dev cluster, one after
# another, and assert after each deployment that the smoke test passes:
#   * all pods are green (Running+Ready, or Completed), and
#   * every Deployment/StatefulSet/DaemonSet rolled out successfully.
#
# Variant axes (each ja/nein):
#   * multi-namespace  -> global.singleNamespace        (nein=true / ja=false)
#   * multi-instance   -> two-layer operators+instance  vs. all-in-one helmfile
#   * linkerd          -> global.serviceMesh.enable     (+ Linkerd control plane)
#
# A variant is encoded as a triplet  MNS,MI,LNK  of 0/1, e.g.  1,0,1
# (multi-namespace=yes, multi-instance=no, linkerd=yes). With no triplet given
# all 8 combinations run.
#
#   ./scripts/test-deployment-variants.sh                 # all 8 variants
#   ./scripts/test-deployment-variants.sh 0,0,0 1,1,1     # only these two
#   ./scripts/test-deployment-variants.sh --list          # show the matrix
# -----------------------------------------------------------------------------

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# --- defaults ---------------------------------------------------------------
# Scratch helmfile environment the harness OWNS: it generates this environment's
# global.yaml.gotmpl per variant with the toggle values. CLI --state-values-set is
# NOT forwarded to the components by the entrypoints, so the toggles must live in
# the environment's values file (which helmfile-root loads directly).
ENV="testing"
PROFILE="development"  # global.profile written into the scratch env (development|production)
CLUSTER_NAME="civitas-local"
TIMEOUT="900"          # per-variant wait budget for pods+rollout (seconds)
MANAGE_CLUSTER=true    # recreate a fresh k3d cluster per variant
KEEP_CLUSTER=false     # keep the last cluster around after the run
CONTINUE_ON_FAILURE=false  # on failure, tear down and proceed to the next variant
USE_REGISTRY_CACHE=true    # start the local pull-through image caches first
LIST_ONLY=false
SELECTED=()

# --- colors -----------------------------------------------------------------
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi
log()  { echo -e "${BLUE}==>${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }

usage() {
  cat <<EOF
Deploy every deployment variant into its own fresh k3d dev cluster, one after
another, and smoke-test it (all pods green + all workloads rolled out).

Variant axes (each ja/nein):
  multi-namespace  -> global.singleNamespace        (true / false)
  multi-instance   -> two-layer operators+instance  vs. all-in-one helmfile
  linkerd          -> global.serviceMesh.enable     (+ Linkerd control plane)

A variant is a triplet  MNS,MI,LNK  of 0/1, e.g.  1,0,1
(multi-namespace=yes, multi-instance=no, linkerd=yes). No triplet => all 8.

Usage: $(basename "$0") [options] [MNS,MI,LNK ...]

Options:
  -e, --env <env>     Scratch helmfile environment to generate & deploy
                      (default: ${ENV}). Refuses committed envs (local/…).
      --profile <p>   global.profile written into the scratch env: development
                      or production (default: ${PROFILE}). production also
                      installs the Prometheus Operator CRDs the prod values need.
      --timeout <s>   Wait budget per variant in seconds (default: ${TIMEOUT})
      --keep          Do not delete the last k3d cluster after the run
      --continue-on-failure
                      Tear down and proceed to the next variant on failure.
                      Default: stop on first failure and keep the cluster up
                      for inspection (k3d uses host ports 80/443, so only one
                      cluster can exist at a time).
      --no-registry-cache
                      Do not start the local pull-through image caches
                      (dev-deployment/registry-cache.sh). On by default.
      --no-cluster    Do not create/delete clusters; deploy into the current
                      kubectl context and clean platform namespaces between runs
      --list          Print the selected variant matrix and exit
  -h, --help          Show this help
EOF
}

# --- arg parsing ------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env)     ENV="$2"; shift 2 ;;
    --profile)    PROFILE="$2"; shift 2 ;;
    --timeout)    TIMEOUT="${2%s}"; shift 2 ;;
    --keep)       KEEP_CLUSTER=true; shift ;;
    --continue-on-failure) CONTINUE_ON_FAILURE=true; shift ;;
    --no-registry-cache) USE_REGISTRY_CACHE=false; shift ;;
    --no-cluster) MANAGE_CLUSTER=false; shift ;;
    --list)       LIST_ONLY=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    all)          SELECTED=(); shift ;;
    [01],[01],[01]) SELECTED+=("$1"); shift ;;
    *) err "unknown argument: $1"; echo; usage; exit 1 ;;
  esac
done

case "$PROFILE" in
  development|production) ;;
  *) err "--profile must be 'development' or 'production' (got '$PROFILE')"; exit 1 ;;
esac

# Build the variant matrix (default: all 8 combinations).
COMBOS=()
if [[ ${#SELECTED[@]} -gt 0 ]]; then
  COMBOS=("${SELECTED[@]}")
else
  for mns in 0 1; do for mi in 0 1; do for lnk in 0 1; do
    COMBOS+=("${mns},${mi},${lnk}")
  done; done; done
fi

yn() { [[ "$1" == "1" ]] && echo "ja " || echo "nein"; }
describe() { # MNS MI LNK -> human readable
  printf "multi-ns=%s  multi-instance=%s  linkerd=%s" "$(yn "$1")" "$(yn "$2")" "$(yn "$3")"
}

if $LIST_ONLY; then
  log "Variant matrix (env=${ENV}):"
  for c in "${COMBOS[@]}"; do IFS=',' read -r mns mi lnk <<<"$c"; echo "  ${c}   $(describe "$mns" "$mi" "$lnk")"; done
  exit 0
fi

# --- environment overlay (where the toggles actually take effect) -----------
# Refuse to overwrite a committed environment's config.
case "$ENV" in
  local|production|nl-dev)
    err "--env '$ENV' is a committed environment; the harness generates the env file and would overwrite it."
    err "Use a scratch env (default: testing)."
    exit 1 ;;
esac
ENV_FILE="deployment/environments/${ENV}/global.yaml.gotmpl"
if [[ -e "$ENV_FILE" ]] && git ls-files --error-unmatch "$ENV_FILE" >/dev/null 2>&1; then
  err "$ENV_FILE is tracked by git; refusing to overwrite. Pick a different scratch env."
  exit 1
fi
# Remove the generated scratch env file on exit so the repo is left clean.
cleanup_env() { rm -f "$ENV_FILE"; rmdir "deployment/environments/${ENV}" 2>/dev/null || true; }
trap cleanup_env EXIT

# --- tooling pre-flight -----------------------------------------------------
need=(helmfile kubectl helm yq)
$MANAGE_CLUSTER && need+=(k3d)
# linkerd CLI only required if any selected variant enables the mesh
if printf '%s\n' "${COMBOS[@]}" | grep -q ',1$'; then need+=(linkerd); fi
missing=()
for t in "${need[@]}"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
if [[ ${#missing[@]} -gt 0 ]]; then err "missing required tools: ${missing[*]}"; exit 1; fi

KCTX=""   # active kube context, set per variant

# --- instance slug (namespace base) -----------------------------------------
get_slug() {
  local f="deployment/environments/${ENV}/global.yaml.gotmpl" s=""
  [[ -f "$f" ]] && s="$(yq -r '.global.instanceSlug // ""' "$f" 2>/dev/null || true)"
  [[ -z "$s" || "$s" == "null" ]] && s="$(yq -r '.global.instanceSlug' defaults/environment/global.yaml)"
  echo "$s"
}

# --- cluster lifecycle ------------------------------------------------------
# Start the local pull-through image caches once. They persist across cluster
# recreations and are wired into k3d-civitas-local.yaml, so fresh clusters pull
# from the local cache instead of re-pulling every image from the internet.
ensure_registry_cache() {
  local script="dev-deployment/registry-cache.sh"
  if [[ ! -x "$script" ]]; then
    warn "registry cache script not found ($script) — continuing without it"
    return 0
  fi
  if ! command -v docker >/dev/null 2>&1; then
    warn "docker not available — skipping registry cache"
    return 0
  fi
  log "Starting local pull-through image caches"
  "$script" up || warn "registry cache failed to start — clusters will pull from upstream"
}

create_cluster() {
  log "Recreating fresh k3d cluster '${CLUSTER_NAME}' (+ ingress/metallb/cert-manager)"
  k3d cluster delete "$CLUSTER_NAME" >/dev/null 2>&1 || true
  local certarg=""
  [[ -f dev-deployment/.ssl/civitas.crt ]] || certarg="cert"
  ./dev-deployment/startup.sh -k $certarg
  KCTX="k3d-${CLUSTER_NAME}"
  kubectl config use-context "$KCTX" >/dev/null
}

# The production profile turns on CNPG's PodMonitor (and other ServiceMonitors),
# which need the Prometheus Operator CRDs to exist or the apply/reconcile fails.
# Install just the CRDs (server-side; the bundle is large) into the fresh cluster.
PROM_OPERATOR_VERSION="v0.78.2"
install_monitoring_crds() {
  log "Installing Prometheus Operator CRDs (${PROM_OPERATOR_VERSION}) for production profile"
  kubectl apply --server-side -f \
    "https://github.com/prometheus-operator/prometheus-operator/releases/download/${PROM_OPERATOR_VERSION}/stripped-down-crds.yaml"
}

install_linkerd() {
  log "Installing Linkerd control plane"
  linkerd check --pre
  kubectl apply --server-side -f \
    https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
  linkerd install --crds | kubectl apply -f -
  linkerd install --set proxy.nativeSidecar=true | kubectl apply -f -
  linkerd check
}

# Kyverno must be running before the platform deploys, because the
# runtime-policies component (components/runtime-policies) applies cluster-scoped
# ClusterPolicy objects that need Kyverno's CRDs + admission webhook to exist.
# This is the same idempotent bootstrap the CI smoke test and `just kyverno` use.
install_kyverno() {
  log "Installing Kyverno (runtime ClusterPolicies prerequisite)"
  ./scripts/ci/install-kyverno-if-missing.sh || return 1
  # Wait for the webhook to be serving so the policy applies don't race it.
  kubectl -n kyverno rollout status deploy --timeout=300s
}

# Keycloak needs its keycloak-smtp secret to exist before its pod starts,
# otherwise the pod never becomes ready. Mirror `just deploy`.
create_smtp_secret() { # MNS
  local slug ns
  slug="$(get_slug)"
  if [[ "$1" == "1" ]]; then ns="${slug}-keycloak"; else ns="${slug}"; fi
  log "Pre-creating keycloak-smtp secret in namespace '${ns}'"
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic keycloak-smtp -n "$ns" \
    --from-literal=host='smtp.example.com' \
    --from-literal=port='587' \
    --from-literal=from='noreply@example.com' \
    --from-literal=user='noreply@example.com' \
    --from-literal=password='YOUR_SMTP_PASSWORD' \
    --dry-run=client -o yaml | kubectl apply -f -
}

# --- deployment -------------------------------------------------------------
# Write the variant's toggles into the scratch environment's global override.
# This is the highest-precedence values file helmfile-root loads, so the toggles
# reliably reach every component (unlike --state-values-set, which the entrypoints
# do not forward). multi-instance is NOT set here — it is a deploy-time choice of
# entrypoint (operators+instance vs. all-in-one), not a global value.
write_env_overlay() { # MNS LNK
  local mns="$1" lnk="$2" single mesh
  single=$([[ "$mns" == "1" ]] && echo false || echo true)   # multi-ns => singleNamespace=false
  mesh=$([[ "$lnk" == "1" ]] && echo true || echo false)
  mkdir -p "$(dirname "$ENV_FILE")"
  cat > "$ENV_FILE" <<EOF
---
# Generated by scripts/test-deployment-variants.sh — DO NOT COMMIT.
global:
  profile: ${PROFILE}
  domain: civitas.test
  instanceSlug: dev
  initialUserEmail: admin@civitas.test
  singleNamespace: ${single}
  serviceMesh:
    enable: ${mesh}
    type: linkerd
    patchNamespaces: ${mesh}
EOF
}

deploy_variant() { # MI
  local mi="$1"
  if [[ "$mi" == "1" ]]; then
    log "Deploying shared operators (multi-instance layer)"
    helmfile -f ./deployment/helmfile-operators.yaml sync -e "$ENV"
    log "Deploying instance"
    helmfile -f ./deployment/helmfile-instance.yaml.gotmpl sync -e "$ENV"
  else
    log "Deploying all-in-one"
    helmfile -f ./deployment/helmfile.yaml sync -e "$ENV"
  fi
}

# --- smoke test: namespaces, pods green, rollout ----------------------------
# Platform namespaces = whatever appeared since the snapshot taken before deploy.
snapshot_namespaces() {
  kubectl get ns -o name | sed 's#namespace/##' | sort
}

# Print every pod in the given namespaces that is NOT green.
not_green_pods() { # ns...
  local ns
  for ns in "$@"; do
    kubectl get pods -n "$ns" --no-headers 2>/dev/null | awk -v ns="$ns" '
      {
        ready=$2; status=$3
        if (status=="Completed" || status=="Succeeded") next
        split(ready, a, "/")
        if (status=="Running" && a[2]>0 && a[1]==a[2]) next
        printf "  %s/%s  %s  %s\n", ns, $1, ready, status
      }'
  done
}

wait_pods_green() { # deadline ns...
  local deadline="$1"; shift
  local ng
  while :; do
    ng="$(not_green_pods "$@")"
    [[ -z "$ng" ]] && { ok "all pods green"; return 0; }
    if (( SECONDS >= deadline )); then
      err "pods still not green after timeout:"; echo "$ng" >&2; return 1
    fi
    sleep 10
  done
}

check_rollouts() { # remaining_seconds ns...
  local remaining="$1"; shift
  local ns kind obj
  for ns in "$@"; do
    for kind in deployment statefulset daemonset; do
      while IFS= read -r obj; do
        [[ -z "$obj" ]] && continue
        kubectl rollout status "$obj" -n "$ns" --timeout="${remaining}s" || return 1
      done < <(kubectl get "$kind" -n "$ns" -o name 2>/dev/null)
    done
  done
  ok "all rollouts complete"
}

# Cluster-wide diagnostics — usable even when the deploy died before any
# platform namespace was detected. Prints the not-ready pods, describes them
# (events: ImagePullBackOff, scheduling, probes…) and tails their logs.
dump_diagnostics() {
  warn "diagnostics for context '${KCTX:-current}':"
  echo "--- pods not Running/Completed (cluster-wide) ---"
  kubectl get pods -A -o wide 2>/dev/null | awk 'NR==1 || $4!="Running" && $4!="Completed"' || true
  # describe + logs for every not-ready pod (ns/name pairs)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local ns name
    ns="${line%% *}"; name="${line##* }"
    echo "--- describe ${ns}/${name} (events) ---"
    kubectl describe pod -n "$ns" "$name" 2>/dev/null | sed -n '/Events:/,$p' | head -n 20 || true
    echo "--- logs ${ns}/${name} (tail) ---"
    kubectl logs -n "$ns" "$name" --all-containers --tail=20 2>/dev/null || true
  done < <(kubectl get pods -A --no-headers 2>/dev/null | awk '
      { ready=$3; status=$4
        if (status=="Completed" || status=="Succeeded") next
        split(ready, a, "/"); if (status=="Running" && a[2]>0 && a[1]==a[2]) next
        print $1, $2 }')
}

# --- run a single variant (returns non-zero on any failure) -----------------
run_variant() { # MNS MI LNK
  local mns="$1" mi="$2" lnk="$3"

  if $MANAGE_CLUSTER; then
    create_cluster || return 1
  else
    KCTX="$(kubectl config current-context)"
    log "Using existing context '${KCTX}'"
  fi

  write_env_overlay "$mns" "$lnk"
  [[ "$PROFILE" == "production" ]] && { install_monitoring_crds || return 1; }
  [[ "$lnk" == "1" ]] && { install_linkerd || return 1; }
  install_kyverno || return 1
  create_smtp_secret "$mns" || return 1

  local before after
  before="$(snapshot_namespaces)"
  if ! deploy_variant "$mi"; then
    err "helmfile sync failed"; dump_diagnostics; return 1
  fi
  after="$(snapshot_namespaces)"

  # Namespaces the platform created during this deploy.
  local PLATFORM_NS=()
  while IFS= read -r line; do [[ -n "$line" ]] && PLATFORM_NS+=("$line"); done \
    < <(comm -13 <(echo "$before") <(echo "$after"))
  # The before/after diff misses any namespace that already existed at snapshot
  # time: in single-namespace mode the whole platform lands in the slug namespace
  # (pre-created above for the keycloak-smtp secret), so it is never "new"; in
  # multi-namespace mode the pre-created <slug>-keycloak is likewise skipped.
  # Always include this instance's namespaces (slug exact, or "<slug>-*").
  local slug; slug="$(get_slug)"
  while IFS= read -r ns; do
    [[ "$ns" == "$slug" || "$ns" == "$slug"-* ]] && PLATFORM_NS+=("$ns")
  done < <(echo "$after")
  # De-duplicate (the slug namespace may be both new and slug-matched).
  if [[ ${#PLATFORM_NS[@]} -gt 0 ]]; then
    local _uniq=(); while IFS= read -r line; do [[ -n "$line" ]] && _uniq+=("$line"); done \
      < <(printf '%s\n' "${PLATFORM_NS[@]}" | sort -u)
    PLATFORM_NS=("${_uniq[@]}")
  fi
  if [[ ${#PLATFORM_NS[@]} -eq 0 ]]; then
    err "no new namespaces detected after deploy — nothing to smoke test"; return 1
  fi
  log "Smoke-testing namespaces: ${PLATFORM_NS[*]}"

  local deadline=$((SECONDS + TIMEOUT))
  if ! wait_pods_green "$deadline" "${PLATFORM_NS[@]}"; then
    dump_diagnostics; return 1
  fi
  local remaining=$((deadline - SECONDS)); (( remaining < 30 )) && remaining=30
  if ! check_rollouts "$remaining" "${PLATFORM_NS[@]}"; then
    dump_diagnostics; return 1
  fi

  # In no-cluster mode clean up the platform namespaces for the next run.
  if ! $MANAGE_CLUSTER; then
    warn "cleaning platform namespaces (no-cluster mode)"
    kubectl delete ns "${PLATFORM_NS[@]}" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  fi
  return 0
}

# --- main loop --------------------------------------------------------------
# Pull-through caches only help the k3d cluster we configure ourselves.
if $USE_REGISTRY_CACHE; then
  if $MANAGE_CLUSTER; then
    ensure_registry_cache
  else
    warn "--no-cluster: skipping registry cache (your cluster's registry config is not managed here)"
  fi
fi

RESULTS=()
total=${#COMBOS[@]}
idx=0
overall_rc=0

for c in "${COMBOS[@]}"; do
  idx=$((idx + 1))
  IFS=',' read -r mns mi lnk <<<"$c"
  echo
  echo -e "${YELLOW}════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}Variant ${idx}/${total}: ${c}   $(describe "$mns" "$mi" "$lnk")${NC}"
  echo -e "${YELLOW}════════════════════════════════════════════════════════════════════${NC}"

  start=$SECONDS
  if run_variant "$mns" "$mi" "$lnk"; then
    dur=$((SECONDS - start))
    ok "variant ${c} PASSED in ${dur}s"
    RESULTS+=("PASS  ${c}  $(describe "$mns" "$mi" "$lnk")  (${dur}s)")
  else
    dur=$((SECONDS - start))
    err "variant ${c} FAILED after ${dur}s"
    RESULTS+=("FAIL  ${c}  $(describe "$mns" "$mi" "$lnk")  (${dur}s)")
    overall_rc=1
    if ! $CONTINUE_ON_FAILURE; then
      if $MANAGE_CLUSTER; then
        warn "Stopping. Cluster '${CLUSTER_NAME}' (context ${KCTX}) is kept for inspection."
        warn "Inspect with: kubectl --context ${KCTX} get pods -A"
        warn "Re-run remaining variants with --continue-on-failure, or delete with: k3d cluster delete ${CLUSTER_NAME}"
      fi
      KEEP_CLUSTER=true
      break
    fi
  fi
done

# Tear down the last cluster unless asked (or forced by a kept failure) to keep it.
if $MANAGE_CLUSTER && ! $KEEP_CLUSTER; then
  log "Removing k3d cluster '${CLUSTER_NAME}'"
  k3d cluster delete "$CLUSTER_NAME" >/dev/null 2>&1 || true
fi

echo
echo -e "${YELLOW}════════════════════════════ SUMMARY ════════════════════════════════${NC}"
for r in "${RESULTS[@]}"; do
  if [[ "$r" == PASS* ]]; then echo -e "${GREEN}${r}${NC}"; else echo -e "${RED}${r}${NC}"; fi
done
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"

exit $overall_rc
