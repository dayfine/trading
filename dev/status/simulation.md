# Status: simulation

## Last updated: 2026-08-23

### 2026-08-18 — F2 clock default promoted 0 → 26 (PR #2384) — **REVERTED 2026-08-19 by #2397**

> **⚠ READ THIS BEFORE THE SECTION BELOW. The flip described here is no longer
> on main.** #2397 returned `entry_order_max_rest_weeks` to `0` after the
> post-merge golden run on
> `goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp` regressed **−40.91pp** —
> which is exactly the postsubmit watch R-5 below anticipated. Verified on main
> 2026-08-19: `[@sexp.default 0]` in both `weinstein_strategy_config.mli` and
> the re-declared record in `weinstein_strategy.mli`.
>
> **A spec that omits the field runs at `0` again.** The "also note for any new
> spec" paragraph at the end of this section is superseded; no pinning is
> required for the old behaviour.
>
> **The mechanism is not dead, and the grid below is still the right grid.**
> The larger sample favours the cut: on 1,147 fills over 26 years, tickets
> resting >26wk are 7.8% of fills and **−15.1%** of realized P&L
> (`project_stale_order_fills_are_not_an_edge`). The −40.91pp cell removed
> **SMCI +240%**, one trade worth more than the whole cut cohort — a tail
> lottery on a net-losing class. Re-flip framed in **#2405**.
>
> **But age may be the wrong variable entirely.** #2407 proposes cancelling on
> whether the *base* that defined `E` still holds, which would supersede the
> clock rather than tune it. **Update 2026-08-23: that companion measurement is
> no longer in flight — it completed and returned NO BUILD as specified**
> (`dev/experiments/base-broken-2026-08-19/README.md`). At this holding cadence
> "the base broke" and "the ticket rested a long time" are nearly the same
> population — 79 of the 89 fills resting >26 weeks had already broken their
> 8-week base low — so the structural test would rescue 10 fills worth 0.76% of
> realized P&L. Issue #2407 is still open; see `## Next Steps`.
>
> Everything below is kept verbatim as the record of what was promoted and what
> it owed.

