#!/usr/bin/env bash
# CI check for stock-exchange. .github/scripts/run-examples.sh runs it from the repository root after
# `silica build stock-exchange`. One order is in flight at a time and every trader's randomness is
# seeded, so the whole session is deterministic. The checks touch every part of the system: the
# risk desk (refusals and supervised crashes), self-trade prevention, the circuit breaker and its
# auctions, the tape statistics and the ledger's zero-sum check, which also sets the exit status.
set -euo pipefail

rc=0
out="$(silica run stock-exchange 2>/dev/null)" || rc=$?
printf '%s\n' "$out"

[ "$rc" -eq 0 ] || { echo "unexpected exit status: $rc" >&2; exit 1; }

expect() { grep -qxF -- "$1" <<< "$out" || { echo "missing line: $1" >&2; exit 1; }; }
expect "  orders      240 sent, 6 refused, 7 crashed the risk desk"
expect "  self-trades 32 prevented (resting order cancelled)"
expect "  halts       3 volatility halts, each ended by a call auction"
expect "  *** reopening auction at 100.50: 300 shares uncrossed; continuous trading resumes"
expect "  *** reopening auction at 100.55: 400 shares uncrossed; continuous trading resumes"
expect "  trades      61 (4 blocks)"
expect "  volume      11500 shares"
expect "  open 100.10  high 100.95  low 100.10  close 100.60"
expect "  vwap        100.62"
expect "clearing: 61 trades booked, shares net to zero: ok, cash nets to zero: ok"
