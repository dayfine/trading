---
name: project_capital_mgmt_scale_in_design
description: "Capital-management explore/exploit scale-in: DESIGNED (#1829), BUILT default-off (#1830-#1833, sibling-position architecture), WF-CV REJECTED 2026-07-03 (ledger scale-in-v1-surface; all 3 WHYs stand). Participation measurement confirmed the chain (79-92% near-miss linkage) AND exposed a REPORTING bug: Metrics.extract_round_trips chimeras sibling round-trips (a first 'adds never fill' conclusion was retracted — adds fill 4/4, 19/20). Stays a default-off axis."
metadata:
  node_type: memory
  type: project
  originSessionId: 78c98b7f-b5bb-42f0-abac-d99c79b0a11d
---

**CONTINUATION-ADD v2 REJECTED — SCALE-IN PROGRAM CLOSED (2026-07-05, ledger
`2026-07-05-continuation-add-v2-surface`):** broad-only 13×2y WF-CV, gate FAIL
all variants (4/13, 3/13, 4/13 Sharpe wins; means ≤ baseline). WHYs: (1)
faithful trigger is RARE by design → low power (5-6/13 folds bit-identical —
zero adds mattered); (2) regime-mixed when it fires (f010 2020-21 monsters:
+10.7pp, press works; f007 2014-15: −15.7pp, press into mean-reversion); (3)
volume confirmation = the load-bearing dial (1.5× blocks exactly the f007
damage, book's "impressive volume" empirically right — but harm-filtered
variant lands DEAD on baseline: removing bad adds removes the edge); (4) root
cause, 9th [[project_edge_is_the_fat_tail]] confirmation NEW angle: under the
binding cash constraint a full-size add is FINANCED BY DISPLACED ENTRIES —
even the book's own press-the-winner reallocates INTO winners OUT OF breadth,
and breadth IS the edge. **FORWARD: intra-envelope capital-reallocation class
EXHAUSTED (v1, v2, harvest-rotate, laggard-cap, macro-trim). Revisit adds only
PAIRED with an envelope change (min_cash/max_exposure pair-sweep — never
done).** Writeup: dev/notes/continuation-add-v2-wfcv-2026-07-05.md.

