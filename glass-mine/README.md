# glass-mine

A choose-your-own-adventure you play from the keyboard. You are a prospector at the mouth of the abandoned Halverd glass mine, where the Heart is said to lie: a crystal as big as a cart wheel. There are six places, a lantern and some singing crystals that change what you can do, and five endings.

```console
$ silica run glass-mine
     Running glass-mine/.silica-build/glass-mine/glass-mine
THE GLASS MINE
A choose-your-own-adventure. Type a number to choose, or help.

THE MOUTH OF THE MINE
Wind whistles over the mouth of the old Halverd glass mine. Somewhere below, the
miners used to say, lies the Heart: a crystal as big as a cart wheel. An oil
lantern hangs on a nail by the entrance. Beside the main shaft, a narrow crack
in the rock breathes cold air.
  1) Take the lantern and climb down the main shaft
  2) Leave the lantern and squeeze into the crack
  3) Decide that treasure is overrated and walk home
> 1

THE MAIN SHAFT
Your lantern throws long shadows down a ladder of rotten rungs. At the bottom the
tunnel splits. From the left comes a soft hum, like a choir holding one note.
From the right comes a cold draft and the sound of water.
  1) Follow the humming
  2) Follow the draft
> 
```

Type a number and press Return. `look` shows the scene again, `help` lists the commands, and `quit` or Ctrl-D ends the game. When the story ends, the game tells you which of the five endings you found.

You can also pipe a whole game in. The game then shows each line it reads after the prompt, so the transcript reads like a session:

```console
$ printf '3\n' | silica run glass-mine
...
> 3

You climb back into the daylight with empty pockets and all ten fingers.
Some days, that is the treasure.

*** THE END: The Long Walk Home ***
You made 1 choice and found ending 1 of 5.
[silica] root actor exited (no supervisor)
```

The last line comes from the standard-input carrier ending normally once the keyboard is closed.

## It needs a compiler with standard input

Reading standard input is new ([`stdin_carrier_design.md`](https://github.com/Silica-Language-and-Compiler/silica/blob/main/compiler/design_documents/stdin_carrier_design.md)) and not yet in a released compiler. It has been checked on macOS on Apple Silicon and on Linux AArch64; Linux x86-64 has the same code but has not been run yet. Until it is released, build the compiler from the `silica` repository (`make gen1` in `compiler/src`) and point the CLI at it and at that repository's standard library:

```console
$ SILICA_COMPILER=<silica>/binaries/silica-gen1 SILICA_STDLIB=<silica>/compiler/stdlib silica run glass-mine
```

With a released compiler that predates it, the build fails on the `(:stdin)` link.

## How it works

Silica has no `read_line`. A program reads standard input the way it reads a socket or a store: through a **carrier**, an actor it talks to with messages. The declaration names the carrier's kind and its link, here the process's standard input:

```silica
module dangerous_glass_mine;

use dangerous_console_stdin_carrier;

carried_on keyboard: (:serial) (:stdin);
```

Standard input is untrusted input from outside the program, like a socket, so its carrier is **dangerous**: `dangerous_console_stdin_carrier` is a Fifi actor over a small C wrapper (`silica_console`, which does a non-blocking `read` on descriptor 0). A module that uses a `dangerous_` module must itself be one, which is why the program is `dangerous_glass_mine.silica` and its module is `dangerous_glass_mine`. The `use` line is needed today: the CLI bundles a library module only when a source file names it.

`dangerous_glass_mine.silica` has three actors: the failure reporter every program registers, the carrier, and `game`, which owns the carrier.

1. `main` starts the carrier with `spawn_dangerous_carrier(keyboard, ...)`, starts `game`, sends the carrier `(:open, game, "")` and waits in `wait_for_exit`. A program that declares a `(:stdin)` link takes standard input over from `wait_for_exit`, so typing `exit` is just a line the game reads ("Type the number of a choice...").
2. The carrier answers `(:link_up, "stdin:tty")` at a terminal, or `"stdin:pipe"` for a file or a pipe. The game prints the first scene and a prompt, and grants **one** receive credit with `(:credit, 1)`.
3. For that credit the carrier sends `(:rx, chunk)`: whatever one `read` returned, which can be part of a line or several lines. The bytes of a dangerous carrier are *external-danger-touched*: the game may not print or match them until it has re-created them. The `(:rx)` arm does that first, with `recreate(chunk, { max_bytes: 65536 })` in a `sequence proc[transport]` (`recreate` needs only the `transport` effect: the copy it makes is allocated inside its own derived function). `recreate` answers `(:ok, data)` or `(:rejected, why)`; a refused chunk is reported ("That input could not be read") and the game asks again. `utf8: true` is deliberately not used here: a chunk can end in the middle of a UTF-8 sequence, so UTF-8 belongs on complete lines, not on chunks. The game then puts the pure lines back together with the standard library's line framing, `wireframe@fresh(:lines)` and `wireframe@unframe`, which returns one line per call without its `\n` or `\r\n`. It handles every line in the chunk, then grants the next credit. Without credit the carrier reads nothing, so nothing is read ahead of the story.
4. Each line is trimmed and matched against `1`, `2`, `3`, `look`, `help` and `quit`. A choice goes through `next_scene`, a table of where each choice leads. The table returns a scene, an ending, 0 for "not a choice here" or a negative number for a choice you cannot make yet, such as offering something you do not have.
5. A line longer than 256 bytes is refused with `(:rejected, :too_large)`. The game recovers with `wireframe@skip_line`, which drops that line through its newline and keeps what follows.
6. At an ending, or on `quit`, the game sends `:close`. The carrier answers `(:link_down, :closed)` and stops, and the game ends the program with `cast_exit(0)`. The end of input gives the same `(:link_down, :closed)` in the middle of the story.

Because the chunk is re-created before it is framed, everything after that point works on ordinary values and the game can print them. `ci.sh` plays a path to every ending and checks the commands, the refusals, an over-long line and the end of input.
