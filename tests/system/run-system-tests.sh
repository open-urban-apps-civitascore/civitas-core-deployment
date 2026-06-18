#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JAVA_PROJECT_DIR="${ROOT_DIR}/tests/system/java"
ROBOT_SUITES=(
  "${ROOT_DIR}/tests/system/robot/tu-001-hero-case.robot"
)
RESULT_DIR="${ROOT_DIR}/tests/system/results"
SERVER_LOG="${RESULT_DIR}/remote-server.log"
REMOTE_PORT="${SYSTEM_TEST_REMOTE_PORT:-8270}"
REMOTE_URL="${SYSTEM_TEST_REMOTE_URL:-http://127.0.0.1:${REMOTE_PORT}}"

mkdir -p "${RESULT_DIR}"
rm -f "${SERVER_LOG}"

mvn -q -f "${JAVA_PROJECT_DIR}/pom.xml" -DskipTests package

java -jar "${JAVA_PROJECT_DIR}/target/civitas-system-tests-0.1.0.jar" "${REMOTE_PORT}" >"${SERVER_LOG}" 2>&1 &
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

python3 -m robot \
  --variable "REMOTE_URL:${REMOTE_URL}" \
  --outputdir "${RESULT_DIR}" \
  --xunit "xunit.xml" \
  "${ROBOT_SUITES[@]}"
