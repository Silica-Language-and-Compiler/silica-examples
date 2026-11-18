# sensor-telemetry

Three sensor actors send synthetic temperature and humidity readings over loopback UDP to
a collector, which prints a live dashboard once a second.

What it shows:

- **Timers**: each sensor re-arms itself with `send_after` (200, 250 and 300 ms); the collector uses
  one for the one-second dashboard (as in `countdown`).
- **Wire format**: each reading is a record `{ id, seq, temp, hum }` of int64s encoded with `wire_etf`
  (`encode((:etf), r)`, Erlang external term format) and decoded on the other side with `decode`.
- **UDP carrier**: `dangerous_udp_carrier`, one carrier per endpoint, sensors and collector alike.
  `wireframe` frames each segment (a datagram travels bare) and `unframe`s it on arrival. The collector
  grants receive credit; the carrier tells it its bound port with `(:link_up, "port:N")`, which it
  passes to the sensors it spawns.
- **Actors**: the sensors and the collector.
- The module is named `dangerous_*` because it uses a dangerous carrier (E4021).

The signal is deterministic: a per-sensor base value plus a small wave from a table. Values are int64
hundredths (2225 is 22.25), exact for every value used, and the dashboard prints them as `whole.frac`.
The mean is `sum / n` in hundredths, truncated.

Why not `float64`: a first version kept float64 stats, and humidity came out equal to temperature. A
record holding two same-shaped records of float64 fields reads the second as the first (a compiler
defect, compiler silica-999908), so the stats are int64 hundredths. `ci.sh` checks that the temperature
and humidity lines differ.

## Run

```console
$ silica run sensor-telemetry
```

It takes about five seconds and exits 0 when every sensor reported (1 otherwise). `ci.sh` runs it
and checks for the final summary.

## Expected output (the numbers and counts vary with timing)

```text
collector listening on 127.0.0.1 port:54321
--- dashboard 1 received=12 bad=0 ---
sensor 0 readings=4
  temp C: min=21.00 max=23.00 mean=22.25
  hum %:  min=35.00 max=45.00 mean=40.00
sensor 1 readings=3
  ...
--- dashboard 5 received=59 bad=0 ---
...
FINAL SUMMARY: readings=59 rejected=0 sensors_reporting=3
```
