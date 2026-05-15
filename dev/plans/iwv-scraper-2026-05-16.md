# iShares IWV holdings scraper — Phase 1.4 plan

Date: 2026-05-16. Track: `data-foundations`. Plan-first deliverable; no
source code in this PR. Implementation lands in four stacked PRs after
this plan is reviewed.

Authority: companion to `dev/notes/phase1.4-iwv-url-probe-2026-05-16.md`
(URL probe + cutoff characterization) and
`dev/notes/vendor-comparison-historical-universe-2026-05-16.md` §Option 7
(why DIY iShares is the chosen Russell 3000 path after Norgate was
retired 2026-05-16).

## 1. Context

The 2026-05-16 vendor pivot retired Norgate (NDU client is Windows-only,
incompatible with our Mac/Linux Docker toolchain). The replacement for
true point-in-time Russell 3000 reconstitution is DIY: fetch iShares'
IWV ETF holdings CSV per `asOfDate`, diff consecutive snapshots, and
reconstruct membership tenure from the diffs.

Phase 1.4's url-probe deliverable (`dev/notes/phase1.4-iwv-url-probe-2026-05-16.md`)
confirmed:

- URL pattern works no-auth, plain HTTPS GET.
- 15-column header is byte-identical from 2006-12-29 through 2026-05-08.
- Sentinel response is deterministic: HTTP 200 + 4,585-byte body +
  `Fund Holdings as of,"-"` on line 2 means no data.
- Cadence is asymmetric: quarterly 2006-09 to 2008, monthly 2009 to
  2012-04, daily 2012-04-30 onward.
- Full backfill ≈ 3,550 snapshots, ≈ 1.5 GB raw CSV, ≈ 3 hours at
  polite 2 s spacing.

This plan turns those findings into an OCaml implementation under
`analysis/data/sources/ishares/`. It deliberately mirrors the layout of
`analysis/data/sources/wiki_sp500/` (PRs #803/#808/#809/#813 — the
Wikipedia + EODHD historical-universe stack) so the same review patterns
apply.

## 2. Approach (chosen design)

### 2.1 Module boundary

All new code lives under `analysis/data/sources/ishares/` — pure data
source, qc-structural A2-clean, no writes into `trading/trading/`. The
sibling `wiki_sp500` directory is the canonical analog.

```
trading/analysis/data/sources/ishares/
├── lib/
│   ├── ishares_holdings_client.{ml,mli}    ← HTTP GET + CSV parse per asOfDate
│   ├── ishares_membership_replay.{ml,mli}  ← diff snapshots → tenure
│   └── dune                                ← libraries: base core re status types
│                                              (cohttp_async + async only used by bin/)
├── bin/
│   ├── fetch_iwv_history.ml                ← CLI: backfill cache, idempotent
│   ├── build_iwv_universe.ml               ← CLI: cached snapshots → russell-3000-...sexp
│   └── dune
├── test/
│   ├── test_ishares_holdings_client.ml
│   ├── test_ishares_membership_replay.ml
│   ├── data/
│   │   ├── iwv_2007-12-31.csv              ← quarterly era fixture
│   │   ├── iwv_2010-01-29.csv              ← monthly era fixture
│   │   ├── iwv_2020-06-15.csv              ← daily era fixture
│   │   ├── iwv_sentinel_2010-01-04.csv     ← sentinel-response fixture
│   │   └── expected_membership_subset.sexp ← golden replay output (3-snapshot toy)
│   └── dune
├── dune-project
└── ishares.opam
```

Rationale (mirrors §"Architecture" in
`dev/plans/wiki-eodhd-historical-universe-2026-05-03.md`):

