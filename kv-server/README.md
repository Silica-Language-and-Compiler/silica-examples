# kv-server

A mini Redis-like key-value server. It speaks a line protocol over TCP on `127.0.0.1:6380` and keeps every change in a log file, so the data survives a restart.

## What it shows

- The standard library's `(:tcp)` carrier (`dangerous_tcp_carrier`) as a listener, one **session actor per connection** (as in [`simple-web-server`](../simple-web-server)). A session reassembles lines from the received bytes, parses the command and asks the owner for it. Several commands in one packet, and a command split across packets, both work.
- A single **owner actor** that holds the data. Sessions never touch it directly: they send `(:set, ...)`, `(:get, ...)`, `(:del, ...)` and `(:keys, ...)` messages and get a `(:reply, text)` back.
- **Persistence** with a `(:store)` carrier on a `(:backing, ...)` file (as in [`local-persistence`](../local-persistence)). Every `SET` and `DEL` is appended as one record (`S <key> <value>` or `D <key>`) and synced. On start-up the owner replays the whole log to rebuild the data and only then opens the listener.
- Byte-level string parsing with `byte_at` and `byte_slice` (as in [`read-log-file`](../read-log-file)).
- The module is named `dangerous_*` because it starts dangerous carriers (E4021).

The data itself is one string of `key value` lines searched linearly, not the standard library's `OrderedMap`: that map is region-typed and no example keeps one in an actor's state across messages. This is fine for an example and linear in the data size.

## Run

From the `silica-examples` root:

```console
$ silica run kv-server
replaying log records: ...      (only when there is a log)
kv-server listening on 127.0.0.1, port:6380
```

(`silica run .` from inside this folder also works; the log path falls back to the local one.)

In another terminal:

```console
$ printf 'SET city Oslo\nSET greeting hello brave world\nGET city\nGET greeting\nGET nope\nKEYS\nDEL city\nGET city\n' | nc -w 1 127.0.0.1 6380
OK
OK
Oslo
hello brave world
(nil)
city greeting
OK
(nil)
```

Or interactively with `nc 127.0.0.1 6380`.

| Command | Reply |
| --- | --- |
| `SET <key> <value>` | `OK` (the value is the rest of the line; a key has no spaces) |
| `GET <key>` | the value, or `(nil)` |
| `DEL <key>` | `OK`, or `(nil)` if there was no such key |
| `KEYS` | the keys separated by spaces, or `(empty)` |
| anything else | `ERR ...` |

Commands are upper case. Stop the server with Ctrl-C, start it again and `GET` your keys.

## Limits

The log is 64 KiB with retention `:stop`: when it is full a `SET`/`DEL` still changes the data in memory, but the append fails and the server prints `could not append to the log: ...`. A line longer than 4096 bytes without a line end is dropped. Plain TCP on loopback only, no authentication.

## Reset the data

Stop the server, then delete the log:

```console
$ rm kv-server/__ignore__kv.sildat
```

## CI

`ci.sh` starts the server, sets and gets keys, stops it, starts it again and checks that the keys survived. It needs only `bash` (it uses `/dev/tcp`).
