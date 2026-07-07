#!/usr/bin/env bash
set -euo pipefail

# System-test runner.
#
# Runs the Robot Framework hero-case suite against a running CIVITAS deployment.
# Works both in CI (cicd image) and locally against any cluster by pointing the
# endpoint env vars / flags at that cluster (e.g. via `kubectl port-forward` or
# public ingress URLs).
#
# Endpoints and credentials are read from environment variables. Sensible
# local-dev defaults are baked into the Java library and the robot resources,
# so a plain `bash tests/system/run-system-tests.sh` targets a local dev stack.
#
# Common env vars (override to target a remote cluster):
#   API_BASE_URL / PORTAL_BACKEND_URL   portal-backend base URL (…/v1)
#   KEYCLOAK_URL, KEYCLOAK_REALM, KEYCLOAK_CLIENT_ID
#   APISIX_GATEWAY_URL / PUBLIC_GATEWAY_URL
#   PORTAL_FRONTEND_URL
#   FROST_BASE_URL
#   SYSTEM_TEST_AUTH_USER / AUTH_USER, SYSTEM_TEST_AUTH_PASSWORD / AUTH_PASSWORD
#
# Runner flags / env vars:
#   --suite <path>            Robot suite/dir to run (repeatable). Default: hero case.
#   --include <tag>           Only run tests with this tag (repeatable). ROBOT_INCLUDE.
#   --exclude <tag>           Skip tests with this tag (repeatable). ROBOT_EXCLUDE.
#   --results-dir <dir>       Output dir. SYSTEM_TEST_RESULT_DIR.
#   --remote-port <port>      Java remote-library port. SYSTEM_TEST_REMOTE_PORT (8270).
#   --skip-build              Reuse an already-built Java remote-library jar.
#   -h | --help               Show this help.

usage() {
  sed -n '4,31p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}


ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JAVA_PROJECT_DIR="${ROOT_DIR}/tests/system/java"

RESULT_DIR="${SYSTEM_TEST_RESULT_DIR:-${ROOT_DIR}/tests/system/results}"
REMOTE_PORT="${SYSTEM_TEST_REMOTE_PORT:-8270}"
SKIP_BUILD="${SYSTEM_TEST_SKIP_BUILD:-false}"

# Suites/tags can be provided via flags (repeatable) or space-separated env vars.
ROBOT_SUITES=()
ROBOT_INCLUDE=(${ROBOT_INCLUDE:-})
ROBOT_EXCLUDE=(${ROBOT_EXCLUDE:-})

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite) ROBOT_SUITES+=("$2"); shift 2 ;;
    --include) ROBOT_INCLUDE+=("$2"); shift 2 ;;
    --exclude) ROBOT_EXCLUDE+=("$2"); shift 2 ;;
    --results-dir) RESULT_DIR="$2"; shift 2 ;;
    --remote-port) REMOTE_PORT="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ${#ROBOT_SUITES[@]} -eq 0 ]]; then
  ROBOT_SUITES=("${ROOT_DIR}/tests/system/robot/tu-001-hero-case.robot")
fi

REMOTE_URL="${SYSTEM_TEST_REMOTE_URL:-http://127.0.0.1:${REMOTE_PORT}}"
SERVER_LOG="${RESULT_DIR}/remote-server.log"

mkdir -p "${RESULT_DIR}"
rm -f "${SERVER_LOG}"

# Resolve the shaded jar path from the pom version so a version bump doesn't
# silently break the runner.
JAR_VERSION="$(sed -n 's:.*<version>\(.*\)</version>.*:\1:p' "${JAVA_PROJECT_DIR}/pom.xml" | sed -n '1p')"

JAR_PATH="${JAVA_PROJECT_DIR}/target/civitas-system-tests-${JAR_VERSION}.jar"

if [[ "${SKIP_BUILD}" != "true" || ! -f "${JAR_PATH}" ]]; then
  mvn -q -f "${JAVA_PROJECT_DIR}/pom.xml" -DskipTests package
fi

if [[ ! -f "${JAR_PATH}" ]]; then
  echo "Java remote-library jar not found at ${JAR_PATH}" >&2
  exit 1
fi

if ! python3 - <<'PY' >/dev/null 2>&1
import importlib.util
import sys

sys.exit(0 if importlib.util.find_spec("Browser") else 1)
PY
then
  echo "Missing Robot Browser library. Install it with:"
  echo "  python3 -m pip install -r tests/system/browser/requirements.txt"
  echo "  rfbrowser init"
  exit 1
fi

java -jar "${JAR_PATH}" "${REMOTE_PORT}" >"${SERVER_LOG}" 2>&1 &
SERVER_PID="$!"

cleanup() {
  if kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

for _ in $(seq 1 90); do
  if ! kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    echo "Java remote server stopped unexpectedly:"
    cat "${SERVER_LOG}"
    exit 1
  fi
  if REMOTE_URL="${REMOTE_URL}" python3 - <<'PY' >/dev/null 2>&1
from xmlrpc.client import ServerProxy
import os
import sys

url = os.environ["REMOTE_URL"]
try:
    ServerProxy(url, allow_none=True).get_keyword_names()
except Exception:
    sys.exit(1)
PY
  then
    break
  fi
  sleep 1
done

if ! REMOTE_URL="${REMOTE_URL}" python3 - <<'PY' >/dev/null 2>&1
from xmlrpc.client import ServerProxy
import os
import sys

url = os.environ["REMOTE_URL"]
try:
    ServerProxy(url, allow_none=True).get_keyword_names()
except Exception:
    sys.exit(1)
PY
then
  echo "Timed out waiting for the Java remote server to start:"
  cat "${SERVER_LOG}"
  exit 1
fi

ROBOT_ARGS=(
  --variable "REMOTE_URL:${REMOTE_URL}"
  --outputdir "${RESULT_DIR}"
  --xunit "xunit.xml"
)
for tag in "${ROBOT_INCLUDE[@]}"; do
  [[ -n "${tag}" ]] && ROBOT_ARGS+=(--include "${tag}")
done
for tag in "${ROBOT_EXCLUDE[@]}"; do
  [[ -n "${tag}" ]] && ROBOT_ARGS+=(--exclude "${tag}")
done

python3 -m robot "${ROBOT_ARGS[@]}" "${ROBOT_SUITES[@]}"
