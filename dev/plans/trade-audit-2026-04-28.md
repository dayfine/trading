# Trade audit — capture decision trail + rate trades (2026-04-28)

## Context

The `goldens-sp500/sp500-2019-2023` benchmark
(`dev/notes/sp500-golden-baseline-2026-04-26.md`) shows the strategy
underperforms buy-and-hold by a wide margin:

| Metric | Strategy | S&P 500 |
|---|---:|---:|
| 5y total return | +18.49% | ~+95% |
| Win rate | 28.57% | n/a |
| Max drawdown | 47.64% | ~-34% (Mar 2020) |
| Sharpe | 0.26 | ~0.5–0.7 |

133 round-trips, 95 losers, 38 winners, profit factor 0.89, CAGR 3.10%.
Realized P&L is slightly negative; the headline return is parked in 8
still-open positions at end-of-period.

The current `trades.csv`
(`trading/trading/backtest/lib/result_writer.ml`) records, per round-trip:

```
symbol, entry_date, exit_date, days_held, entry_price, exit_price,
quantity, pnl_dollars, pnl_percent, entry_stop, exit_stop, exit_trigger
```

That's enough to compute *what* happened. It does not record *why* the
strategy decided to enter a particular symbol that Friday, *what
alternatives existed at decision-time*, or *what the macro / stage /
RS / cascade context looked like* at entry and at exit. Without that
context we can't tell whether a losing trade was a good decision that
the market reversed on, or a bad decision that should never have
fired — and therefore we can't tell whether to fix the screener, the
stop placement, the macro gate, or the position sizing.

This plan designs a `Trade_audit` subsystem that:

1. Captures the decision trail at entry + the state at exit, alongside
   `trades.csv`.
2. Computes per-trade ratings (R-multiple, decision-quality,
   counterfactuals) so we can tell good-decision-bad-outcome apart from
   bad-decision-bad-outcome.
3. Renders a markdown audit report that surfaces aggregate findings —
   "of 95 losers, X had macro=Bullish at entry but flipped to Bearish
   during the hold," etc.

This is a **plan-only PR**. No code lands here. Implementation is
phased over 4–5 follow-up PRs, each ≤500 LOC.

## Authority

- Baseline metrics: `dev/notes/sp500-golden-baseline-2026-04-26.md`
- Current trade log writer: `trading/trading/backtest/lib/result_writer.{ml,mli}`
- Runner result type: `trading/trading/backtest/lib/runner.{ml,mli}`
  — `result.round_trips : Metrics.trade_metrics list`,
  `result.stop_infos : Stop_log.stop_info list`
- Strategy entry/exit decisions:
  `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml`
  — `_run_screen` (line 393), `_screen_universe` (line 344),
  `entries_from_candidates` (line 202)
- Screener cascade: `trading/analysis/weinstein/screener/lib/screener.{ml,mli}`
- Per-indicator modules: `trading/analysis/weinstein/{macro,stage,rs,volume,resistance,support,sector}/lib/`
- Stop log (predecessor for capture pattern): `trading/trading/backtest/lib/stop_log.{ml,mli}`
- Trace (predecessor for collector pattern): `trading/trading/backtest/lib/trace.{ml,mli}`

## Approach

### Capture-strategy choice — Option A (in-strategy capture, sibling sexp file)

Three options were evaluated:

- **Option A: enrich `Trade_log` / observer pattern**. Add a
  `Trade_audit` collector that mirrors `Stop_log`'s shape: pure
  observer, mutable collector seeded by the strategy at known capture
  points, persisted alongside `trades.csv` as `trade_audit.sexp`
  (sexp because the records are deeply nested). Capture sites are
  inside `_run_screen` (macro/sector/screener output) and
  `entries_from_candidates` (per-entry sizing + stop calc). Exit
  context piggybacks on `Stop_log`'s existing `TriggerExit` capture.
- **Option B: separate `Trade_decision_trail` module subscribing to
  per-Friday simulator events**. More invasive — requires an event
  bus on the simulator's per-step callback, which doesn't exist
  today; would force changes to `Simulator` and the strategy
  interface.