- **Pure lib, I/O in bin.** Parser is a `string -> _ Status.status_or`
  function — no network calls inside the lib. HTTP fetch is in
  `ishares_holdings_client.fetch_for_date`, which takes an injected
  `fetch_fn` (the EODHD client's `default_fetch` pattern: `Uri.t -> string
  Status.status_or Deferred.t`). Tests inject a fixture-backed fetch_fn;
  live CLI calls `Cohttp_async.Client.get`.
- **Pinned fixtures, never network in tests.** Three era fixtures + one
  sentinel cover the parser's full surface. Tests are reproducible on a
  laptop with no network.
- **Idempotent on-disk cache.** `fetch_iwv_history.exe` is resume-safe —
  it skips dates already present on disk. The cache layout under
  `dev/data/ishares/iwv/` is gitignored (vendor-license caution; same
  posture we use for the EODHD CSV cache).

### 2.2 Library: `ishares_holdings_client`

Two responsibilities — fetch and parse. The split lets us test the parser
on pinned CSVs without touching the network.

```ocaml
(* ishares_holdings_client.mli — abridged *)

type holding = {
  ticker : string;                 (** Verbatim "Ticker" column. May be "-". *)
  name : string;                   (** "Name" — full security name. *)
  sector : string;                 (** "Sector" — pre-2012 may be "-". *)
  asset_class : string;            (** "Asset Class" — "Equity"/"Cash"/"Futures"/etc. *)
  market_value : float;            (** USD. *)
  weight_pct : float;              (** Holding weight in the ETF, percent. *)
  quantity : float;
  price : float;
  location : string;               (** "United States" / etc. *)
  exchange : string;
  currency : string;
  market_currency : string;        (** Pre-2012 may be "-". *)
}
[@@deriving show, eq]

type snapshot = {
  as_of : Core.Date.t;             (** From "Fund Holdings as of" metadata row. *)
  holdings : holding list;         (** In source order — parser preserves rows. *)
}
[@@deriving show, eq]

(** Sentinel response: HTTP 200 + "Fund Holdings as of" cell = "-". *)
type parse_outcome =
  | No_data_sentinel             (** Server returned a template with no holdings. *)
  | Parsed of snapshot

val parse : string -> parse_outcome Status.status_or
(** Pure CSV-text parser. Accepts UTF-8 BOM. Tolerates pre-2012 era
    quirks: empty Sector / Market Currency cells ("-"), ascending row
    order, synthetic tickers ("0R01", "GEC"), un-tickered positions
    ("-"). Returns [Error] only on structural failure (missing columns,
    unreadable Date in metadata, malformed row). *)

val build_uri : Core.Date.t -> Uri.t
(** Construct the iShares holdings URL for an asOfDate. *)

type fetch_fn = Uri.t -> string Status.status_or Async.Deferred.t

val default_fetch : fetch_fn
(** [Cohttp_async.Client.get] with a polite User-Agent header; same
    pattern as [Eodhd.Http_client.default_fetch]. *)

val fetch_for_date :
  ?fetch:fetch_fn ->
  as_of:Core.Date.t ->
  unit ->
  parse_outcome Status.status_or Async.Deferred.t
(** End-to-end: build URI, fetch, parse. Tests inject a fixture-backed
    [fetch] that returns a string from a pinned file. *)
```

Implementation notes:

- The CSV parser uses the same `Csv` library posture as
  `wiki_sp500.changes_parser` (re + hand-rolled tokenization). It must
  not assume row order: pre-2012 is ascending by Market Value;
  2012+ is descending. We extract by column header name, not column
  index, just like `Wiki_sp500.Changes_parser` does.
- The preamble has nine fixed lines before the column header (line 10).
  Line 2 holds the `Fund Holdings as of,<date>` metadata pair — the
  sentinel check parses this cell first and short-circuits if it equals
  `"-"`.
- Header matching is case-sensitive and on the verbatim 15-column shape
  the probe confirmed STABLE. Tests fail loudly if the header drifts:
  one PASS test on each era fixture + one FAIL test on a synthetic
  header-mismatch input.
- We do **not** filter to US equities inside the parser — that's a
  consumer concern. The probe doc recommended `Asset Class = "Equity"`
  + `Location = "United States"`; the universe-builder applies that
  filter in `build_iwv_universe.exe`.

### 2.3 Library: `ishares_membership_replay`

Pure tenure-reconstruction logic over a list of cached snapshots. No
I/O, no fetch.

```ocaml
(* ishares_membership_replay.mli — abridged *)

type tenure = {
  index : string;                  (** "IWV" today; reserved for IWB/IWM later. *)
  ticker : string;
  first_seen : Core.Date.t;        (** Earliest snapshot containing [ticker]. *)
  last_seen : Core.Date.t;         (** Latest snapshot containing [ticker]. *)
  active_through : Core.Date.t option;
      (** When the ticker disappeared for >= [removal_threshold] consecutive
          snapshots after [last_seen], we treat it as removed and record
          the last-observed date as the lower bound. [None] = ticker still
          present in the most recent snapshot, or insufficient data after
          [last_seen] to declare removal. Mirrors [Daily_price.active_through]
          semantics (PR #1076/#1094). *)
  observed_sectors : string list;
      (** All distinct GICS sectors seen across this ticker's tenure.
          Most tickers have one; a few (e.g. post-2018 GICS reclass) have two. *)
}
[@@deriving show, eq]

type config = {
  removal_threshold : int;
      (** Number of consecutive missing snapshots that count as a
          removal. Defaults to 3 (see §2.3.2 below). *)
}

val default_config : config

val reconstruct :
  ?config:config ->
  Ishares_holdings_client.snapshot list ->
  tenure list Status.status_or
(** [reconstruct snapshots] returns one [tenure] record per (ticker)
    observed across the input list. Input list must be in ascending
    [as_of] order; the function returns [Error] if not.

    Filtering: holdings with [asset_class <> "Equity"], [location <>
    "United States"], or [ticker = "-"] are dropped before tenure
    construction — see plan §2.3.3. *)

val to_universe_sexp :
  as_of:Core.Date.t ->
  tenure list ->
  Core.Sexp.t
(** Render the membership *at* [as_of] as a [(Pinned (...))] sexp matching
    [trading/test_data/backtest_scenarios/universes/broad-3000-2010-01-01.sexp]
    — the existing universe fixture shape. Each entry carries [symbol]
    and [sector] (first observed). Output is sorted by [symbol] ascending
    for determinism. *)
```

#### 2.3.1 Tenure reconstruction algorithm

Reverse-time replay would be more natural for *removals* (a ticker that
falls out of one snapshot but is in the next is a gap), but the iShares
stream gives us *forward* snapshots cleanly. We use a forward scan:

```
input: snapshots sorted by as_of ascending
output: { (index, ticker) -> tenure record }

state: Hashtbl<ticker, tenure_in_progress>
  tenure_in_progress = { first_seen; last_seen; observed_sectors; absent_streak }

for snap in snapshots (ascending):
    seen_in_snap = {h.ticker for h in snap.holdings if (h.asset_class="Equity"
                                                       && h.location="United States"
                                                       && h.ticker <> "-")}
    for t in seen_in_snap:
        if t in state:
            state[t].last_seen = snap.as_of
            state[t].absent_streak = 0
            if h.sector ∉ state[t].observed_sectors:
                state[t].observed_sectors += [h.sector]
        else:
            state[t] = new { first_seen=snap.as_of; last_seen=snap.as_of;
                             observed_sectors=[h.sector]; absent_streak=0 }
    for t in (state.keys - seen_in_snap):
        state[t].absent_streak += 1
        if state[t].absent_streak >= config.removal_threshold:
            (* Removal confirmed; freeze active_through at the last_seen we
               already have, and remove from state so re-appearance starts
               a fresh tenure. *)
            emit { ...state[t]; active_through = Some state[t].last_seen }
            remove t from state

end:
    for t in state.keys:
        if t in last snapshot:
            emit { ...state[t]; active_through = None }
        else:
            (* Tail-of-history disappearance not long enough to confirm
               removal. Conservative: leave active_through = None.
               Downstream PI filter falls back on Daily_price.active_through. *)
            emit { ...state[t]; active_through = None }
```

Complexity is O(N · M) where N is the snapshot count and M is the
average holdings count (~2,900). For the full ~3,550 × 2,900 corpus
that's ~10M hashtbl ops — order of seconds in OCaml.

#### 2.3.2 The 3-snapshot removal threshold — tradeoff

Single-snapshot disappearances do occur in the iShares stream (the
probe doc cites 2013-11-15 as a single-day sentinel between OK
2013-11-14 and 2013-11-18 — that's iShares not reporting on a Friday,
**not** a delisting). Counting any one-day gap as a removal would
introduce spurious tenure splits and double-count tickers.

We require **3 consecutive misses** before declaring a removal:

| Threshold | False positives (data glitches counted as removal) | False negatives (real removal missed at era boundaries) |
|----------:|---|---|
| 1 | High — every single-day glitch | Low |
| 2 | Medium — two-in-a-row glitches still possible | Low |
| **3** | **Low — three-in-a-row data glitches are extremely rare** | **Acceptable — 3 misses ≈ 3 days in daily era, ≈ 3 months in monthly era, ≈ 9 months in quarterly era** |
| 5+ | Very low | High in monthly/quarterly eras — defers removal recognition by months |

3 is the right knob for the **daily era (2012-04-30 onward)** which
covers 14 of the 20 years. The quarterly/monthly era (2006-09 to
2012-04) has too coarse a cadence for the threshold to be meaningful —
in practice in those eras a ticker missing 3 quarters is genuinely
gone. So 3 works as a single static value across all eras; we expose
it as `config.removal_threshold` so callers can override if needed.

Documented limitation: for tenure that **ends inside the quarterly era**,
`last_seen` is at best a 3-month-stale lower bound. Per-symbol delisting
precision flows through `Daily_price.active_through` (PRs #1076 / #1094)
from the EODHD price feed instead. The IWV-derived tenure is the
*membership* signal; the delisting *date* is the price-feed's job.

#### 2.3.3 Asset-class / location filter

The probe doc identified these non-equity rows the parser must keep
seeing (so the schema lock-in test stays honest) but the
universe-builder must drop:

- `Asset Class = "Futures"` — e.g. `ESM6`, `RTYM6` (S&P 500 / Russell 2000 futures hedges).
- `Asset Class = "Cash"` — the USD position at end of file.
- `Location <> "United States"` — pre-2012 included cross-listings like Citigroup on LSE.
- `Ticker = "-"` — un-tickered positions (e.g. rights, escrows in pre-2012 data).

Filter happens in `Ishares_membership_replay.reconstruct`, **after**
parsing. Tests cover both "row is preserved by parser" and "row is
dropped by reconstruct".

### 2.4 CLI: `fetch_iwv_history`

Resume-safe backfill of the snapshot cache. Single command.

```
Usage:
  fetch_iwv_history.exe \
    --from YYYY-MM-DD \
    --until YYYY-MM-DD \
    [--cache-dir PATH]       # default: dev/data/ishares/iwv/
    [--cadence daily|monthly|quarterly|auto]  # default: auto
    [--polite-sleep-ms N]    # default: 2000
    [--max-snapshots N]      # default: no cap; useful for partial backfills
```

Behavior:

- For each `asOfDate` D in [from, until] at the chosen cadence:
  - If `<cache-dir>/YYYY-MM-DD.csv` exists and is non-zero-byte and is
    **not** a sentinel, skip. (Sentinel detection on disk re-uses the
    parser's line-2 check.)
  - Otherwise fetch via `Ishares_holdings_client.fetch_for_date ~as_of:D`,
    sleep `polite_sleep_ms`, write the response body to disk.
- On sentinel response, write a 1-byte marker file `D.sentinel` so the
  next run doesn't re-fetch. Marker files don't count toward cache hits.
- On HTTP error, log and continue — don't abort the whole backfill on
  one transient failure. Exponential backoff on the next request.
- Reports: at end, print summary of (snapshots-fetched, snapshots-skipped,
  sentinels-marked, errors-encountered).

Cadence `auto` policy (from the probe doc):
- 2006-09-29 → 2008-12-31: query quarter-ends only (Mar 31, Jun 30,
  Sep 30, Dec 31).
- 2009-01-31 → 2012-04-30: query month-ends only.
- 2012-04-30 → present: query every weekday. (Holidays auto-sentinel and
  get marked, so they cost one round-trip per holiday per backfill.)

The cadence policy is exposed in code as a small function
`Build_iwv_universe_lib.cadence_dates : from:Date.t -> until:Date.t -> Date.t list`
so it's testable independently.

### 2.5 CLI: `build_iwv_universe`

Reads the cached snapshot directory, runs the parser + replay, emits the
universe sexp.

```
Usage:
  build_iwv_universe.exe \
    --as-of YYYY-MM-DD \
    --cache-dir PATH \                   # default: dev/data/ishares/iwv/
    --output PATH                        # required; e.g. russell-3000-2026-05-01.sexp
    [--from YYYY-MM-DD]                  # default: 2006-09-29 (earliest available)
    [--removal-threshold N]              # default: 3
```

Output sexp shape mirrors PR #1103's
`broad-3000-2010-01-01.sexp` so the screener can consume both without
changes:

```
;; russell-3000 universe — as-of 2026-05-01.
;; Source: iShares IWV holdings via Phase 1.4 scraper.
;; Generated by trading/analysis/data/sources/ishares/bin/build_iwv_universe.exe
;; Tenure replay: 3-snapshot removal threshold, ascending forward scan.
;; Coverage window: <from>..<as_of>. Snapshot count: N.
;; ...
(Pinned
 (((symbol A)     (sector "Health Care"))
  ((symbol AA)    (sector Materials))
  ...))
```

The CLI also writes a sibling `<output>.tenure.csv` with the raw tenure
table (`ticker, first_seen, last_seen, active_through, observed_sectors`)
so downstream consumers can wire `Daily_price.active_through` consistently.
Both outputs are atomic-renamed (write to `.tmp`, then `rename`) to keep
in-flight runs from corrupting consumers.

## 3. PR split

The full deliverable is too large for one PR (~900 LOC including tests
and fixtures). Four stacked PRs.

| PR | Branch | Adds | LOC (est. without fixtures) |
|---|---|---|---:|
| **PR-A** | `feat/data/iwv-client` | `ishares_holdings_client.{ml,mli}` + parser tests + 4 era fixtures + `dune` wiring | ~300 |
| **PR-B** | `feat/data/iwv-replay` | `ishares_membership_replay.{ml,mli}` + replay tests + toy snapshot fixtures | ~250 |
| **PR-C** | `feat/data/iwv-fetch-cli` | `fetch_iwv_history.exe` + cadence-policy helpers + `dev/data/ishares/iwv/` in `.gitignore` | ~150 |
| **PR-D** | `feat/data/iwv-universe-cli` | `build_iwv_universe.exe` + `russell-3000-<as-of>.sexp` golden fixture + sexp diff test | ~200 |

Each PR is independently buildable and testable: PR-A depends only on
the `Status` / `Core` libraries; PR-B depends on PR-A's parser types;
PR-C depends on PR-A only (it just calls `fetch_for_date` in a loop);
PR-D ties PR-A + PR-B + the cache together.

Submitting: `jst submit feat/data/iwv-universe-cli` reads the bookmarks
on the stack and opens four PRs, each targeting the one below it.

## 4. Files to change

PR-A (Holdings client + parser):

| Path | Action |
|---|---|
| `trading/analysis/data/sources/ishares/dune-project` | new |
| `trading/analysis/data/sources/ishares/ishares.opam` | new |
| `trading/analysis/data/sources/ishares/lib/dune` | new |
| `trading/analysis/data/sources/ishares/lib/ishares_holdings_client.ml` | new |
| `trading/analysis/data/sources/ishares/lib/ishares_holdings_client.mli` | new |
| `trading/analysis/data/sources/ishares/test/dune` | new |
| `trading/analysis/data/sources/ishares/test/test_ishares_holdings_client.ml` | new |
| `trading/analysis/data/sources/ishares/test/data/iwv_2007-12-31.csv` | new fixture (~30 KB, pinned) |
| `trading/analysis/data/sources/ishares/test/data/iwv_2010-01-29.csv` | new fixture |
| `trading/analysis/data/sources/ishares/test/data/iwv_2020-06-15.csv` | new fixture |
| `trading/analysis/data/sources/ishares/test/data/iwv_sentinel_2010-01-04.csv` | new sentinel fixture |

PR-B (Membership replay):

| Path | Action |
|---|---|
| `trading/analysis/data/sources/ishares/lib/ishares_membership_replay.ml` | new |
| `trading/analysis/data/sources/ishares/lib/ishares_membership_replay.mli` | new |
| `trading/analysis/data/sources/ishares/test/test_ishares_membership_replay.ml` | new |
| `trading/analysis/data/sources/ishares/test/data/expected_membership_subset.sexp` | new golden |

PR-C (Fetch CLI):

| Path | Action |
|---|---|
| `trading/analysis/data/sources/ishares/bin/dune` | new (or extend if PR-D lands first) |
| `trading/analysis/data/sources/ishares/bin/fetch_iwv_history.ml` | new |
| `.gitignore` | add `dev/data/ishares/` |

PR-D (Universe-builder CLI):

| Path | Action |
|---|---|
| `trading/analysis/data/sources/ishares/bin/build_iwv_universe.ml` | new |
| `trading/analysis/data/sources/ishares/bin/build_iwv_universe_lib.{ml,mli}` | new (cadence + write helpers; mirrors `wiki_sp500/bin/build_universe_lib`) |
| `trading/test_data/backtest_scenarios/universes/russell-3000-2026-05-01.sexp` | new fixture (committed; ~3000 entries) |
| `dev/status/data-foundations.md` | tick Phase 1.4 checkbox + Completed note |

## 5. Acceptance criteria

Across all four PRs:

- [ ] Every public function in `*.mli` is exported with a doc comment.
- [ ] No function exceeds 50 lines; no module exceeds 5 public functions
  without explicit justification.
- [ ] All thresholds / cadence boundaries routed through a config record
  or a CLI flag — no magic numbers in the body (the 3-snapshot threshold,
  the 9-line preamble offset, the 2 s polite-sleep default, the
  `2012-04-30` daily-cadence cutover are all named constants or flag
  defaults).
- [ ] **No Python** — verified by `find` over the touched paths and by
  the existing `no_python_check.sh` linter on CI.
- [ ] Pinned fixtures committed under `test/data/`; cache dir
  `dev/data/ishares/` gitignored.
- [ ] `dune build && dune runtest` green with zero warnings on a clean
  checkout of each PR.
- [ ] `dune build @fmt` passes.
- [ ] `dev/status/data-foundations.md` updated as part of PR-D: Phase 1.4
  ticked, Completed entry naming the four merged PRs.

PR-specific:

- **PR-A** — parser tests cover:
  - One PASS test per era fixture (quarterly 2007, monthly 2010, daily
    2020); assert `as_of`, `List.length holdings`, and a spot-check on
    one specific holding (e.g. `AAPL` price in 2020-06-15).
  - Sentinel detection: `parse sentinel_fixture` returns
    `Ok No_data_sentinel`.
  - Header drift: a synthetic input with a renamed column header
    returns `Error _`.
  - BOM stripping: input prefixed with `\xEF\xBB\xBF` parses fine.

- **PR-B** — replay tests cover:
  - 3-snapshot toy: ticker present in all three → one tenure record,
    `first_seen=snap1.as_of`, `last_seen=snap3.as_of`, `active_through=None`.
  - Confirmed removal: ticker present in snap1, absent in snaps 2-4 (3
    misses) → `active_through = Some snap1.as_of`.
  - Single-day glitch: ticker present in snaps 1, 2, 4, 5 (single miss
    at snap3) → one tenure, `active_through=None`.
  - Sector drift: ticker shows sector="Information Technology" in snap1,
    "Communication Services" in snap2 → `observed_sectors` has both, in
    order seen.
  - Non-equity filter: rows with `asset_class="Futures"` are absent
    from the output tenure list.
  - Unsorted input → `Error`.

- **PR-C** — backfill smoke test:
  - Unit test on `Build_iwv_universe_lib.cadence_dates` for the three
    era windows + the boundary days.
  - Idempotency: re-running `fetch_iwv_history.exe` with the same
    `--from / --until` against a fully-cached dir issues zero HTTP
    requests (verified by injecting a `fetch_fn` that records calls).
  - Sentinel marker handling: a `<D>.sentinel` file in the cache is
    treated as "skip this date" on resume.

- **PR-D** — end-to-end:
  - Given the three era fixtures piped in as the snapshot list,
    `build_iwv_universe.exe --as-of 2020-06-15` produces a sexp whose
    `(Pinned (...))` content matches `expected_membership_subset.sexp`.
  - Output sexp is byte-stable under repeated runs (alphabetical sort
    of symbols).

## 6. Risks / unknowns

1. **IWV vs Russell 3000 drift.** IWV tracks Russell 3000 with some
   sampling — tracking error is ~5-15 bps and the membership lists are
   *close but not identical*. We document this in the universe sexp
   header and in the tenure-CSV README. If a downstream backtest depends
   on exact Russell 3000 membership rather than IWV holdings, the user
   must source from FTSE Russell directly (not in scope for Phase 1.4;
   see Open Question #2).
2. **Cloudflare / JS challenge change.** The probe didn't hit any
   anti-bot challenge at 2 s spacing, but iShares could turn one on at
   any time. Mitigation: the historical fetch is one-time; once cached,
   we don't need to re-fetch the past. If the endpoint goes hostile,
   we freeze the historical pulls and document the failure mode. Live
   updates fall back to EODHD `IWV.US` fundamentals
   (`HistoricalTickerComponents`).
3. **Schema migration.** The 15-column header is stable 2006→2026, but
   that doesn't guarantee it stays stable post-2026. Mitigation: the
   parser fails loudly on header drift (the test ensures this), and any
   migration becomes a parser update — no replay-logic change.
4. **GICS reclassifications.** Sectors reclassify periodically (e.g.
   the 2018 GICS revision moved Facebook/Google into "Communication
   Services" from "Information Technology"). We surface this via
   `observed_sectors : string list` but pick the *first observed* sector
   for the universe sexp's per-symbol field, matching the existing
   `broad-3000-...sexp` shape. Documented limitation; downstream sector
   analysis sees one fixed label per symbol.
5. **Large fixture sizes.** Each era CSV is ~430 KB. Four committed
   fixtures = ~1.7 MB. That's larger than the wiki_sp500 fixtures (~70 KB
   each) but still well under the 100 MB GitHub soft limit. If review
   pushes back, we can truncate each fixture to ~100 rows preserving
   the header + sentinel cases. The PASS test then asserts a *lower
   bound* on `List.length holdings` (e.g. ≥ 90) rather than the full
   ~2,900.
6. **Vendor-license posture.** iShares' Terms of Use don't explicitly
   permit redistribution of holdings CSVs. We cache locally
   (gitignored), commit truncated samples only as test fixtures, and
   document this in the per-source README. Same posture as the EODHD
   cache. If counsel pushes back, fixture truncation in §5 keeps the
   committed bytes within fair-use territory.
7. **Backfill runtime.** ~3 hours one-time is acceptable for the user
   but not for a CI job. The fetch CLI is local-only; CI never invokes
   it. Tests only ever use the pinned fixtures.

## 7. Open questions for the user

Three knobs we want the user's explicit answer on before PR-D:

1. **Daily vs weekly granularity for 2012+ era.** Daily is the natural
   cadence iShares serves. Weinstein's strategy operates on weekly bars
   (Friday close per `docs/design/weinstein-book-reference.md` §Time
   Frame). Two options:
   - (a) Keep daily snapshots in the cache and replay them all (~3,500
     snapshots, ~1.3 GB raw on disk after compression). Tenure
     resolution is daily — accurate to the day of removal.
   - (b) Downsample to Fridays only (~720 snapshots in the daily era).
     Tenure resolution is weekly — accurate to the week of removal.
     ~5× smaller cache, ~5× faster backfill.
   **Recommendation:** (b) weekly. The strategy doesn't act mid-week;
   day-level membership precision is wasted. `Daily_price.active_through`
   already carries day-level delisting precision when needed.
2. **IWV ≠ Russell 3000 — material divergence?** IWV is a sampled
   replicator. We should document the divergence in the sexp header,
   but the user may want a sharper number (e.g. "drift averages X
   tickers per year") before relying on it. Two options:
   - (a) Ship with a qualitative note ("IWV tracks but does not equal
     Russell 3000; tracking error ~5-15 bps").
   - (b) One-time quantitative cross-check against an external source
     (e.g. FTSE Russell's PDF reconstitution lists for one or two
     years) and document the per-year delta.
   **Recommendation:** (a) for the initial ship. (b) is a follow-up
   if a downstream backtest is sensitive to it.
3. **Picker compatibility with PR #1103.** PR #1103's
   `pick_broad_3000.exe` does alphabetical sort + top-N from
   `sectors.csv`. Two options for `build_iwv_universe.exe`:
   - (a) **Full membership** — emit every PI member on `as_of`
     (typically ~2,900–3,000 tickers).
   - (b) **Top-N picker** — sort alphabetically, take top N (default
     N=3,000), to maximize 1-to-1 compatibility with the existing
     `broad-3000-2010-01-01.sexp` fixture's bytes.
   **Recommendation:** (a) full membership. PR #1103's alpha-top-N is
   a workaround we needed because sectors.csv had no PI signal; with
   true PI membership we should ship the membership. Add a
   `--limit-top-n N` flag for cases where someone wants the legacy
   shape.

## 8. Out of scope

- Sibling ETFs (IWB / Russell 1000, IWM / Russell 2000). The URL
  pattern is the same with different product IDs (see
  `dev/status/data-foundations.md` §Track 1). A follow-up plan
  generalizes the client to take a `product_id`; this plan ships IWV
  only.
- Live OCaml port of mid-session refreshes. The fetch CLI is local
  manual operation; we do not auto-refresh in CI or via cron in this
  plan.
- Pre-2006-09 data. iShares does not serve it; the gap is acknowledged
  and explicitly deferred to either (a) the optional fja05680 1996–1999
  tail (SP500 only — does not cover Russell 3000), or (b) a future
  vendor signup (Sharadar / institutional).
- IWV-vs-Russell-3000 quantitative drift report — see Open Question #2.
- GICS-reclassification reconstruction. We record observed sectors per
  ticker but do not track *when* each reclassification happened
  point-in-time.
- Schema migration tooling. If iShares changes column shape post-2026,
  the parser will fail loudly and we'll update it then — no proactive
  versioning.

## 9. References

- `dev/notes/phase1.4-iwv-url-probe-2026-05-16.md` — URL probe results.
- `dev/notes/vendor-comparison-historical-universe-2026-05-16.md` §Option 7.
- `dev/notes/next-session-priorities-2026-05-16.md` §Phase 1.4.
- `dev/plans/wiki-eodhd-historical-universe-2026-05-03.md` — sibling
  plan whose module layout we mirror.
- `dev/status/data-foundations.md` §Track 1 — current track scope.
- `trading/analysis/data/sources/wiki_sp500/` — canonical analog
  (parser + replay + bin CLI; PRs #803/#808/#809/#813).
- `trading/analysis/data/sources/eodhd/lib/http_client.{ml,mli}` —
  `default_fetch` / `fetch_fn` pattern we re-use.
- `trading/analysis/data/types/lib/daily_price.mli` —
  `active_through` semantics we mirror.
- `trading/test_data/backtest_scenarios/universes/broad-3000-2010-01-01.sexp`
  — target sexp shape.
- `.claude/rules/no-python.md` — repo posture.
- `.claude/rules/qc-structural-authority.md` §A2 — module-boundary rule
  this plan respects (no writes into `trading/trading/`).