**CONTINUATION-ADD v2 BUILT (2026-07-04/05, plan #1852, code #1855, default-off):**
book re-read (Ch. 3 §The Trader's Way) showed v1 conflated the investor ½+½
(initial-position pullback completion) with the book's ACTUAL press-the-winner
mechanism — the **continuation buy**: consolidation near the rising 30w MA →
fresh breakout above the consolidation top on volume → **full-size** buy (<50%
of continuation breakouts pull back; the no-pullback ones are the home runs).
v1's `Early_new_high` was a proxy invention. Built: `Consolidation_breakout`
trigger (nested consolidation_config: min_weeks 4 / band 0.10 / ma_proximity
0.10 / volume_ratio 1.25 — all axes) + explicit `add_fraction : float option`
(None = v1 legacy 1−initial_entry_fraction). ⚠ v2 surfaces MUST set
`extension_max_pct ≥ 0.25` (consolidation closes sit up to ~22% above MA —
"Either dead at 0.15" class hazard, documented in .mli). NEXT: broad-only
(top-3000, NO sp500 per user) WF-CV surface: baseline vs full-size+cont-add;
launch gated on Docker.raw recompact (55GB > 30GB preflight).

**PARTICIPATION MEASUREMENT (2026-07-03/04, `dev/experiments/scale-in-participation-2026-07-03/RESULTS.md`) — confirmed the chain; first conclusion RETRACTED:**
- **RETRACTION (2026-07-04):** the #1843 claim "add channel never functioned /
  StopLimit(close,close) root cause / smoothing = cash throttle" was WRONG — an
  artifact of trades.csv. Pipeline trace: **adds fill routinely** (sp500 f001
  pullback 4/4; broad f011 pullback 19/20; simulator entry orders are Market —
  StopLimit is the LIVE path only). All 3 original ledger WHYs stand.
- **REAL bug found: `Metrics.extract_round_trips` chimeras sibling round-trips.**
  Symbol-stream consecutive (Buy,Sell) pairing, no qty/position identity:
  B_parent B_add S_parent S_add → B_parent dropped, chimera (B_add,S_parent) row,
  S_add dropped (verified NPKI f011). Blast radius: trades.csv, win_rate,
  total_trades, avg_holding_days, ALL per-trade analyses for scale-in runs;
  equity-curve metrics (the WF-CV verdict) unaffected. **FIXED #1847
  (2026-07-04):** qty-aware FIFO pairing (fold + `_pair_step`), double-QC
  approved, bit-identical for single-position streams. Pre-#1847 trades.csv
  from scale-in runs stays unreliable.
- **Confirmed:** ½-sizing→breadth near-lossless (79–92% of new names = baseline's
  `Insufficient_cash` near-misses; skips/Friday flat ~10, constraint always binds);
  fat-tail tax visible per-decision (avg entry $169k→$98k sp500).
- **Carried prereqs for the untested full-size+adds shape:** explicit
  `add_fraction` knob (v1: adds sized `1 − initial_entry_fraction` → full-size
  entries get zero-size adds); LIVE add-order shape fix (live emits
  StopLimit(close,close) = adverse selection; sim/live divergence).
- **Lesson:** verify the reporting layer handles a new mechanism's structure
  before reading conclusions off it — trace emit→order→fill once.

**VALIDATION VERDICT (2026-07-03, ledger `2026-07-03-scale-in-v1-surface`):
REJECT for promotion — stays default-off axis.** 2-cell WF-CV (sp500 + broad
top-3000, 2000-2026, 13×2y folds, production caps). sp500: outright tax
(Sharpe .92→.78, return 36→23%; fold-002 recovery 146→55% = monsters ½-sized).
Broad (decisive cell): return dead-flat ~20%, mild risk smoothing —
`either_loose` (Either + ext 0.25) best on every risk metric (MaxDD 15.4→13.9,
10/13 DD wins, 2022 fold −0.42→−0.03 Sharpe) but +0.065 Sharpe doesn't survive
DSR. THE 3 WHYs: (1) ½-initial-entry is itself a fat-tail tax (explore-side
[[project_edge_is_the_fat_tail]] — under-sizing unpredictable winners = same
class as trimming); (2) Either structurally DEAD at extension_max_pct 0.15
(breakouts sit 10-20% above 30w MA → new highs read extended; only ext 0.25
makes the continuation arm live, and it supplies ALL the risk benefit); (3)
breadth reverses the sign (3rd breadth-dependent knob after declining-MA +
capacity-BROAD). UNTESTED promising shape: full-size entries + continuation
adds (drop the ½-sizing = keep only the un-taxed press-the-winner half).
Bonus: surface caught the same-state sibling fill mis-routing simulator bug →
#1837 (order→position link routing). Note: dev/notes/scale-in-wfcv-2026-07-03.md.

2026-07-02 design session (grill) + 2026-07-03 build session. Plan:
`dev/plans/capital-management-scale-in-2026-07-02.md` (#1829). **BUILT v1,
default-off**, via 4 PRs (each CI + qc-structural + qc-behavioral gated):

- **#1830** sim `Fill_router` (extracted from simulator.ml): side-aware fill
  routing (Long Entering←Buy / Long Exiting←Sell / Short mirrors) — required
  because sibling positions put a buy and a sell order on one symbol at once.
- **#1831** `Stops_runner` per-ticker single advance: per-update memo
  (ticker → (pre_advance_state, event)); first position advances the shared
  Weinstein stop machine, siblings replay the event (all exit on a hit, all get
  UpdateRiskParams on a raise). Plus `Stop_transitions` extraction.
- **#1832** `Scale_in_detector` (pure pullback-hold / early-new-high / Either +
  extension gate) + `enable_scale_in`/`scale_in_config` default-off knobs.
- **#1833** `Scale_in_runner` + wiring: sibling `CreateEntering` adds into
  revealed strength, before the fresh-entry walk with reduced-cash arbitration
  (adds outrank fresh); fresh entries sized ×initial_entry_fraction via
  `Scale_in_runner.entry_sizing_config`. `scale_in_added` closure-state budget.

**KEY ARCHITECTURE DECISION (differs from plan §4, same behavior):** the
`Holding → add` transition landed as a **sibling position** — own id
(`gen_position_id`), own lifecycle, same symbol, and NO stop_states write (both
units ride the ticker's one trailing stop = book-faithful one-stop discipline).
Zero core position-state-machine changes; the enablers were fill-routing (#1830)
and single-advance (#1831). Positions maps are id-keyed so siblings are
structurally fine; `held_symbols` keeps fresh entries excluded.

**Follow-ups (non-blocking, from QC):** (1) catastrophic-stop check uses each
position's own post-advance state — a second sibling evaluates against the
already-advanced state; inert (catastrophic_stop_pct default 0.0) but align to
the memoized pre-advance state if a spec ever arms both. (2)
`entry_sizing_config` has no direct unit test (pure code motion; CI goldens
cover the off-path). (3) detector's omitted-field config test round-trips a full
record rather than a truly field-omitted sexp.

**The system read (load-bearing, reusable):**
- The **signal layer** (which symbols are Stage-2/breakout/RS/macro) is *exogenous* —
  market-driven, does NOT depend on portfolio state. Self-contained.
- But the portfolio **IS** an input: `on_market_close` gets
  `Portfolio_view.t = {cash; positions}`. Two feedback loops ALREADY exist — a
  **balancing loop** (cash gate → caps exposure → the ~97% `Insufficient_cash` skips)
  and a **reinforcing loop** (NAV-proportional sizing → compounding). What's MISSING
  is any loop keyed on the stock's *health/composition* that adapts the *policy*
  (existing feedbacks are static structural constraints, not adaptive control).

**Two orthogonal levers — keep separate (the key decomposition):**
1. **Reallocation** — *how* capital is distributed inside a fixed exposure envelope.
   This design. No bear-defense trade-off.
2. **Envelope size** — ⚠ CORRECTED 2026-07-05 ([[project_envelope_knobs_dead]]): the
   "≤70% invested" claim was FALSE — both knobs are dead code (`check_limits` never
   called); backtests run 89-99% deployed. No envelope to loosen; pair-sweep cancelled.
   Cash-skips happen at ~0% reserve. Only expansion = margin (structural).

**The mechanism (explore/exploit scale-in), all knobs default-off/no-op:**
- Reuse EXISTING state machines (position lifecycle `Entering→Holding→Exiting→Closed`
  + weekly-reclassified Weinstein stage w/ `late` flag + distance-above-30wk-MA). The
  machine SHRINKS positions today (partial exit) but can't GROW one → the `Holding→add`
  transition is the real build. Partitions (reserved/exploring/running) EMERGE from
  per-state sizing — NO pool-rebalancer (steering the partition = overfit/churn).
- **Explore:** ½-risk-unit initial entries (broad survey; cash-rationed 97% → "half-enter"
  is effectively always-on).
- **Exploit:** max **1** add on the **first pullback** (Weinstein ½+½), gated
  `not-late AND not-extended`. Sized in **RISK units not notional %** (avoids the NAV-drift
  trap): initial ½ unit → add to full 1-unit, notional capped at existing
  `max_position_pct_long 0.30`. Each add its own stop.
- **Following revealed strength, NEVER predicting** (winners≈losers at entry,
  [[project_accuracy_is_unreachable_diversify_instead]]). Pullback-HOLD = the reveal.
  Arbitration: add (revealed) > fresh (unproven) for scarce cash, + exploration floor.

**Why worth building (vs the 8 rejected levers):** it's a **reallocation** not a trim —
never touches a running winner (harvest-rotate/macro-trim/late-stop all rejected for taxing
the tail, [[project_edge_is_the_fat_tail]]); tail-aligned (sample broad → feed the confirmed);
Weinstein's own scale-in dial → faithful, NO passive-sleeve/barbell faithfulness question
([[project_regime_barbell_direction]] was CLOSED on that). Motivated by
[[project_decision_audit_faithful]] (near-misses are as good as funded → capacity is the lever).

**The #1 open question the backtest MUST measure:** a pure-pullback trigger **under-sizes
gap-and-go monsters** (fastest winners never pull back → stuck ½-size in the tail). If
confirmed, the `either` trigger (pullback OR early not-extended new-high) is the fix. v1
default = `pullback`; trigger is a knob `{pullback|early_new_high|either}`.

Validation: land default-off → Variant_matrix axis → WF-CV bear-inclusive → confirmation grid.
