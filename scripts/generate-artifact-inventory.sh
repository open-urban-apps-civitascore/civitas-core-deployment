#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Generate full CIVITAS artifact inventory + SBOM outputs and write SUMMARY.md.

Usage:
  scripts/generate-artifact-inventory.sh --platform-repo <path> [options]

Options:
  --deployment-repo <path>  Deployment repo path (default: cwd)
  --platform-repo <path>    Platform repo path (required)
  --env <name>              Helmfile environment (default: production)
  --out-dir <path>          Output directory (default: <deployment>/out/sbom-<timestamp>)
  --max-passes <n>          Max image scan retry passes (default: 120)
  --scan-timeout <sec>      Per-image scan timeout seconds (default: 600)
  --mvn-timeout <sec>       Per-module Maven dependency tree timeout (default: 300)
  --skip-image-scan         Skip image scanning loop (uses existing image scan files if present)
  --help                    Show this help
USAGE
}

die() {
  echo "$*" >&2
  exit 1
}

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required tool: $cmd"
}

count_lines() {
  local file="$1"
  if [[ -f "$file" ]]; then
    wc -l < "$file" | tr -d ' '
  else
    echo 0
  fi
}

ensure_parent_dir() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
}

append_unique_line() {
  local line="$1"
  local file="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

remove_lines_with_prefix() {
  local prefix="$1"
  local file="$2"
  local tmp
  tmp="$(mktemp)"
  awk -v p="$prefix" 'index($0, p) != 1' "$file" > "$tmp"
  mv "$tmp" "$file"
}

set_failure_reason() {
  local image="$1"
  local reason="$2"
  local file="$OUT_DIR/images/failure-reasons.tsv"
  local tmp
  tmp="$(mktemp)"
  awk -F '\t' -v i="$image" '$1 != i' "$file" > "$tmp"
  printf '%s\t%s\n' "$image" "$reason" >> "$tmp"
  mv "$tmp" "$file"
}

clear_failure_reason() {
  local image="$1"
  local file="$OUT_DIR/images/failure-reasons.tsv"
  local tmp
  tmp="$(mktemp)"
  awk -F '\t' -v i="$image" '$1 != i' "$file" > "$tmp"
  mv "$tmp" "$file"
}

refresh_failed_images_from_pending() {
  local pending="$OUT_DIR/images/pending-images.txt"
  local reasons="$OUT_DIR/images/failure-reasons.tsv"
  local failed="$OUT_DIR/images/failed-images.txt"
  local image reason

  : > "$failed"
  while IFS= read -r image; do
    [[ -n "$image" ]] || continue
    reason="$(awk -F '\t' -v i="$image" '$1==i {print $2; exit}' "$reasons")"
    if [[ -n "$reason" ]]; then
      echo "$image | $reason" >> "$failed"
    else
      echo "$image | pending" >> "$failed"
    fi
  done < "$pending"
}

emit_bullets() {
  local file="$1"
  if [[ -s "$file" ]]; then
    sed 's/^/- /' "$file"
  else
    echo "- (none)"
  fi
}

parse_images() {
  sed -E "s/^[[:space:]]*image:[[:space:]]*//; s/^['\"]//; s/['\"]$//"
}

init_timeout_bin() {
  TIMEOUT_BIN="timeout"
  if command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN="gtimeout"
  elif ! command -v timeout >/dev/null 2>&1; then
    die "Missing timeout command (install coreutils for gtimeout/timeout)."
  fi
}

parse_args() {
  DEPLOYMENT_REPO="$(pwd)"
  PLATFORM_REPO=""
  ENV_NAME="production"
  OUT_DIR=""
  MAX_PASSES=120
  SCAN_TIMEOUT=600
  MVN_TIMEOUT=300
  SKIP_IMAGE_SCAN=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --deployment-repo) DEPLOYMENT_REPO="$2"; shift 2 ;;
      --platform-repo) PLATFORM_REPO="$2"; shift 2 ;;
      --env) ENV_NAME="$2"; shift 2 ;;
      --out-dir) OUT_DIR="$2"; shift 2 ;;
      --max-passes) MAX_PASSES="$2"; shift 2 ;;
      --scan-timeout) SCAN_TIMEOUT="$2"; shift 2 ;;
      --mvn-timeout) MVN_TIMEOUT="$2"; shift 2 ;;
      --skip-image-scan) SKIP_IMAGE_SCAN=1; shift 1 ;;
      --help|-h) usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -n "$PLATFORM_REPO" ]] || die "--platform-repo is required"
  [[ -d "$DEPLOYMENT_REPO" && -d "$PLATFORM_REPO" ]] || die "Invalid repository path(s)."

  if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="$DEPLOYMENT_REPO/out/sbom-$(date +%Y%m%d-%H%M%S)"
  fi
}

