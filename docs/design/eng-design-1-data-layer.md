# Data Layer — Engineering Design

**Codebase:** `dayfine/trading` — ~18,600 lines OCaml, 34 test files. Core + Async throughout.

**Related docs:** [System Design](weinstein-trading-system-v2.md) · [Book Reference](weinstein-book-reference.md)

## Data Layer

## 1.1 Components

- **EODHD Client** — extend existing `analysis/data/sources/eodhd/`
- **Data Cache** — extend existing `analysis/data/storage/csv/`
- **Universe Registry** — extend existing `analysis/data/storage/csv/registry/`
- **Data Source Abstraction** — new: `analysis/weinstein/data_source/`

## 1.2 Requirements

**Functional:**
- Fetch weekly OHLCV bars for any US equity from EODHD
- Fetch daily and weekly bars for market indices (DJI, SPX, global)
- Fetch exchange symbol lists with sector/industry metadata
- Cache all fetched data locally; avoid redundant API calls
- Serve data through a uniform interface regardless of live vs historical vs synthetic source
- Support date-bounded queries ("AAPL weekly bars from 2020-01-01 to 2025-12-31")

**Non-functional:**
- Respect EODHD rate limits (100K calls/day, throttle concurrent requests)
- Full universe scan (~5,000 actively traded US equities): initial fetch <30 min, weekly incremental <5 min
- Cache is idempotent: same query twice → identical results, no corruption on concurrent access

**Non-requirements:**
- Real-time or streaming data (end-of-day only)
- Sub-second query latency (batch system, not a trading desk)
- Multi-user concurrency (single user, single process)

## 1.3 Design

### EODHD Client Extensions

The existing client supports: daily historical prices, symbol list, bulk last-day. We add:

```ocaml
(* Additions to http_client.mli *)

type period = Daily | Weekly | Monthly [@@deriving show, eq]

type historical_price_params = {
  symbol : string;
  start_date : Date.t option;
  end_date : Date.t option;
  period : period;              (* NEW — currently hardcoded to Daily *)
}

val get_fundamentals :
  token:string -> symbol:string -> ?fetch:fetch_fn -> unit ->
  Fundamentals.t Status.status_or Deferred.t

val get_index_symbols :
  token:string -> index:string -> ?fetch:fetch_fn -> unit ->
  string list Status.status_or Deferred.t
```

Implementation change: replace hardcoded `("period", ["d"])` with period from params. One-line change.

**Fundamentals type:**
```ocaml
type fundamentals = {
  symbol : string; name : string; sector : string;
  industry : string; market_cap : float; exchange : string;
} [@@deriving show, eq]
```

### Data Source Abstraction

The seam between live and historical/synthetic modes. All three implement the same interface.

```ocaml
(* data_source.mli *)
module type DATA_SOURCE = sig
  val get_bars :
    symbol:string -> period:Types.Cadence.t ->
    ?start_date:Date.t -> ?end_date:Date.t -> unit ->
    Types.Daily_price.t list Status.status_or Deferred.t

  val get_universe : unit -> Fundamentals.t list Status.status_or Deferred.t

  val get_daily_close : symbol:string -> date:Date.t -> float option Deferred.t
end
```

| Implementation | Source | Use case |
|---|---|---|
| `Live_source` | EODHD API + cache | Weekly scans, daily monitoring |
| `Historical_source` | Local cache, date-bounded | Backtesting (no lookahead) |
| `Synthetic_source` | Programmatic generation | Stress testing, edge cases |

**`Historical_source` enforces no lookahead:** Given a simulation date, it filters cached data to return only bars on or before that date. Critical for backtest integrity.

### Cache

**Storage format:** CSV files (reuse existing `csv_storage`).

**Directory structure:**
```
data/
├── daily/               # existing layout
│   └── A/A/AAPL/prices.csv
├── weekly/              # NEW
│   └── A/A/AAPL/prices.csv
├── indices/             # NEW
│   ├── DJI/prices.csv
│   └── GSPC/prices.csv
├── fundamentals/        # NEW
│   └── universe.json
└── metadata/            # existing
```

**Why CSV, not SQLite?**
- Existing codebase uses CSV with tested parser/writer
- Data is append-mostly (new bars each week)
- Human-inspectable and git-friendly
- ~5,000 symbols × 52 weeks × 10 years = ~2.6M rows — CSV is adequate
- No complex queries needed — load full symbol history, filter in memory

**Trade-off:** At 50,000+ symbols or intraday data, CSV would bottleneck. SQLite would be the natural upgrade — same file-based simplicity with indexed queries. The `DATA_SOURCE` abstraction means swapping storage doesn't touch analysis code.

### Idempotency and Correctness

- **Fetch idempotency:** EODHD returns same data for same query. Cache writes are idempotent via `csv_storage.save ~override:true`.
- **Incremental updates:** Weekly scans fetch only the latest week. Cache appends new bars. Staleness detected by comparing last cached date vs current date.
- **Atomicity:** Write to temp file, rename. Atomic on POSIX.

### Performance

| Operation | Time |
|---|---|
| Initial full-universe fetch | 15–25 min (5K calls, 20 concurrent) |
| Weekly incremental | 5–10 min |
| Backtest data load (10yr, 5K symbols) | ~2–5 sec (local I/O, lazy loading) |

---

## Storage decisions

| Price bars | CSV | `data/{period}/{A}/{L}/{SYM}/prices.csv` | Existing pattern, append-friendly |
| Index bars | CSV | `data/indices/{INDEX}/prices.csv` | Same |
| Fundamentals | JSON | `data/fundamentals/universe.json` | Semi-structured, infrequent updates |
| Config | JSON | `config.json` | Human-editable, standard |

## Trade-offs

| Decision | Chosen | Alternative | Rationale |
|---|---|---|---|
| CSV storage | Files on disk | SQLite | Existing pattern, adequate at scale, human-readable. DATA_SOURCE abstraction means swap is zero analysis code change. |
| Extend EODHD client | Add period param + fundamentals | Build new client | Existing client works, well-tested, just needs small additions |
| Three DATA_SOURCE impls | Live + Historical + Synthetic | Single client | Clean separation of concerns, backtest integrity (no lookahead) |
