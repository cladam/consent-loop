#!/usr/bin/env bash

set -euo pipefail

db_path="$(mktemp -t consent-loop.XXXXXX.db)"
log_path="$(mktemp -t consent-loop.XXXXXX.log)"
response_path="$(mktemp -t consent-loop.XXXXXX.json)"
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -f "$db_path" "$db_path-shm" "$db_path-wal" "$log_path" "$response_path"
}
trap cleanup EXIT

hica build
CONSENT_LOOP_DB_PATH="$db_path" ./src/main >"$log_path" 2>&1 &
server_pid=$!

curl --fail --silent --show-error \
  --retry 20 --retry-connrefused --retry-delay 1 \
  http://localhost:8080/health >"$response_path"

grep -q '"status": "ok"' "$response_path"
grep -q '"db": "ok"' "$response_path"

echo "health integration passed"