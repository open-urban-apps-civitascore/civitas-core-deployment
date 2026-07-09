#!/usr/bin/env bash
set -euo pipefail

# ensure we are in the repo root
cd "$(dirname "$0")/../.."

COMPONENT=${1:-""}

selector_arg=""
if [[ -n "$COMPONENT" ]]; then
  selector_arg="--selector component=${COMPONENT}"
fi

echo "Testing base requirements..."
helmfile template -f deployment/helmfile.yaml -e local $selector_arg > /tmp/rendered-local.yaml
kyverno apply .ci/policies/base --resource /tmp/rendered-local.yaml
echo "All policies passed!"
echo "Testing production requirements (base + production)..."
helmfile template -f deployment/helmfile.yaml -e production $selector_arg > /tmp/rendered-production.yaml
kyverno apply .ci/policies/base .ci/policies/production --resource /tmp/rendered-production.yaml
echo "All production policies passed!"