check_prereqs() {
  local required=(syft helmfile rg yq jq mvn shasum sed awk)
  local c
  for c in "${required[@]}"; do
    need_cmd "$c"
  done
  init_timeout_bin
}

init_output_dirs() {
  mkdir -p "$OUT_DIR"/{sources,images,manifests,logs}
  echo "OUT_DIR=$OUT_DIR"
}

generate_source_sboms() {
  syft "dir:$DEPLOYMENT_REPO" \
    --exclude './dev-deployment/**' \
    --exclude './out/**' \
    -o cyclonedx-json > "$OUT_DIR/sources/deployment.source.cdx.json"
  syft "dir:$DEPLOYMENT_REPO" \
    --exclude './dev-deployment/**' \
    --exclude './out/**' \
    -o spdx-json > "$OUT_DIR/sources/deployment.source.spdx.json"
  syft "dir:$PLATFORM_REPO" \
    --exclude './dev-environment/**' \
    --exclude './config-adapter/config-adapter-examples/**' \
    -o cyclonedx-json > "$OUT_DIR/sources/platform.source.cdx.json"
  syft "dir:$PLATFORM_REPO" \
    --exclude './dev-environment/**' \
    --exclude './config-adapter/config-adapter-examples/**' \
    -o spdx-json > "$OUT_DIR/sources/platform.source.spdx.json"
}

render_manifests() {
  (
    cd "$DEPLOYMENT_REPO"
    helmfile -f ./deployment/helmfile.yaml template -e "$ENV_NAME"
  ) > "$OUT_DIR/manifests/deployment-$ENV_NAME.rendered.yaml"
}

build_image_list() {
  rg -No --no-filename '^[[:space:]]*image:[[:space:]]*"?[^" ]+"?' "$OUT_DIR/manifests/deployment-$ENV_NAME.rendered.yaml" \
    | parse_images > "$OUT_DIR/images/images.txt"

  # Extract CI runner images from GitLab CI configs (these run in production pipelines).
  rg -No --no-filename '^[[:space:]]*image:[[:space:]]*"?[^" ]+"?' \
    "$DEPLOYMENT_REPO/.gitlab-ci.yml" \
    "$PLATFORM_REPO/.gitlab-ci.yml" \
    2>/dev/null | parse_images >> "$OUT_DIR/images/images.txt" || true
  rg -No --no-filename '^[[:space:]]*image:[[:space:]]*"?[^" ]+"?' \
    "$PLATFORM_REPO/.gitlab/ci/"*.yml \
    2>/dev/null | parse_images >> "$OUT_DIR/images/images.txt" || true

  grep -v '{{' "$OUT_DIR/images/images.txt" | grep -v '^$' | sort -u > "$OUT_DIR/images/images.clean.txt"
  mv "$OUT_DIR/images/images.clean.txt" "$OUT_DIR/images/images.txt"
}

init_scan_state() {
  # If pending-images.txt already exists we are resuming a previous run —
  # keep existing scan state so already-scanned images stay recorded.
  if [[ -s "$OUT_DIR/images/pending-images.txt" ]]; then
    echo "Resuming previous scan ($(count_lines "$OUT_DIR/images/pending-images.txt") images pending)"
    return
  fi

  : > "$OUT_DIR/images/scanned-images.txt"
  : > "$OUT_DIR/images/failed-images.txt"
  : > "$OUT_DIR/images/failure-reasons.tsv"
  : > "$OUT_DIR/images/image-file-map.txt"
  cp "$OUT_DIR/images/images.txt" "$OUT_DIR/images/pending-images.txt"
}

