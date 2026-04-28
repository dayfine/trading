# Optimal-strategy counterfactual — opportunity-cost analysis (2026-04-28)

## Context

The `goldens-sp500/sp500-2019-2023` baseline
(`dev/notes/sp500-golden-baseline-2026-04-26.md`) shows the strategy
under-performs buy-and-hold by a wide margin: +18.49% over 5y vs ~+95%
for SPY, 28.57% win rate, 47.64% max drawdown, Sharpe 0.26. 133 round
trips, 95 losers, 38 winners, profit factor 0.89.

The sister `Trade_audit` plan
(`dev/plans/trade-audit-2026-04-28.md`) captures the *decision trail*
behind each entry — macro regime, stage, RS, cascade score, and the
unchosen alternatives at decision time. That answers "*why* did the
strategy pick this trade?" but leaves an upstream question open:

> Even if the cascade ranking were perfect, *how much* P&L is reachable
> under our system's structural constraints (universe, sizing, stops),
> and how far does the actual run fall short of that ceiling?

If the actual run is close to the ceiling, the cascade is roughly
optimal and gains require fundamental strategy changes (different
indicators, different stop discipline, different sizing). If the actual
run is far below the ceiling, the cascade is mis-prioritising and
gains are reachable by re-weighting cascade scores or adding
filters — without changing the strategy's structural design.

