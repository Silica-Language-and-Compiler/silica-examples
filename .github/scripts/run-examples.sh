#!/usr/bin/env bash
# Builds and runs every example in this repository and checks that each one works.
#
#   .github/scripts/run-examples.sh                      every example
#   .github/scripts/run-examples.sh hello-world shapes   only these
#
# An example is any top-level folder that holds a .silica file, so a new example is picked up
# without changing this script or the workflow. For each example:
#
#   1. `silica build <example>` must succeed.
#   2. If the folder has a ci.sh, it runs with bash from the repository root and must exit 0.
#      Add one when the example needs setup first, never exits on its own (a server), or prints
#      output worth checking. SILICA_EXAMPLE holds the folder name.
#      Without a ci.sh, `silica run <example>` must exit 0 or 2. A `main` that returns an atom
#      exits with that atom's index, and :ok is 2. A runtime failure exits 1, 70 or 71.
#
# A build gets BUILD_TIMEOUT seconds (default 900). A run or ci.sh gets RUN_TIMEOUT seconds
# (default 180). Running out of time is a failure. Each one runs in its own process group,
# and the whole group is killed afterwards, so nothing it started (a server, say) is left running.
#
# Needs `silica` on PATH. Works with the bash 3.2 that ships with macOS.
set -uo pipefail

BUILD_TIMEOUT="${BUILD_TIMEOUT:-900}"
RUN_TIMEOUT="${RUN_TIMEOUT:-180}"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root" || exit 1

command -v silica >/dev/null 2>&1 || {
  echo "error: silica is not on PATH; install it from https://github.com/Silica-Language-and-Compiler/silica-cli" >&2
  exit 1
}

on_github=0
[ "${GITHUB_ACTIONS:-}" = true ] && on_github=1

logs="$(mktemp -d "${TMPDIR:-/tmp}/silica-examples.XXXXXX")"
trap 'rm -rf "$logs"' EXIT

is_example() {
  [ -d "$1" ] && [ -n "$(find "$1" -name '*.silica' -not -path '*/.silica-build/*' -print -quit)" ]
}

examples=()
if [ $# -gt 0 ]; then
  for arg in "$@"; do
    arg="${arg%/}"
    is_example "$arg" || { echo "error: $arg is not an example folder (no .silica file in it)" >&2; exit 1; }
    examples+=("$arg")
  done
else
  for dir in */; do
    dir="${dir%/}"
    is_example "$dir" && examples+=("$dir")
  done
fi
[ ${#examples[@]} -gt 0 ] || { echo "error: no examples found in $root" >&2; exit 1; }

# run_limited <seconds> <log> <command...>
# Runs the command in its own process group with its output appended to <log>. When the command
# ends or runs out of time, kills the group. Sets RUN_STATUS, and RUN_TIMED_OUT to 1 or 0.
run_limited() {
  local limit="$1" log="$2"; shift 2
  local marker="$logs/.timed-out"
  rm -f "$marker"

  set -m  # gives each background job its own process group
  "$@" >> "$log" 2>&1 < /dev/null &
  local pid=$!
  (
    sleep "$limit"
    : > "$marker"
    kill -TERM -- "-$pid" 2>/dev/null
    sleep 5
    kill -KILL -- "-$pid" 2>/dev/null
  ) > /dev/null 2>&1 &
  local watchdog=$!
  set +m

  wait "$pid" 2>/dev/null  # without 2>/dev/null, bash reports a killed job as "Terminated"
  RUN_STATUS=$?
  kill -KILL -- "-$watchdog" 2>/dev/null
  kill -KILL -- "-$pid" 2>/dev/null
  wait "$watchdog" 2>/dev/null

  RUN_TIMED_OUT=0
  [ -f "$marker" ] && RUN_TIMED_OUT=1
  return 0
}

summary_rows=""
failures=()

for example in "${examples[@]}"; do
  log="$logs/$example.log"
  : > "$log"
  start=$SECONDS
  result="" detail=""

  printf '\n===== %s =====\n' "$example" >> "$log"
  printf '$ silica build %s\n' "$example" >> "$log"
  run_limited "$BUILD_TIMEOUT" "$log" silica build "$example"
  if [ "$RUN_TIMED_OUT" = 1 ]; then
    result=fail detail="build timed out after ${BUILD_TIMEOUT}s"
  elif [ "$RUN_STATUS" != 0 ]; then
    result=fail detail="build failed (exit $RUN_STATUS)"
  elif [ -f "$example/ci.sh" ]; then
    printf '\n$ bash %s/ci.sh\n' "$example" >> "$log"
    run_limited "$RUN_TIMEOUT" "$log" env SILICA_EXAMPLE="$example" bash "$example/ci.sh"
    if [ "$RUN_TIMED_OUT" = 1 ]; then
      result=fail detail="ci.sh timed out after ${RUN_TIMEOUT}s"
    elif [ "$RUN_STATUS" != 0 ]; then
      result=fail detail="ci.sh failed (exit $RUN_STATUS)"
    else
      result=pass detail="ci.sh passed"
    fi
  else
    printf '\n$ silica run %s\n' "$example" >> "$log"
    run_limited "$RUN_TIMEOUT" "$log" silica run "$example"
    if [ "$RUN_TIMED_OUT" = 1 ]; then
      result=fail detail="run timed out after ${RUN_TIMEOUT}s (add a ci.sh if it is not meant to exit)"
    elif [ "$RUN_STATUS" = 0 ] || [ "$RUN_STATUS" = 2 ]; then
      result=pass detail="ran, exit $RUN_STATUS"
    else
      result=fail detail="run failed (exit $RUN_STATUS)"
    fi
  fi
  elapsed=$((SECONDS - start))

  if [ "$on_github" = 1 ]; then
    echo "::group::$example: $result, $detail (${elapsed}s)"
    cat "$log"
    echo "::endgroup::"
    [ "$result" = pass ] || echo "::error title=Example $example failed::$detail"
  else
    printf '%-4s  %-32s %s (%ss)\n' "$(echo "$result" | tr '[:lower:]' '[:upper:]')" "$example" "$detail" "$elapsed"
    [ "$result" = pass ] || { cat "$log"; echo; }
  fi

  if [ "$result" = pass ]; then icon="✅"; else icon="❌"; failures+=("$example"); fi
  summary_rows="$summary_rows| \`$example\` | $icon $detail | ${elapsed}s |"$'\n'
done

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Examples on $(silica version 2>/dev/null | awk '/^platform:/ {print $2}')"
    echo
    echo "Compiler: \`$(silica version 2>/dev/null | awk '/^compiler:/ {print $2}' | xargs basename 2>/dev/null)\`"
    echo
    echo "| Example | Result | Time |"
    echo "| ------- | ------ | ---- |"
    printf '%s' "$summary_rows"
  } >> "$GITHUB_STEP_SUMMARY"
fi

echo
passed=$(( ${#examples[@]} - ${#failures[@]} ))
if [ ${#failures[@]} -gt 0 ]; then
  echo "${passed} of ${#examples[@]} examples passed. Failed: ${failures[*]}"
  exit 1
fi
echo "All ${#examples[@]} examples passed."