scan_one_image() {
  local image="$1"
  local rc=0
  local id cdx spdx log
  id="$(printf '%s' "$image" | shasum -a 256 | awk '{print $1}')"
  cdx="$OUT_DIR/images/${id}.cdx.json"
  spdx="$OUT_DIR/images/${id}.spdx.json"
  log="$OUT_DIR/logs/${id}.log"

  append_unique_line "$id $image" "$OUT_DIR/images/image-file-map.txt"

  if [[ -s "$cdx" && -s "$spdx" ]]; then
    append_unique_line "$image" "$OUT_DIR/images/scanned-images.txt"
    remove_lines_with_prefix "$image | " "$OUT_DIR/images/failed-images.txt"
    clear_failure_reason "$image"
    return 0
  fi

  rm -f "$cdx" "$spdx"

  if "$TIMEOUT_BIN" "$SCAN_TIMEOUT" syft "registry:$image" -o cyclonedx-json > "$cdx" 2>"$log"; then
    if "$TIMEOUT_BIN" "$SCAN_TIMEOUT" syft "registry:$image" -o spdx-json > "$spdx" 2>>"$log"; then
      append_unique_line "$image" "$OUT_DIR/images/scanned-images.txt"
      remove_lines_with_prefix "$image | " "$OUT_DIR/images/failed-images.txt"
      clear_failure_reason "$image"
      return 0
    else
      rc=$?
      rm -f "$spdx"
      if [[ ! -s "$log" ]]; then
        echo "syft spdx scan failed for $image (exit=$rc, timeout=${SCAN_TIMEOUT}s)" > "$log"
      fi
      set_failure_reason "$image" "spdx failed (exit=$rc)"
      return 1
    fi
  else
    rc=$?
    rm -f "$cdx"
    if [[ ! -s "$log" ]]; then
      echo "syft cyclonedx scan failed for $image (exit=$rc, timeout=${SCAN_TIMEOUT}s)" > "$log"
    fi
    set_failure_reason "$image" "cdx failed (exit=$rc)"
    return 1
  fi
}

scan_images_resumable() {
  local pass=1
  local total ok fail pending image

  while [[ -s "$OUT_DIR/images/pending-images.txt" && "$pass" -le "$MAX_PASSES" ]]; do
    : > "$OUT_DIR/images/next-pending-images.txt"

    while IFS= read -r image; do
      [[ -n "$image" ]] || continue
      if ! scan_one_image "$image"; then
        echo "$image" >> "$OUT_DIR/images/next-pending-images.txt"
      fi
    done < "$OUT_DIR/images/pending-images.txt"

    sort -u "$OUT_DIR/images/next-pending-images.txt" -o "$OUT_DIR/images/next-pending-images.txt"
    mv "$OUT_DIR/images/next-pending-images.txt" "$OUT_DIR/images/pending-images.txt"
    sort -u "$OUT_DIR/images/scanned-images.txt" -o "$OUT_DIR/images/scanned-images.txt"
    refresh_failed_images_from_pending

    total="$(count_lines "$OUT_DIR/images/images.txt")"
    ok="$(count_lines "$OUT_DIR/images/scanned-images.txt")"
    fail="$(count_lines "$OUT_DIR/images/failed-images.txt")"
    pending="$(count_lines "$OUT_DIR/images/pending-images.txt")"

    echo "PASS=$pass TOTAL=$total OK=$ok FAIL=$fail PENDING=$pending" | tee -a "$OUT_DIR/logs/pass-progress.log"
    pass=$((pass + 1))
  done
}

