#!/usr/bin/env bash

set -euo pipefail

db_path="$(mktemp -t consent-loop.XXXXXX.db)"
log_path="$(mktemp -t consent-loop.XXXXXX.log)"
request_path="$(mktemp -t consent-loop.XXXXXX.hml)"
response_path="$(mktemp -t consent-loop.XXXXXX.hml)"
headers_path="$(mktemp -t consent-loop.XXXXXX.headers)"
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -f \
    "$db_path" "$db_path-shm" "$db_path-wal" \
    "$log_path" "$request_path" "$response_path" "$headers_path"
}
trap cleanup EXIT

cat >"$request_path" <<'HML'
#hml 0.3
#text: amendment
#namespace decision: "https://hica.dev/schemas/decision/v1"
@proposal(id: "PROP-042", version: "1.1", status: "refinement") {
  title: "Migrate services to a trunk-based monorepo"
  created: 2026-06-06T10:00:00Z
  cooling-period: 24h
  @body {
    Add a mandatory prerequisite for workspace caching.
  }
  @participants {
    @participant(user: "alex", level: 3)
    @participant(user: "sofia", level: 1) {
      @amendment(target-version: "1.1", status: "adopted") {
        Add package-level caching before migration.
      }
    }
  }
  @references {
    @ref(type: "URL", value: "https://example.com/issues/104", description: "Benchmark")
  }
  @history {
    @revision(version: "1.1", event: "amendment-adopted", timestamp: 2026-06-06T14:30:00Z)
  }
}
HML

hica build
CONSENT_LOOP_DB_PATH="$db_path" ./src/main >"$log_path" 2>&1 &
server_pid=$!

curl --fail --silent --show-error \
  --retry 20 --retry-connrefused --retry-delay 1 \
  http://localhost:8080/health >/dev/null

status_code="$(curl --silent --show-error \
  --dump-header "$headers_path" \
  --output "$response_path" \
  --write-out '%{http_code}' \
  --header 'Content-Type: application/hml' \
  --data-binary "@$request_path" \
  http://localhost:8080/v1/proposals/submit)"

[[ "$status_code" == "201" ]]
grep -qi '^Content-Type: application/hml' "$headers_path"
grep -q '@proposal(id: "PROP-042", version: "1.0", status: "submission")' "$response_path"
[[ "$(grep -c '@revision' "$response_path")" == "1" ]]

status_code="$(curl --silent --show-error \
  --output "$response_path" \
  --write-out '%{http_code}' \
  --header 'Content-Type: application/hml' \
  --data-binary "@$request_path" \
  http://localhost:8080/v1/proposals/submit)"

[[ "$status_code" == "409" ]]
grep -q '"code": "proposal_exists"' "$response_path"

echo "submission integration passed"