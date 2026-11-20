# stock-exchange

A small stock exchange, built from actors. Four trading strategies send orders through a supervised risk desk to a price-time priority matching engine. The engine has a volatility circuit breaker and reopening call auctions. A live trade tape and a clearing ledger close out the session. It is the largest example here: about 1,700 lines in ten modules. It uses most of the language at once:

| Feature | Where |
| ------- | ----- |
| Several modules, `export name/arity`, `use`, `module@fn(...)` | every file; `main.silica` uses all of them |
| User-defined traits with required and provided methods, implemented for several record shapes | `Strategy.silica` (three trader types), `Priced.silica` (order tickets and trades) |
| Sum types of tagged tuples, records with atom-union fields, exhaustive `case` | the engine's request record, every actor's message type |
| Lists of records, list patterns, recursion instead of loops | `book.silica`, `ledger.silica` |
| Higher-order functions and function literals | `stats.silica`: every statistic is one `fold` with a different literal |
| `call` (request/reply) and `cast` between actors, `spawn_registered`, `call_registered`, `cast_registered` | `main.silica` |
| A `Supervisor` with `:permanent` children, a report sink and a `FailureReporter` | the risk desk |
| Timers: `send_after` paces the session | the driver |
| Explicit effects: `sequence proc[concurrency]`, `proc[device_io]`, `proc[mem(normal)]` | everywhere; effects never leak into a function's signature |

## How it works

```
driver ──call──▶ engine          :quote, what the book looks like
driver ──call──▶ trader k        the snapshot; the trader answers with its next order
driver ──cast──▶ risk worker     the order, packed into one int64 ticket (codec)
risk worker ──call──▶ engine     an order that passed the checks; the engine matches it
engine ──cast──▶ tape ──cast──▶ ledger           every trade, in the order it happened
risk worker / supervisor sink ──cast──▶ driver   the order's outcome; then the next order
```

- **Traders** are call-only actors. Each one's state is a `Strategy` record plus a random seed. The record's shape picks the implementation:
  - `{ spread, size }`: a market maker. It quotes both sides of the mid and often cancels its oldest quote. There are two: tight and wide.
  - `{ size, trigger }`: momentum. It buys or sells at market when the last trade moved by `trigger`, and otherwise quotes passively.
  - `{ size, odd_every, wild_every }`: noise. It sends random orders, with the occasional odd lot or fat-fingered price.
- **The risk desk** is a `Supervisor` with two workers, `:risk_a` and `:risk_b`. A worker's message is a single `int64`: `codec` packs the order ticket into decimal digit fields. The desk refuses a limit order priced more than 5% from the last trade. It also caps the value of a round lot at $20,000; with these traders the band always catches a bad price first, so the cap never fires here. It also has a deliberate bug: it divides the notional by the number of round lots (100 shares), so an odd lot of 50 shares divides by zero and crashes the worker. The supervisor restarts it, the `FailureReporter` prints the crash report to standard error, and the report sink tells the driver to carry on. Let it crash.
- **The engine** is the only owner of the book (`book.silica`):
  - Matching uses price-time priority. Trades happen at the resting order's price, and a partly filled order keeps its place in the queue.
  - Market orders sweep the book and then drop any remainder (immediate-or-cancel).
  - Self-trade prevention: when an order would trade with a resting order from the same trader, the engine cancels the resting order instead.
  - The engine is a two-state machine, `:continuous` and `:halted`. A trade more than 0.40% from the reference price halts the market. The book then freezes for six orders. Limit orders rest unmatched, and market orders join at the edge of the band.
  - A **call auction** ends each halt. It picks the one price that trades the most shares. Ties go first to the smallest imbalance, then to the price closest to the last trade. Every crossing order then trades at that price.
  - At the close the engine publishes the best five price levels on each side.
- **The tape** prints each trade, flags blocks of $40,000 or more (`Priced@is_block`) and forwards each trade to the ledger. At the close it prints open, high, low, close, volume, turnover and VWAP.
- **The ledger** books every trade into share and cash positions and marks them to the closing price. It then checks the zero-sum invariant: across all accounts, shares and cash must both net to exactly zero. The program exits 0 if they do and 1 if they don't.

