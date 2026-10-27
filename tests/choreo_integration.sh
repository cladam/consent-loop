#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

for tool in hica choreo curl sqlite3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: required acceptance-test tool not found: $tool" >&2
    exit 1
  fi
done

if [[ "$#" -eq 0 ]]; then
  set -- tests/health.chor tests/submission.chor
fi

for spec in "$@"; do
  choreo validate --file "$spec"
done

# The service currently binds a fixed port. Never test an unrelated listener.
if curl --silent --max-time 2 --output /dev/null http://127.0.0.1:8080/health; then
  echo "error: port 8080 is already in use; stop that service before testing" >&2
  exit 1
else
  curl_status=$?
  if [[ "$curl_status" -ne 7 ]]; then
    echo "error: port 8080 is not available (curl exited $curl_status)" >&2
    exit 1
  fi
fi

hica build

export CONSENT_LOOP_TEST_DIR
CONSENT_LOOP_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/consent-loop-choreo.XXXXXX")"
export CONSENT_LOOP_DB_PATH="$CONSENT_LOOP_TEST_DIR/proposals.db"
export CONSENT_LOOP_BASE_URL="http://127.0.0.1:8080"
server_pid=""

cleanup() {
  result=$?
  trap - EXIT
  if [[ -n "$server_pid" ]]; then
    if kill -0 "$server_pid" 2>/dev/null; then
      kill "$server_pid"
    fi
    wait "$server_pid" 2>/dev/null || true
  fi
  if [[ "$result" -ne 0 ]]; then
    echo "ConsentLoop service log:" >&2
    cat "$CONSENT_LOOP_TEST_DIR/service.log" >&2
  fi
  rm -f \
    "$CONSENT_LOOP_DB_PATH" "$CONSENT_LOOP_DB_PATH-shm" "$CONSENT_LOOP_DB_PATH-wal" \
    "$CONSENT_LOOP_TEST_DIR/service.log" \
    "$CONSENT_LOOP_TEST_DIR/before.sql" "$CONSENT_LOOP_TEST_DIR/after.sql"
  rmdir "$CONSENT_LOOP_TEST_DIR"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

./src/main >"$CONSENT_LOOP_TEST_DIR/service.log" 2>&1 &
server_pid=$!

ready=false
for ((attempt = 0; attempt < 50; attempt++)); do
  if ! kill -0 "$server_pid" 2>/dev/null; then
    echo "error: ConsentLoop exited before becoming ready" >&2
    exit 1
  fi
  if curl --fail --silent --max-time 1 "$CONSENT_LOOP_BASE_URL/health" >/dev/null; then
    ready=true
    break
  fi
  sleep 0.1
done
if [[ "$ready" != true ]]; then
  echo "error: ConsentLoop did not become ready on port 8080" >&2
  exit 1
fi

for spec in "$@"; do
  choreo run --file "$spec"
done
