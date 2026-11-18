#!/usr/bin/env bash
# CI check for parallel-wordcount. .github/scripts/run-examples.sh runs it from the repository root
# after `silica build parallel-wordcount`. Runs the example and checks the numbers that do not depend
# on the core count: the total word count, the number of distinct words and the top 10 table.
# (The "mapper N on core N" lines vary with the machine and their order with scheduling, so only
# their presence is checked.)
set -euo pipefail

out="$(silica run parallel-wordcount)"
printf '%s\n' "$out"

expect() { grep -qxF -- "$1" <<< "$out" || { echo "missing line: $1" >&2; exit 1; }; }
grep -q '^cores used: [1-8]$' <<< "$out" || { echo "missing line: cores used: N" >&2; exit 1; }
grep -q '^mapper [0-9] on core [0-9] counted [0-9]* words$' <<< "$out" || { echo "no mapper lines" >&2; exit 1; }
expect "total words: 91"
expect "distinct words: 32"
expect "top 10 words:"
expect "  1. the: 19"
expect "  2. dog: 9"
expect "  3. fox: 7"
expect "  4. and: 6"
expect "  5. quick: 5"
expect "  6. lazy: 4"
expect "  7. away: 3"
expect "  8. brown: 3"
expect "  9. oak: 3"
expect "  10. tree: 3"
