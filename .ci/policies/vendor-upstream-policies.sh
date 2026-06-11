#!/usr/bin/env bash
set -euo pipefail

# Re-vendors maintained upstream policies from github.com/kyverno/policies
# into base/. To update: bump UPSTREAM_REF, run this script, review the diff
# and run `just test-policies` (expectations live in tests/kyverno-test.yaml).
UPSTREAM_REF=76be98a25d49ae01278a94ecde8f50f9e08577ef

# Note: the PSS baseline policies disallow-capabilities and restrict-seccomp
# are deliberately absent - their restricted counterparts
# (disallow-capabilities-strict, restrict-seccomp-strict) are strict supersets
# and running both would report every violation twice. The same applies to
# best-practices/require-drop-all, which disallow-capabilities-strict subsumes.
UPSTREAM_POLICIES=(
  best-practices/require-ro-rootfs/require-ro-rootfs.yaml
  pod-security/baseline/disallow-host-namespaces/disallow-host-namespaces.yaml
  pod-security/baseline/disallow-host-path/disallow-host-path.yaml
  pod-security/baseline/disallow-host-ports/disallow-host-ports.yaml
  pod-security/baseline/disallow-host-process/disallow-host-process.yaml
  pod-security/baseline/disallow-privileged-containers/disallow-privileged-containers.yaml
  pod-security/baseline/disallow-proc-mount/disallow-proc-mount.yaml
  pod-security/baseline/disallow-selinux/disallow-selinux.yaml
  pod-security/baseline/restrict-apparmor-profiles/restrict-apparmor-profiles.yaml
  pod-security/baseline/restrict-sysctls/restrict-sysctls.yaml
  pod-security/restricted/disallow-capabilities-strict/disallow-capabilities-strict.yaml
  pod-security/restricted/disallow-privilege-escalation/disallow-privilege-escalation.yaml
  pod-security/restricted/require-run-as-non-root-user/require-run-as-non-root-user.yaml
  pod-security/restricted/require-run-as-nonroot/require-run-as-nonroot.yaml
  pod-security/restricted/restrict-seccomp-strict/restrict-seccomp-strict.yaml
  pod-security/restricted/restrict-volume-types/restrict-volume-types.yaml
)

cd "$(dirname "$0")"

targets=()
for policy in "${UPSTREAM_POLICIES[@]}"; do
  target="base/$(basename "$policy")"
  targets+=("${target}")
  echo "Vendoring ${policy} -> ${target}"
  {
    echo "---"
    echo "# upstream content is vendored verbatim, so long lines are tolerated:"
    echo "# yamllint disable rule:line-length"
    echo "# Vendored from github.com/kyverno/policies"
    echo "# path: ${policy}"
    echo "# ref: ${UPSTREAM_REF}"
    echo "# Do not edit by hand; re-run .ci/policies/vendor-upstream-policies.sh instead."
    curl -fsSL "https://raw.githubusercontent.com/kyverno/policies/${UPSTREAM_REF}/${policy}"
  } > "${target}"
done

# Normalize to the repo's YAML style (pre-commit runs prettier + yamllint).
if command -v npx >/dev/null; then
  npx --yes prettier@3.3.0 --config ../configs/.prettierrc --write "${targets[@]}"
else
  echo "WARNING: npx not found; run pre-commit to normalize formatting." >&2
fi

echo "Done. Review the diff and run: just test-policies"
