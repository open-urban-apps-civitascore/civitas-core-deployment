#!/usr/bin/env bash
set -euo pipefail

# ensure we are in the repo root
cd "$(dirname "$0")/.."

COMPONENT=${1:-""}

selector_arg=""
if [[ -n "$COMPONENT" ]]; then
  selector_arg="--selector component=${COMPONENT}"
fi

helmfile template -f deployment/helmfile.yaml -e local $selector_arg | kyverno apply .ci/policies --resource -
