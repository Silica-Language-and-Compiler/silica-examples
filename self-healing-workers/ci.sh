#!/usr/bin/env bash
# CI check for self-healing-workers. .github/scripts/run-examples.sh runs it from the repository root
# after `silica build self-healing-workers`. Runs the example and checks the summary line: nine of the
# twelve jobs complete, three poisoned jobs crash a worker, and each crash is followed by a restart.
set -euo pipefail

out="$(silica run self-healing-workers 2>/dev/null)"
printf '%s\n' "$out"

expect() { grep -qxF -- "$1" <<< "$out" || { echo "missing line: $1" >&2; exit 1; }; }
expect "summary: jobs_completed=9 crashes=3 restarts=3"
