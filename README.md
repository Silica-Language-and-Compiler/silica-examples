# Silica examples

Small, runnable programs written in [Silica](https://github.com/Silica-Language-and-Compiler/silica), a memory-safe, functional systems language. Each folder is one project, and the [`silica` CLI](https://github.com/Silica-Language-and-Compiler/silica-cli) builds and runs it with one command.

| Example | Shows |
| ------- | ----- |
| [`hello-world`](hello-world/) | Printing a line: the `device_io` effect inside a `sequence proc` block |
| [`web-server`](web-server/) | An HTTP server on `127.0.0.1:5173`, built from actors and the standard library's `(:tcp)` carrier |

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

To try the web server, run it in one terminal and query it from another:

```console
$ silica run web-server
$ curl http://localhost:5173
Hello Web Server
```

See [`web-server/README.md`](web-server/README.md) for how it works.

## Learn more

- `silica spec` shows where the language specification is installed and how to search it
- [Language specification](https://github.com/Silica-Language-and-Compiler/silica/blob/main/compiler/design_documents/silica-specification.md)
- [Tutorials](https://github.com/Silica-Language-and-Compiler/silica/tree/main/compiler/tutorials_and_howtos)
- [silica-cli README](https://github.com/Silica-Language-and-Compiler/silica-cli#readme), with every command and environment variable