derive_helm_lists() {
  local chart_file name version chartver cname

  : > "$OUT_DIR/derived-civitas-helm.txt"
  while IFS= read -r chart_file; do
    name="$(yq -r '.name // ""' "$chart_file")"
    version="$(yq -r '.version // ""' "$chart_file")"
    [[ -n "$name" ]] || continue
    echo "$name | $version | $chart_file" >> "$OUT_DIR/derived-civitas-helm.txt"
  done < <(rg --files "$DEPLOYMENT_REPO" -g '**/Chart.yaml')
  sort -u "$OUT_DIR/derived-civitas-helm.txt" -o "$OUT_DIR/derived-civitas-helm.txt"

  rg -No --no-filename 'helm\.sh/chart:[[:space:]]*[^[:space:]]+' "$OUT_DIR/manifests/deployment-$ENV_NAME.rendered.yaml" \
    | sed -E 's/^helm\.sh\/chart:[[:space:]]*//' > "$OUT_DIR/derived-manifest-helm.txt"
  rg -No --no-filename '^[[:space:]]*chart:[[:space:]]*[A-Za-z0-9._-]+-[0-9][^[:space:]]*' "$OUT_DIR/manifests/deployment-$ENV_NAME.rendered.yaml" \
    | sed -E 's/^[[:space:]]*chart:[[:space:]]*//' >> "$OUT_DIR/derived-manifest-helm.txt"
  sort -u "$OUT_DIR/derived-manifest-helm.txt" -o "$OUT_DIR/derived-manifest-helm.txt"

  awk -F' | ' '{print $1}' "$OUT_DIR/derived-civitas-helm.txt" | sort -u > "$OUT_DIR/derived-civitas-helm-names.txt"

  : > "$OUT_DIR/derived-thirdparty-helm.txt"
  while IFS= read -r chartver; do
    [[ -n "$chartver" ]] || continue
    cname="$(echo "$chartver" | sed -E 's/-[0-9].*$//')"
    if ! grep -qxF "$cname" "$OUT_DIR/derived-civitas-helm-names.txt"; then
      echo "$chartver | rendered-manifest" >> "$OUT_DIR/derived-thirdparty-helm.txt"
    fi
  done < "$OUT_DIR/derived-manifest-helm.txt"
  sort -u "$OUT_DIR/derived-thirdparty-helm.txt" -o "$OUT_DIR/derived-thirdparty-helm.txt"
}

derive_image_lists() {
  awk '{print $2}' "$OUT_DIR/images/image-file-map.txt" | sort -u > "$OUT_DIR/derived-all-images.txt"
  rg '^registry\.gitlab\.com/civitas-connect/civitas-core/' "$OUT_DIR/derived-all-images.txt" > "$OUT_DIR/derived-civitas-images.txt" || true
  rg -v '^registry\.gitlab\.com/civitas-connect/civitas-core/' "$OUT_DIR/derived-all-images.txt" > "$OUT_DIR/derived-thirdparty-images.txt" || true
}

derive_frontend_packages() {
  local frontend_dir="$PLATFORM_REPO/portal-frontend"
  local lockfile="$frontend_dir/pnpm-lock.yaml"

  if [[ -f "$lockfile" ]]; then
    FRONTEND_DIRECT_PROD="$(yq -r '.importers["."].dependencies // {} | length' "$lockfile")"

    # Use pnpm ls --prod to get only production dependencies (transitive).
    # Falls back to the full lockfile package list if pnpm is unavailable or node_modules is missing.
    if command -v pnpm >/dev/null 2>&1 && [[ -d "$frontend_dir/node_modules" ]]; then
      (cd "$frontend_dir" && pnpm ls --prod --depth=Infinity --parseable 2>/dev/null) \
        | grep -v "^$frontend_dir\$" \
        | sed -E 's#.*/node_modules/##' \
        | sort -u > "$OUT_DIR/derived-frontend-packages.txt"
      FRONTEND_TOTAL_PACKAGES="$(count_lines "$OUT_DIR/derived-frontend-packages.txt")"
    else
      echo "WARNING: pnpm or node_modules not available, falling back to full lockfile (includes dev dependencies)" >&2
      yq -r '.packages | keys | .[]' "$lockfile" | sort -u > "$OUT_DIR/derived-frontend-packages.txt"
      FRONTEND_TOTAL_PACKAGES="$(yq -r '.packages | length' "$lockfile")"
    fi
  else
    : > "$OUT_DIR/derived-frontend-packages.txt"
    FRONTEND_TOTAL_PACKAGES=0
    FRONTEND_DIRECT_PROD=0
  fi
}

