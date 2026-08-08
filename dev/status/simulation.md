# Status: simulation

## Last updated: 2026-08-07

### 2026-08-07 — next-bar-open Market-entry fill (Fix #1, branch `feat/sim-entry-next-open`, PR #2238)

Plan: `dev/plans/fill-model-faithfulness-2026-08-07.md` Workstream C. Findings:
`dev/notes/fill-model-fix-findings-2026-08-07.md` §5.

**What.** New default-off strategy config flag `sim_entry_fill_next_open : bool
[@sexp.default false]`. When true, a **Market ENTRY** order routing to an
`Entering` position is held back on any step where its symbol has no fresh bar,
so it fills at the **next fresh trading bar's open** instead of the signal bar
the engine retains on non-trading (weekend/holiday) steps. Scope: Market entries
only — exits, stops, StopLimit entries, and the decision-time `entry_price`
(sizing / stops) are untouched.

**Seam (deviates from the plan's `fill_router.ml:69` expectation).** The engine
already fills Market entries at a bar's open, but `Market_state.update` keeps the
last bar per symbol on empty-bar steps, so a Friday-close decision fills against
that stale bar's own open (an optimistic, same-day price). Implemented as an
optional generic `?can_fill` predicate on `Engine.process_orders` (`None` =
bit-identical) + a new `Next_open_fill_gate` module that builds the entry-only
gate from `positions` + `today_bars`; `panel_runner` threads the flag from the
strategy config like `entry_extension_max_pct`. Extracted the gate to keep
`simulator.ml` under the 500-line limit (517 → 484, no bump).

**Status: DONE (PR #2238).** R1 (off = bit-identical, verified by the OFF test +
cached-clean simulation/engine suites) + R2 (axis-expressible
`((flag sim_entry_fill_next_open) (values (true false)))`). Tests
(`test_sim_entry_next_open.ml`, 4): OFF stale-open fill, ON next-fresh-open fill,
fill-basis-only (sizing unchanged), exits-unaffected-when-on.

**Next.** Fix #2 (no-chase entry E, Workstream D) is the remaining scoped
follow-up; then the honest ladder re-run (Step 3) under WF-CV + confirmation grid
before any default flip.

### 2026-08-06 — book-faithful stop re-anchoring for E-anchored entries (branch `feat/stop-anchor-entry-base`)

Note: `dev/notes/honest-ladder-2026-08-05.md` (AXTI evidence). Book authority:
`docs/design/weinstein-book-reference.md` §5.1. User go 2026-08-06 (pair the
E-anchored entry with a book-faithful stop).

**What.** New default-off strategy config flag `stop_anchor_at_entry_base :
bool [@sexp.default false]`. The faithfulness fix that PAIRS with the E-anchored
entry family (#2209 + #2217): those tickets rest the entry at the breakout level
E, but the initial stop still came from the deep support-floor machinery
anchored to crash lows. For a crash-recovery name the mismatched pair
(E-entry × crash-floor-stop) inflated risk% so the entry walk's 15%
`max_stop_distance_pct` gate (G15 step 3) rejected the ticket as `Stop_too_wide`
— AXTI (score 100, ranked #1) was skipped 24× in the localtop26 arm and never
entered; systemically 11,178 / 13,765 `Stop_too_wide` skips over 26y
(localtop26 / localtop52). When armed AND the entry is E-anchored (effective
`trigger_at_suggested`), a support-floor stop farther from E than
`max_stop_distance_pct` is re-anchored to the buffer-below-breakout stop (the
`initial_stop_buffer` fallback the stops layer already computes — book §5.1
"just under the breakout base / below the MA"). Structural floors already within
15% (normal shapes) are unchanged; the `Stop_too_wide` gate itself is untouched
(it now sees honestly-paired risk).

**Status: DONE (this PR).** R1 (off = bit-identical) + E-family gating
(inert unless `trigger_at_suggested`). INITIAL stop only — trailing machinery,
admission, grading, `breakout_price`, false-virgins protection all UNCHANGED.
Narrowest seam: `Entry_audit_helpers.initial_stop_and_kind`
(`_maybe_reanchor_to_entry_base`, reuses the production fallback via an empty
callbacks bundle — no new floor math) + `make_entry_transition`
(`?stop_anchor_at_entry_base`, ANDs with `trigger_at_suggested`) + `Entry_walk`
call site.

**Completed.** `stop_anchor_at_entry_base` flag (3 sync'd config sites);
5 unit tests (R1 off pin, armed re-anchor of an AXTI-shaped deep floor to the
entry base, normal-shape bit-identity, E-family gate, and the load-bearing
`entries_from_candidates` integration pin funding a previously-`Stop_too_wide`
candidate); composes-with note in the .mli with the E-anchored family.

**Next steps (not in this PR).** WF-CV surface on the armed E-family bundle
(`sim_entry_trigger_at_suggested` + `enable_sim_entry_stoplimit` +
`entry_anchor_local_range_weeks` + `stop_anchor_at_entry_base`) per the
honest-ladder plan; ledger ACCEPT gates any default flip.

### 2026-08-05 — book-faithful E-anchored entry trigger (PR #2209)

Plan: `dev/plans/gtc-breakout-orders-2026-08-05.md` (Step 1). Branch
`feat/entry-trigger-at-e`. Diagnosis: `dev/notes/bke-order-diagnosis-2026-08-05.md`.

**What.** New default-off strategy config flag `sim_entry_trigger_at_suggested :
bool [@sexp.default false]`. When true AND `enable_sim_entry_stoplimit` is on, the
strategy anchors `CreateEntering.entry_price` (and sizing) at the candidate's
`suggested_entry` (breakout level E) instead of the current close (the G14 fix-B
default). The emitted order is then a genuine `StopLimit (E, E×(1±band))` resting
at the breakout — matching the book (Ch.3 p.67-68 / ref §4.7) and the live
report's E-anchored tickets. User decision 2026-08-05 (Step 0 option (b)).

**Status: DONE.** R1 (off = bit-identical) pinned; split-safe in-sim (G14 fix-A
truncates the screener lookback at splits, so E and the close share one price
basis). Narrowest seam: `Entry_audit_helpers.effective_entry_price` +
`make_entry_transition` + `Entry_walk` AND-gate. StopLimit-rests-at-E-fills-on-cross
already pinned by `test_gtc_entry_persistence.ml`.

**Completed.** `sim_entry_trigger_at_suggested` flag (3 sync'd config sites);
3 unit tests (E-anchor entry+sizing, R1 off pin); plan Step 0/1 updated.

**Next steps (Steps 2-3, not in this PR).**
- **PR2 — execution-faithfulness audit CAPTURE** (`feat/execution-faithfulness-audit`):
  **DONE.** Extended `Trade_audit.audit_record` with an optional
  `execution : execution_faithfulness option [@sexp.option]` record
  (`designed_order_type` Market/StopLimit+trigger+limit; `designed_trigger`;
  `fill_price`; `fill_vs_trigger_pct`; `fill_within_band`; `faithful`) —
  external_exit_decision pattern (#2085), old sexps parse. New
  `Execution_faithfulness` module joins each entry to its realised fill (reuses
  `Trade_context`'s position join) and is wired at the runner
  (`_assemble_result`). `designed_trigger` recovered exactly as the effective
  entry from the audit dollar fields (`entry_decision` carries no `shares`);
  `designed_order_type` from `entry_order_kind_of_config`. Default runs ⇒ Market
  ⇒ faithful=true. Includes the CP4 inertness test
  (`sim_entry_trigger_at_suggested` alone is inert) + `Entry_walk` re-export.
- **PR3 — execution-faithfulness REPORT columns** (follow-on, split for size):
  surface the execution fields as `trade_audit_report` columns + a
  %-faithful / mean-fill-vs-trigger summary line (mirror #2196's external-exit
  fallback). Not started.
- **Step 2** — managed GTC lifecycle (cancel-on-candidacy-loss, re-grade amend).
- **Step 3** — honest fill-model ladder re-derivation + WF-CV surface on the
  E-anchored basis.

### 2026-07-27 — LH phantom SHORT + duplicated `trades.csv` rows (issue #2059)

Plan: `dev/plans/lh-phantom-short-2026-07-27.md`. Branch
`fix/lh-phantom-short`.

**Root cause (single, shared by all three reported defects).**
`Metrics.extract_round_trips` was not quantity-faithful: `_pair_step` popped an
*entire* open entry for *any* opposing trade regardless of its quantity. A
**partial** exit therefore (a) booked the **full entry quantity** against the
**partial exit price**, over-stating that row's P&L, and (b) silently dropped
the residual shares — so the **next** closing `Sell` found `open_entries` empty
and fell into the "open a new entry" arm, i.e. it was re-read as a **short
open**. That phantom short lives only inside the pairing fold (never in the
portfolio, never in any strategy position map), which is exactly why no exit
channel ever re-evaluated it; it is eventually "covered" by an unrelated later
re-entry `Buy`, printing a multi-decade SHORT row with inverted P&L in a run
with `enable_short_side = false`. Two orphaned sells produce two byte-identical
rows, so realized-PnL aggregation double-counts.

The LH numbers in #2059 are reproduced field-for-field from a **pure-long**
trade stream: `Buy 1934 @ 139.44` (2001-06-09), LabCorp's 2-for-1 split on
**2001-06-12** (the LONG row's exit date), a stop-out selling 1934 on the split
day and the remaining 1934 the next day, and an ordinary Aug-2024 re-entry.
Split restatement turns the entry into the reported `3868 @ 69.72`; the orphaned
second sell becomes `SHORT 1934 @ 67.40 -> 224.30, 8459 days`. The shared
`position_id` on all three rows is **not** evidence of a shared position record —
`Trade_context._position_id_for_trade` joins by `(symbol, entry_date)` with a
7-calendar-day backward window, so the phantom (4 days later) inherits the
LONG's audit id. It says only that the strategy never decided to open a short.

**Fix (this PR).** `Metrics` now tracks unconsumed quantity per open entry
(`_open_entry.remaining`, entry-date share basis). A closing trade consumes
`min(remaining, exit_qty / split_factor)` from the selected entry, emits one
round-trip per entry leg touched carrying the **consumed** quantity, and repeats
with what is left of the exit. Entry selection is unchanged (exact
split-adjusted quantity match, else FIFO). Only a genuine **over-close** (exit
larger than every open entry) opens an entry on the closing side — the correct
reading, since `Portfolio` really does flip direction there. Bit-identical for
the alternating full-exit stream, the sibling scale-in stream (#1847), and every
split-straddling full exit; only partial-exit streams change, and those are the
ones that were wrong.

- [x] **Defect 1 (SHORT in a long-only run) — CLOSED.**
- [x] **Defect 2 (8,459-day zombie) — CLOSED.** Never a portfolio zombie; the
      row was manufactured by the fold.
- [x] **Defect 3 (exact duplicate rows) — CLOSED for the orphan cause.** Each
      orphan produced its own phantom short; orphans are no longer produced.

Verify: `dune runtest trading/simulation/test` — tests 26-29 of
`test_metrics.ml` (`partial exit across split emits no phantom SHORT`,
`over-sell reports one SHORT, not a duplicate`, `partial exit splits into two
legs`, `over-close opens leftover on closing side`). Test 27 asserts the exact
row multiset and prints #2059's literal 1-LONG + 2-identical-SHORT shape before
the fix. Blast radius: `trades.csv` / `n_round_trips` / `total_pnl` /
`win_rate` / `avg_holding_days` on runs containing partial exits (trim,
maintenance-reduce, harvest-rotate, split-day stop fills); equity-curve metrics
untouched.

#### Filed, not fixed — for review by `feat-weinstein` / a follow-up

1. **Can a single fill flip a position's sign?** If the real 2001-06-13 LH
   stream contained a genuine over-sell (two `Sell 1934` against 1934 held), one
   SHORT row survives the fix — correctly, because the portfolio genuinely
   flipped short (`Portfolio` has an explicit "Direction changed" branch when a
   trade crosses zero). Proposed invariant: **no single fill may flip an
   existing position from long to short or back.** Opening a short from flat
   stays legal; a reversal in one fill is never intended by any channel.
   Cheapest enforcement point that is *not* a core module:
   `Cancel_handler.apply_trades_best_effort` (simulation layer, already the
   single funnel every fill passes through), as a rejected-fill + loud `WARN`
   alongside the existing cash-floor rejection path. Deliberately **not** done
   here: it changes simulation behaviour, wants its own default-off flag + a
   regression pass, and the artefacts needed to confirm an over-sell actually
   occurred are not present in this container. Not attempted in
   `weinstein_strategy.ml` or the stop machine (`dev/decisions.md`).
2. **`position_id` in `trades.csv` is not a reliable forensic key.**
   `Trade_context._position_id_for_trade` resolves it via a 7-day backward
   window over audit records *for the symbol*, so any round-trip whose entry
   lands within a week of a real entry decision inherits that decision's id even
   when it belongs to a different (or non-existent) position. This is what made
   #2059's three rows look like one position. Any per-trade forensic that groups
   by `position_id` should be re-checked. The fix would be to thread the real
   position link through `Fill_router`'s order links into the round-trip rather
   than re-deriving it by date proximity.

### 2026-07-04 — sibling round-trip pairing fix (#1847, MERGED as `761c30cf`)

`#1847` (`fix/sibling-round-trip-pairing`, author dayfine) fixes a **reporting**
bug in `Metrics.extract_round_trips`: sibling positions (scale-in parent + add on
one symbol) interleave as `Buy, Buy, Sell, Sell`; the old side-only consecutive
pairing dropped the parent entry, emitted one chimera row, and dropped the add's
exit. `_pair_trades_for_symbol` now keeps a per-symbol FIFO queue matching exits
to the open entry by split-adjusted quantity (else oldest). Bit-identical for the
alternating single-position stream (all default runs). This is the real bug behind
the retracted #1843 add-channel conclusion (retraction merged as #1846). Blast
radius: `trades.csv` / `total_trades` / `win_rate` / `avg_holding_days` on
scale-in-enabled runs only; equity-curve metrics (WF-CV verdict basis) untouched.

**Resolution (2026-07-04 run 2 — orchestrator run 28721834266):** `#1847`
**MERGED** to main as `761c30cf` ("fix(simulation): position-faithful round-trip
pairing for sibling positions"). The maintainer resolved the run-1 nesting-linter
CI blocker on `_pair_trades_for_symbol` and updated the branch; CI went green and
the PR merged. Behavioral was APPROVED (19:26Z, score 4). Follow-up docs handoff
`#1849` marked the round-trip-pairing P0 done. This closes run-1's escalated
Question 1 ("let the orchestrator finish #1847, or keep it maintainer-LOCAL?") —
the maintainer completed it. Per-trade analysis of scale-in-enabled runs is now
trustworthy; the scale-in fresh full-size+adds WF-CV surface remains data-gated.

### 2026-07-03 — fill-routing fix (#1837, MERGED)

`#1837` routes fills by order→position link (fixes stray fill attribution). Merged
2026-07-03 08:54Z (run 4).

### 2026-06-12 — exit-fill-reject retry (#1553)

Fixed the cash-floor-rejected exit-fill zombie (issue #1553): a position
whose stop fired and moved to `Exiting`, but whose cover/sell fill was
then rejected by the portfolio cash floor, was stranded in `Exiting`
forever (the stop machinery only re-evaluates `Holding`), so it rode the
adverse move unbounded (THM short −240% in the Nov-2022 bear).

Three pieces, all simulation/backtest-layer (no core-module edit):
- **Revert (M):** `Cancel_handler.revert_rejected_exits` reverts an
  unfilled `Exiting` position back to `Holding` (reconstructed from the
  `Exiting` state's carried fields, preserving the stop), so the stop
  re-evaluates next cycle and re-triggers the exit — a natural retry
  loop. Wired into `Simulator._process_fills_and_cancels` right after the
  entry-side `transitions_for_rejected_trades`. Partially-filled exits are
  deliberately not reverted (would desync the portfolio's booked partial
  cover). Rejected-fill apply/bucket relocated to
  `Cancel_handler.apply_trades_best_effort` (keeps `simulator.ml` under
  the file-length limit).
- **Observability (S):** `apply_trades_best_effort` now emits a loud
  per-trade `WARN` (symbol/side/qty/price/reason) on every
  portfolio-rejected fill — no more silent drops.
- **Fold_health (S):** additive `Stuck_held_positions` finding +
  `Fold_health.check_divergence` (config-thresholded
  `max_stuck_held_positions`, default 0) flags portfolio↔strategy
  divergence (open positions not under stop evaluation). Pure/additive;
  runner-wiring (threading the strategy position count through
  `Runner.result`) deferred to a harness follow-up to keep the PR in
  budget.

Verify: `dune runtest trading/simulation/test trading/backtest/test`
(7 cancel_handler tests + 12 fold_health tests green).
Decision items for review (PR body): (1) a core `CancelExit`
(`Exiting -> Holding`) transition to replace the simulation-layer state
reconstruction; (2) exempting risk-reducing (closing) trades from the
portfolio cash floor.

## Last updated (prior): 2026-05-22

## Status
IN_PROGRESS

Split-day broker-model redesign + regression follow-ups fully wrapped
(PRs #658 / #662 / #664 / #667 broker-model; #678 strategy-side-position-map
fix; #680 stop-state rescaling; #682 short-side flag for sp500 mitigation;
all merged 2026-04-28..29). Slice 1+3 verdicts remain APPROVED. M5
walk-forward harness COMPLETE 2026-05-16 (#1100/#1111/#1116, see
`walk-forward-cv` track); Bayesian Phase 3 tuner stack consumed it via
#1126/#1132/#1136/#1143/#1145 (see `tuning` track). Track stays
IN_PROGRESS for residual simulator follow-ups landed 2026-05-16..18
(margin Phase 2 wiring, NAV silent-fallback removal, rejected-fill
retry plumbing — listed below).

P0 CI RED (`split_day_stop_exit:1:post_split_exit_no_orphan_equity`, $400 drift)
was resolved by PR #752 (2026-05-02); CI green on `main` since.

### Recent simulator fix-forward (2026-05-16..18)

- **#1119 — margin Phase 2 simulator wiring** (MERGED 2026-05-16):
  daily borrow-fee accrual + maintenance force-cover on short positions;
  ties the `short-side-strategy` track's Reg-T Phase 1 collateral (#1113/#1115)
  into the per-step simulator loop. Default-off via `margin_config.enabled = false`
  preserves all goldens. See `dev/status/short-side-strategy.md` for the bear-window
  validation follow-on (ops-data dispatchable).
- **#1123 — silent cash-fallback NAV removal** (MERGED 2026-05-16):
  `_resolve_price` no longer substitutes `current_cash` when forward-fill
  fails; instead surfaces `last_known_mark` + fail-loud `Status.Error`.
  Closes the equity-curve corruption mode tracked in
  `dev/notes/cell-e-15y-engineering-blocker-2026-05-09.md`. Builds on
  prior #1019 / #1063 fixes; supersedes the workaround documented in
  `memory/project_simulator_nav_fallback_bug.md`.
- **#1128 — `portfolio_valuation.compute` nesting linter fix-forward**
  (MERGED 2026-05-16): cosmetic refactor following the #1123 extraction;
  no behavioral change.
- **#1177 — surface rejected fills via CancelEntry (P0a-residual)**
  (MERGED 2026-05-18): residual fix-forward from the BAH gap-buffer
  work; rejected fills now flow back to strategies via `CancelEntry`
  so they can retry. Closes the silent-drop hazard that surfaced after
  #1123 landed.

## QC
overall_qc: APPROVED (Slice 1 + Slice 3)
structural_qc: APPROVED (Slice 1: 2026-04-07, Slice 3: 2026-04-10)
behavioral_qc: APPROVED (Slice 1: 2026-04-07, Slice 3: 2026-04-10)
See dev/reviews/simulation.md.

## Interface stable
YES

## Blocked on
- None

## Existing infrastructure — DO NOT reimplement
`trading/trading/simulation/` is a **generic** framework shared across all strategies (not Weinstein-specific). Phases 1–3 are complete and tested:
- **Phase 1** (core types): `config`, `step_result`, `step_outcome`, `run_result` in `lib/types/simulator_types.ml`
- **Phase 2** (OHLC price path): intraday path generation, order fill detection for all order types
- **Phase 3** (daily loop): `step` and `run` implemented; engine + order manager + portfolio wired up
- The simulator already takes a `(module STRATEGY)` in its `dependencies` record

The Weinstein work in eng-design-4 adds Weinstein-specific components **on top** without breaking general use.

## Completed

- `strategy_cadence` added to simulator config — Weekly/Daily gate (#195)
- `Weinstein_strategy` — full `STRATEGY` impl, daily stop cadence, Friday-gated screening (#196, merged 2026-04-07)
  - Stop updates: daily (adjusts trailing stops as MA moves)
  - Macro analysis + screening: Fridays only (Weinstein weekly review cadence)
  - `_update_stops`, `_screen_universe`, `_make_entry_transition` wired to all analysis modules
- `Synthetic_source` — deterministic `DATA_SOURCE` impl for testing; 4 bar patterns: Trending/Basing/Breakout/Declining; 8 tests (feat/simulation branch)
- End-to-end smoke test — `Simulator.run` with `Weinstein_strategy` on CSV data in temp dir; 3 tests covering smoke + date range + weekly cadence

### Slice 2 (2026-04-09)

- **`Portfolio_view.t` on STRATEGY interface** — replaced `~positions:Position.t String.Map.t` with `~portfolio:Portfolio_view.t` containing `{ cash; positions }`. Simulator constructs it from `Portfolio.current_cash` + position map. Weinstein strategy derives portfolio value via `Portfolio_view.portfolio_value` for position sizing. 3 tests for the utility module.
- **Bar accumulation** — per-symbol daily bar buffer (`Hashtbl<string, Daily_price.t list>`) in `make` closure. Accumulated idempotently on each `on_market_close` call. Converted to weekly via `Time_period.Conversion.daily_to_weekly` for stage/macro/screening analysis. Replaces `_collect_bars` placeholder.
- **MA direction** — computed from `Stage.classify` on the weekly bar buffer instead of hardcoded `Flat`. Falls back to `Flat` when insufficient bars (< ma_period).
- **Simulation date** — `_make_entry_transition` uses current bar's date instead of `Date.today`.
- **Smoke test extended** — `hist_start` moved to 2022-01-01 (100+ weekly bars warmup). Added `portfolio_value > 0` assertion.

### Slice 3 (2026-04-10) — merged (#246)

- **Prior stage accumulation** — per-symbol `prior_stages` Hashtbl in the `make` closure. `Stage.classify` and `Stock_analysis.analyze` now receive accumulated prior stage instead of `None`. Enables accurate Stage1→Stage2 transition detection in `is_breakout_candidate`.
- **Index prior stage** — `Macro.analyze` receives accumulated index prior stage instead of `None`.
- **Breakout smoke test** — new test using `Breakout` synthetic pattern (40 weeks basing, 8x breakout volume, 1-year sim from data start). Asserts: orders submitted, trades executed, positive portfolio value. Full screener→order→trade pipeline verified end-to-end.

All slices merged: Slice 1 (#196), Slice 2 (#237, #240, #241, #242), Slice 3 (#246).

### Split-day OHLC redesign — broker-model approach (2026-04-29)

Plan: `dev/plans/split-day-ohlc-redesign-2026-04-28.md`. Closes the open
PR #641 band-aid trail; supersedes its `_split_adjust_bar` rescale in
favour of a discrete event on the position ledger. Four PRs landed:

- **PR-1 — Split_detector primitive** (#658, MERGED 2026-04-28).
  `trading/analysis/data/types/lib/split_detector.{ml,mli}`. Pure
  function `detect_split ~prev ~curr` that compares raw vs adjusted
  close ratios, snaps to small rationals, distinguishes splits from
  dividends via a 5% threshold. Configurable tolerances. 5 fixtures
  (AAPL 4:1, reverse 1:5, dividend, quiet, 3:2 boundary).
- **PR-2 — Split_event ledger primitive** (#662, MERGED 2026-04-28).
  `trading/trading/portfolio/lib/split_event.{ml,mli}` — built
  alongside `Portfolio` per CLAUDE.md. `apply_to_position` quadruples
  quantity / quarters cost-basis-per-share on 4:1; total cost basis
  preserved. `apply_to_portfolio` no-ops when symbol not held. 4
  fixtures (forward 4:1, reverse 1:5, no-op, 3:2 fractional).
- **PR-3 — wire detector + ledger into `Simulator.step`** (#664, MERGED
  2026-04-29). Adds `Price_cache.get_previous_bar` /
  `Market_data_adapter.get_previous_bar`, a `splits_applied :
  Split_event.t list` field on `step_result`, and a
  `_detect_splits_for_held_positions` step in `Simulator.step` that
  fires before strategy invocation. `_to_price_bar`,
  `_compute_portfolio_value`, `_make_get_price` are unchanged — raw
  OHLC flows everywhere, only the position ledger is adjusted on
  splits. New `test_split_day_mtm.ml` (3/3 PASS): 4:1 continuity,
  no-split window unchanged, split-day with no held position.
- **PR-4 — verification + decisions promotion** (this PR, 2026-04-29).
  `dune build && dune runtest` exit 0; `dune build @fmt` clean. Smoke
  parity goldens bit-identical to pre-#641 main (`panel-golden-2019-full`
  7 round-trips / 33.3% win, `tiered-loader-parity` 5 round-trips /
  60.0% win). Decision promoted to `dev/decisions.md`. sp500-2019-2023
  canonical baseline rerun deferred to local — GHA's 22-symbol fixture
  cannot satisfy the 491-symbol universe (same data-availability
  blocker that scoped the tier-4 release-gate to local). When a
  maintainer runs the local sp500 baseline, MaxDD is expected to drop
  from 97.69% to ~5% (the strategy's actual non-bug Stage-4 floor)
  with trade count, return, and win rate roughly unchanged. Tracked
  in `dev/notes/split-day-broker-model-verification-2026-04-29.md`
  and the §Follow-up below.

  Verify: `dev/lib/run-in-env.sh dune runtest trading/simulation/test/`
  (3/3 split_day_mtm PASS) + `dev/lib/run-in-env.sh
  _build/default/trading/backtest/scenarios/scenario_runner.exe --dir
  test_data/backtest_scenarios/smoke --fixtures-root
  test_data/backtest_scenarios` (5/5 PASS).

## In Progress

- **Split-day broker-model redesign + regression (WRAPPED 2026-04-29)**.
  PRs #658 (Split_detector) + #662 (Split_event ledger) + #664 (Simulator
  wire-in) + #667 (verification + decisions promotion) + #678
  (`fix/split-day-broker-model-debug`, strategy-side `Position.t`
  cross-side sync) + #680 (`feat/weinstein-split-day-stop-adjustment`,
  `Stop_split_adjust.scale` rescaling stop_states on split events) +
  #682 (`feat/weinstein-short-side-flag` + sp500 long-only override)
  all merged. The 97.69% phantom MaxDD on `goldens-sp500/sp500-2019-2023`
  is structurally resolved. See `dev/decisions.md` §"2026-04-29 —
  Split-day broker model: regression" + §"2026-04-29 — Split-day OHLC:
  broker model".

- **M5 walk-forward + parameter tuner — DONE via cross-tracks.** The
  M5 surface has shipped under sibling tracks: walk-forward CV harness
  via #1100/#1111/#1116 (`walk-forward-cv` track, MERGED 2026-05-16),
  Bayesian Phase 3 tuner stack via #1126/#1132/#1136/#1143/#1145
  (`tuning` track, MERGED 2026-05-17). Subsequent V1→V3 production
  sweeps + V3-V7 methodology stack landed under `tuning`; see
  `dev/status/tuning.md` for the current surface (`promote_config.sh`
  + cross-scenario validation per PR #1237).

## Blocking Refactors
- None

## Follow-up

- **Local sp500 baseline rerun (deferred from PR-4 of split-day redesign)** —
  capture post-PR-3 metrics on `goldens-sp500/sp500-2019-2023` against
  the full 491-symbol universe. Cannot run in GHA (22-symbol fixture
  insufficient). Reproduction shape:
  ```sh
  docker exec trading-1-dev bash -c '
    cd /workspaces/trading-1/trading && eval $(opam env) &&
    dune build trading/backtest/scenarios/scenario_runner.exe &&
    _build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir trading/test_data/backtest_scenarios/goldens-sp500 \
      --fixtures-root trading/test_data/backtest_scenarios'
  ```
  Expected: trade count ≈ 134 (per
  `dev/notes/sp500-2019-2023-baseline-canonical-2026-04-28.md`),
  total return ≈ +71%, win rate ≈ 38%, MaxDD ~5% (down from 97.69%
  phantom). Once captured, supersede the canonical baseline note and
  re-pin `goldens-sp500/sp500-2019-2023.sexp` `expected` ranges
  against the corrected MaxDD. Plan reference:
  `dev/plans/split-day-ohlc-redesign-2026-04-28.md` §PR-4.
- Volume dilution in weekly aggregation: a single high-volume daily breakout bar gets averaged with 4 normal-volume bars in the weekly sum, requiring unrealistically high `breakout_volume_mult` (8x daily) to achieve 2x weekly ratio. Consider enhancing `Synthetic_source.Breakout` to apply volume spike across multiple days of the breakout week.
- Test does not yet assert on specific position symbols (AAPL open position) or PnL direction — trades are confirmed but position-level assertions deferred.
- `TODO(simulation/price-cache-data-source)` — Remove tmpdir round-trip in strategy smoke tests once `Price_cache` accepts an injected `DATA_SOURCE` (follow-up to #218/#219). See `trading/weinstein/strategy/test/test_weinstein_strategy_smoke.ml`.
- `TODO(simulation/stoplimit-orders)` — `order_generator` uses Market orders; should be StopLimit orders with entry/exit prices from transitions. See `simulation/lib/order_generator.ml` and `.mli`.
- `TODO(simulation/monthly-cadence)` — Monthly cadence conversion not implemented in `time_series.ml` — currently returns empty. See `simulation/lib/data/time_series.ml`.
- `TODO(simulation/bar-granularity)` — Engine `price_bar` type lacks configurable bar granularity (daily/hourly/minute) and volume data. See `engine/lib/types.mli`.
- ~~**Macro.analyze cadence mismatch**~~ — RESOLVED. `Ad_bars_aggregation.daily_to_weekly` is now called at `make` time (see `weinstein_strategy.ml:254`), so `Macro.analyze` receives weekly-cadence `ad_bars` matching the weekly `index_bars`.
- **Simulation loop performance** — current 6-year / 1654-stock backtest takes
  ~40 min and ~7 GB RAM (see `dev/status/backtest-infra.md` §Performance).
  Bottlenecks worth profiling before attempting optimization:
  - `Stage.classify` is O(n) per weekly step (recomputes full MA series).
    The `classify_step` incremental pattern tracked in
    `dev/status/screener.md` §Followup / "Stage classifier: incremental
    `classify_step` for simulation" is the direct fix.
  - Hashtbl iteration ordering still partially non-deterministic (see #298,
    #274) — fixing may close reruns rather than speed up.
  - Weinstein strategy's `_screen_universe` runs the full cascade every
    Friday — cache per-symbol stage between weeks where possible.
  - Per-scenario parallelism already exists via `scenario_runner
    --parallel N` (from #316); intra-simulation parallelism would require
    design work.
  Not yet profiled — start with `perf` / `ocaml-landmarks` / `bolt` on a
  single golden scenario to find the actual hot path before optimising.

## Known gaps

- `T2-B` performance gate test deferred to M5
- Trade assertions deferred to Slice 3 (see Follow-up)

## Next Steps

### Future slices

- Position-level assertions: verify AAPL open position, PnL direction
- ~~Walk-forward backtest (M5): parameter tuner with validation period~~
  — **DONE** via `walk-forward-cv` track (#1100/#1111/#1116, MERGED
  2026-05-16) + `tuning` track Bayesian Phase 3 (#1126/#1132/#1136/#1143/#1145,
  MERGED 2026-05-17). Cross-scenario validation as the next promote-gate
  surface owned by `tuning` per PR #1237.
- Performance gate test (T2-B)
- Local sp500-2019-2023 baseline rerun — still deferred (needs full
  491-symbol universe data not present in GHA)

