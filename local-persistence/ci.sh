#!/usr/bin/env bash
# CI check for local-persistence. .github/scripts/run-examples.sh runs it from the repository root
# after `silica build local-persistence`. Starts from an empty log, runs the example twice and
# checks that the second run replays the records the first one stored.
set -euo pipefail

rm -f local-persistence/__ignore__journal.sildat

expect() { grep -qxF -- "$2" <<< "$1" || { echo "missing line: $2" >&2; exit 1; }; }

first="$(silica run local-persistence)"
printf '%s\n' "$first"
expect "$first" "log oldest=0 next=0 capacity=8192"
expect "$first" "synced 3"
expect "$first" "rx_end 3"
expect "$first" "link_down :closed"

second="$(silica run local-persistence)"
printf '%s\n' "$second"
expect "$second" "log oldest=0 next=3 capacity=8192"
expect "$second" "synced 6"
expect "$second" "rx_end 6"
expect "$second" "link_down :closed"

rm -f local-persistence/__ignore__journal.sildat
