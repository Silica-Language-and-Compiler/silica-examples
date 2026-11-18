# Silica examples

Small, runnable programs written in [Silica](https://github.com/Silica-Language-and-Compiler/silica), a memory-safe, functional systems language. Each folder is one project, and the [`silica` CLI](https://github.com/Silica-Language-and-Compiler/silica-cli) builds and runs it with one command.

| Example | Shows |
| ------- | ----- |
| [`hello-world`](hello-world/) | Printing a line: the `device_io` effect inside a `sequence proc` block |
| [`fizzbuzz`](fizzbuzz/) | Recursion instead of loops, and `case` on booleans instead of if/else |
| [`list-pipeline`](list-pipeline/) | `List[int64, mem(normal)]`, list patterns, and `map`/`filter`/`fold` with function literals |
| [`shapes`](shapes/) | A sum type of tagged tuples, matched with `case`, with `float64` arithmetic |
| [`ping-pong`](ping-pong/) | Two actors trading messages with `cast`, each carrying its own state |
| [`countdown`](countdown/) | Timers: an actor that schedules its own messages with `send_after` and measures elapsed time |
| [`tic-tac-toe`](tic-tac-toe/) | A minimax player against a random one, with the board as `uint64` bitmasks and a hand-rolled random number generator |
| [`game-of-life`](game-of-life/) | Conway's Game of Life on a wrapping 8x8 grid packed into one `uint64`, animated in the terminal by a timer-driven actor |
| [`dice-race`](dice-race/) | A board race in which each die is an actor answering `call`, and a referee actor keeps the players in a list of records |
| [`simple-web-server`](simple-web-server/) | An HTTP server on `127.0.0.1:5173` that answers every request with one fixed response, built from actors and the standard library's `(:tcp)` carrier |
| [`web-server-from-static-files`](web-server-from-static-files/) | An HTTP server that keeps its files in a Silica store (`(:store)` carrier, `site.sildat`): `PUT` stores a file, `GET` streams it back in chunks |
| [`ml-linear-regression`](ml-linear-regression/) | Least-squares linear regression over a CSV file, replayed from a `(:store)` storage carrier: records unframed, `decode`d and parsed, with flat memory however long the file is |
| [`read-log-file`](read-log-file/) | Reading a text log through a `(:store)` storage carrier and printing its `[ERROR]` rows, with a byte-level parser and per-level counts |
| [`local-persistence`](local-persistence/) | A log that survives between runs: each run appends to a `(:store)` carrier on a `(:backing)` file, syncs it to disk and replays everything stored so far |
| [`self-healing-workers`](self-healing-workers/) | Let it crash: a `Supervisor` restarts workers that die on poisoned jobs, a `FailureReporter` prints each crash, and the work carries on |
| [`kv-server`](kv-server/) | A small Redis-like key-value server on `127.0.0.1:6380` (`SET`, `GET`, `DEL`, `KEYS`): the `(:tcp)` carrier for clients and a `(:store)` log that restores the data after a restart |
| [`route-planner`](route-planner/) | Dijkstra shortest paths and Prim's minimum spanning tree over a European road network, using the standard library's weighted graph and Brodal–Okasaki priority queue |
| [`sensor-telemetry`](sensor-telemetry/) | Timer-driven sensor actors send `wire_etf`-encoded readings over the `(:udp)` carrier to a collector that prints a live min/max/mean dashboard |
| [`parallel-wordcount`](parallel-wordcount/) | Map-reduce word count: one mapper actor pinned to each CPU core, merged by a reducer into totals and a top-10 list |

The games play themselves: the language doesn't read from standard input yet, so there is no keyboard input. `dice-race` compiles with warning W2300, which says the referee's state is copied after every message. That's fine at this size.

## Install the CLI

The CLI runs on macOS on Apple Silicon, Linux on AArch64 and Linux on x86-64. You need `curl` and `tar`. To assemble and link programs, you also need `clang` on macOS (from the Xcode Command Line Tools: `xcode-select --install`) or `cc` on Linux.

```bash
curl -fsSL https://github.com/Silica-Language-and-Compiler/silica-cli/releases/latest/download/install.sh | bash
```

The installer puts everything in `~/.silica`. Add its `bin` folder to your `PATH`, for example in `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/.silica/bin:$PATH"
```

Then check it:

```console
$ silica version
```

The first build downloads the latest Silica compiler for your machine. It also downloads the standard library when an example needs it.

## Run an example

Clone this repository, and run an example from its root:

```console
$ git clone https://github.com/Silica-Language-and-Compiler/silica-examples.git
$ cd silica-examples
$ silica run hello-world
   Compiling hello-world (1 module) with silica-999921-macos-applesilicon
  Assembling hello-world
     Linking hello-world
    Finished hello-world/.silica-build/hello-world/hello-world
     Running hello-world/.silica-build/hello-world/hello-world
Hello, world!
```

`silica run <folder>` compiles every `.silica` file in the folder, assembles the output, links an executable and runs it. Build output goes to `<folder>/.silica-build/`, so the source tree stays clean. To build without running, use `silica build <folder>`.

A Silica `main` that returns an atom exits with that atom's index. `hello-world` returns `:ok`, so its exit status is **2**, not 0.

To try a web server, run it in one terminal and query it from another:

```console
$ silica run simple-web-server
$ curl http://localhost:5173
Hello Web Server
```

`web-server-from-static-files` serves files you store in it. Run it from its folder, upload the sample site with `curl -T public/index.html http://localhost:5173/` (and the other files under `public/`), then open <http://localhost:5173> in a browser.

`ml-linear-regression` reads its CSV through a storage log, so convert the CSV first, from the repository root:

```console
$ python3 ml-linear-regression/csv_to_sildat.py
$ silica run ml-linear-regression
```

`read-log-file` reads a text log through the same kind of backing. `silica sildat` packs the log; `--capacity` is the size in the program's `(:backing)` link:

```console
$ silica sildat read-log-file/app.log read-log-file/__ignore__app.sildat --capacity 1048576
$ silica run read-log-file
```

`local-persistence` creates its own log file on the first run, so there is nothing to convert. Run it a few times to watch the log grow, and delete `local-persistence/__ignore__journal.sildat` to start over.

See [`simple-web-server/README.md`](simple-web-server/README.md) and [`web-server-from-static-files/README.md`](web-server-from-static-files/README.md) for how they work.

## Adding an example

Each pull request builds, runs and checks every example on macOS (Apple Silicon), Linux on AArch64 and Linux on x86-64. It uses the latest `silica` CLI and the latest released compiler ([`.github/workflows/examples.yml`](.github/workflows/examples.yml)). Any top-level folder with a `.silica` file in it counts as an example, so a new one is picked up without changing the workflow. An example passes when:

1. `silica build <folder>` succeeds, and
2. `silica run <folder>` exits with status 0 or 2 (`:ok`) within 3 minutes.

If an example needs setup first, never exits on its own (like a server), or prints output worth checking, add a `ci.sh` to its folder. It then runs in place of step 2, with `bash` from the repository root, and it must exit 0. Anything it leaves running is stopped afterwards. See [`read-log-file/ci.sh`](read-log-file/ci.sh) and [`simple-web-server/ci.sh`](simple-web-server/ci.sh) for examples.

To run the same checks locally, from the repository root:

```console
$ .github/scripts/run-examples.sh                 # every example
$ .github/scripts/run-examples.sh hello-world     # just this one
```

## Learn more

- `silica spec` shows where the language specification is installed and how to search it
- [Language specification](https://github.com/Silica-Language-and-Compiler/silica/blob/main/compiler/design_documents/silica-specification.md)
- [Tutorials](https://github.com/Silica-Language-and-Compiler/silica/tree/main/compiler/tutorials_and_howtos)
- [silica-cli README](https://github.com/Silica-Language-and-Compiler/silica-cli#readme), with every command and environment variable
