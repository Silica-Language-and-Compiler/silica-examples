#!/usr/bin/env bash
# CI check for route-planner. .github/scripts/run-examples.sh runs it from the repository root after
# `silica build route-planner`. Runs the example and checks routes and the spanning tree weight.
set -euo pipefail

rc=0
out="$(silica run route-planner 2>/dev/null)" || rc=$?
printf '%s\n' "$out"

[ "$rc" -eq 0 ] || [ "$rc" -eq 2 ] || { echo "unexpected exit status: $rc" >&2; exit 1; }

expect() { grep -qxF -- "$1" <<< "$out" || { echo "missing line: $1" >&2; exit 1; }; }
expect "Lisbon -> Madrid -> Barcelona -> Lyon -> Zurich -> Munich -> Prague -> Warsaw (distance 350)"
expect "Amsterdam -> Cologne -> Munich -> Rome (distance 153)"
expect "Barcelona -> Lyon -> Zurich -> Munich -> Vienna (distance 176)"
expect "Paris -> Brussels -> Cologne -> Berlin -> Prague (distance 137)"
expect "Lisbon -> Madrid -> Barcelona -> Lyon -> Milan -> Rome (distance 289)"
expect "minimum spanning tree: 15 roads, total weight 607"
