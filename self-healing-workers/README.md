# self-healing-workers

Supervision and "let it crash". A `Supervisor` keeps a pool of three worker actors (`w1`, `w2`, `w3`) alive while some of the jobs they process are poisoned and crash them.

- A driver actor hands out twelve jobs one at a time, round-robin over the workers. A job is the number a worker divides 1000 by.
- Jobs 2, 5 and 9 are `0`. The worker divides by zero, which the runtime treats as a crash (`:language_error`).
- The supervisor (`:one_for_one`, children `:permanent`) restarts the crashed worker with its original state, and work continues.
- A registered `FailureReporter` prints each crash report to standard error.
- The supervisor's report sink (`:set_report_sink`) tells the driver once the restart is done, so the next job goes to a worker whose name is registered again.
- At the end the driver prints a summary and ends the program with `cast_exit(0)`.

Jobs are dispatched one at a time on purpose: `cast_registered` to a name that is briefly free during a restart would fail, and this keeps the example deterministic.

## Run

From the `silica-examples` root:

```console
$ silica run self-healing-workers
```

## Expected output

The program prints this on standard output. The crash reports go to standard error. Dispatch is serial, so the order is fixed.

```
supervisor ready: 3 workers, crash reports go to stderr
worker 1: 1000 / 3 = 333
worker 2: 1000 / 4 = 250
supervisor: a worker crashed
worker 1: 1000 / 6 = 166
worker 2: 1000 / 7 = 142
supervisor: a worker crashed
worker 1: 1000 / 9 = 111
worker 2: 1000 / 10 = 100
worker 3: 1000 / 11 = 90
supervisor: a worker crashed
worker 2: 1000 / 13 = 76
worker 3: 1000 / 14 = 71
summary: jobs_completed=9 crashes=3 restarts=3
```

`ci.sh` runs the example and checks the summary line.
