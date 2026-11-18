#!/usr/bin/env bash
# CI check for simple-web-server. .github/scripts/run-examples.sh runs it from the repository root
# after `silica build simple-web-server`. Starts the server, waits for it to listen on port 5173,
# checks that two requests get the fixed response, then stops it.
set -euo pipefail

log="$(mktemp)"
silica run simple-web-server > "$log" 2>&1 &
server=$!
stop() {
  pkill -P "$server" 2>/dev/null || true
  kill "$server" 2>/dev/null || true
  echo "--- server output"
  cat "$log"
  rm -f "$log"
}
trap stop EXIT

for _ in $(seq 1 60); do
  kill -0 "$server" 2>/dev/null || { echo "the server exited before it answered" >&2; exit 1; }
  curl -s -o /dev/null --max-time 2 http://127.0.0.1:5173/ && break
  sleep 1
done

for path in / /some/other/path; do
  body="$(curl -sS --max-time 5 "http://127.0.0.1:5173$path")"
  echo "GET $path -> $body"
  [ "$body" = "Hello Web Server" ] || { echo "unexpected response to GET $path" >&2; exit 1; }
done
