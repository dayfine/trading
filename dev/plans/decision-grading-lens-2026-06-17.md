# Decision-grading lens — design (2026-06-17)

**Origin:** user direction 2026-06-17 (`project_next_lever_decision_grading`).
Every grid/experiment this past month judged configs on **top-level aggregate
metrics** (Sharpe, MaxDD, edge-vs-index). That is shallow. The point of a *lens*
is to go **decision by decision** — grade each entry / stop / stage-exit /
laggard-rotation against (a) its realized outcome and (b) the counterfactual of
not taking it — and learn which **decision types** add vs destroy value. We have
done this once, ad-hoc (`dev/experiments/trade-forensics-2026-06-12/`), never as a
repeatable instrument.

**Faithfulness:** this is a pure read-only analysis lens. It changes NO strategy
behavior, so `experiment-flag-discipline` does not apply (no mechanism, no flag).
It is the *measurement* layer, not a strategy dial.

## What already exists (REUSE — do not rebuild)

Code map 2026-06-17 (Explore). Premise correction: **MFE/MAE are NOT "always 0"
anymore** — fixed by PR #1506 (two bugs: `daily_bars_for` → `weekly_bars_for ~n`;
and `emit_exit_audit` now also fires on stage3-force-exit + laggard-rotation +
force-liquidation exits, not just stops). MFE/MAE per trade are live in
`trade_audit.sexp`.

- **`trading/trading/backtest/lib/`** — `Result_writer` emits `trades.csv` (13
  base + 6 `Trade_context` cols incl `entry_stage`, `entry_volume_ratio`,
  `screener_score_at_entry`, `stop_trigger_kind`), `equity_curve.csv`, and
  `trade_audit.sexp` (full `audit_record` list = per-trade `entry_decision` +
  `exit_decision`). `Trade_audit` types in `backtest/lib/trade_audit.mli`.
- **`exit_decision`** (`trade_audit.mli:156`) carries
  `max_favorable_excursion_pct`, `max_adverse_excursion_pct` (populated from
  `exit_audit_capture._excursions` via `Bar_reader.weekly_bars_for`). Exit reason
  enum: `Position.exit_reason` (`strategy/lib/position.mli:159`) →
  `StopLoss | TakeProfit | SignalReversal | TimeExpired | Underperforming |
  PortfolioRebalancing | StrategySignal {label}`. Special exits use
  `StrategySignal{label="stage3_force_exit" | "laggard_rotation"}`.
- **`entry_decision`** (`trade_audit.mli:90`) — full entry context: stage,
  ma_direction/slope, rs, volume_quality/ratio, resistance/support, sector,
  cascade_score/grade, suggested/installed stop, risk_pct, position value,
  `alternatives_considered`.
- **`trading/trading/backtest/trade_audit_report/`** — `Trade_audit_report.load
  ~scenario_dir` joins `trades.csv` + `trade_audit.sexp` + `summary.sexp`.
  `Trade_audit_ratings` already computes per-trade R-multiple, MFE%/MAE%,
  hold-time anomaly, behavioral metrics (over-trading, exit-winners-early,
  exit-losers-late), R1–R8 conformance, cascade-quartile win matrix. CLI:
  `backtest/bin/trade_audit_report_bin.ml`.
- **`analysis/scripts/trade_autopsy`** — has the `missed_gain_pct` post-exit
  continuation pattern, but only for the per-symbol simple strategy (no stops /
  laggard). The pattern is reusable; the tool is not.
- **`Bar_reader.weekly_bars_for ~n ~as_of`** (weinstein strategy lib) — supports
  arbitrary `as_of` + lookback `n`; the same call used for MFE/MAE. **It can read
  bars AFTER an exit** by passing `~as_of` past `exit_date` — this is the hook for
  the counterfactual.

## The gap to build = the COUNTERFACTUAL exit grade

Today MFE/MAE measure excursion **up to the exit**. Nothing measures what happened
**after** the exit. For a winner-let-run strategy the central question is exactly
that: *when we sold, did we leave money on the table (premature) or dodge a drop
(good)?* That is the missing decision grade.

### Phase 1 — post-exit continuation capture (pure lib, TDD)