derive_backend_jars() {
  local pom moddir modname

  while IFS= read -r pom; do
    [[ -n "$pom" ]] || continue
    moddir="$(dirname "$pom")"
    modname="$(echo "$moddir" | sed "s#^$PLATFORM_REPO/##; s#/#_#g")"
    mkdir -p "$moddir/.tmp"

    "$TIMEOUT_BIN" "$MVN_TIMEOUT" mvn -B -f "$pom" -Djava.io.tmpdir="$moddir/.tmp" -DskipTests dependency:tree \
      -Dscope=runtime -DoutputFile="$OUT_DIR/${modname}.runtime.tree.txt" >/dev/null || true

    "$TIMEOUT_BIN" "$MVN_TIMEOUT" mvn -B -f "$pom" -Djava.io.tmpdir="$moddir/.tmp" -DskipTests dependency:tree \
      -Dscope=test -DoutputFile="$OUT_DIR/${modname}.test.tree.txt" >/dev/null || true
  done < <(rg --files "$PLATFORM_REPO" -g '**/pom.xml' | grep -v '/dev-environment/' | grep -v '/config-adapter-examples/')

  cat "$OUT_DIR"/*.runtime.tree.txt 2>/dev/null \
    | rg '[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+:jar:[A-Za-z0-9_.-]+' -o \
    | sed -E 's/^[+| -]+//' \
    | sort -u > "$OUT_DIR/derived-runtime-jars.txt"

  cat "$OUT_DIR"/*.test.tree.txt 2>/dev/null \
    | rg '[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+:jar:[A-Za-z0-9_.-]+' -o \
    | sed -E 's/^[+| -]+//' \
    | sort -u > "$OUT_DIR/derived-test-jars.txt"

  rg '^de\.civitas(core|-core)?:|^de\.civitas-core:' "$OUT_DIR/derived-runtime-jars.txt" > "$OUT_DIR/derived-civitas-runtime-jars.txt" || true
  rg -v '^de\.civitas(core|-core)?:|^de\.civitas-core:' "$OUT_DIR/derived-runtime-jars.txt" > "$OUT_DIR/derived-thirdparty-runtime-jars.txt" || true
  rg '^de\.civitas(core|-core)?:|^de\.civitas-core:' "$OUT_DIR/derived-test-jars.txt" > "$OUT_DIR/derived-civitas-test-jars.txt" || true
  rg -v '^de\.civitas(core|-core)?:|^de\.civitas-core:' "$OUT_DIR/derived-test-jars.txt" > "$OUT_DIR/derived-thirdparty-test-jars.txt" || true

  BACKEND_RUNTIME_TOTAL="$(count_lines "$OUT_DIR/derived-runtime-jars.txt")"
  BACKEND_RUNTIME_CIVITAS="$(count_lines "$OUT_DIR/derived-civitas-runtime-jars.txt")"
  BACKEND_RUNTIME_THIRDPARTY="$(count_lines "$OUT_DIR/derived-thirdparty-runtime-jars.txt")"
  BACKEND_TEST_TOTAL="$(count_lines "$OUT_DIR/derived-test-jars.txt")"
  BACKEND_TEST_CIVITAS="$(count_lines "$OUT_DIR/derived-civitas-test-jars.txt")"
  BACKEND_TEST_THIRDPARTY="$(count_lines "$OUT_DIR/derived-thirdparty-test-jars.txt")"
}

write_summary() {
  local total ok fail pending

  total="$(count_lines "$OUT_DIR/images/images.txt")"
  ok="$(count_lines "$OUT_DIR/images/scanned-images.txt")"
  fail="$(count_lines "$OUT_DIR/images/failed-images.txt")"
  pending="$(count_lines "$OUT_DIR/images/pending-images.txt")"

  {
    echo "# List of Artifacts"
    echo
    echo "Helm Charts, Docker Images, JARs, etc."
    echo
    echo "## Civitas"
    echo
    echo "### Helm Charts"
    emit_bullets "$OUT_DIR/derived-civitas-helm.txt"
    echo
    echo "### Docker Images"
    emit_bullets "$OUT_DIR/derived-civitas-images.txt"
    echo
    echo "### JARs (Runtime, Transitive)"
    emit_bullets "$OUT_DIR/derived-civitas-runtime-jars.txt"
    echo
    echo "### JARs (Test Scope, Transitive)"
    emit_bullets "$OUT_DIR/derived-civitas-test-jars.txt"
    echo
    echo "### Other Artifacts"
    echo "- Source SBOM: sources/deployment.source.cdx.json"
    echo "- Source SBOM: sources/deployment.source.spdx.json"
    echo "- Source SBOM: sources/platform.source.cdx.json"
    echo "- Source SBOM: sources/platform.source.spdx.json"
    echo
    echo "## Third party"
    echo
    echo "### Helm Charts"
    emit_bullets "$OUT_DIR/derived-thirdparty-helm.txt"
    echo
    echo "### Docker Images"
    emit_bullets "$OUT_DIR/derived-thirdparty-images.txt"
    echo
    echo "### JARs (Runtime, Transitive)"
    emit_bullets "$OUT_DIR/derived-thirdparty-runtime-jars.txt"
    echo
    echo "### JARs (Test Scope, Transitive)"
    emit_bullets "$OUT_DIR/derived-thirdparty-test-jars.txt"
    echo
    echo "### Frontend Packages (Production, Transitive, pnpm)"
    echo "- Total production packages: $FRONTEND_TOTAL_PACKAGES"
    echo "- Direct production dependencies: $FRONTEND_DIRECT_PROD"
    echo "- Full package list file: derived-frontend-packages.txt"
    echo
    echo "### Other Artifacts"
    echo "- Rendered manifests: manifests/deployment-$ENV_NAME.rendered.yaml"
    echo "- Image mapping: images/image-file-map.txt"
    echo "- Scan logs: logs/*.log"
    echo
    echo "## Scan Metadata"
    echo "- Generated at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "- Deployment repo: $DEPLOYMENT_REPO"
    echo "- Platform repo: $PLATFORM_REPO"
    echo "- Helmfile environment: $ENV_NAME"
    echo "- Total images discovered: $total"
    echo "- Images scanned successfully: $ok"
    echo "- Images failed after retries: $fail"
    echo "- Images pending scan completion: $pending"
    echo
    echo "## Dependency Totals"
    echo "- Backend runtime JARs (all/civitas/third-party): $BACKEND_RUNTIME_TOTAL / $BACKEND_RUNTIME_CIVITAS / $BACKEND_RUNTIME_THIRDPARTY"
    echo "- Backend test-scope JARs (all/civitas/third-party): $BACKEND_TEST_TOTAL / $BACKEND_TEST_CIVITAS / $BACKEND_TEST_THIRDPARTY"
    echo "- Frontend production packages: $FRONTEND_TOTAL_PACKAGES"
    echo
    echo "## Image Scan Status"
    echo "- Pending list: images/pending-images.txt"
    echo "- Failed list: images/failed-images.txt"
  } > "$OUT_DIR/SUMMARY.md"
}

main() {
  parse_args "$@"
  check_prereqs
  init_output_dirs

  generate_source_sboms
  render_manifests
  build_image_list

  if [[ "$SKIP_IMAGE_SCAN" -eq 0 ]]; then
    init_scan_state
    scan_images_resumable
  fi

  derive_helm_lists
  derive_image_lists
  derive_frontend_packages
  derive_backend_jars
  write_summary

  echo "SUMMARY_WRITTEN=$OUT_DIR/SUMMARY.md"
}

main "$@"
