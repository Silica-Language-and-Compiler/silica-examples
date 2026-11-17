# ml-linear-regression

A small ML data-processing example. It fits a straight line to a two-column CSV file with ordinary least squares, reports how well the line fits, and uses it to make a prediction. The sample data is hours studied against exam score.

From the `silica-examples` root (or `python3 csv_to_sildat.py` and `silica run .` inside this folder):

```console
$ python3 ml-linear-regression/csv_to_sildat.py
generated 1000 rows in ml-linear-regression/__ignore__data.csv
wrote 1001 records in 10 blocks to ml-linear-regression/__ignore__data.sildat
$ silica run ml-linear-regression
    Building libsilica_store.a
   Compiling ml-linear-regression (7 modules) with silica-999908-macos-applesilicon
  Assembling ml-linear-regression
     Linking ml-linear-regression
    Finished ml-linear-regression/.silica-build/ml-linear-regression/ml-linear-regression
     Running ml-linear-regression/.silica-build/ml-linear-regression/ml-linear-regression
records in the log: 1001
skipped record 0 (not two numbers): hours_studied,exam_score
rows used:     1000
rows skipped:  1
slope:         6.009379762140492
intercept:     44.956357668427088
r squared:     0.968176774349285
model:         y = 6.009379762140492 * x + 44.956357668427088
predict x = 9.300000000000000: 100.843589456333674
[silica] root actor exited (no supervisor)
```

The last line comes from the storage carrier ending normally after `:close`.

## Why there is a Python step

Silica has no files, paths or directories. A program keeps and reads data only through a **storage carrier** (`transport_serialization_design.md` §6.8 in the Silica repository). A storage carrier is a `(:store)` declaration whose link names the medium:

```silica
carried_on dataset: (:store) (:backing, "ml-linear-regression/__ignore__data.sildat", 67108864, :stop);
```

That declaration is the only place a host path appears. The backing is not a text file. It is an append-only log of checked, numbered records in 4096-byte blocks. So a CSV has to be put into that form before a Silica program can read it. `csv_to_sildat.py` does this, the same way the Silica trials' `make_backings.py` writes backings: in Python, without depending on any Silica code. Each non-empty line of the CSV becomes one stored value, the line as a Silica `string`:

| Layer | What it adds |
| ----- | ------------ |
| value | `encode((:etf), line)`: the string in the BEAM External Term Format |
| record | `wireframe@record(:etf, 1, ...)`: format id 1 and schema version 1 |
| segment | the `:storage` framing header (one segment per line) |
| envelope | length, sequence number and CRC-32C, written by the carrier's on-medium form |
| block | a 4096-byte block with its own header and check |

`__ignore__data.csv` and `__ignore__data.sildat` are both generated, and the repository's `*__ignore*` rule in `.gitignore` keeps them out of git.

## How it works

`dangerous_linear_regression.silica` has two actors: the `(:backing)` carrier from the standard library, and an `owner` that receives everything the carrier sends.

1. `main` starts the carrier with `spawn_dangerous_carrier(dataset, ...)` and sends `(:open, owner, "")`. The carrier recovers the log and answers `(:link_up, info)` and `(:log, oldest, next, capacity)`.
2. The owner asks for a replay with `(:read, oldest)` and grants a window of 8 receive credits.
3. For each `(:rx, segment)`, the owner runs `wireframe@unframe`, then `wireframe@unrecord` (which checks format and schema), then **`decode((:etf), ...)`**. Stored bytes are untrusted until `decode` re-creates a value from them (§6.8.3). The owner then parses the line as `x,y`, adds it to six running sums (n, Σx, Σy, Σxy, Σx², Σy²) and returns one credit to the carrier.
4. On `(:rx_end, next)`, it solves for the line:
   - slope = (nΣxy − ΣxΣy) / (nΣx² − (Σx)²)
   - intercept = (Σy − slope·Σx) / n
   - r² = (nΣxy − ΣxΣy)² / ((nΣx² − (Σx)²)(nΣy² − (Σy)²))

   Then it prints the results and sends `:close`.
5. On `(:link_down, :closed)`, the program exits with status 0. If the first path doesn't resolve, the program falls back to the second (see Notes).

The program keeps only the sums, never the rows, and the credit window bounds how many records are in flight. Memory therefore stays flat however long the CSV is. This is the "stream of values" that §6.8.3 describes for large data.

A line that is not two numbers is skipped and reported. The CSV header is skipped that way. The parser accepts an optional `-`, digits, and an optional `.` followed by more digits, with blanks around each field. Silica has no integer-to-float conversion, so digits are turned into `float64` by a table.

The module name starts with `dangerous_` because the `(:backing)` carrier is a dangerous actor over the standard library's C store wrapper (`libsilica_store.a`, built by the CLI on first use).

## The data

`csv_to_sildat.py` first generates `__ignore__data.csv`: a header and `ROWS` rows (1,000 as shipped) of hours studied (x, uniform from 0 to 10) against exam score (y = 6.0·x + 45.0, plus Gaussian noise with standard deviation 3.0), rounded to two decimals. A fixed seed makes every run write the same file, so the fit should land near slope 6.0 and intercept 45.0. The script then converts the CSV into `__ignore__data.sildat`, one record per line, in a 64 MiB backing. Change `ROWS` or `SEED` at the top of the script to try other data. At 1,000,000 rows, the conversion takes about 4 seconds and the replay about 2.5 minutes on an Apple Silicon Mac. The replay time is the standard library carrier reading one record per dispatch; the program prints `replayed N` every 100,000 records.

## Use your own data

Pass a path to any two-column CSV (x first, y second), and the script converts it instead of generating one:

```console
$ python3 ml-linear-regression/csv_to_sildat.py ~/my_data.csv
$ silica run ml-linear-regression
```

The script rewrites `__ignore__data.sildat` each time. The backing holds 64 MiB, which is about 1.4 million lines of this size. For more data, raise `CAPACITY` in the script **and** the capacity in both `carried_on` lines together. The carrier refuses a backing of another size with `:mismatch`.

## Notes

- **Where to run it.** A backing path is relative to the directory the program runs in. The program declares the file twice: `ml-linear-regression/__ignore__data.sildat` for the `silica-examples` root and `__ignore__data.sildat` for the project folder. It opens the first, and if that path doesn't resolve (`:medium`), it closes that carrier and opens the second. So `silica run ml-linear-regression` from the root and `silica run .` inside the folder both work. From the folder you'll see one extra `[silica] root actor exited (no supervisor)` line before the results, from the first carrier ending. Started from any other directory, the program creates an empty `__ignore__data.sildat` there and reports that the log is empty.
- **Without the Python step**, the carrier creates an empty backing, and the program prints `the log is empty: run ...` and exits.
- **Compiler workarounds.** The current compiler (silica-999908) has two `float64` code-generation bugs. `add_point` and `fitted` are written to avoid both:
  1. In a record literal, a field that reads a `float64` parameter can get the value of the field before it. For example, `{ a: x, b: y }` gives `b = x`. The workaround is to bind each field to a local first.
  2. Inside a function whose body is a `sequence` block, the third `float64` parameter reads `0.0` once other calls have run. The workaround is to pass the sums record instead, and bind the values before the `sequence`.
