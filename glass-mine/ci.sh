#!/usr/bin/env bash
# CI check for glass-mine. .github/scripts/run-examples.sh runs it from the repository root after
# `silica build glass-mine`. The game reads standard input, so each run pipes in a list of choices:
# one path to each of the five endings, then a run that exercises the commands, the two refusals,
# a line that is too long and the end of input in the middle of the story.
set -euo pipefail

play() {  # play <choices...>: one choice per line; prints stdout, fails on a non-zero exit
  local rc=0 out
  out="$(printf '%s\n' "$@" | silica run glass-mine 2>/dev/null)" || rc=$?
  [ "$rc" -eq 0 ] || { echo "unexpected exit status $rc for input: $*" >&2; exit 1; }
  printf '%s\n' "$out"
}

expect() {  # expect <output> <line>
  grep -qxF -- "$2" <<< "$1" || { echo "missing line: $2" >&2; exit 1; }
}

out="$(play 3)"
expect "$out" "*** THE END: The Long Walk Home ***"
expect "$out" "You made 1 choice and found ending 1 of 5."

out="$(play 2 2)"
expect "$out" "*** THE END: Wings in the Dark ***"

out="$(play 2 1 1)"
expect "$out" "*** THE END: Downstream ***"

out="$(play 1 1 1 1)"
expect "$out" "*** THE END: The Singing Shard ***"
expect "$out" "You made 4 choices and found ending 4 of 5."

out="$(play 1 2 1 2)"
expect "$out" "*** THE END: The Heart of the Mountain ***"
expect "$out" "You made 4 choices and found ending 5 of 5."

# Into the Heart chamber without the lantern or a crystal, then the end of input mid-story.
long="$(head -c 1000 /dev/zero | tr '\0' 'z')"
out="$(play help 9 2 1 2 2 "$long" 2 1 "  look  ")"
expect "$out" "  quit   stop playing (Ctrl-D works too)"
expect "$out" "Type the number of a choice, or look, help or quit."
expect "$out" "> (That line is too long; the mine ignores it.)"
expect "$out" "In the dark you cannot see a way past it. The figure waits."
expect "$out" "You pat your pockets. You have nothing to offer. The figure waits."
expect "$out" "The lantern gutters out and the story fades. Come back another day."

echo "glass-mine: all five endings, the commands and the refusals behave"
