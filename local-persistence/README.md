# local-persistence

Keeps a small log in a file on this machine and adds to it on every run. Each run appends three records, makes them durable, replays the whole log from the oldest record and exits. The file outlives the program, so the second run replays six records, the third nine, and so on.

```console
$ silica run local-persistence
    Building libsilica_store.a
   Compiling local-persistence (5 modules) with silica-999908-macos-applesilicon
  Assembling local-persistence
     Linking local-persistence
    Finished local-persistence/.silica-build/local-persistence/local-persistence
     Running local-persistence/.silica-build/local-persistence/local-persistence
link_up backing
log oldest=0 next=0 capacity=8192
synced 3
rx started
rx reading 21
rx reading 22
rx_end 3
link_down :closed
[silica] root actor exited (no supervisor)
$ silica run local-persistence
...
log oldest=0 next=3 capacity=8192
synced 6
rx started
rx reading 21
rx reading 22
rx started
rx reading 21
rx reading 22
rx_end 6
link_down :closed
[silica] root actor exited (no supervisor)
```

The last line comes from the storage carrier ending normally after `:close`.

## How it works

Silica has no files, paths or directories. A program keeps data only through a **storage carrier**, a `(:store)` declaration whose link names the medium:

```silica
carried_on journal: (:store) (:backing, "local-persistence/__ignore__journal.sildat", 8192, :stop);
```

The `(:backing)` medium is a durable, append-only log of checked records in a file on the host. The carrier creates the file on the first run. It holds 8192 bytes (two 4096-byte blocks). The retention is `:stop`, so a full log refuses new records.

`dangerous_local_persistence_example.silica` has two actors: the `(:backing)` carrier from the standard library (`dangerous_store_backing_carrier`), and an `owner` that receives everything the carrier sends. Every request to the carrier is a `cast`.

1. `main` starts the carrier and sends `(:open, owner, "")`. The carrier recovers the log from the file and answers `(:link_up, "backing")` and `(:log, oldest, next, capacity)`.
2. The owner appends three records with `(:tx, record, self())` and asks for `:sync`. The carrier writes them, flushes (`F_FULLFSYNC` on macOS, `fdatasync` on Linux) and only then answers `(:synced, n)`: records below `n` are safe on disk.
3. The owner asks for a replay with `(:read, 0)` and grants 1000 receive credits. The carrier sends nothing without credit. Each record arrives as `(:rx, record)`, and `(:rx_end, n)` follows the last one.
4. The owner sends `:close`. The carrier flushes and answers `(:link_down, :closed)`, and the program exits with status 0.

The module is named `dangerous_` because it starts a `(:backing)` carrier, a dangerous actor over the standard library's C store wrapper (E4021).

## When the log is full

Each run's `:sync` pads the tail to the carrier's 512-byte write unit, so the 8192-byte log takes 16 runs (48 records). After that, every append gets `(:tx_failed, :full)`, and the records already stored are still replayed:

```console
log oldest=0 next=48 capacity=8192
tx_failed :full
tx_failed :full
tx_failed :full
synced 48
...
rx_end 48
```

To start over, delete the file: `rm local-persistence/__ignore__journal.sildat`.

Other retentions: `:ring` overwrites the oldest block instead of refusing, and `:trim` releases records when the owner sends `(:trim, upto)`. `(:store) (:memory, 8192, :stop)` is the same log held in memory, so nothing is kept between runs.

## Notes

- **Where to run it.** As in `read-log-file`, the program declares the backing twice: `local-persistence/__ignore__journal.sildat` for the repository root and `__ignore__journal.sildat` for the project folder. It falls back to the second when the first doesn't resolve, so both `silica run local-persistence` and `silica run .` use the same file. From inside the folder, you'll see one extra `[silica] root actor exited (no supervisor)` line before the output.
- **The file is generated** and kept out of git (`*.sildat` in `.gitignore`).
- **If the log can't be opened**, the program prints `the log could not be opened: <why>` and exits with status 1. `:in_use` means another process holds the file's lock, `:mismatch` means the file exists at a size other than 8192, and `:medium` means it can't be opened or read.
