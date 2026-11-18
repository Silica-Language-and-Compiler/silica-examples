#!/usr/bin/env bash
# CI check for ml-linear-regression. .github/scripts/run-examples.sh runs it from the repository
# root after `silica build ml-linear-regression`. Generates the CSV and its store backing, runs the
# example and checks that the fit lands near the line the data was generated from (y = 6x + 45).
set -euo pipefail

python3 ml-linear-regression/csv_to_sildat.py
out="$(silica run ml-linear-regression)"
printf '%s\n' "$out"

grep -qxF "rows used:     1000" <<< "$out" || { echo "expected 1000 rows to be used" >&2; exit 1; }

# near <label> <want> <tolerance>: the number after "<label>:" is within tolerance of want.
near() {
  awk -v label="$1:" -v want="$2" -v tol="$3" '
    $1 == label { found = 1; d = $2 - want; if (d < 0) d = -d; if (d > tol) { bad = $2 } }
    END {
      if (!found) { print "no " label " line" > "/dev/stderr"; exit 1 }
      if (bad != "") { print label " " bad " is not within " tol " of " want > "/dev/stderr"; exit 1 }
    }' <<< "$out"
}
near slope 6.0 0.1
near intercept 45.0 1.0
