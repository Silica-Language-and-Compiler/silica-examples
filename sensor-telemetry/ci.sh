#!/usr/bin/env bash
# CI check for sensor-telemetry. .github/scripts/run-examples.sh runs it from the repository root
# after `silica build sensor-telemetry`. Runs the example (about 6 seconds), accepts exit status 0
# or 2, and checks that dashboards and the final summary were printed.
set -euo pipefail

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

rc=0
silica run sensor-telemetry > "$log" 2>&1 || rc=$?
cat "$log"

case "$rc" in
  0|2) ;;
  *) echo "sensor-telemetry exited with status $rc" >&2; exit 1 ;;
esac

grep -q "^--- dashboard 1 " "$log" || { echo "missing first dashboard" >&2; exit 1; }
grep -q "^FINAL SUMMARY: readings=" "$log" || { echo "missing final summary" >&2; exit 1; }
grep -q "sensors_reporting=3" "$log" || { echo "not every sensor reported" >&2; exit 1; }

# Humidity and temperature use different bases, so their stat lines must differ (an earlier compiler
# defect made them identical).
temp_line="$(grep -m1 "^  temp C:" "$log" | sed 's/^  temp C://')"
hum_line="$(grep -m1 "^  hum %:" "$log" | sed 's/^  hum %://')"
[ -n "$temp_line" ] && [ -n "$hum_line" ] || { echo "missing temp or hum stats" >&2; exit 1; }
[ "$(echo $temp_line)" != "$(echo $hum_line)" ] || { echo "temp and hum stats are identical" >&2; exit 1; }
grep -qE "^  hum %: +min=(3|4|5)[0-9]\." "$log" || { echo "hum stats are not in the humidity range" >&2; exit 1; }