Exactly one order is in flight at a time, and the only actor that prints during the session is the tape. Every message that reaches the tape is caused by the one before it. So the run is deterministic: the same trades, halts and positions every time.

## Run

From the `silica-examples` root:

```console
$ silica run stock-exchange
```

The crash reports go to standard error; add `2>/dev/null` to hide them.

## Expected output (abridged)

```
exchange open: 4 traders, 2 risk workers under a supervisor, opening price 100.00

  #  1  noise       buys  100 @ 100.10  from momentum
  #  2  momentum    buys  400 @ 100.40  from maker-wide  [block]
  #  3  momentum    buys  100 @ 100.20  from noise
  #  4  momentum    buys  100 @ 100.40  from maker-wide
  #  5  noise       buys  300 @ 100.55  from momentum
  *** halt: 100.55 is more than 0.40% from the reference 100.00; the book is frozen for 6 orders
  *** reopening auction at 100.50: 300 shares uncrossed; continuous trading resumes
  #  6  momentum    buys  100 @ 100.50  from noise
  #  7  momentum    buys  200 @ 100.50  from maker-tight
        ! order 32 from noise: refused, limit price outside the 5% band
  ...
        ! order 68 from noise: odd lot crashed the risk worker; the supervisor restarted it
  ...

closing book (best 5 levels a side)
                 ask  101.05   2100 shares in 5 orders
                 ask  101.00    200 shares in 1 order
                 ask  100.90   1000 shares in 3 orders
                 ask  100.85    400 shares in 1 order
                 ask  100.65    200 shares in 1 order
                 ------ spread 0.10 ------
                 bid  100.55    200 shares in 1 order
                 bid  100.50    400 shares in 1 order
                 bid  100.40   2000 shares in 5 orders
                 bid  100.35    300 shares in 1 order
                 bid  100.30    400 shares in 1 order

market summary
  orders      240 sent, 6 refused, 7 crashed the risk desk
  self-trades 32 prevented (resting order cancelled)
  halts       3 volatility halts, each ended by a call auction
  trades      61 (4 blocks)
  volume      11500 shares
  turnover    $1157130.00
  open 100.10  high 100.95  low 100.10  close 100.60
  vwap        100.62
  resting     12 bids, 15 asks

positions at the close (marked at 100.60)
  maker-tight   -400 shares   cash  +40420.00   p&l  +180.00
  maker-wide    -600 shares   cash  +60625.00   p&l  +265.00
  momentum      +100 shares   cash  -10500.00   p&l  -440.00
  noise         +900 shares   cash  -90545.00   p&l    -5.00
clearing: 61 trades booked, shares net to zero: ok, cash nets to zero: ok
```

`ci.sh` runs the example and checks the summary lines, two of the auctions and the clearing line.

## Modules

| File | What it holds |
| ---- | ------------- |
| `main.silica` | the actors: driver, engine, traders, risk desk and its supervisor, tape, ledger, start-up |
| `book.silica` | the order book: matching, self-trade prevention, cancels, price levels, the call auction (pure) |
| `Strategy.silica` | the `Strategy` trait and its three implementations |
| `Priced.silica` | the `Priced` trait: notional value and the block-trade test |
| `codec.silica` | packs an order ticket into one `int64` and back |
| `stats.silica` | `fold` and the tape statistics built on it |
| `ledger.silica` | accounts, trade booking, totals, mark-to-market P&L |
| `market.silica` | tick size, mid price, percentage and basis-point bands |
| `rng.silica` | a seeded linear congruential generator that cannot overflow |
| `fmt.silica` | prices, signed money and aligned columns |

## Notes

- Silica has no type aliases or generics, so record and list types are written out in full wherever they appear. The engine's state type is long; that is the language being explicit, not repetition you can factor out.
- An atom literal passed straight to a function in another module is typed `atom`, not the narrower union the parameter wants. Bind it first with the union type (`side: :buy | :sell <- :buy;`), or pass it through a function whose return type is the union, as `codec` does.
- The build reports warning W2300 for the engine, tape and ledger behaviours: their state is copied at the end of every message. That's fine at this size.
- Tune the session in `main.silica`: `rounds`, `halt_bp`, `halt_orders`, the traders' parameters and seeds. A different seed gives a different but still deterministic session. Update `ci.sh` to match.
