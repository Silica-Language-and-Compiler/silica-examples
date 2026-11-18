# parallel-wordcount

A map-reduce word count across the CPU cores.

- **Discover the cores.** `get_performance_cores()` and `get_efficiency_cores()` give the logical core ids; the program uses
  their number (at most 8) as the number of mappers.
- **One mapper actor per core, pinned.** `spawn(state, behavior, stack_policy(...), state_policy(...), core)` pins an actor to a core.
  The built-in corpus (eight lines in the source) is dealt out round-robin, so mapper `j` gets lines `j, j + n, ...`.
- **Map.** Each mapper tokenizes its chunk byte by byte with `byte_at` (letters and digits make a word, upper case is folded to
  lower case, `bytes_of` builds the word), counts words in a list of `{ w, n }` records, and casts one `(:count, word, n)`
  message per distinct word to the reducer, then `(:done, core, words)`.
- **Reduce.** The reducer actor merges the counts into its own list of records. When every mapper is done it prints the total
  and the top 10 words (ties broken alphabetically) and ends the program with `cast_exit(0)`.

The ordered maps in the standard library are not used: their keys are integers, so the table is a plain list of records.

## Pinning

On an OS-hosted target the core id requests thread affinity from the OS. Linux can enforce it. Apple Silicon macOS treats it as a
hint, so the actor is still bound to its carrier thread for that core id, but the OS decides where that thread runs. The program is
the same either way, and "which core" in the output is the core id the mapper was pinned to
(see `compiler/design_documents/execution-environments-hosted-vs-bare-metal.md`).

## Run

```console
$ silica run parallel-wordcount
```

Output on an 8-core machine. The `mapper` lines come in any order and their word counts
depend on the core count; the rest does not:

```
cores used: 8
mapper 3 on core 3 counted N words
mapper 0 on core 0 counted N words
...
total words: 91
distinct words: 32
top 10 words:
  1. the: 19
  2. dog: 9
  3. fox: 7
  4. and: 6
  5. quick: 5
  6. lazy: 4
  7. away: 3
  8. brown: 3
  9. oak: 3
  10. tree: 3
```

`ci.sh` runs the example and checks the total, the distinct count and the top 10 table, which were counted from the corpus
independently of the program.
