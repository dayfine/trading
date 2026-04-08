# Data Universe — Design

**Status:** DRAFT
**Assigned to:** ops-data agent + feat-weinstein (universe type change)
**Unblocks:** survivorship-correct backtesting, policy-driven ops-data automation

---

## Problem

Three related gaps block production-grade backtesting:

1. **Manual ops-data invocations**: the ops-data agent waits for an explicit prompt
   specifying which symbols to fetch. There is no machine-readable definition of
   "complete coverage."

2. **Survivorship bias**: `get_universe` returns currently-listed instruments only.
   A backtest run over 2010–2024 would silently omit every company that was
   delisted, acquired, or went bankrupt in that window — overstating strategy
   returns by selecting only "winners."

3. **`Instrument_info` carries no listing period**: even if delisted symbols were
   fetched and stored, `Historical_source.get_universe` has no basis for filtering
   to "what was actually tradeable on this simulation date."

---

## Target state

- A `data/fetch-policy.sexp` declares the target universe and lookback.
- ops-data reads this, diffs it against `data/inventory.sexp`, and fetches gaps
  — no manual invocation needed for routine coverage maintenance.
- `Instrument_info.t` carries `listing_start` and `delisting_date` so
  `Historical_source.get_universe` can return only instruments tradeable on the
  simulation date.
- Lead-orchestrator invokes ops-data as a weekly maintenance step.

---

## Component 1: Fetch policy file

**File:** `data/fetch-policy.sexp`

```sexp
((target_exchanges (NYSE NASDAQ AMEX))
 (include_types    (common_stock etf))
 (include_delisted true)
 (lookback_years   30)
 (cadence          daily))
```

**Semantics:**
- `target_exchanges`: EODHD exchange codes for US equities
- `include_types`: EODHD instrument type filter; `common_stock` covers ordinary
  shares; `etf` needed for sector/index proxies (SPY, XLF, etc.)
- `include_delisted`: when `true`, fetch EODHD's delisted-ticker endpoint
  (`exchange-symbol-list/US?delisted=1`) in addition to currently listed
- `lookback_years`: how far back to fetch; determines `start_date = today - N years`
- `cadence`: always `daily` for this system

ops-data reads this file on every invocation (manual or scheduled). It:
1. Fetches the full symbol list from EODHD matching the policy
2. Diffs against `data/inventory.sexp`
3. Fetches gaps incrementally: recent-data top-up for existing symbols first
   (cheap, idempotent), then missing symbols (expensive, one-time)
4. Rebuilds `data/inventory.sexp` after each batch
5. Writes a coverage report to `dev/health/data-YYYY-MM-DD.md`

Incremental fetching is important: 5–10k symbols × 30 years is ~37M bars
(~3 GB CSV). It should be spread across multiple runs, not one blocking session.

---

## Component 2: `Instrument_info` extension

**File:** `analysis/data/types/lib/instrument_info.mli`

```ocaml
type t = {
  symbol       : string;
  name         : string;
  sector       : string;
  industry     : string;
  market_cap   : float;
  exchange     : string;
  listing_start  : Core.Date.t option;
  (** First trading date. [None] if not available from EODHD. *)
  delisting_date : Core.Date.t option;
  (** Last trading date for delisted instruments. [None] = still listed. *)
}
[@@deriving show, eq, sexp]
```

Both fields are `option` to preserve backwards compatibility: existing
`universe.sexp` files without these fields deserialize with `None` via
`[@sexp.option]` (or explicit default in the sexp deserializer).

**Where the data comes from:**
- `listing_start`: from EODHD `get_fundamentals` → `General.IPODate`
- `delisting_date`: from EODHD `exchange-symbol-list/US?delisted=1` →
  `last_price_date` field; present only for delisted symbols

---

## Component 3: `Historical_source` survivorship filter

**File:** `analysis/weinstein/data_source/lib/historical_source.ml`

`get_universe` currently returns the full list from `universe.sexp` regardless
of simulation date. After this change it filters to instruments that were
tradeable on `config.simulation_date`:

```ocaml
let _is_listed_on date (info : Types.Instrument_info.t) =
  let started =
    match info.listing_start with
    | None -> true  (* unknown → assume always listed *)
    | Some d -> Date.(d <= date)
  in
  let not_yet_delisted =
    match info.delisting_date with
    | None -> true  (* still listed *)
    | Some d -> Date.(date <= d)
  in
  started && not_yet_delisted

(* in get_universe *)
List.filter ~f:(_is_listed_on config.simulation_date) all_instruments
```

This is the core of survivorship-bias correction. A simulation running
2010–2024 will automatically see only companies that existed on each
simulation date, including those that were later delisted.

**Behaviour for missing listing data (`None` fields):** conservatively treated
as "always listed" — this slightly overstates the universe but never
silently drops a real instrument. As EODHD coverage improves and ops-data
populates the fields, the filter becomes progressively more accurate.

---

## Component 4: `Daily_price` — no change needed

The current type already has `adjusted_close`:

```ocaml
type t = {
  date           : Core.Date.t;
  open_price     : float;
  high_price     : float;
  low_price      : float;
  close_price    : float;
  volume         : int;
  adjusted_close : float;
}
```

EODHD's `adjusted_close` accounts for both splits and dividends (total return
basis). All Weinstein analysis (stage classification, MA slope, RS, volume
confirmation, resistance) operates on adjusted prices — no explicit dividend
or split fields are needed for this methodology.

**If explicit corporate action events are needed in future** (e.g., for
detecting split-driven volume spikes or tax-lot accounting): add a separate
`Corporate_action` type alongside `Daily_price` rather than expanding the
price bar. This keeps the common path simple. Defer until there is a concrete
use case.

---

## Component 5: ops-data scheduling

ops-data is currently human-triggered. To automate:

1. **Lead-orchestrator Step 2e** (new): check `dev/health/data-YYYY-MM-DD.md`
   — if the most recent data report is older than 7 days, dispatch ops-data
   before any feat-agents run.
2. ops-data reads `data/fetch-policy.sexp`, runs a coverage diff, fetches gaps,
   writes a new health report, and returns a summary.
3. If the coverage diff exceeds a threshold (e.g., > 100 symbols missing recent
   data), the orchestrator notes it in the daily summary as an escalation.

This makes data freshness a first-class concern in the daily run rather than
a manual afterthought.

---

## Implementation order

All four components are independent and can be implemented in any order.
Recommended sequence based on value vs. effort:

| Step | Component | Who | Effort |
|------|-----------|-----|--------|
| 1 | `data/fetch-policy.sexp` (file only, no code) | ops-data | trivial |
| 2 | `Instrument_info` extension (type + serde) | feat-weinstein or ops-data | small |
| 3 | `Historical_source` survivorship filter | feat-weinstein | small |
| 4 | ops-data policy-driven fetch loop | ops-data | medium |
| 5 | Lead-orchestrator Step 2e (weekly data check) | harness-maintainer | small |

Steps 1–3 are low-risk (type extension is sexp-backward-compatible; filter
defaults to conservative behaviour). Step 4 is the bulk of the data work.

---

## Out of scope

- **Intraday / tick data**: not needed for Weinstein weekly methodology
- **Fundamental data expansion** (earnings, P/E, debt): not used in any current
  analysis module
- **Multi-exchange non-US coverage**: deferred until Weinstein global analysis
  is in scope
- **Real-time price feeds**: live source already uses EODHD end-of-day API;
  no change needed
- **Explicit dividend/split event types**: deferred pending concrete use case

---

## Files to create / modify

| File | Change |
|------|--------|
| `data/fetch-policy.sexp` | new: policy declaration |
| `analysis/data/types/lib/instrument_info.mli` | add `listing_start`, `delisting_date` |
| `analysis/data/types/lib/instrument_info.ml` | update record + serde |
| `analysis/weinstein/data_source/lib/historical_source.ml` | add survivorship filter in `get_universe` |
| `analysis/weinstein/data_source/lib/historical_source.mli` | no interface change |
| `.claude/agents/lead-orchestrator.md` | add Step 2e: weekly data freshness check |
| `dev/status/data-layer.md` | add `## Known gaps` entry for listing period data |
