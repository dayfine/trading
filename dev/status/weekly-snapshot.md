# Status: weekly-snapshot

## Last updated: 2026-06-14

## Status
IN_PROGRESS

(Owner: feat-weinstein per #778 scope expansion.)

**2026-06-14 (M6.6 generator):** `generate_weekly_snapshot` bin SHIPPED via
PR (`feat/weekly-snapshot-generator`). The missing producer is built: a new
`weinstein_trading.snapshot_gen` lib (`Weekly_snapshot_generator.generate`)
runs the existing screener cascade (`Macro.analyze` → `Sector.analyze` →
`Stock_analysis.analyze` → `Screener.screen`) on cached bars for one as-of date
and assembles a `Weekly_snapshot.t`; the CLI bin loads a Pinned universe + CSV
bars, builds a `Bar_reader`, and `Snapshot_writer.write_to_file`s it to
`dev/weekly-picks/<system-version>/<date>.sexp`. No strategy logic
reimplemented — pure wiring of existing public primitives; no core-module
changes. Remaining M6.6 (live DATA_SOURCE / cron / alerts / trading-state) stays
deferred.

**2026-06-14 rework (PR #1588):** CI `build-and-test` tripped the repo nesting
linter (a full-runtest target the scoped `dune runtest` skipped) on three
helpers in `weekly_snapshot_generator.ml`. Fixed by extracting the innermost
nested blocks into named private `_helper`s (`_set_sector_ctx_for_etf`,
`_analyze_ticker`, `_etf_rating` + `_sector_name_if_rated`) — pure structural
refactor, no behavior change; full `dune runtest` now passes including the
nesting linter.

**2026-06-14 test follow-up (PR #1596, `feat/weekly-snapshot-generator`):**
test-only follow-up to #1588 closing two gaps vs the M6.6 brief: (a) added the
**C2 macro-gate pin** — `test_bearish_macro_blocks_longs` uses a `Declining`
synthetic index so the macro gate reads `Bearish` and asserts zero long
candidates (the merged suite had no bearish fixture); (b) fixed three P6
`equal_to true` matchers wrapping boolean predicates (entry>0, stop<entry,
regime-known) to use real matchers (`gt`, an `(entry - stop)` projection,
`matching` over the closed label set). 7 tests pass; no lib/bin change.

Track created 2026-05-02 to absorb M6.1–M6.5 (verification harness via incremental processing). Plan: `dev/plans/m6-weekly-snapshot-verification-2026-05-02.md`. Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M6.1–M6.5 (added 2026-05-02).

**2026-06-14 reconcile (orchestrator):** M6.1–M6.5 are SHIPPED on main —
`trading/trading/weinstein/snapshot/lib/{weekly_snapshot,snapshot_writer,snapshot_reader,forward_trace,pick_diff,report_renderer,round_trip_verifier}.{ml,mli}`
plus bins `trace_picks`, `diff_picks`, `render_weekly_report`,
`verify_corporate_actions`. The remaining gap is **M6.6**: there is no
*generator* that runs the screener+strategy on cached data, builds a
`Weekly_snapshot.t`, and writes it to `dev/weekly-picks/<version>/<date>.sexp`
(the dir does not yet exist). The consumers (trace/diff/render) all read an
existing pick file; nothing produces one. The concrete next step is a small
`generate_weekly_snapshot` bin (`--as-of/--universe/--bars/--snapshot-dir`).
See `dev/notes/next-session-priorities-2026-06-14.md` §3. **M6.6 is DEFERRED
pending a human scope green-light** (the live-cycle scheduling decision is an
open Question to the maintainer — carried in the daily summary).

## Interface stable
NO

M6.1–M6.5 interfaces (`Weekly_snapshot.t`, writer/reader, forward-trace,
pick-diff, report-renderer) are merged and stable; the remaining M6.6
`generate_weekly_snapshot` generator interface is not yet built, so the
track interface is not fully stable.

The reframe: **weekly picks are first-class durable artifacts before they're inputs to live trading.** This subsystem is a verification harness first; the M6.6 live cycle is wiring on top.

## Blocked on
- None. Prior M5.1 blocker (`split_day_stop_exit:1:post_split_exit_no_orphan_equity`) was RESOLVED by PR #752. Track is owner-pending: feat-weinstein not currently dispatched on M6.x items.

## Scope

### M6.1 — Weekly snapshot generator

`trading/trading/weinstein/snapshot/lib/{weekly_snapshot,snapshot_writer,snapshot_reader}.{ml,mli}` (new). Format: `dev/weekly-picks/<system-version>/<date>.sexp` containing macro context, sector strength, ranked candidates with score/grade/entry/stop/rationale, held positions. Schema-versioned. Round-trip stable.

Wired into `Simulator.step` via gated `--write-snapshots <dir>` flag.

### M6.2 — Forward-trace renderer

`trading/trading/weinstein/snapshot/lib/forward_trace.{ml,mli}` (new). Pure function `(picks, bars, horizon_days) → per-pick outcome`. Reports max favorable, max adverse, final price, stop-trigger, winner/loser. Uses adjusted_close.

CLI: `trace_picks <pick-file> <bars-dir> --horizon 20`.

### M6.3 — Cross-version pick diff

`trading/trading/weinstein/snapshot/lib/pick_diff.{ml,mli}` (new). Set/map operations on parsed snapshots. Reports `added_in_v2`, `removed_in_v2`, score deltas, rank changes, macro_change.

CLI: `diff_picks <v1.sexp> <v2.sexp>`.

### M6.4 — Split/dividend verification harness

EODHD `/splits` + `/div` endpoints (new wiring; data already in plan). Replay 5 known scenarios:

| Symbol | Date | Action |
|---|---|---|
| AAPL | 2020-08-31 | 4:1 forward split |
| TSLA | 2020-08-31 | 5:1 forward split |
| GOOG | 2022-07-18 | 20:1 forward split |
| NVDA | 2024-06-10 | 10:1 forward split |
| KO | 2024 | quarterly cash dividend |

Assertions: adjusted_close round-trip, position quantity post-split, total cost basis preserved, no phantom pick churn, stop-loss adjusted, dividend cash injected for KO.

Wired into `dune runtest` so CI catches G14-class regressions automatically.

### M6.5 — Weekly report renderer

`trading/trading/weinstein/snapshot/lib/report_renderer.{ml,mli}` (new). Pure `Weekly_snapshot.t → string` (markdown). Same shape as eventual M6.6 live report.

CLI: `render_weekly_report <pick-file>` → stdout.

### M6.6 — DEFERRED

Live `DATA_SOURCE` impl, cron wrapper, alert dispatch, trading-state durability. ~5 sessions once verification phase is solid.

## In Progress
- None.

## Next Steps

M6.1–M6.5 are SHIPPED (see the 2026-06-14 reconcile above). M6.6's generator is
now also SHIPPED (`generate_weekly_snapshot` bin +
`weinstein_trading.snapshot_gen` lib, PR `feat/weekly-snapshot-generator`). The
remaining queue:

1. **[M6.6, DONE]** ~~`generate_weekly_snapshot` bin~~ — SHIPPED 2026-06-14.
   Runs the existing screener cascade on cached data, assembles
   `Weekly_snapshot.t`, and `Snapshot_writer.write_to_file`s it to
   `dev/weekly-picks/<version>/<date>.sexp`.
2. **[M6.6, optional]** generate + commit a first baseline pick record to diff
   future weeks against (the stretch item; deferred — needs a committed
   universe + cached bars to run against, not done in the generator PR).
3. **[M6.6, deferred]** live `DATA_SOURCE` impl, cron wrapper, alert dispatch,
   trading-state durability (see §Out of scope).

## Parallelism
M6 work runs in parallel with `experiments` track M5.2 — no shared source files.

## Out of scope

- Live data wiring (M6.6).
- Cron / alert dispatch / webhook delivery (M6.6).
- Trading-state persistence across process restart (M6.6).
- Mid-week stop monitor (M6.6).
- Real-time intraday updates — we trade weekly.
