# M6 — Weekly Snapshot as Verification Harness

Date: 2026-05-02 — replaces the original monolithic M6 ("Full Automated Cycle") with a verification-first decomposition.

Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M6.1–M6.6 (added 2026-05-02).

## Context

Original M6 was *"set up cron, generate weekly scan, send alerts, render Saturday report"* — i.e. live trading. We are not ready for live trading. The libraries that would power it (M1–M4) all exist but no live shell has been built.

Reframe: **the weekly cycle becomes a verification harness first, a live trading system second.** We can run the same pipeline incrementally over historical data (week by week) and produce *durable, diffable, version-tagged* pick artifacts. These artifacts:

- prove the screener is stable (small input changes don't churn picks chaotically)
- expose split/dividend handling regressions deterministically
- enable cross-version A/B at the pick level (not just aggregate metrics)
- give us a forward-trace ledger ("if we'd taken this pick on this date, here's what happened")
- produce the same report shape that would eventually power M6.6 cron

So M6.1–M6.5 ship as a verification subsystem. M6.6 (true live cycle) is a wiring layer on top, deferred.

## Why this matters now

The G14 split-adjustment surface and the post-split-exit CI failure (`split_day_stop_exit:1:post_split_exit_no_orphan_equity`, run [25238889053](https://github.com/dayfine/trading/actions/runs/25238889053)) prove that aggregate-metric backtests can hide structural bugs that would surface immediately on a per-week pick artifact. A weekly snapshot-driven flow makes these bugs catastrophically easier to spot:

- pick-set stability: did the same Friday's pick set change unexpectedly between system versions?
- split round-trip: did a known split (AAPL 4:1, 2020-08-31) cause a phantom pick churn?
- forward-trace: did the system pick a stock that subsequently went to zero, and was the stop honored?

## M6.1 — Weekly snapshot generator

### Goal

At each Friday close (in a backtest, "each simulated Friday"), write a durable pick artifact containing:

- ranked candidate list (long + short)
- per-candidate score, rationale, suggested entry, suggested stop, sector
- macro regime context
- snapshot of held positions + their stops
- system version tag (commit SHA)

### Format

`dev/weekly-picks/<system-version>/<date>.sexp`

Example:
```sexp
((system_version "c93bf39d")
 (date 2020-08-28)
 (macro ((regime Bullish) (score 0.72) (indicators ...)))
 (sectors_strong (XLK XLY XLC))
 (sectors_weak (XLE XLU))
 (long_candidates
   (((symbol AAPL) (score 0.91) (grade A+)
     (entry 502.13) (stop 466.20) (sector XLK)
     (rationale "Stage2 breakout above 30wk MA, 2.1x volume confirmation")
     (rs_vs_spy 1.34) (resistance_grade A))
    ((symbol MSFT) (score 0.87) ...)
    ...))
 (short_candidates (...))
 (held_positions
   (((symbol GOOG) (entered 2020-06-19) (stop 1365.00) (status Holding))
    ...)))
```

### Implementation

New: `trading/trading/weinstein/snapshot/lib/{weekly_snapshot,snapshot_writer}.{ml,mli}`

Wires existing screener output into a sexp serializer. No new analysis logic — `Screener.scan` already produces the data; we just persist it durably with a stable schema.

For backtest mode: extend `Simulator.step` to call `Snapshot_writer.persist` on every Friday close (gated by `--write-snapshots <dir>` flag).

For live mode (M6.6): same call site after live `DATA_SOURCE` returns Friday's bars.

### Acceptance

- Running a backtest with `--write-snapshots dev/weekly-picks/<version>/` produces one `.sexp` per Friday in the simulation window
- Schema versioned: every snapshot file starts with `(schema_version 1)` so future format evolution is forward-compatible
- File names sortable: `YYYY-MM-DD.sexp` lexicographically orders by date
- Round-trip stable: `Snapshot_reader.parse |> Snapshot_writer.serialize` is identity
- Adding a single bar to one symbol changes that snapshot's pick scores deterministically; all other Fridays unchanged

### Files to touch

- `trading/trading/weinstein/snapshot/lib/weekly_snapshot.{ml,mli}` (new) — types
- `trading/trading/weinstein/snapshot/lib/snapshot_writer.{ml,mli}` (new) — serializer
- `trading/trading/weinstein/snapshot/lib/snapshot_reader.{ml,mli}` (new) — parser
- `trading/trading/weinstein/snapshot/test/test_round_trip.ml` (new)
- `trading/trading/simulation/lib/simulator.ml` — Friday call-site (gated by config)
- `trading/trading/backtest/bin/backtest_runner.ml` — `--write-snapshots <dir>` flag

## M6.2 — Forward-trace renderer

### Goal

Given a pick file and the bars that followed, produce a per-pick outcome report. Pure function — no strategy execution needed. Lets us answer "would these picks have worked?" without re-running the full simulator.

### Contract

```ocaml
val trace_picks :
  picks:Weekly_snapshot.t ->
  bars:Daily_price.t list String.Map.t ->
  horizon_days:int ->
  Forward_trace.t
```

`Forward_trace.t` per-pick:

```sexp
((symbol AAPL) (pick_date 2020-08-28) (suggested_entry 502.13) (suggested_stop 466.20)
 (entry_filled_at 502.13) (entry_filled_date 2020-08-31)
 (max_favorable 565.00) (max_adverse 491.00)
 (final_price 525.00) (final_date 2020-09-25)
 (pct_return_horizon 4.55%)
 (stop_triggered no)
 (max_drawdown_within_horizon -2.21%)
 (winner true))
```

Aggregated:
```sexp
((horizon_days 20)
 (total_picks 12)
 (winners 8) (losers 3) (stopped_out 1)
 (avg_return_pct 3.15%)
 (avg_winner_return 7.20%) (avg_loser_return -2.80%)
 (best_pick AAPL) (worst_pick XOM))
```

### Implementation

New: `trading/trading/weinstein/snapshot/lib/forward_trace.{ml,mli}`

Pure function over (pick file, bars, horizon). Uses adjusted_close where available (for split safety). Reads bars via `Market_data_adapter` (same path as simulator).

### Acceptance

- Round-trip on a known historical pick (AAPL 2020-08-28 entry, +1% in 20 days): pinned values
- Stop-trigger detection: synthetic pick with stop = $400 on a bar with low = $399 → stopped_out=yes
- Split-day round-trip: AAPL 4:1 split between pick date and horizon end → entry/exit prices both adjusted, no phantom 4× return
- Full horizon report renders to markdown via existing `release_perf_report` pattern

### Files to touch

- `trading/trading/weinstein/snapshot/lib/forward_trace.{ml,mli}` (new)
- `trading/trading/weinstein/snapshot/test/test_forward_trace.ml` (new) — known-historical fixtures
- `trading/trading/weinstein/snapshot/bin/trace_picks.ml` (new) — CLI: `trace_picks <pick-file> <bars-dir> --horizon 20`

## M6.3 — Cross-version pick diff

### Goal

Compare pick sets across system versions on the same date. Catches silent screener drift.

### Contract

```ocaml
val diff_pick_sets :
  v1:Weekly_snapshot.t ->
  v2:Weekly_snapshot.t ->
  Pick_diff.t
```

Output:
```sexp
((date 2020-08-28)
 (v1_version "c93bf39d") (v2_version "deadbeef")
 (added_in_v2 (NVDA AMZN))
 (removed_in_v2 (XOM CVX))
 (score_changes
   (((symbol AAPL) (v1_score 0.91) (v2_score 0.88) (delta -0.03))
    ((symbol MSFT) (v1_score 0.87) (v2_score 0.92) (delta +0.05))))
 (rank_changes
   (((symbol AAPL) (v1_rank 1) (v2_rank 3))
    ((symbol MSFT) (v1_rank 2) (v2_rank 1))))
 (macro_change ((v1 Bullish) (v2 Bullish))))
```

### Implementation

New: `trading/trading/weinstein/snapshot/lib/pick_diff.{ml,mli}`

Simple set/map operations on parsed snapshot files. CLI tool `diff_picks <v1.sexp> <v2.sexp>`.

### Acceptance

- Identical files → empty diff
- Adding one symbol to v2 → `added_in_v2 = [sym]`; everything else equal
- Score change → reported with delta
- Rank-only changes (same set, different order) → `rank_changes` populated, `added/removed` empty

## M6.4 — Split/dividend verification harness

### Goal

The verification idea you described: deterministically catch G14-class regressions by replaying *known* historical corporate actions and asserting round-trip correctness.

### Replay scenarios (seed set)

| Symbol | Date | Action | Why |
|---|---|---|---|
| AAPL | 2020-08-31 | 4:1 forward split | Most-traded large-cap split in recent memory; canonical reference |
| TSLA | 2020-08-31 | 5:1 forward split | Same day as AAPL — tests two simultaneous splits in one universe |
| GOOG | 2022-07-18 | 20:1 forward split | Large factor, tests numerical robustness |
| NVDA | 2024-06-10 | 10:1 forward split | Recent, easily verified against external sources |
| KO | 2024 (recurring quarterly dividends) | Cash dividend ~$0.485 | Tests dividend cash injection without quantity change |
| JNJ | 2023-08 | KVUE spinoff | Spinoff = quantity change with cost-basis split. Stretch goal. |

### Data source

EODHD endpoints already paid for:
- `/splits/{symbol}.{exchange}` — split factor + ex-date
- `/div/{symbol}.{exchange}` — cash dividend + ex-date
- EOD bars `adjusted_close` field — ground truth for verification

Zero added data spend.

### Test contract

For each scenario:

```ocaml
val verify_split_round_trip :
  symbol:string ->
  split_date:Date.t ->
  factor:float ->
  bars:Daily_price.t list ->
  pick_pre_split:Weekly_snapshot.t ->
  pick_post_split:Weekly_snapshot.t ->
  Round_trip_result.t
```

Assertions:
1. `bars[date < split_date].adjusted_close × factor ≈ bars[date < split_date].close_price` after applying split
2. Strategy held position from pre-split snapshot still appears in post-split snapshot, with `quantity_post = quantity_pre × factor` and `entry_price_post = entry_price_pre / factor`
3. Total cost basis preserved: `quantity_pre × entry_price_pre = quantity_post × entry_price_post`
4. No phantom new pick appearing solely because of the split (ranking drift purely from split-induced numerics)
5. Stop-loss adjusted: `stop_post = stop_pre / factor`
6. For cash dividends: `cash_post = cash_pre + (quantity × div_per_share)`; quantity unchanged

### Implementation

New: `trading/trading/weinstein/snapshot/test/test_split_replay.ml`

Fixtures: `trading/trading/weinstein/snapshot/test/fixtures/{aapl-2020-split,tsla-2020-split,goog-2022-split,nvda-2024-split,ko-2024-divs}/` with bars + expected snapshots.

CLI tool: `verify_corporate_actions <fixture-dir>`. Runs all scenarios, reports pass/fail per scenario.

### Acceptance

- All 5 scenarios green
- Adding a 6th scenario is a 30-minute task (fixture generation is the bulk of work)
- Failure messages name the specific assertion violated + diff against expected snapshot
- Wired into `dune runtest` so CI catches regressions automatically

### Files to touch

- `analysis/data/sources/eodhd/lib/{splits_endpoint,dividends_endpoint}.{ml,mli}` (new) — wire two endpoints
- `trading/trading/weinstein/snapshot/lib/round_trip_verifier.{ml,mli}` (new)
- `trading/trading/weinstein/snapshot/test/test_split_replay.ml` (new)
- `trading/trading/weinstein/snapshot/test/fixtures/<scenario>/` (new) × 5

## M6.5 — Weekly report renderer

### Goal

Markdown report from a single pick file. Same shape as the eventual M6.6 live report, just driven by historical data.

### Output (rendered from `2020-08-28.sexp`)

```markdown
# Weekly Pick Report — 2020-08-28

System version: `c93bf39d` (Score_picked filler PR-4)

## Macro
**Bullish** (score 0.72) — A/D line rising, S&P > 30wk MA, sector breadth strong

## Strong sectors
- XLK (Technology) — RS 1.18
- XLY (Consumer Discretionary) — RS 1.12
- XLC (Communication Services) — RS 1.07

## Long candidates (top 10)

| Rank | Symbol | Grade | Score | Entry | Stop | Risk % | Rationale |
|---|---|---|---|---|---|---|---|
| 1 | AAPL | A+ | 0.91 | $502.13 | $466.20 | 7.2% | Stage 2 breakout, 2.1× volume |
| 2 | MSFT | A  | 0.87 | $215.50 | $200.10 | 7.1% | Continuation breakout |
| ... |

## Short candidates (top 5)
...

## Held positions

| Symbol | Entry | Days held | Current | Stop | P&L | Status |
|---|---|---|---|---|---|---|
| GOOG | 2020-06-19 ($1432.40) | 50 | $1502.10 | $1365.00 | +4.86% | Holding |
| ... |
```

### Implementation

New: `trading/trading/weinstein/snapshot/lib/report_renderer.{ml,mli}`

Pure function `Weekly_snapshot.t -> string` (markdown). No I/O.

CLI: `render_weekly_report <pick-file>` → stdout. Used by both backtest historical replay and (future) M6.6 live cron.

### Acceptance

- Round-trip stable: same input → identical output (deterministic)
- Renders all sections even with empty data (no candidates, no held positions)
- Schema-version-aware: rejects unknown schema versions with a clear error

## M6.6 — True live cycle (DEFERRED)

Out of scope for the verification phase. To unblock:

- Live `DATA_SOURCE` impl pulling EODHD on demand (not from CSV cache)
- Cron wrapper triggering Friday-close + daily-stop-monitor runs
- Alert dispatch (email + a webhook target)
- Trade-log persistence across runs
- Trading state durability (positions, stops, history) survives process restart

This is wiring on top of M6.1–M6.5; libraries already exist. Estimated effort ~5 sessions once verification phase is solid.

## Files to touch (rollup)

| Phase | New module path |
|---|---|
| M6.1 | `weinstein/snapshot/lib/{weekly_snapshot,snapshot_writer,snapshot_reader}` |
| M6.2 | `weinstein/snapshot/lib/forward_trace`, `weinstein/snapshot/bin/trace_picks` |
| M6.3 | `weinstein/snapshot/lib/pick_diff`, `weinstein/snapshot/bin/diff_picks` |
| M6.4 | `weinstein/snapshot/lib/round_trip_verifier`, `weinstein/snapshot/test/test_split_replay`, `analysis/data/sources/eodhd/lib/{splits,dividends}_endpoint` |
| M6.5 | `weinstein/snapshot/lib/report_renderer`, `weinstein/snapshot/bin/render_weekly_report` |

## Dependencies

```
M6.1 (snapshot writer) ──→ M6.2 (forward trace)
                       ──→ M6.3 (pick diff)
                       ──→ M6.5 (report renderer)
                       ──→ M6.4 (split/div replay — uses snapshot format as fixture)

M6.4 also depends on EODHD splits + dividends endpoints (new wiring)
```

M6 work can run **in parallel with M5.2 experiment infra** — they share no source files. M6.1 should follow M5.1 (foundation hardening) since the post-split-exit CI failure is the very thing M6.4 would catch deterministically.

## Risks / unknowns

- **Snapshot schema bloat.** Every screener change risks bloating the snapshot format. Mitigate: `schema_version` field + explicit migration tests when bumping.
- **Snapshot file size.** ~500 candidates × 100 fields each ≈ 50 KB per Friday × 52 weeks × 30 years = ~80 MB. Acceptable. Compress with `.sexp.gz` if it grows.
- **Cross-version diff requires both versions to share schema.** Bumping schema forces re-emitting v1 snapshots in v2 schema before diffing. Build a `migrate_snapshot_v1_to_v2` utility when the time comes.
- **Forward-trace adjusted_close dependency.** If adjusted_close is wrong in source data, forward-trace silently corrupts. Mitigate: M6.4 verifies adjusted_close round-trip before forward-trace runs.
- **EODHD splits/divs endpoint reliability.** Unverified for our specific historical scenarios (AAPL 2020 etc). First M6.4 PR includes a one-off audit pass against external references (Yahoo Finance, Wikipedia ex-date).

## Acceptance for M6 verification phase

- M6.1 snapshot generator green; sp500-2019-2023 backtest produces ~250 weekly snapshots
- M6.2 forward-trace renders horizon outcomes for all picks; sample report human-readable
- M6.3 cross-version diff between two arbitrary main commits produces interpretable output
- M6.4 all 5 corporate-action replay scenarios green; CI gates further G14-class regressions
- M6.5 weekly report shape signed off by user as "this is what I'd want to read on Saturday morning"

## Out of scope

- Live data wiring (M6.6)
- Alert dispatch / cron / webhook delivery (M6.6)
- Trading-state persistence across process restart (M6.6)
- Mid-week stop monitor (M6.6)
- Real-time intraday updates (we trade weekly; no need)
