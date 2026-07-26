# Status: weekly-snapshot

## Last updated: 2026-07-26

## Status
IN_PROGRESS

**QC (PR #2097, mirrored by the orchestrator — the QC agents were fenced
read-only on a shared working tree and could not write here):**
`structural_qc: APPROVED` (5/5) and `behavioral_qc: APPROVED` (4/5), both at
tip `5454d9f1`; `overall_qc: APPROVED`. One rework iteration: at base tip
`ad11fb7f` behavioral returned NEEDS_REWORK (3/5) on a CP4 gap — short-side
spike flagging at `weekly_snapshot_generator.ml:220` was claimed in the `.mli`,
the PR body and this file but pinned by nothing, and the mutation
`(shorts, [])` left the whole suite green. Closed by
`test_armed_spike_flags_short_candidate_and_warns` at the `generate` seam.
Merged `089116bc` with all three gates green. Full verdicts are PR review
comments on #2097; audit record `dev/audit/2026-07-26-weekly-snapshot.json`.
One non-blocking nit carried: the *flagged* candidate's own
rank/entry/stop/sizing invariance holds by construction
(`{ c with data_suspect = true }`) but is not pinned at the seam.

**2026-07-26 (spike-bar "data-suspect" flag, issue #2083 Finding 3, PR #2097
`feat/weekly-snapshot-spike-flag`):** Closes the last of the three 07-17
report-review findings. F1 (sparse-tail gate) and F2 (rename tracking, still
unbuilt) attack the data source; F3 is the **report-hygiene backstop**: even
when a spike bar is genuine and the ticker alive, a candidate whose signal
rests on a single outsized bar gets a visible caveat on the ticket. New module
`Weinstein_snapshot_gen.Spike_bar_gate`
(`trading/trading/weinstein/snapshot/gen/lib/spike_bar_gate.{ml,mli}`, mirrors
the sibling `Sparse_tail_gate` shape): `check` compares the last daily bar
at/before `as_of` against the prior **resident** bar's close (on a zombie feed
that is not the prior trading day — that is the point) and reports the
**absolute** percentage move; `>= threshold_pct` -> `Data_suspect { move_pct;
threshold_pct; bar_date }`.