This plan designs an **`Optimal_strategy`** subsystem that replays each
backtest with perfect-hindsight candidate selection (still within the
system's constraints) and emits a counterfactual report comparing
actual vs ideal P&L, surfacing the opportunity cost.

User's framing (2026-04-28):

> "we could process the data in the time span separately, and pick up
> the most promising trade under our system (so partially using the
> system), e.g. find stocks break out 30w MA and trace it through stage
> conversion (an ideal exit point), to come up with a theoretical
> 'optimal' performance of the strategy, and then see how far we fall
> short (with the same sizing limit), e.g. due to opportunity cost —
> that at the moment we committed to other losing / not-winning-so-much
> trades."

This is a **plan-only PR**. No code lands here. Implementation is
phased over 4–5 follow-up PRs.

## Authority

- User's quote (above)
- Sister plan: `dev/plans/trade-audit-2026-04-28.md` — shares the
  observer / report shape; cross-references for `alternatives_considered`
  semantics
- Perf framework: `dev/plans/perf-scenario-catalog-2026-04-25.md`
- Stage classifier: `trading/analysis/weinstein/stage/lib/stage.{ml,mli}`
- Existing screener cascade: `trading/analysis/weinstein/screener/lib/screener.{ml,mli}`
- Weinstein book reference: `docs/design/weinstein-book-reference.md`
  — §Stage Definitions, §Stop-Loss Rules, §Buy/Sell Criteria
- Stop state machine: `trading/trading/weinstein/portfolio_risk/`
- Trade audit (already in flight, partial): `trading/trading/backtest/lib/trade_audit.{ml,mli}`

## Goal definition — "optimal under the system's constraints"

The counterfactual is *not* an absolute upper bound on returns — that
would just be "long the single best-performing stock at full leverage".
It is the upper bound *reachable while respecting the system's design
constraints*, isolating opportunity cost from cascade-ranking error.

### What the counterfactual respects

| Constraint | Source | Why kept |
|---|---|---|
| Universe of symbols | `Scenario.t.symbols` — same SP500 holdings used by the actual run | Don't reward picks that were unavailable to the real strategy |
| Stage gate (longs enter only on Stage 1→2 transition above resistance with volume confirmation) | `weinstein-book-reference.md` §Stage 2 + `analysis/weinstein/screener` cascade phase B | The strategy's structural rule — a Stage-3 chase is not a "good pick the strategy missed" |
| Stop discipline (Weinstein trailing stop — never lowered, triggers on weekly close) | `eng-design-3-portfolio-stops.md`, `weinstein-book-reference.md` §Stop-Loss Rules | An exit rule the system applies to every trade; the counterfactual must use it too |
| Sizing constraints (position size cap, sector concentration cap, total exposure cap, fixed-risk-per-trade) | `Scenario.t.portfolio_config` + `Weinstein_strategy.entries_from_candidates` | The system can't deploy infinite capital into the best symbol; the counterfactual lives under the same envelope |
| Concurrent-position cap | Same as above | Same — the counterfactual fills a finite portfolio |

### What the counterfactual ignores (the perfect-hindsight axis)

| Relaxation | Why dropped |
|---|---|
| Cascade ranking / scoring (grade, score, top-N cap) | This *is* the variable under test — we want to know what's reachable if ranking were perfect |
| Macro / RS gates (configurable on/off; default: relaxed for upper bound, kept for honest counterfactual — see §Two report variants) | The macro gate's value is itself a question the audit + counterfactual together answer |
| Stop-buffer / `initial_stop_buffer` extra padding | Treated as a parameter; counterfactual uses the cleanest stop = `suggested_stop` from the screener |

The counterfactual sees future data — that's the entire point. The
report labels every counterfactual metric `(perfect-hindsight,
unrealizable)` so readers don't mistake it for an out-of-sample target.

## Approach

### Phase A — enumerate candidates (`Stage_transition_scanner`)

**Input**: the same panel data the backtest already loads (Friday-bar
panel + indicators), the scenario's symbol universe, the run window
[start_date, end_date].

**Output**: a list of `candidate_entry` records, one per (symbol, week)
where the symbol satisfied the system's *structural* entry condition:

```ocaml
(* trading/trading/backtest/optimal/lib/optimal_types.mli sketch *)
type candidate_entry = {
  symbol : string;
  entry_week : Date.t;          (* Friday of the breakout week *)
  side : Trading_base.Types.position_side;
                                (* Long for Stage 1→2, Short for Stage 3→4 *)
  entry_price : float;          (* week's close, mirrors actual strategy *)
  suggested_stop : float;       (* same as Screener.scored_candidate.suggested_stop *)
  risk_pct : float;             (* (entry - stop) / entry *)
  sector : string;              (* for sector concentration cap *)
  cascade_grade : Weinstein_types.grade;  (* for `Two report variants` *)
}
```

**Algorithm**: walk the panel forward week by week. At each Friday, for
each symbol in the universe, ask the existing `Screener.screen` (with
the actual run's config) the same question it asks today: *is this a
breakout candidate this week?* The screener already exposes the
per-symbol `Stock_analysis.is_breakout_candidate` predicate and the
ranked output. Drop the screener's macro gate, top-N cap, and grade
threshold — keep only the breakout-condition predicate + sizing-input
fields (`suggested_entry`, `suggested_stop`, `sector`).

**Two report variants** (see §Output): one variant keeps the macro gate
(honest counterfactual — "what's reachable if cascade ranking were
perfect, all else equal?"), one drops it (upper bound — "what's
reachable if we also relaxed the macro gate?"). The same scanner emits
both by tagging each candidate with `passes_macro : bool`.

### Phase B — score each candidate by realized outcome (`Outcome_scorer`)

For each `candidate_entry`, compute the realized P&L under the
counterfactual exit rule:

**Counterfactual exit rule** (per Weinstein book §Sell Criteria + the
existing stop state machine):

1. Compute the Weinstein trailing stop forward from `entry_week`,
   using the same stop logic the actual strategy uses
   (`Weinstein_stops.compute_initial_stop_with_floor` for entry,
   trailing rule for subsequent weeks).
2. Compute the *ideal* exit independently: the first weekly close
   after entry where `Stage.classify` returns Stage 3 (top/distribution)
   — operationally, the first Friday where the stage transitions
   2 → 3 per the existing classifier with a small forward window so we
   don't false-trigger on transient flip-flops (window = N weeks of
   sustained Stage-3 classification, default N=2; tunable in the
   counterfactual config).
3. Exit at `min(stop_hit, stage3_transition, end_of_run)`.

The exit price is the weekly close on the exit week. P&L is `(exit -
entry) * shares` for longs, mirrored for shorts. The
`initial_risk_dollars` is `(entry - stop) * shares`, used to express
P&L as an R-multiple.

**Output**: the candidate enriched with realized outcome:

```ocaml
type scored_candidate = {
  entry : candidate_entry;
  exit_week : Date.t;
  exit_price : float;
  exit_trigger : [`Stage3_transition | `Stop_hit | `End_of_run];
  raw_return_pct : float;     (* (exit - entry) / entry, sign for side *)
  hold_weeks : int;
  initial_risk_per_share : float;
  r_multiple : float;         (* raw_return / risk_pct — comparable across positions *)
  passes_macro_gate : bool;   (* tag from Phase A *)
}
```

**Implementation note**: this phase reads forward bars from the panel
(it already has them — backtests load the full window upfront). Pure
function; the only input is the panel + the candidate, no portfolio
state.

### Phase C — assign positions under sizing constraints (`Optimal_portfolio_filler`)

Greedily fill the counterfactual portfolio week-by-week, ranking
candidates within each Friday by R-multiple descending and filling
until the sizing envelope is full. This phase is **path-dependent** —
today's pick changes tomorrow's available capital — so the "greedy
heuristic" choice matters.

**Heuristic** (chosen): **earliest-Friday, R-multiple descending, with
hindsight on R-multiple but live capital tracking**.

```
Initialize portfolio with scenario.starting_cash, empty positions.
For each Friday F in [start, end]:
  For each candidate c with entry_week = F, scored from Phase B,
    sorted by r_multiple descending:
      if c.symbol already held: skip
      if portfolio at concurrent-position cap: skip
      if sector_exposure(c.sector) + size(c) > sector_cap: skip
      compute size(c) = risk_per_trade_dollars / c.initial_risk_per_share
      if cash < size(c) * c.entry_price: skip
      open position; deduct cash
  Mark to market: existing positions tracked at week's close.
  Apply exit rule: any position whose exit_week = F closes at exit_price.
