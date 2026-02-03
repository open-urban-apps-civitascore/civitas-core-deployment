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
helmfile template -f deployment/helmfile.yaml -e local $selector_arg | kyverno apply .ci/policies/base --resource -
echo "All policies passed!"
echo "Testing production requirements..."
helmfile template -f deployment/helmfile.yaml -e production $selector_arg | kyverno apply .ci/policies/production --resource -
echo "All production policies passed!"
