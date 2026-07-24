#!/usr/bin/env bash
set -euo pipefail

# ensure we are in the repo root
cd "$(dirname "$0")/../.."

COMPONENT=${1:-""}

selector_arg=""
if [[ -n "$COMPONENT" ]]; then
  selector_arg="--selector component=${COMPONENT}"
fi

# Accepted findings (e.g. an upstream chart not supporting a policy) are
# tracked as PolicyExceptions colocated with the component, not silenced
# globally - see components/*/policy-exceptions.yaml and .ci/policies/README.md.
shopt -s nullglob
exception_args=()
for f in components/*/policy-exceptions.yaml; do
  exception_args+=(--exception "$f")
done
shopt -u nullglob

echo "Testing base requirements..."
helmfile template -f deployment/helmfile.yaml -e local $selector_arg > /tmp/rendered-local.yaml
kyverno apply .ci/policies/base --resource /tmp/rendered-local.yaml "${exception_args[@]}"
echo "All policies passed!"
echo "Testing production requirements (base + production)..."
helmfile template -f deployment/helmfile.yaml -e production $selector_arg > /tmp/rendered-production.yaml
kyverno apply .ci/policies/base .ci/policies/production --resource /tmp/rendered-production.yaml "${exception_args[@]}"
echo "All production policies passed!"