`Weinstein_strategy_config.entry_order_max_rest_weeks` was promoted `0 → 26`
**by user decision**, outside the normal gate. The full evidence and the
declared deviations live on that field's `.mli` docstring and in
`dev/experiments/_ledger/2026-08-18-entry-ticket-clock26-promotion.sexp`
(verdict **`Inconclusive`**, not `Accept` — the ledger's verdict type has no
"promoted-by-override" label; same shape as the #2047 bundle precedent).

**Why this section exists.** The PR's own argument for shipping ahead of the
grid is that *the grid still happens*. A session handoff note
(`dev/notes/next-session-priorities-2026-08-19.md`) is not a tracked
obligation, so the owed work is recorded here.

**Owed — the confirmation grid** (`.claude/rules/promotion-confirmation.md`).
Re-run the candidate surface `{0, 13, 26, 52}` across ≥3 independent
(period × universe) cells. Queued as **validation of a shipped default**, not as
a gate before one: if it fails, the response is to reconsider the flip, not to
discount the grid.

- **R-1 — at least one cell must span a genuinely different macro regime**
  (ideally deep enough to cover 2000-02 + 2008). Four agreeing post-2009 cells
  were exactly what the early-admission grid had before a 27y cell reversed it.
- **R-2 — commit the per-arm outputs.** The three clock draws
  (513.42 / 434.06 / 377.73) and the three null draws
  (265.44 / 281.71 / 397.95) currently live only in `/tmp` chain logs; nothing
  in the repo carries them. They are reproducible from
  `dev/experiments/ttl-retest-2026-08-16/specs/ttl-retest-06-clock26-only.sexp`
  at salts 0/1/2 (added on main by #2377), but reproducible ≠ recorded.
- **R-5 — postsubmit watch on
  `trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp`.**
  It arms StopLimit and is deliberately left *unpinned* (a golden should track
  intended defaults), so the new default can move it — and
  `golden-runs-sp500-5y.yml` runs post-merge only, so the PR never saw it. The
  13 non-golden StopLimit specs were pinned at `0` in #2384 to keep their
  recorded results reproducible.

**Also note for any new spec:** after this flip, an arm that omits
`entry_order_max_rest_weeks` runs at **26**, not `0`. Both 2026-08-18 ledger
entries measured `0` under the label `null`; that label no longer denotes the
shipped default. Pin the field explicitly.

### 2026-08-10 — ticket-lifecycle audit fields (branch `feat/ticket-lifecycle-audit-fields`, PR-5)

Plan: `dev/plans/entry-ticket-async-v2-2026-08-10.md` §4 PR-5 row + §3-F6 + §5.
Book: `docs/design/weinstein-book-reference.md` §4.5 (triple confirmation), §4.2
(the two breakout-volume branches).

**The gap.** Under the asynchronous ticket model an entry is no longer one
instant — the ticket is *placed* on one Friday and *fills* (or is cancelled)
later — but `Trade_audit.entry_decision` recorded only the placement instant's
analysis. None of ladder-v4's §5 questions were answerable from
`trade_audit.sexp`: how long tickets rested, which F1 clock admitted them,
whether the fill's volume actually confirmed, and whether the §4.5
triple-confirmed cohort is where the outsized winners live.

**What.** One new `[@sexp.option]` field, `entry_decision.ticket_lifecycle`,
carrying: `placement_date`; `ticket_age_weeks_at_cancel` and
`ticket_age_weeks_at_fill` (two separate columns — see below); `fill_volume` (a
`fill_volume_check` = a 4-way `fill_volume_verdict` — `Confirmed_spike` /
`Confirmed_buildup` / `Unconfirmed` / **`No_verdict`** — paired with a 3-way
`fill_volume_outcome`: `Ejected` / `Skipped_other_exit` / `Held`);
`freshness_basis`; `sized_down_wide_stop`; and the F6 `triple_confirmation`
measurements (breakout-volume multiple, RS zero-cross, in-base advance %).
Supporting: `Volume.classify_breakout` (the named form of `confirms_breakout`,
defined as its projection), `Volume_eject_runner.fill_week_confirmations` +
`emit_fill_week_audit` (the audit twin of `update`, sharing one
fill-week-window helper), and two new leaf modules — `Entry_ticket_tags`
(strategy-side placement projections) and `Ticket_lifecycle` (backtest-side
sub-schema + its two resolution merges, the way `Stop_log` owns
`exit_trigger`).

**Status: MERGED #2270 `a03f2a4e` 2026-08-11.** Capture-only — no config field, no gate, no
behaviour change; goldens move only in sexp shape. Discharges two deferrals:
#2258's `Sized_down_wide_stop` (was `entry_meta` + trace only) and
qc-behavioral #2267's held-without-verdict recommendation
(`Some { verdict = No_verdict; _ }` is now countable alongside the eject rate).

**The audit population diverges from the eject population — deliberately, and
now recorded.** `Volume_eject_runner.update` (the decision surface) skips every
position in `skip_position_ids` — another exit channel (stop, Stage-3, laggard,
force-liq, liquidity, extension) already claimed it this tick.
`fill_week_confirmations` (the audit surface) does not: the fill's volume
verdict is a property of the *fill*, and the cohort it retains (weak-volume
breakout that stops out in week 0/1) is exactly what plan §5 prediction 4
measures. The wider population is therefore kept, and each row additionally
carries `fill_volume_outcome`, read off the tick's **actual** eject transitions
and skip set rather than inferred from the verdict. So an `Unconfirmed` count is
**not** an eject count; v4 can compute "unconfirmed fills" and "actual ejects"
separately and measure their overlap. Pinned by a test that shows a
`skip_position_ids` position yielding an audit row tagged `Skipped_other_exit`
while `update` returns `[]`.

**What actually gates the no-behaviour-change claim.** The **required** PR
checks do *not* assert backtest metrics: `perf-tier1-smoke` is a 120 s
timeout/crash gate, `dune runtest` carries no full-run metric assertion, and the
scenario metric goldens run in the scheduled `golden-runs-*` workflows, not on
this PR. Nothing in the required checks would catch a moved number. What *is*
gated here: (a) default-config inertness driven through the real
`Special_exits.run` pipeline with a capturing recorder (zero events), plus
unarmed / flag-without-family / mid-week coverage at the runner level; and (b)
constructor-for-constructor equivalence of the `confirms_breakout` refactor,
asserted against independently written expected verdicts rather than against
`classify_breakout`'s own output.

**Scope notes / follow-ups.**
- **Fill-side age has a 7-day ceiling.** It is stamped by
  `Execution_faithfulness.enrich`, which joins through `Trade_context`'s 7-day
  window — so a ticket resting longer than a week is not matched and the age
  stays `None` (that row also already gets `execution = None` today, a
  pre-existing property of that join, not introduced here). The **cancel-side**
  age (from `CancelEntry`, via `Trade_audit.record_transitions`) is unbounded
  and is the one F2's TTL analysis should read. The two live in **separate
  columns** (`ticket_age_weeks_at_fill` / `ticket_age_weeks_at_cancel`) so the
  fill side's structural cap cannot leak into a fill-inclusive-sounding
  statistic. Widening the entry↔fill join for long-resting async tickets is a
  real follow-up — it currently blinds #2158's execution-faithfulness column on
  exactly the v4 arms.
- `EntryFill` transitions are not visible to `on_transitions` (fills are applied
  inside `_process_fills_and_cancels`), which is why the fill date has to come
  from the round-trip join rather than from a transition observer.
- F6 gates nothing, per plan §3-F6. `Entry_ticket_tags.is_triple_confirmed`
  exists for cohort analysis of a completed run and has no strategy caller.

### 2026-08-10 — F2 `entry_order_ttl_weeks` + re-screen cancel (branch `feat/entry-order-ttl`, PR-3)

Plan: `dev/plans/entry-ticket-async-v2-2026-08-10.md` §2-M2 / §3-F2 / §4 PR-3
row (+ §6 "TTL × freeze" pin-lifecycle risk). Book: §4.7 "until you either
cancel the orders or they are actually executed" + the §7 weekend-homework loop.

**The gap.** `test_gtc_entry_persistence.ml` pins that an unfilled StopLimit
entry order rests forever until a bar trades through `E`. That is GTC with **no
cancel authority anywhere in the system** — only half of §4.7 exists, so a
ticket written against a base that has since broken down still fills weeks
later.

**What.** New `Weinstein_strategy_config.entry_order_ttl_weeks : int
[@sexp.default 0]`. When `> 0`, each weekly review re-examines every unfilled
`Entering` position (`Entry_ticket_ttl`, new module):

1. **Primary — re-screen cancel.** Cancel when the symbol fails the next weekly
   re-screen. The predicate reuses the cascade's own gates (Phase-1 stage filter
   specialised to the ticket's side, the sector pre-filter, and the newly
   exported `Screener.longs_admitted_by_macro` /
   `Screener.shorts_admitted_by_macro`), so re-screen and screen cannot drift.
   A resting ticket's symbol is *held*, hence excluded from the candidate list —
   which is why the question has to be re-asked directly.
2. **Backstop — clock TTL.** Cancel after more than `entry_order_ttl_weeks`
   whole weeks unfilled (placed week 0 → survives week N → cancelled week N+1).

Cancelling emits `Position.CancelEntry`, **releases the symbol's `Entry_freeze`
pin** (new `Entry_freeze.release`; `apply`'s stale-release rule cannot cover this
— the symbol is still held on the cancelling tick and may still be qualifying
after a clock cancel), and the simulator retires the resting order via
`Cancel_handler.cancel_resting_entry_orders`. Partially-filled entries are never
cancelled (booked shares).

**Status: READY_FOR_REVIEW.** R1 — `0` returns `[]` without even consulting the
re-screen predicate and no strategy emits `CancelEntry`, so the simulator's new
cancel path is unreachable at the default; this **extends**, never weakens, the
`test_gtc_entry_persistence` contract (that file gains a third test for the new
half; its two original tests are untouched). R2 — real config field resolved by
`Overlay_validator.apply_overrides`, so `((entry_order_ttl_weeks (0 4 8)))`
expands as a `Variant_matrix` axis (round-trip + omitted-field parse tests). R3
— no default flipped. **Faithfulness: BOOK-NEUTRAL dial** — §4.7 + §7 grant the
cancel authority and locate the decision in the weekly review, but the book
names no number; the 13-weeks-with-no-revalidation cell is the least book-like.

**Scope notes / follow-ups.**
- The cancel pass runs inside the Friday screen, so it is skipped on a
  force-liquidation-halted week (entries are gated off wholesale there).
- Order matching uses the `(symbol, entry-side)` heuristic `Fill_router` already
  relies on — the per-step `order_links` table is cleared on every generation
  pass, so an order placed on an earlier step has no position-id link.
- Ticket age is now projected into the persisted `Trade_audit.entry_decision`
  row by PR-5 (`ticket_lifecycle.ticket_age_weeks_at_cancel`, set from the
  `CancelEntry` transition — its own column, unbounded, distinct from the
  7-day-capped `ticket_age_weeks_at_fill`). The cancel *reason* is still not
  carried.

### 2026-08-10 — F3 `stop_width_mode` + nearest-floor anchor arm (branch `feat/stop-width-mode`, PR-2)

Plan: `dev/plans/entry-ticket-async-v2-2026-08-10.md` §3-F3 / §4 PR-2 row.
Evidence: `dev/notes/ladder-v3-faithful-stoplimit-2026-08-09.md` (crash-recovery
names tripped `Stop_too_wide` 22–28× on the exact record-run entry weeks).

**What.** Two rival, default-off treatments of a structurally wide initial stop:

1. `stop_width_mode : Drop_over_max | Size_down [@sexp.default Drop_over_max]`
   + `stop_width_size_down_max_pct : float [@sexp.default 0.0]` on
   `Weinstein_strategy_config`. `Size_down` admits a candidate whose stop sits
   past `stops_config.max_stop_distance_pct` and lets fixed-risk sizing shrink
   the share count ~`1/stop_distance`; the drop threshold moves to the swept
   sanity ceiling (`0.0` falls back to `max_stop_distance_pct`, so an
   unconfigured `Size_down` admits exactly the `Drop_over_max` population).
   Admitted-by-mechanism entries carry
   `Entry_audit_capture.entry_meta.sized_down_wide_stop = true` and trace as
   `Sized_down_wide_stop`. **Honest citation: NOT a documented book mechanism** —
   §5.1's "prefer other candidates" is comparative, but the book's remedies are
   nearest-low anchoring, the §5.3 trader stop, or passing; never risk-parity
   size-down. Labelled a tolerated-participation reading in `stop_width_mode.mli`.
2. `stops_config.support_floor_anchor_scope : Window_extreme | Nearest
   [@sexp.default Window_extreme]` — the competing **faithful** arm. `Nearest`
   anchors the initial stop on the nearest qualifying prior correction low
   instead of the window extremum's (crash-floor) counter-move, shrinking the
   stop *distance* the book's way rather than the share count. Orthogonal to the
   existing `support_floor_anchor_mode` (Wick/Close) price-field dial.

New module: `trading/trading/weinstein/strategy/lib/stop_width_mode.{ml,mli}`
(pure gate: `Admit | Admit_sized_down | Drop`).

**Status: READY_FOR_REVIEW.** R1 — both defaults are exact no-ops (pinned by
default-drops-36%-stop, omitted-sexp-field, and `Window_extreme` bit-identity
tests). R2 — both are real config fields resolved by
`Overlay_validator.apply_overrides`, so `stop_width_mode` and
`stops_config.support_floor_anchor_scope` expand as `Variant_matrix` axes. R3 —
no default flipped; promotion needs a ledger ACCEPT + the confirmation grid.

**Scope note / follow-up.** The `Sized_down_wide_stop` tag lives on the
strategy-internal `entry_meta` and the `PANEL_GOLDEN_DEBUG` candidate trace.
Projecting it into the persisted `Backtest.Trade_audit.entry_decision` sexp row
is the plan's **PR-5** audit-fields step (which owns the golden-shape change).


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

- [x] **Walk-order docstrings go stale when `Demote_over_max` is armed**
  (residual R-a from PR #2352 qc-behavioral iteration 1) — DONE, branch
  `docs/walk-order-docstrings`. Three docstrings asserted that the entry walk
  funds candidates in screener score order, which stops being true once
  `config.stop_width_mode = Demote_over_max` permutes the candidate list in
  `Entry_walk._prepare_candidates` before the walk. All three were traced to
  the code path and confirmed stale before rewriting; each now states the
  configuration under which its ordering claim holds rather than hedging:
  - `screen_record.mli` `funded` — was "in screener order (score-desc)"; now
    names both producers (`of_audit_records` = walk emission order, screener
    order except under `Demote_over_max` where it is post-demotion order;
    `Weekly_adapter` = always score-desc, no entry walk).
  - Same file, `inversion` — was "usually `false` … flags a sizing / sector-cap
    quirk". Now: anomaly signal only under the `Drop_over_max` default; fires
    systematically by design under an armed `Demote_over_max`; and the cause
    enumeration points at `Trade_audit.skip_reason` (10 constructors) instead
    of naming only sizing / sector caps.
  - `weinstein_strategy_config.mli` `short_sleeve_fraction` — was "re-emitted
    in original screener order"; `Entry_walk._sleeve_decisions` re-sorts by the
    index into the list *handed to* the walk, i.e. post-demotion order when
    that mode is armed. Reworded to "the order the candidates entered the walk".

  Completeness: swept the tree for other score/screener-ordering claims. The
  snapshot-side ones (`weekly_snapshot.mli`, `report_shared.mli`,
  `pick_diff.mli`, `weekly_snapshot_generator.mli`, `screener.mli`) are correct
  as written — `entries_from_candidates` has exactly one production caller
  (`weinstein_strategy_screening.ml`), so the demotion never reaches the
  snapshot path. `entry_walk.ml`'s own "Order." paragraph was already corrected
  by #2352. No fourth stale site. Docstrings only; no default changed, and
  `weinstein_strategy_config.ml` has a zero-byte diff.

  Found but not fixed (out of R-a scope, sibling agent owns the file this run):
  `Trade_audit.alternatives_considered` is documented as "Top-N candidates from
  the same screen call that were not entered", but
  `Entry_audit_capture.alternatives_of_decisions` emits **every** `Skipped`
  decision in the walk regardless of any top-N cut. Worth a follow-up on
  `trade_audit.mli`.
- **The demoted-wide cohort is not greppable from the trace** (residual R-c from
  PR #2352). Under `Demote_over_max` a wide-stop candidate that gets admitted
  behind the narrow ones records `"Pass"` with `sized_down_wide_stop = false` —
  indistinguishable in the audit from a candidate that was never wide. Under
  `Size_down` the same candidate is tagged `Sized_down_wide_stop`. Consequence:
  a `Demote_over_max` arm cannot be attributed post-hoc ("which entries did the
  demotion actually admit, and where in the walk did they land?") without
  re-running. Fix shape: either a `demoted_wide_stop` boolean on `entry_meta`
  alongside `sized_down_wide_stop`, or a rank-delta field on the screen record.
  Needed before any ladder cell that runs this mode is read for attribution.
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

Reconciled 2026-08-23. The list below had not been touched since the May
"Future slices" framing while ~13 simulation PRs shipped; every claim here was
re-verified against the merge commits on main before being kept.

### Shipped since the May list (verified on main 2026-08-23)

Recorded here because the narrative sections above do not cover most of it.
This is a merge-state reconcile, not a re-review — see each PR for the contract.

**Entry-ticket TTL / cancellation.** The knob split landed as
`#2349 59b26c3b` (2026-08-16, re-screen vs clock separated), with the cancel
precedence pinned and 40 archived specs migrated in `#2355 41f982ca`
(2026-08-17). The re-test ran (`#2353 29af15dd`, narrowed by
`#2368 a994b7bc`) and returned a **REJECT** — `#2376 56c6b9eb` (2026-08-19):
condition-based cancellation, not the re-screen, is the operative lever.

**The clock-26 promotion and its revert.** `#2384 5c278bb7` flipped
`entry_order_max_rest_weeks` 0 → 26; `#2397 283ec468` reverted it the same day
after the `goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp` golden regressed
**−40.91pp**. A second cell confirmed the direction at **−38.42pp**
(`#2392 3ec73568`). **Superseded 2026-08-31: the clock re-promoted 0 → 52 and
MERGED as `#2587`** (ledger ACCEPT `2026-08-27-entry-rest-weeks-surface.sexp`,
3-cell broad grid, robust value 52, paired 12-golden table 11/12 bit-identical;
#2405 closed). The follow-up D-null (top-1000, `#2610`) found the return effect
breadth-sensitive (−39/−395/−310pp paired across salts) while maxDD stays
robust; **USER DECISION 2026-08-31: keep 52** (ledger amended `#2611` — top-1000
is the composition probe, not the deployment breadth). Default on main is `52`.
Optional residual: an A-null (clockA-{0,52} at salts 1,2) to pin cell A's
salt-0-only +183.5pp. Open issue **#2407** proposes cancelling on
whether the base that defined `E` still holds; its companion measurement is
**done and is a NO BUILD as specified** —
`dev/experiments/base-broken-2026-08-19/README.md` finds only 10 fills / 0.76%
of realized P&L would be rescued, because 79 of the 89 fills resting >26 weeks
had already broken their 8-week base low. The issue is still open; whether to
close it is a maintainer call (see recommendation below).

**Ticket-funding leg (`arc-readiness` plan, all default-off).**
`#2378 2e8bd315` G3 `reserve_cash_for_resting_tickets`; `#2463 d7c3d295` G2a
`entry_fill_reject_retries`; `#2468 094b91b0` G2b
`entry_fill_size_to_available`. The three-way grid closed the program
(`#2473 aa70c876`): **G3 is a terminal REJECT as a global default**
(53 trades over 26y — reservation exhausts the pool); **G2a/G2b stay
default-off axes** with no promotion case at current power. Design + verdict
live on the `arc-readiness` track, not here.

**Engine-side instrumentation.** `#2423 a9f4c419` counts cap-refused StopLimit
entries and extracts `Fill_rules`; `#2431 74b16fae` pins the
blocked-then-filled clause of that tally.

### Still open

- **Position-level assertions** — verify the AAPL open position and PnL
  direction in the strategy smoke test. Carried unchanged from the May list;
  still not done, still small. (Also listed under `## Follow-up`.)
- **Performance gate test (T2-B)** — carried from `## Known gaps`; unchanged.
- **The demoted-wide cohort is not greppable from the trace** (residual R-c of
  `#2352`, merged 2026-08-17) — see `## Follow-up`. Needed *before* any ladder
  cell running `Demote_over_max` is read for attribution, so this is the one
  item here with a real ordering constraint.
- **`Trade_audit.alternatives_considered` docstring is wrong** — documented as
  "Top-N candidates", but `Entry_audit_capture.alternatives_of_decisions` emits
  every `Skipped` decision with no top-N cut. Found during `#2352` rework,
  deliberately left out of scope. Docstring-only fix.
- **Local sp500-2019-2023 baseline rerun** — still deferred; needs the full
  491-symbol universe, absent in GHA. Note this is a **golden re-pin**, which
  `.claude/rules/universe-discipline.md` explicitly permits on sp500; it is not
  a measurement and must not be quoted as evidence about strategy behaviour.
- The `TODO(simulation/*)` items under `## Follow-up` (price-cache data source,
  StopLimit order generation, monthly cadence, bar granularity) — all unchanged
  and unverified against current code in this reconcile; treat their status as
  unknown rather than confirmed-open.

### Recommendations (not decisions)

- **Issue #2407 should probably be closed or re-scoped**, since its own
  companion measurement returned NO BUILD as specified. Left open here because
  closing a tracked issue is a maintainer call, not a bookkeeping reconcile.
- **This track's boundary is drifting.** The TTL, funding and engine work above
  is mostly owned in practice by `arc-readiness` and `backtest-infra`; this file
  records it only because the code lives under `simulation/` and `engine/`.
  Worth an explicit ownership decision rather than continuing to mirror.

