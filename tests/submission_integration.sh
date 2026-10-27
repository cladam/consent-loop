#!/usr/bin/env bash

set -euo pipefail

exec "$(dirname "$0")/choreo_integration.sh" tests/submission.chor
