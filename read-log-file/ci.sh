#!/usr/bin/env bash
# CI check for read-log-file. .github/scripts/run-examples.sh runs it from the repository root
# after `silica build read-log-file`. Packs app.log into the store backing, runs the example and
# checks the rows and counts it reports.
set -euo pipefail

silica sildat read-log-file/app.log read-log-file/__ignore__app.sildat --capacity 1048576
out="$(silica run read-log-file)"
printf '%s\n' "$out"

expect() { grep -qxF -- "$1" <<< "$out" || { echo "missing line: $1" >&2; exit 1; }; }
expect "lines in the log: 21"
expect "  line 8: 2026-11-17 08:01:20 [ERROR] POST /checkout 500 payment gateway timeout after 30000ms (order 77812)"
expect "  line 18: 2026-11-17 08:05:12 [ERROR] GET /orders/99120 404 order not found"
expect "LOG:   13"
expect "WARN:  4"
expect "ERROR: 4"
