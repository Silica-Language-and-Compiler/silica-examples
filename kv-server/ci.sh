#!/usr/bin/env bash
# CI check for kv-server. .github/scripts/run-examples.sh runs it from the repository root after
# `silica build kv-server`. Starts from an empty log, starts the server, SETs and GETs keys, stops
# the server, starts it again and checks that the keys (and a DEL) survived the restart.
set -euo pipefail

port=6380
data=kv-server/__ignore__kv.sildat
log="$(mktemp)"
server=""
rm -f "$data"

# Whether something accepts connections on the port.
up() { (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; }

start() {
  silica run kv-server >> "$log" 2>&1 &
  server=$!
  for _ in $(seq 1 90); do
    kill -0 "$server" 2>/dev/null || { echo "the server exited before it answered" >&2; exit 1; }
    up && return 0
    sleep 1
  done
  echo "the server never listened on port $port" >&2
  exit 1
}

stop() {
  [ -n "$server" ] || return 0
  pkill -P "$server" 2>/dev/null || true
  kill "$server" 2>/dev/null || true
  wait "$server" 2>/dev/null || true
  server=""
  for _ in $(seq 1 30); do up || return 0; sleep 1; done
}

cleanup() {
  stop
  echo "--- server output"
  cat "$log"
  rm -f "$log" "$data"
}
trap cleanup EXIT

# kv <replies> <command>...: sends the commands on one connection, prints the first <replies> lines.
kv() {
  local n="$1" line
  shift
  exec 3<>"/dev/tcp/127.0.0.1/$port"
  printf '%s\n' "$@" >&3
  for _ in $(seq 1 "$n"); do
    IFS= read -r -t 10 line <&3 || { exec 3>&-; echo "no reply from the server" >&2; return 1; }
    printf '%s\n' "$line"
  done
  exec 3>&-
}

expect() {
  [ "$1" = "$2" ] || { echo "expected: $2" >&2; echo "got:      $1" >&2; exit 1; }
}

start
out="$(kv 5 "SET city Oslo" "SET greeting hello brave world" "GET city" "GET greeting" "GET missing")"
echo "$out"
expect "$out" "$(printf 'OK\nOK\nOslo\nhello brave world\n(nil)')"

out="$(kv 4 "SET tmp 1" "DEL tmp" "GET tmp" "KEYS")"
echo "$out"
expect "$out" "$(printf 'OK\nOK\n(nil)\ncity greeting')"

stop
echo "--- restart"
start
out="$(kv 4 "GET city" "GET greeting" "GET tmp" "KEYS")"
echo "$out"
expect "$out" "$(printf 'Oslo\nhello brave world\n(nil)\ncity greeting')"
