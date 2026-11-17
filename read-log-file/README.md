# read-log-file

Reads an application log and prints every failed row: the lines logged at `[ERROR]`. `[LOG]` and `[WARN]` lines are counted but not printed. The sample is `app.log`, a short run of a made-up shop server with LOG, WARN and ERROR lines in the form `<date> <time> [LEVEL] message`.

From the `silica-examples` root (or `silica sildat app.log __ignore__app.sildat --capacity 1048576` and `silica run .` inside this folder):

```console
$ silica sildat read-log-file/app.log read-log-file/__ignore__app.sildat --capacity 1048576
wrote 21 lines in 1 block to read-log-file/__ignore__app.sildat (capacity 1048576)
$ silica run read-log-file
    Building libsilica_store.a
   Compiling read-log-file (7 modules) with silica-999908-macos-applesilicon
  Assembling read-log-file
     Linking read-log-file
    Finished read-log-file/.silica-build/read-log-file/read-log-file
     Running read-log-file/.silica-build/read-log-file/read-log-file
lines in the log: 21
failed rows:
  line 8: 2026-11-17 08:01:20 [ERROR] POST /checkout 500 payment gateway timeout after 30000ms (order 77812)
  line 12: 2026-11-17 08:02:41 [ERROR] POST /login 401 invalid password for user id 4410 (attempt 3 of 3)
  line 15: 2026-11-17 08:04:30 [ERROR] worker email-3 crashed: smtp connection refused (restarting)
  line 18: 2026-11-17 08:05:12 [ERROR] GET /orders/99120 404 order not found
LOG:   13
WARN:  4
ERROR: 4
[silica] root actor exited (no supervisor)
```

The last line comes from the storage carrier ending normally after `:close`.

## Why the log is converted first

Silica has no files, paths or directories. A program reads data only through a **storage carrier**, a `(:store)` declaration whose link names the medium:

```silica
carried_on logfile: (:store) (:backing, "read-log-file/__ignore__app.sildat", 1048576, :stop);
```

The backing is an append-only log of checked records, not a text file. `silica sildat` converts `app.log` first: each non-empty line becomes one stored value, the line as a Silica `string`. The layers of that file are the same ones [`ml-linear-regression`](../ml-linear-regression/README.md#why-there-is-a-python-step) describes. `__ignore__app.sildat` is generated and kept out of git. `--capacity 1048576` is the size in both `carried_on` lines; the carrier refuses a backing of another size with `:mismatch`.

## How it works

`dangerous_read_log.silica` has two actors: the `(:backing)` carrier from the standard library, and an `owner` that receives everything the carrier sends.

1. `main` starts the carrier and sends `(:open, owner, "")`. The carrier answers `(:link_up, info)` and `(:log, oldest, next, capacity)`.
2. The owner asks for a replay with `(:read, oldest)` and grants a window of 8 receive credits.
3. For each `(:rx, segment)`, the owner runs `wireframe@unframe`, `wireframe@unrecord` and `decode((:etf), ...)` to get the line back as a string. It finds the text between the first `[` and the next `]`, compares it with `ERROR`, `WARN` and `LOG` byte by byte, prints the line (with its 1-based line number) if it is `ERROR`, bumps that level's count and returns one credit.
4. On `(:rx_end, next)`, it prints the counts and sends `:close`. A line with no recognised level is counted as `other`, shown only when there are some.
5. On `(:link_down, :closed)`, the program exits with status 0.

Only the counts are kept, never the lines, so memory stays flat however long the log is.

## Use your own log

```console
$ silica sildat ~/my_app.log read-log-file/__ignore__app.sildat --capacity 1048576
$ silica run read-log-file
```

Lines need a `[LEVEL]` tag somewhere in them. The backing holds 1 MiB (roughly 10,000 lines like the sample). For more, raise `--capacity` and the capacity in both `carried_on` lines together. A line longer than 4051 bytes does not fit in one record.

## Notes

- **Where to run it.** As in `ml-linear-regression`, the program declares the backing twice: `read-log-file/__ignore__app.sildat` for the repository root and `__ignore__app.sildat` for the project folder, and falls back to the second if the first doesn't resolve. From inside the folder you'll see one extra `[silica] root actor exited (no supervisor)` line before the output.
- **Without the conversion**, the carrier creates an empty backing and the program prints `the log is empty: run ...` and exits.