- **Option C: post-hoc reconstruction by replaying the strategy on
  each entry date**. Cleanest decoupling but ~10× expensive (every
  trade triggers a partial rerun) and only approximate (the strategy
  is stateful via `prior_macro` / `prior_stages`, so post-hoc replay
  diverges from the live decision unless we also persist the full
  state snapshot — at which point we're back to Option A with extra
  steps).

**Choosing A.** Reasons:

1. **The observer pattern is already proven** in this codebase
   (`Stop_log`, `Trace`). Same shape: mutable collector + capture
   sites at the strategy/runner boundaries + sexp persistence.
2. **Lowest capture cost**. The data needed already lives in scope at
   the capture sites (`macro_result`, `sector_map`, `screener_result`,
   `entries_from_candidates`'s arguments). We just route it to the
   collector.
3. **Bit-equivalent backtest behaviour**. The audit collector has no
   read paths into the strategy — it only writes. Disabling it
   removes a small amount of overhead and produces a backtest
   identical to today's.
4. **Composes with `Stop_log`**. Exit context is already captured
   there; we extend that record with macro/stage state at exit time
   rather than rebuilding parallel infrastructure.

Option B is rejected because the simulator-event-bus refactor is large
and orthogonal — if/when it lands for other reasons, the audit module
can subscribe to it and we delete the in-strategy capture; that's a
clean migration. Option C is rejected because reconstruction
correctness becomes a second test surface we'd have to maintain in
parallel.

### Data model

Two new records, both `[@@deriving sexp]`:

```ocaml
(* trading/trading/backtest/lib/trade_audit.mli sketch *)

(** Decision trail captured at entry. *)
type entry_decision = {
  symbol : string;
  entry_date : Date.t;
  position_id : string;             (* matches Stop_log.stop_info *)

  (* Macro state at decision time. *)
  macro_trend : Weinstein_types.market_trend;
  macro_confidence : float;
  macro_indicators : Macro.indicator_reading list;

  (* Symbol-level analysis at decision time. *)
  stage : Weinstein_types.stage;
  ma_direction : Weinstein_types.ma_direction;
  ma_slope_pct : float;
  rs_state : Rs.rs_state option;     (* Rs.result.state *)
  rs_value : float option;
  volume_quality : Volume.confirmation option;
  resistance_quality : Resistance.density option;
  support_quality : Support.density option;
  sector_name : string;
  sector_rating : Screener.sector_rating;

  (* Cascade outcome. *)
  cascade_score : int;
  cascade_grade : Weinstein_types.grade;
  cascade_score_components : (string * int) list;
      (* itemised score breakdown: ("stage2_breakout", 30); ("strong_volume", 20); ... *)
  cascade_rationale : string list;
  side : Trading_base.Types.position_side;

  (* Sizing + stop. *)
  suggested_entry : float;
  suggested_stop : float;            (* from screener *)
  installed_stop : float;            (* after initial_stop_buffer *)
  stop_floor_kind : [`Support_floor | `Buffer_fallback];
  risk_pct : float;
  initial_position_value : float;
  initial_risk_dollars : float;      (* (entry - stop) * qty *)

  (* Top-N alternatives that scored higher/comparable but were not chosen. *)
  alternatives_considered : alternative_candidate list;
}

and alternative_candidate = {
  symbol : string;
  side : Trading_base.Types.position_side;
  score : int;
  grade : Weinstein_types.grade;
  reason_skipped : skip_reason;       (* Insufficient_cash | Already_held |
                                          Below_min_grade | Sized_to_zero |
                                          Sector_concentration | Top_n_cutoff *)
}

(** State captured at exit. *)
type exit_decision = {
  symbol : string;
  exit_date : Date.t;
  position_id : string;
  exit_trigger : Stop_log.exit_trigger;

  (* Macro state at exit. *)
  macro_trend_at_exit : Weinstein_types.market_trend;
  macro_confidence_at_exit : float;

  (* Symbol-level state at exit. *)
  stage_at_exit : Weinstein_types.stage;
  rs_state_at_exit : Rs.rs_state option;
  distance_from_ma_pct : float;       (* (close - ma) / ma *)

  (* Holding-period summary captured by the simulator step stream. *)
  max_favorable_excursion_pct : float;  (* peak unrealized gain during hold *)
  max_adverse_excursion_pct : float;    (* trough unrealized loss during hold *)
  weeks_macro_was_bearish : int;        (* Friday count where macro flipped Bearish during hold *)
  weeks_stage_left_2 : int;             (* Friday count where stage was not Stage2 *)
}
```

`alternatives_considered` is the load-bearing field for diagnosing
"alternative-coverage" — when a losing trade lost, was there a
higher-scoring alternative that won? It's captured as the
`Screener.result.buy_candidates` / `short_candidates` list at
decision-time, minus the ones that did get sized + entered.

### Trade rating heuristics

A separate pure module `Trade_rating` consumes
`Trade_audit.entry_decision + exit_decision + Metrics.trade_metrics +
Stop_log.stop_info` and emits per-trade ratings:

```ocaml
type rating = {
  r_multiple : float;
      (* pnl_dollars / initial_risk_dollars; canonical Weinstein metric *)

  decision_quality : [`Aligned | `Misaligned | `Marginal];
      (* Aligned: macro Bullish + Stage2 + grade ≥ B + RS positive
         Misaligned: any of (macro Bearish for long / Bullish for short),
                     stage ≠ 2 (longs) / 4 (shorts), grade ≤ C
         Marginal: otherwise *)

  outcome : [`Win | `Loss];

  cell : [
    | `Good_decision_good_outcome   (* Aligned + Win *)
    | `Good_decision_bad_outcome    (* Aligned + Loss   — pure variance / bad luck *)
    | `Bad_decision_good_outcome    (* Misaligned + Win — gift, don't repeat *)
    | `Bad_decision_bad_outcome     (* Misaligned + Loss — fix the screener / sizing *)
    | `Marginal_*                   (* the marginal-cell variants *)
  ];

  hold_time_anomaly :
    [`Normal | `Stopped_immediately | `Held_indefinitely];
      (* days_held is one of: ≤3 (immediate stop-out — likely whipsaw),
                              ≥365 (held >1y — likely the strategy never re-evaluated),
                              everything else *)

  drawdown_during_trade : float;
      (* max_adverse_excursion_pct — depth of worst point during hold *)

  counterfactual_looser_stop : float option;
      (* if exit_trigger = Stop_loss and the trade reverted within
         <some-config> bars after exit, what would PnL have been at
         exit_date + N? Approximation. *)

  alternative_coverage : [`No_alternatives | `Alternatives_won | `Alternatives_lost];
      (* For losing trades: did a higher-scoring alternative considered
         at the same entry-date end up with positive PnL? Cross-references
         alternatives_considered against later trades. *)
}
```

`r_multiple` is the canonical Weinstein-style metric — PnL expressed
in units of initial risk. A trade that risks $1k and wins $3k is +3R;
one that risks $1k and stops out at -$1k is -1R. The aggregate `R/trade`
distribution tells us whether the strategy has positive expectancy
even at a 28% win rate (it needs an average winner ≥2.5R for that to
work). If we're losing trades at -1.5R and winning at +1.0R, the
strategy is structurally broken even before stop-tuning.

### Audit binary + report

`bin/trade_audit.exe` (in `trading/trading/backtest/bin/`) reads:

- `<output_dir>/trades.csv`
- `<output_dir>/trade_audit.sexp` (new artefact)
- `<output_dir>/summary.sexp`
- `<output_dir>/equity_curve.csv`

and emits `<output_dir>/trade_audit.md` containing:

1. **Run header** — period, universe, key metrics from `summary.sexp`.
2. **Per-trade table** — one row per round-trip:
   `symbol | entry_date | side | grade@entry | macro@entry | stage@entry | r_multiple | hold_days | exit_trigger | cell`.
3. **Outlier callouts** — best/worst 5 by R-multiple, with one-line
   narrative ("entered XYZ Stage2 grade=A, +4.2R; exited on
   signal_reversal 240 days later").
4. **Aggregate breakdowns**:
   - R-multiple distribution (histogram, mean, median, p10/p90).
   - Win rate × cell — does decision-quality predict outcome at all?
   - Win rate by `macro@entry` — does the macro gate work?
   - Win rate by `stage@entry` (was the entry actually in Stage2?).
   - Win rate by sector.
   - Win rate by `cascade_grade`.
   - MAE / MFE distribution (was the strategy sitting on huge unrealized
     gains it gave back?).
5. **Insight section** — auto-generated findings of the form:
   - "Of 95 losing trades, X had macro=Bullish at entry but flipped to
     Bearish during the hold and the strategy did not exit."
   - "Of 95 losing trades, X were stopped out within 3 days (whipsaw)."
   - "Of N grade=A entries, K were losers — grade is uncorrelated with
     outcome."
   - "Of M trades with `Alternatives_won` flag, the average alternative
     R-multiple was Y while the chosen trade was Z — the cascade
     ranking is mis-prioritising."

### System tracing — given a single trade, walk the audit

The `trade_audit.sexp` file is queryable by symbol + entry_date and
gives the full decision trail above. For deeper drilling (e.g. "what
did `Macro.analyze` return on every Friday in the 6 weeks before this
entry?"), the existing trace path
(`Backtest.Trace` + `?trace` arg) is the right shim — it's per-phase,
not per-symbol. Cross-phase per-symbol tracing is *not* in scope
here; the audit answers "what did the strategy think when it pulled
the trigger" but not "what was the per-symbol cascade history leading
up to that pull." That's a separate concern.

## Files to change

By PR. Each PR ≤ ~400 LOC including tests.

### PR-1: Trade_audit module (types + collector + persistence)

- `trading/trading/backtest/lib/trade_audit.{ml,mli}` — new module.
  Mirrors `Stop_log`'s shape: `type t` collector, `create`,
  `record_entry_decision`, `record_exit_decision`, `get_audit ->
  audit_record list`. Sexp on every record type via `[@@deriving sexp]`.
- `trading/trading/backtest/lib/dune` — register the new module.
- `trading/trading/backtest/test/test_trade_audit.ml` — round-trip
  sexp tests for every record type, collector accumulates correctly,
  empty-collector returns []. ~10 tests.
- Touches `Runner.result` to add `audit : Trade_audit.audit_record
  list` (default empty).
- Touches `Result_writer.write` to emit `trade_audit.sexp` next to
  `trades.csv` when `audit` is non-empty.

LOC estimate: 350.

### PR-2: capture sites in screener + strategy + simulator

- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` —
  thread an `?audit:Trade_audit.t option` argument through `make`,
  `_on_market_close`, `_run_screen`, `_screen_universe`,
  `entries_from_candidates`. At `_run_screen` capture macro snapshot.
  In `_screen_universe`, after `Screener.screen` returns, capture the
  full `screen_result` (buy + short candidates) before sizing. In
  `entries_from_candidates`, for each kept entry capture the
  alternative-candidate list (everything in the screener output that
  was not kept), the stop-floor kind from
  `Weinstein_stops.compute_initial_stop_with_floor`, and the installed
  stop level. Per-symbol stage / RS / volume / resistance / support
  state come from the `Stock_analysis.t` already in scope.
  - Strategy-public surface: extend `make`'s optional args by one
    field; existing callers pass `None`. Backtest behaviour is
    unchanged when audit is `None`.
- `trading/trading/backtest/lib/runner.{ml,mli}` — own a
  `Trade_audit.t` per run, pass it through `Weinstein_strategy.make`,
  drain it into `result.audit` in the Teardown phase, mirror
  `Stop_log`'s wiring.
- Exit-side capture: extend `Stop_log.exit_trigger` consumers (in
  `Stops_runner` and the daily-stop-update path) to also call into
  `Trade_audit.record_exit_decision`. The macro state at exit is the
  cached `prior_macro` ref already in scope.
- Tests: extend the existing strategy-level e2e test to verify the
  audit collector is populated with N entries for an N-trade
  scenario; verify alternatives_considered is non-empty when the
  screener has more candidates than fit.

LOC estimate: 500. May split into PR-2a (entry capture) and PR-2b
(exit + alternatives capture) if it grows.

### PR-3: trade_audit.exe markdown renderer

- `trading/trading/backtest/lib/trade_audit_report.{ml,mli}` — pure
  renderer. Input: `audit_record list + Metrics.trade_metrics list +
  Stop_log.stop_info list + Summary.t`. Output: markdown string.
  Functions are pure; binary just orchestrates I/O.
- `trading/trading/backtest/bin/trade_audit.ml` — thin binary. Reads
  the four files, calls the renderer, writes
  `<output_dir>/trade_audit.md`.
- `trading/trading/backtest/bin/dune` — register the executable.
- `trading/trading/backtest/test/test_trade_audit_report.ml` — verify
  the rendered markdown contains the expected per-trade rows for a
  fixture with 3 trades; verify outlier callouts pick the right
  trades; verify graceful handling of zero-trade input.

LOC estimate: 400.

### PR-4: Trade_rating heuristics + aggregate insights

- `trading/trading/backtest/lib/trade_rating.{ml,mli}` — pure module.
  Input: `(audit_record × trade_metrics × stop_info)` triple. Output:
  `rating` record per trade.
- `trading/trading/backtest/lib/trade_audit_insights.{ml,mli}` — pure
  aggregator. Input: rated trade list. Output: `insight list` with
  shape `{ headline : string; supporting_count : int; total : int;
  category : insight_category }` for the report's Insight section.
- Wire both into `trade_audit_report.ml` so the rendered markdown gains
  the rating columns + insight section.
- Tests: rating-classification coverage (every cell of the
  decision-quality × outcome matrix exercised); insight thresholds
  fire at the right counts; alternative-coverage cross-trade lookup
  works.

LOC estimate: 450.

### PR-5: integrate into release_perf_report (optional)

- `trading/trading/backtest/release_report/release_report.{ml,mli}` —
  if `trade_audit.md` exists alongside `summary.sexp`, link it from
  the release report's per-scenario row. Pure additive.
- LOC estimate: 100.

## Risks / unknowns

1. **`alternatives_considered` retention cost.** The S&P 500 golden
   has ~260 Fridays × ~20 max_buy_candidates = ~5K candidate snapshots
   over the run. Each snapshot is a list of `scored_candidate`. A naive
   implementation captures the full candidate list at every screen
   call regardless of whether any entry happens; that's wasteful. The
   collector should only retain the candidate list at the screen calls
   where ≥1 entry actually fires (133 round-trips × ≤20 candidates =
   ≤2.6K candidate records — negligible).

2. **Exit-time state capture timing.** The macro/stage state at exit
   needs to be the state on the *day the exit fired*, not the next
   Friday. For stop-loss exits firing mid-week, we have to read
   `prior_macro` / `prior_stages` as they stand at the time of the
   `TriggerExit`. Both are mutable refs in scope at the
   `Stops_runner` call site, so this is a captured-by-value question
   — done correctly by snapshotting at capture time, not by reading
   them lazily. PR-2 must verify this with a test that runs a
   multi-week scenario where macro flips on Tuesday and a stop fires
   on Wednesday.

3. **PR-1 + PR-2 interaction with `Trade_audit.t` plumbing.** The
   `make` constructor in `weinstein_strategy.mli` already accepts five
   optional arguments. Adding a sixth will need a careful look at all
   call sites — there are several (test fixtures, `Runner`, the
   non-runner exec paths). PR-2 must enumerate them and verify
   passthrough is harmless.

4. **Bit-equivalence under audit-on vs audit-off.** Adding capture
   sites must not change strategy state. Pin this via a parity test:
   run the same scenario with and without the audit collector and
   assert `summary.sexp` is identical. This goes in PR-2.

5. **`Trade_rating.counterfactual_looser_stop` correctness.** This
   field requires post-hoc bar lookup — given an exit_date and a
   would-have-been stop level, what was the price N bars later? Needs
   bar data accessible to the renderer, which today is not — the
   renderer reads `output_dir/` only. Two options: (a) snapshot the
   needed forward bars at exit-time and persist them in
   `trade_audit.sexp`, or (b) the renderer takes an extra
   `--bar-data` flag and re-reads from the data directory. Option (a)
   is cleaner; PR-4 picks it.

6. **Schema migration.** `trade_audit.sexp` is new — no migration.
   But `summary.sexp` and `trades.csv` schemas don't change in this
   plan, so existing consumers are unaffected.

7. **No live-mode hooks.** This plan is backtest-only. Live mode
   would need a different persistence story (per-decision file
   appended each Friday rather than one file at end-of-run). Out of
   scope.

## Acceptance criteria

By the time PR-4 lands:

- Running `dune exec trading/backtest/scenarios/scenario_runner.exe
  -- --dir trading/test_data/backtest_scenarios/goldens-sp500/` produces
  `trade_audit.sexp` alongside the existing `trades.csv`.
- Running `dune exec trading/backtest/bin/trade_audit.exe -- <dir>`
  produces `<dir>/trade_audit.md` with:
  - Per-trade table with all 12 columns named in §"Audit binary +
    report" item 2.
  - At least 3 outlier callouts.
  - Aggregate breakdowns by macro, stage, sector, grade.
  - At least 1 firing insight from the Insight section on the
    sp500-2019-2023 baseline.
- `summary.sexp` is byte-identical to the pre-audit baseline (proven
  by parity test in PR-2).
- The audit can answer the question that motivates this plan: "of the
  95 losing trades on sp500-2019-2023, how many entered with
  macro=Bullish but exited after macro flipped Bearish?" — this number
  appears as an explicit insight bullet in the rendered report.
- All tests pass: `dune build && dune runtest && dune build @fmt`.

## Out of scope

- **Strategy changes themselves.** The audit is for *understanding*,
  not fixing. Once we know which findings the audit surfaces, future
  PRs in `backtest-infra` (regime-aware stops, drawdown circuit
  breaker, segmentation classifier) react to them. Those are
  separate plans.
- **Live-mode hooks.** Backtest-only. A live-mode audit would need
  per-Friday flush instead of end-of-run flush; tracked as a
  follow-up after the backtest version is proven.
- **Per-bar simulator-side instrumentation** ("how did this symbol
  evolve through the cascade across the 12 weeks before entry?").
  That's a parallel-but-orthogonal concern; the existing `Trace`
  module is closer to the right abstraction for it. Not blocking.
- **ML / auto-tuning of cascade weights.** The audit gives the data
  needed to feed such a tuner, but the tuner itself is a separate
  programme.
- **Cross-scenario aggregation.** `release_perf_report` has the right
  shape for this if/when needed (PR-5 is optional). Initial focus is
  per-scenario depth.

## Phasing summary

| PR | What | LOC est. | Owner |
|---|---|---:|---|
| PR-1 | `Trade_audit` types + collector + persistence | 350 | feat-backtest |
| PR-2 | Capture sites in strategy + screener + simulator | 500 | feat-backtest (may split) |
| PR-3 | `trade_audit.exe` + markdown renderer | 400 | feat-backtest |
| PR-4 | `Trade_rating` + insight aggregator | 450 | feat-backtest |
| PR-5 | release_perf_report integration (optional) | 100 | feat-backtest |
| **Total** | | **~1,800** | |

Total scope: ~1,800 LOC across 4–5 PRs over an estimated 1–2 week
implementation window. Each PR is independently mergeable + tests
pass on its own; PR-3 onward consumes artefacts produced by earlier
PRs. PR-2 is the riskiest single step (touches the strategy hot
path); the parity test in §Risks item 4 is the load-bearing safety
net.