**Flag, do not drop** (unlike F1): the candidate keeps its rank, entry, stop
and size. `Weekly_snapshot.candidate` gains an additive `data_suspect : bool
[@sexp.default false]` (the `stop_is_structural` precedent from #2091);
`Report_renderer` marks the Symbol cell `TEST (!)` plus an explanatory footnote
(same treatment as the fallback-stop asterisk); a warning line stating the
candidate was **kept** is appended to `Weekly_snapshot.t.warnings`. Wired into
`Weekly_snapshot_generator` beside the `_sparse_tail_*` helpers, applied to
long AND short candidates (`generate`'s candidate assembly was extracted into
`_build_candidates` to stay inside the function-length cap).

Default-off per `experiment-flag-discipline.md` R1/R2: one new field
`spike_bar_threshold_pct : float [@sexp.default 0.0]` on
`Weinstein_strategy_config.config`; `<= 0.0` disables (same convention as
`sparse_tail_window_trading_days = 0`), so an unarmed run is bit-identical.
Real config field -> resolves through `Overlay_validator.apply_overrides` and
is expressible as a `Variant_matrix` axis. **Default NOT flipped and NOT armed
in `live-config-overrides.sexp`** — that needs a ledger ACCEPT (R3).
Engineering data-hygiene flag, **not** a Weinstein book rule: no
`weinstein-book-reference.md` section is cited (none supports it) and the spine
is untouched — no change to stage classification, the Stage-2-only buy rule,
volume confirmation, entry, stop or sizing.

Code health (same PR, second commit): the new wiring pushed
`weekly_snapshot_generator.ml` past the 300-line file-length limit. Fixed by
**extraction**, not a limit bump or an `@large-module` marker
(`.claude/rules/code-health-discipline.md`): each #2083 gate module now owns
both halves of its own semantics — `Spike_bar_gate.flag_candidates` (flag a
candidate list) and `Sparse_tail_gate.partition` (split tickers into eligible +
warnings, a pure code move) — and the held-book enrichment moved verbatim into
a new `Held_position_row` module (`enrich` / `long_market_value`; it concerns
the held book, not the screener cascade). Generator 299 -> 261 lines, so the
file has real headroom again. No behaviour change in either move; all
dune-wired linters green (file-length, nesting, fn-length, mli-coverage,
magic-numbers, fmt).

Tests: `test_spike_bar_gate.ml` (12 unit tests — disabled/negative no-op, +58%
SNSE-shaped spike, quiet bar, downward spike reporting the absolute move,
inclusive threshold boundary, gapped series comparing the prior *resident* bar,
<2 bars, no bars, zero prior close, both `warning` branches); 6 new
generator-level tests pinned at the **`generate` seam** (default-config
disabled; disabled run bit-identical on a spiked fixture; armed+spike flags AND
keeps the candidate + warns; armed on a quiet dense fixture stays clean; the
**short**-side flag+keep+warn on a spiked `SHRT` fixture; and a two-candidate
list where only one spikes, pinning same-length/same-order plus the non-spiking
row byte-identical to its disabled-run self); 2 renderer tests (marker +
footnote present / absent); `test_round_trip` pins the additive-field
back-compat default. Six mutations run, each turning **exactly one** new test
red: (A) long call site bypassed, (B) `~threshold_pct:0.0`, (C) drop instead of
flag, (D) `_symbol_cell` marker removed, (E) footnote legend removed, (F) the
SHORT call site bypassed (`let shorts, short_warnings = (shorts, [])`) — (F)
fails only the new short-side seam test (QC rework 1). `dune build @fmt` + `dune build` exit 0. Full `dune runtest` exits 1
ONLY on the pre-existing `Tuner.Bayesian_opt` LAPACKE GP-Cholesky failures
(`Failure("LAPACKE: 9")` in `bayesian_opt_cholesky.ml`; maintainer-owned fix PR
#2009, stalled since 07-19) — unrelated to this diff, which touches no tuner
code. Every weinstein/snapshot test and every dune-wired linter is green.

**2026-07-26 (structural stop for weekly-pick candidates, issue #2084 Finding
2, PR `feat/screener-structural-stop`):** Fixes the second finding from the
same 07-17 report review: the displayed AND live-instructed stop for a
candidate pick (e.g. rank-1 FTH, `$33.98`) was `entry * (1 - 8%)` — a flat
percentage divorced from chart structure, unlike the backtest's actual entry
stop (which already derives a real support floor via
`Weinstein_stops.compute_initial_stop_with_floor`). Since PR #2078 wired the
sized instruction line ("on fill place SELL STOP @ $<stop>"), this was also a
live/sim divergence: the same symbol's backtest entry installs a structural
stop while the live instruction told the trader to place the naive one; sizing
was also wrong (always assumed an 8% stop distance).

New module `Weinstein_snapshot_gen.Stop_recompute`
(`trading/trading/weinstein/snapshot/gen/lib/stop_recompute.{ml,mli}`)
consolidates two call sites that both wrap `compute_initial_stop_with_floor`:
`for_candidate` (new — overlays the real structural stop onto a screener
candidate before sizing/display) and `for_held_long` (moved out of
`weekly_snapshot_generator.ml` verbatim — pre-existing held-position
"recommended stop" logic, unchanged behavior). `Weekly_snapshot.candidate`
gains an additive `stop_is_structural : bool [@sexp.default false]` field;
`Report_renderer` marks a fallback (non-structural) stop with a trailing `*`
plus an explanatory footnote so a reader can tell the two apart without
cross-referencing the chart.

Deliberately does **not** touch `Screener.scored_candidate.suggested_stop`,
`screener_scoring.ml`, or `screener.ml` — the pure cascade library has no
daily-bar access, and its `suggested_stop` value still feeds
`trading/backtest/optimal/lib/stage_transition_scanner.ml` (the
optimal-strategy counterfactual tool) unchanged; that tool's own tests
(`test_stage_transition_scanner.ml`, pinning `suggested_stop = 92.46` under
the flat-8% formula) still pass untouched, confirming no backtest/golden path
was moved. Per `.claude/rules/experiment-flag-discipline.md`, this landed
**on by default** (no new config field) — see
`dev/plans/screener-structural-stop-2026-07-26.md` for the empirical
default-branch check (grepped every `suggested_stop` / candidate-stop
consumer; ran full `dune runtest` before/after). This is a
display/instruction-path correctness fix restoring
`.claude/rules/weinstein-faithful-core.md` spine item 5 to the live path, not
a new strategy mechanism.

Tests: `test_weekly_snapshot_generator` (fallback stop differs from the
screener's raw flat-8% proxy — proves the overlay ran; sizing keys off the
post-overlay stop distance — proves overlay-before-sizing ordering) and
`test_report_renderer` (fallback stop renders `*` + footnote; structural stop
renders neither). Every new assertion mutation-tested (overlay call removed,
overlay/sizing pipe order swapped, `is_structural` forced `true`, stop-cell /
footnote logic stubbed) and confirmed to go red.

QC rework iteration 2 added the missing **short-side `generate`-seam** pin:
`test_short_candidate_overlay_applied_at_generate_seam` builds a synthetic
early-Stage-4 breakdown fixture (`SHRT`, a decline whose 30-week MA has just
turned down, with volume expansion on the breakdown leg and a ~13%
counter-rally spliced onto its final bars) so a real short candidate flows
through `Screener.screen` into `result.short_candidates`. It asserts
`stop_is_structural = true` (the first such assertion on either side — the
prior tests only covered the fallback branch) and that the stop sits in
`[rally_high, rally_high * 1.10]`, i.e. just above the prior counter-rally
high per §6.3. Mutation-verified: reverting the short overlay to a bare
`List.map … candidate_of_scored` → red; flipping `~side:Short` to `~side:Long`
at the same call site → red (stop lands at `63.875`, the long-side correction
low, outside the band).

**2026-07-26 (sparse-tail eligibility gate, issue #2083 fix 1, PR
`feat/weekly-snapshot-sparse-tail`):** Closes the data-hygiene hole behind the
2026-07-17 report's rank-1 "SNSE" pick, a ticker that did not exist at the
broker (Sensei Biotherapeutics had renamed to Faeth Therapeutics, SNSE->FTH,
on 2026-06-16). The feed kept serving occasional stale bars under the dead
symbol (6 bars across ~15 trading days, one anomalous spike near the right
edge) and the existing "too few bars" check never fired because the series
read current at `as_of` and was merely sparse in the middle. New module
`Weinstein_snapshot_gen.Sparse_tail_gate` (`trading/trading/weinstein/snapshot/gen/lib/sparse_tail_gate.{ml,mli}`):
`check` counts bars actually present in the trailing `window_trading_days`
**trading days** (via `Bar_reader.daily_view_for`'s calendar-walk, so weekends
never count as "missing") ending at `as_of`; fewer than `min_bars` ->
`Sparse_tail`. Two new flat fields on `Weinstein_strategy.config`
(`sparse_tail_min_bars`, `sparse_tail_window_trading_days`, both
`[@sexp.default 0]` — default disabled, exact no-op) resolve through the real
`Config_overrides_loader` -> `Overlay_validator.apply_overrides` path (same
mechanism as `resistance_lookback_bars` / `candidate_ranking`), so they are
consumed **only** by `Weekly_snapshot_generator.generate` — the backtest/live
strategy path never reads them, so arming cannot move a backtest number.
Wired into `generate`: a dropped ticker is excluded from candidate
consideration and a warning line is emitted (not a silent drop). Schema:
`Weekly_snapshot.t` gains an additive `warnings : string list [@sexp.default
[]]` field (no version bump; pinned that the actual committed
`dev/weekly-picks/7f24f2c8d/2026-07-17.sexp` — the file at the center of the
incident — still parses). `Report_renderer` gains a `## Warnings` section
(bulleted, `(none)` when empty). Armed in
`dev/weekly-picks/live-config-overrides.sexp` at the issue's own suggested
threshold (`min_bars=10`, `window_trading_days=15`). Out of scope (per issue
#2083): fix 2 (rename tracking on fetch) and fix 3 (spike-bar "data-suspect"
flag) — separate, larger changes. Tests: `Sparse_tail_gate` unit tests
(disabled/armed/dense/sparse/no-bars/warning-text, incl. an explicit
"~6 bars in ~15 trading days with a spike near the edge" SNSE-shaped
regression fixture) + generator-level tests (default-config carries the gate
disabled; disabled run is bit-identical on a fixture that would be dropped if
armed; armed+sparse drops + warns; armed+dense retains) + an overrides-loader
test proving the arming path resolves through the genuine loader/validator.
Every new assertion was mutation-tested (break the implementation, confirm
red, restore) — see PR body for the per-test mutation log. `dune build @fmt`
+ `dune build` + full `dune runtest` all green (a nesting-linter violation in
the first draft of `Sparse_tail_gate` was fixed by splitting the disabled/
armed branches and the message-formatting body into named helpers).

**2026-07-24 (live execution protocol — Phase A+B, PR `feat/picks-protocol`):**
Weekly picks are now executable end-to-end and held positions thread week to
week. **Phase A (portfolio state):** new `Weinstein_snapshot_gen.Live_portfolio`
module — a human-editable sexp file (`cash`, `as_of`, `positions` of
`{symbol; shares; entry_price; entry_date; stop_price}`); template committed at
`dev/weekly-picks/portfolio.sexp` (user must set real `cash`). The generator
gains `--portfolio PATH`: it prices each held position via the same `Bar_reader`
(current close as-of the run date), computes unrealized %, and recomputes the
Weinstein support-floor stop (`Weinstein_stops.compute_initial_stop_with_floor`,
shown beside the current stop with the delta — no new stop logic; full trailing
state machine deferred to Phase C). Held tickers are excluded from candidate
output. **Phase B (sized instructions):** each long candidate is sized via the
existing `Portfolio_risk.compute_position_size` (fixed-risk sizing, MIRRORING the
backtest — risk-normalized, NOT equal-sized; a tighter stop earns more shares).
The report gains an `Instruction` column (`BUY STOP <n> sh @ $<entry> … place
SELL STOP @ $<stop>, GTC …`); 0-share results render their reason; without
`--portfolio` candidates size against a $100k template and are stamped `UNSIZED`.
New `Trade_sizing` helper module. Schema: `candidate` + `held_position` gained
additive `[@sexp.default]` fields (no version bump) — old snapshots still load
(pinned test + verified on committed `7f24f2c8d/2026-07-17.sexp`). Plan:
`dev/plans/weekly-picks-execution-protocol-2026-07-24.md`. All weinstein tests +
full build green, `@fmt` clean.

**2026-07-24 (report rendering fixes, P1 #2050 follow-up):** Two display-only
fixes to the weekly report (PR `feat/picks-render-fixes`). (1)
`Report_renderer.render` now renders each candidate's `resistance_grade` in a
new Markdown `Resistance` column (long + short candidate tables); it was
sexp-only before. `None` renders as `-`. (2) `weekly_snapshot_generator` strips
the module-qualified `Weinstein_types.` prefix that `[@@deriving show]` emits —
grade strings are now the bare quality label (e.g. `Heavy_resistance (0.82)`)
via a small explicit `_overhead_quality_label` (mirrors `_regime_label`; the
`[@@deriving show]` on the type is untouched). No scoring/analysis/default
changes. Tests: new renderer + generator assertions pin the clean unprefixed
string and the `None -> "-"` cell; `dune runtest trading/weinstein/snapshot`
passes, `@fmt` clean.

**2026-06-28 (snapshot-warehouse fast input path):** `generate_weekly_snapshot`
now has a fast bar-source path so a weekly screen runs in seconds instead of the
prior ~2h20m (the CSV path loads ALL bars into memory via
`Bar_reader.of_in_memory_bars` every run — unusable for a 26-week sweep). PR
`feat/weekly-snapshot-mode`. New lib module
`Weinstein_snapshot_gen.Snapshot_warehouse_reader` opens a pre-built snapshot
warehouse (`manifest.sexp` + per-symbol `.snap`), builds a real trading-day
calendar, and returns a `Bar_reader.of_snapshot_views ~calendar` reader — the
same on-demand LRU-streamed reader the backtest runners use. The bin gains a
`--bars-snapshot-dir DIR` input flag, mutually exclusive with the existing
`--bars` CSV path (errors clearly if both/neither given); the CSV path is
unchanged (back-compat). **TDD parity pin:** a new test builds a tiny warehouse
end-to-end with the real `build_snapshots` build path (`Build_runner.build`)
over fixture synthetic bars in a temp CSV store, reads it via
`Snapshot_warehouse_reader`, and asserts the generated `Weekly_snapshot.t` is
**identical** to the in-memory-CSV-path snapshot — proving the build→read
pipeline before we build a large warehouse. 9 tests pass (7 existing + 2 new).
No screener/strategy logic changed; no core-module changes.

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

`trading/trading/weinstein/snapshot/lib/report_renderer.{ml,mli}`. Pure `Weekly_snapshot.t → string` (markdown). Same shape as eventual M6.6 live report. Display limits are configurable (`render ?long_limit ?short_limit`, default long 7 / short 5); a truncated table appends a tie-honesty note stating how many hidden names tie the cutoff score (#1826). Display-only — the `.sexp` retains the screener's full capped list.

CLI: `render_weekly_report <pick-file> [-long-limit N] [-short-limit N]` → stdout.

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
1b. **[snapshot-mode, DONE]** ~~`--bars-snapshot-dir` fast input path~~ — SHIPPED
   2026-06-28 (`feat/weekly-snapshot-mode`). Next: build a large warehouse over
   the live universe with `build_snapshots` and run a real multi-week sweep
   (the parity test already proved the build→read pipeline on a tiny fixture).
2. **[M6.6, optional]** generate + commit a first baseline pick record to diff
   future weeks against (the stretch item; deferred — needs a committed
   universe + cached bars to run against, not done in the generator PR).
3. **[M6.6, deferred]** live `DATA_SOURCE` impl, cron wrapper, alert dispatch,
   trading-state durability (see §Out of scope).
4. **[#2083 F2, OPEN]** rename tracking on fetch — the remaining unbuilt
   finding from the 07-17 report review (F1 shipped #2090, F3 shipped #2097).
   Separate, larger dispatch: detect a delisted/renamed ticker at fetch time
   and re-pin the universe, rather than annotating downstream.
5. **[#2083 F3 follow-up]** decide an arming threshold for
   `spike_bar_threshold_pct` and arm it in
   `dev/weekly-picks/live-config-overrides.sexp` (the flag ships default-off;
   the incident bar was +58%, a 25-30% threshold is the obvious first
   candidate). Requires one live-report dry run to check the false-positive
   rate on genuine gap-up breakouts before arming.

## Parallelism
M6 work runs in parallel with `experiments` track M5.2 — no shared source files.

## Out of scope

- Live data wiring (M6.6).
- Cron / alert dispatch / webhook delivery (M6.6).
- Trading-state persistence across process restart (M6.6).
- Mid-week stop monitor (M6.6).
- Real-time intraday updates — we trade weekly.