`Decision_grading.Post_exit` (lib): pure function

```
val post_exit_metrics :
  side:position_side ->
  exit_price:float ->
  exit_date:Date.t ->
  bars:weekly_bar list ->   (* bars at/after exit_date *)
  horizons_weeks:int list -> (* e.g. [4;13;26] *)
  post_exit_result
```

`post_exit_result` per horizon: `continuation_pct` (=(price_at_exit+h / exit_price
- 1), sign-adjusted for side), `post_exit_max_favorable_pct`,
`post_exit_max_adverse_pct`. Long: positive continuation after a sell = gave up
gains. Tests on synthetic bar series (rising / falling / choppy), boundary
horizons, short side sign-flip, missing-bars → None.

### Phase 2 — decision grade + classifier (pure lib, TDD)

`Decision_grading.Grade`: combine realized + counterfactual into a per-trade,
per-decision grade.

- **Exit grade** (the headline). For each closed trade, given realized pnl and
  `post_exit` continuation at horizon H:
  - long sold, continuation ≥ +T_premature → `Premature` (gave up a winner)
  - long sold, continuation ≤ −T_good → `GoodExit` (dodged a drop)
  - else `Neutral`
  Thresholds configurable; faithful defaults T_premature = +10%, T_good = −10% at
  H=13w (one quarter). Report all of {4,13,26}.
- **Entry grade.** Did the position realize positive pnl? what fraction of its MFE
  did it capture (`pnl_pct / mfe_pct`)? tagged with entry context (stage, score,
  volume_ratio) for slicing.

### Phase 3 — aggregation by decision type + markdown (lib + reuse loader)

Group grades by `exit_reason` label (`stop_loss`, `stage3_force_exit`,
`laggard_rotation`, `force_liquidation`, `end_of_period`). Per group report: n,
mean realized pnl%, mean post-exit continuation, **% premature**, **net
value-add** (realized − counterfactual-if-held). This is the systematized,
repeatable version of the 2026-06-12 finding ("stops ≈ net-zero in chop; laggard =
profit engine"). Renderer mirrors `trade_audit_report` markdown style.

### Phase 4 — CLI exe

`backtest/decision_grading/bin/decision_grading_bin.ml`: takes `--scenario-dir`
(reads via `Trade_audit_report.load`) + a bar source (`--snapshot-dir`, same
resolver as `rolling_start_eval`) to fetch post-exit bars; `--horizons 4,13,26`;
`--out report.md`. Lives at `trading/trading/backtest/decision_grading/{lib,bin}`,
deps mirror `trade_audit_report/dune` + `weinstein.strategy` (Bar_reader) +
`data_panel.snapshot`.

### Phase 5 — stretch: paired laggard-rotation counterfactual

Laggard-rotation is special: it sells X to fund a *specific* new buy Y. The right
counterfactual is "did Y outperform X over the subsequent window?" — pair each
rotation exit with the entry it funded (same timestamp), compare forward returns.
Richer than the held-vs-sold baseline; do after Phases 1–4 land.

## Sequencing / constraints

- Each phase < 500 LOC, TDD per CLAUDE.md (skeleton+`.mli` → tests → impl →
  self-review → `dune fmt`). Phases 1–2 are pure (synthetic-bar tests, no data
  gate). Phase 3–4 need a real `scenario_dir` to smoke-test.
- **Container contention:** the top-3000 1998-2026 matrix is running (CPU-bound,
  ~5h left). Per `sweep-hygiene`, do not run heavy concurrent dune/agent work that
  fights it. Design (this doc) is host-only and safe now; **implementation starts
  once the 1998 run frees the container**, or via a single carefully-scoped
  feat-backtest agent if contention proves tolerable.
- QC: pure infra/analysis PR — qc-structural + generic CP1–CP4; domain S*/L*/C*/T*
  rows NA (no strategy logic changed).

## Why this is the right next thing (not more grids)

It is the instrument that makes every subsequent strategy change — including
long-short (Initiative B) — judgeable at the **decision** level instead of by
aggregate Sharpe. "Capitalize the analysis process": turn one-off forensics into a
standing tool. Top-level grids stay as a final confirmation step, not the primary
search.