```

Three heuristics were considered:

- **A: earliest-Friday + R-descending (chosen)** — natural reading of
  "perfect ranking under same arrival order". Single forward pass; cheap;
  matches the actual strategy's calendar.
- **B: globally optimal across all weeks (knapsack-style)** — let the
  filler skip a Friday's best candidate if a better one arrives next
  week. Computationally expensive (NP-hard with sector + concurrency
  caps; tractable only with ILP). Produces a cleaner upper bound but
  the gap to A is small in practice (most weeks have a saturated
  schedule).
- **C: random-restart / Monte Carlo** — sample multiple greedy fills;
  report the best. Only useful if A's variance is high; not expected
  here because R-multiple is a strong sort key.

**Choosing A.** Reasons:

1. **Calendar-honest**. The actual strategy fills positions Friday by
   Friday; A measures opportunity cost on the same axis.
2. **Cheap**. Linear in candidate count.
3. **Tight enough**. The gap to a globally optimal solution (B) is
   bounded above by the difference between best-this-week and
   best-next-week R-multiples, which is small relative to the gap to
   the actual strategy. Reporting this gap as a sanity check is a
   PR-5 follow-up.

If A's reported counterfactual P&L is suspiciously close to the actual
or has wide variance under input perturbation, follow-up with B or C.

### Phase D — counterfactual report (`Optimal_strategy_report`)

Pure markdown renderer. Inputs:

- `actual_round_trips : Metrics.trade_metrics list` (from `trades.csv` /
  `Runner.result.round_trips`)
- `actual_summary : Summary.t` (from `summary.sexp`)
- `optimal_round_trips : optimal_round_trip list` (from Phase C)
- `optimal_summary : optimal_summary` (computed inline from C's output —
  total return, win rate, MaxDD, Sharpe, R distribution)

Output: `<output_dir>/optimal_strategy.md` containing:

1. **Run header** — period, universe, scenario name. Loud disclaimer
   that the counterfactual uses look-ahead and is unrealizable.
2. **Headline comparison table**:

   | Metric | Actual | Optimal (constrained) | Optimal (relaxed macro) | Δ to constrained |
   |---|---:|---:|---:|---:|
   | Total return | +18.5% | +X% | +Y% | +Z pp |
   | Win rate | 28.6% | x.x% | y.y% | |
   | MaxDD | -47.6% | -x.x% | -y.y% | |
   | Sharpe | 0.26 | x.xx | y.yy | |
   | Profit factor | 0.89 | x.xx | y.yy | |
   | Round-trips | 133 | N | M | |
   | Avg R-multiple | x.xx | y.yy | z.zz | |
3. **Per-Friday divergence table** — for each Friday where actual and
   constrained-counterfactual picks differ:
   - Actual picks (symbols + sizes)
   - Counterfactual picks (symbols + sizes)
   - Top 3 candidates the actual *could* have picked but didn't, with
     their realized R-multiples
4. **"Trades the actual missed"** — entries the counterfactual took
   that the actual didn't, ranked by realized P&L. For each, flag the
   reason from the cascade diagnostics (already captured by trade-audit
   PR-2 cascade-rejection counts in `Screener.cascade_diagnostics`):
   - "Filtered by grade threshold"
   - "Sized to zero (risk too tight)"
   - "Sector cap"
   - "Top-N cutoff"
5. **"Trades the actual took that the counterfactual would have skipped"**
   — losers the actual entered that didn't make the counterfactual's
   ranked cut. Aggregate the cumulative realized loss attributable to
   these.
6. **Implications block** — auto-generated narrative:
   - If `optimal_return / actual_return > 3.0`: "cascade is significantly
     mis-scoring; gains reachable via re-weighting"
   - If `optimal_return / actual_return < 1.5`: "cascade is near-optimal;
     gains require structural changes"
   - In between: "moderate cascade improvement reachable; structural
     changes also needed for full upside"

## Files to change

By PR. Each PR ≤ ~400 LOC including tests.

### PR-1: data model + `Stage_transition_scanner`

- `trading/trading/backtest/optimal/lib/optimal_types.{ml,mli}` — new
  module. `candidate_entry`, `scored_candidate`, `optimal_round_trip`,
  `optimal_summary` records, all `[@@deriving sexp]`.
- `trading/trading/backtest/optimal/lib/stage_transition_scanner.{ml,mli}`
  — pure scanner. Input: panel data + universe + window + screener
  config. Output: `candidate_entry list` (one per breakout-week per
  symbol). Reuses `Stock_analysis.is_breakout_candidate` and
  `Screener.scored_candidate` fields directly so the counterfactual
  uses the *same* breakout predicate as the live cascade.
- `trading/trading/backtest/optimal/lib/dune` — register modules.
- `trading/trading/backtest/optimal/test/test_stage_transition_scanner.ml`
  — fixtures with synthetic Stage-1→2 transitions; assert scanner finds
  exactly the seeded weeks; round-trip sexp tests for every record type.
  ~8 tests.

LOC estimate: 300.

### PR-2: realized-outcome scorer

- `trading/trading/backtest/optimal/lib/outcome_scorer.{ml,mli}` —
  pure scorer. Input: `candidate_entry + Bar_panel.t`. Output:
  `scored_candidate`. Implements counterfactual exit rule
  (Stage3_transition / Stop_hit / End_of_run, whichever first).
  Reuses `Weinstein_stops.compute_initial_stop_with_floor` for the
  initial stop and the existing trailing-stop walker for subsequent
  weeks.
- `trading/trading/backtest/optimal/test/test_outcome_scorer.ml` —
  three fixtures: (a) candidate exits via Stage3 transition, (b) candidate
  exits via stop hit, (c) candidate runs to end-of-run.
  Plus an R-multiple computation test pinning a known value.

LOC estimate: 300.

### PR-3: greedy sizing-constrained fill

- `trading/trading/backtest/optimal/lib/optimal_portfolio_filler.{ml,mli}`
  — Phase C implementation. Walks Fridays, applies greedy fill rule,
  produces `optimal_round_trip list`.
- `trading/trading/backtest/optimal/lib/optimal_summary.{ml,mli}` —
  thin metrics aggregator (total return, win rate, MaxDD, Sharpe, R
  distribution, profit factor).
- `trading/trading/backtest/optimal/test/test_optimal_portfolio_filler.ml`
  — fixtures stress-testing each constraint:
  - Concurrent-position cap forces lower-rank candidate skip
  - Sector cap forces skip even when ranking allows
  - Cash exhaustion forces skip
  - Two simultaneous candidates ranked by R-multiple
  - End-of-run forces close-out

LOC estimate: 400.

### PR-4: markdown report renderer

- `trading/trading/backtest/optimal/lib/optimal_strategy_report.{ml,mli}`
  — pure renderer. Input: actual round-trips + summary + optimal
  round-trips + summary. Output: markdown string.
- `trading/trading/backtest/optimal/bin/optimal_strategy.ml` — thin
  binary. Reads `output_dir/`'s artefacts (`trades.csv`,
  `summary.sexp`, the panel cache referenced by `summary.sexp`),
  invokes scanner→scorer→filler→renderer, writes
  `<output_dir>/optimal_strategy.md`.
- `trading/trading/backtest/optimal/bin/dune` — register exe.
- `trading/trading/backtest/optimal/test/test_optimal_strategy_report.ml`
  — fixture with seeded actual + counterfactual round-trips; assert
  the rendered markdown contains the expected divergence rows, the
  expected outlier callouts, and the implications block fires the
  right narrative for the seeded ratio.

LOC estimate: 400.

### PR-5 (optional): wire into `release_perf_report`

- `trading/trading/backtest/release_report/release_report.{ml,mli}`
  — if `optimal_strategy.md` exists alongside `summary.sexp`, link it
  from the per-scenario row plus add a column "Δ to optimal
  (constrained)" populated from the counterfactual summary.
- `trading/trading/backtest/scenarios/scenario_runner.ml` — optional
  flag `--emit-counterfactual` defaulting off (counterfactual cost is
  ~1 panel pass, not free; opt-in until shown to be cheap on tier-1).

LOC estimate: 200.

## Risks / unknowns

1. **Stage-3 detection is forward-looking by definition.** The counterfactual
   uses future Stage classifications to find the "ideal exit". The window
   parameter (default 2 sustained Stage-3 weeks) is a hyperparameter; PR-2
   must expose it via the counterfactual config and run sensitivity at
   1, 2, 3, 4 weeks to verify the conclusion is robust. If the report's
   verdict flips between window=1 and window=4, the counterfactual is
   too noisy to interpret.

2. **Path-dependency of the greedy fill.** As called out in §Phase C
   heuristic discussion, A may be loose vs B. Mitigation: PR-3 ships a
   sanity test that runs a small synthetic universe (10 symbols, 1 year)
   under both A and B (B implemented as a brute-force enumerator —
   feasible at this scale only) and asserts they agree to within 5pp of
   total return. If they diverge widely, the choice of A is wrong and
   we revisit.

3. **The screener config used by the scanner must match the actual run.**
   Any drift (different `min_grade`, different sector-rating thresholds)
   makes the counterfactual incomparable. Mitigation: PR-1 reads the
   screener config from `summary.sexp` rather than reconstructing it,
   and pins a regression test asserting the scanner's input config
   equals the actual run's config.

4. **Weinstein trailing-stop reuse vs reimplementation.** The actual
   strategy's trailing stop lives in `Weinstein_stops` and is wired
   into the simulator step. The counterfactual filler is *not* a
   simulator — it computes exits in a single pass over panel bars. So
   the counterfactual must call `Weinstein_stops` in a non-stateful
   way (compute the stop level forward week by week given a fixed
   initial entry + fixed bar series). If `Weinstein_stops` doesn't
   expose a pure-functional walker today, PR-2 either (a) extracts one
   into a new pure helper used by both the simulator and the
   counterfactual, or (b) re-implements the stop-walk inline in
   `outcome_scorer.ml` and pins parity with a test that runs the same
   bar series through both paths. Option (a) is preferred (single
   source of truth); option (b) is the fallback if (a) requires
   touching too much shared code.

5. **`Bar_panel.t` access in PR-4 binary.** The renderer-binary needs
   the panel data to run the scanner. Two options:
   - (i) the binary re-loads from `trading_data/` using
     `Bar_panel.load`. Cheap, mirrors how scenario_runner does it.
   - (ii) `summary.sexp` retains a panel-cache pointer; the binary
     follows it.
   PR-4 picks (i) — `summary.sexp` should not grow a panel pointer.

6. **Macro-gate variant computation cost.** The "relaxed macro" variant
   re-runs the scanner with the macro gate dropped, doubling Phase A
   work. PR-1 makes this an opt-in flag (`--variants=constrained` |
   `constrained,relaxed`); release_perf_report uses
   `constrained,relaxed`; ad-hoc runs use just `constrained` to halve
   cost.

7. **Look-ahead bias is the entire point — make sure the report says so.**
   PR-4's renderer must include the disclaimer prominently. Pinned by
   a test asserting the rendered markdown contains the literal string
   "perfect-hindsight" in the header.

8. **No live-mode equivalent.** The counterfactual is a backtest-only
   artefact. A live-mode "what could I have done last quarter?"
   readout could be derived from the same code but requires a
   different invocation path (run on a closed window after the fact);
   out of scope.

## Acceptance criteria

By the time PR-4 lands:

- Running `dune exec backtest/optimal/bin/optimal_strategy.exe -- <output_dir>`
  for the sp500-2019-2023 baseline produces `<output_dir>/optimal_strategy.md`
  with:
  - Headline comparison table populated for actual + constrained +
    relaxed-macro variants.
  - Per-Friday divergence table with at least 1 row.
  - "Trades the actual missed" with at least 5 entries.
  - "Trades the actual took" with at least 5 entries.
  - Implications block with one of the three narratives fired.
  - Disclaimer prominently in header.
- The constrained-counterfactual total return is ≥ the actual total
  return (sanity check — perfect ranking can't hurt under same
  constraints; if violated, the filler has a bug).
- The relaxed-macro counterfactual total return is ≥ the constrained
  one (sanity — relaxing a constraint can't hurt).
- All tests pass: `dune build && dune runtest && dune build @fmt`.
- Sensitivity test at Stage-3 window ∈ {1,2,3,4}: total return varies
  by < 20%; verdict (which implication branch fires) does not flip.

## Out of scope

- **Live-mode counterfactual.** Backtest-only; live-mode is a separate
  concern.
- **Strategy parameter tuning.** The counterfactual reveals *whether*
  the cascade is mis-scoring; it does not propose better weights. The
  parameter tuner (a separate `dev/plans/parameter-tuner-*.md` track)
  consumes the counterfactual's findings as input.
- **Multi-strategy comparison.** One canonical Weinstein, one
  counterfactual definition. A "compare to a different strategy
  family" exercise needs a different framework.
- **Realised-but-unattributable returns.** The counterfactual measures
  per-trade opportunity cost; it does not attribute the difference
  between actual and optimal to specific cascade-score components
  (e.g. "x% comes from grade weighting, y% from RS weighting"). That's
  a regression-on-cascade-features exercise, separate.
- **Real-time integration.** Counterfactual runs offline against
  closed scenarios; not invoked from the live trading loop.
- **Cross-scenario aggregation (initial release).** PR-5 adds the
  hook into `release_perf_report` if it lands; the initial
  deliverable is per-scenario depth.

## Phasing summary

| PR | What | LOC est. | Owner |
|---|---|---:|---|
| PR-1 | `Optimal_types` + `Stage_transition_scanner` | 300 | feat-backtest |
| PR-2 | `Outcome_scorer` (forward exit walker) | 300 | feat-backtest |
| PR-3 | `Optimal_portfolio_filler` (greedy A) + `Optimal_summary` | 400 | feat-backtest |
| PR-4 | `Optimal_strategy_report` + `optimal_strategy.exe` | 400 | feat-backtest |
| PR-5 | release_perf_report integration (optional) | 200 | feat-backtest |
| **Total** | | **~1,600** | |

Total scope: ~1,600 LOC across 4–5 PRs. Each PR is independently
mergeable + tests pass on its own; PR-3 onward consumes artefacts
produced by earlier PRs. PR-3 is the riskiest single step (path-dependent
greedy heuristic; correctness pinned by the small-universe brute-force
parity test in §Risks item 2).

## Relationship to sister tracks

- **trade-audit** (`dev/plans/trade-audit-2026-04-28.md`) — the audit
  captures *why a specific trade was chosen* and the alternatives at
  decision time. The counterfactual answers *what was the best
  achievable across all alternatives, with the same constraints*.
  Together they cover both the per-decision diagnosis (audit) and the
  aggregate ceiling (counterfactual). The audit's
  `alternatives_considered` field is conceptually the input to the
  counterfactual's per-Friday filler — but the counterfactual uses
  the full screener output (including alternatives the cascade
  rejected), not just the audit's snapshot.
- **backtest-perf** — the counterfactual emits one extra artefact per
  scenario; if PR-5 lands, it shows up in the release report. Cost is
  modest (one panel pass + sort/fill); should not bottleneck the
  perf workflow.
- **parameter-tuner** (future) — once the counterfactual quantifies
  the gap, a tuner consumes per-Friday "would this candidate have
  won?" labels to fit cascade weights. Out of scope here.
