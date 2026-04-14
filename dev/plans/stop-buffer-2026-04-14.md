# Plan: Stop-Buffer Tuning Experiment

Date: 2026-04-14
Track: backtest-infra (feat-backtest agent)
Triggers: Step 3.5 #1 (first deliverable from new agent), #4 (experiment design)

---

## 1. Context

**What is the experiment.** The Weinstein Trading System's initial stop placement
uses `initial_stop_buffer`, a multiplier applied to the screener's
`suggested_stop` when computing the initial stop level for new entries. The
current default is `1.02` (a 2% buffer below the 30-week MA support level). The
hypothesis is that this buffer is far too tight, causing premature stop-outs on
normal intraday volatility.

**What baseline results show.** Across three golden scenarios (2018-2023,
2015-2020, 2020-2024) totalling 375 trades on 1,654 stocks, 74% of trades
(258/375) exit within 0-1 days. This is textbook whipsaw behavior. The win rate
ranges from 28.6% to 47.7%, and closed-trade P&L is negative in 2 of 3
scenarios despite portfolio gains of +27% to +305%. The strategy is "death by a
thousand cuts" — 51.2% of all trades are small losses (<5%).

**Hypothesis.** Widening `initial_stop_buffer` from 1.02 to values in the
1.05-1.15 range will reduce whipsaw exits, increase average holding days,
improve win rate, and improve or maintain total returns. Per Weinstein Ch. 6,
initial stops should sit below the "significant support floor (prior correction
low)" which is typically 5-15% below entry — the current 2% is much tighter than
the book prescribes. Trade-off: wider stops increase per-trade risk when they do
trigger.

**Infrastructure.** PRs #306 (deep-merge `--override` flags), #315 (extracted
`backtest_runner_lib`), and #316 (fork-based parallel scenario runner) were built
specifically to enable this experiment.

---

## 2. Approach

### Experiment variants

Five scenario variants, each differing only by `initial_stop_buffer`:

| Variant | `initial_stop_buffer` | Buffer meaning |
|---------|----------------------|----------------|
| buffer-1.02 | 1.02 | 2% below support (current default / control) |
| buffer-1.05 | 1.05 | 5% below support |
| buffer-1.08 | 1.08 | 8% below support |
| buffer-1.12 | 1.12 | 12% below support |
| buffer-1.15 | 1.15 | 15% below support (book maximum) |

### Periods

Run smoke scenarios first (~5-10 min each). Use the "recovery-2023" smoke period
(2023-01-02 to 2023-12-31) as the primary iteration period — highest trade count
(109 trades in baseline), most statistical signal per run.

Once results are stable, run the winning 2-3 variants on the golden
"six-year-2018-2023" period for full validation (~40 min each).

### Scenario file format

Each variant is a `.sexp` file in
`trading/test_data/backtest_scenarios/experiments/stop-buffer/`. Only difference
is `config_overrides`. Example:

```scheme
;; Stop-buffer experiment: 5% buffer (initial_stop_buffer = 1.05)
((name "stop-buffer-1.05-recovery-2023")
 (description "Stop buffer 1.05 (5%) on 2023 recovery period")
 (period ((start_date 2023-01-02) (end_date 2023-12-31)))
 (config_overrides (((initial_stop_buffer 1.05))))
 (expected
  ((total_return_pct   ((min -50.0) (max 200.0)))
   (total_trades       ((min 0)     (max 200)))
   (win_rate           ((min 0.0)   (max 100.0)))
   (sharpe_ratio       ((min -5.0)  (max 10.0)))
   (max_drawdown_pct   ((min 0.0)   (max 60.0)))
   (avg_holding_days   ((min 0.0)   (max 365.0))))))
```

`expected` ranges intentionally wide (unconstrained) — experiment observes
metric values, doesn't enforce them.

### Running

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune exec trading/backtest/scenarios/scenario_runner.exe -- \
     --dir test_data/backtest_scenarios/experiments/stop-buffer \
     --parallel 5'
```

### Metrics to compare

| Metric | Why it matters |
|--------|----------------|
| `win_rate` | Primary signal — should increase with wider stops |
| `avg_holding_days` | Should increase (fewer 0-1 day exits) |
| `total_return_pct` | Must not degrade significantly |
| `max_drawdown_pct` | Wider stops = larger per-trade loss potential |
| `total_trades` | May decrease (fewer re-entries after whipsaw) |
| `sharpe_ratio` | Risk-adjusted return |
| `ProfitFactor` | Gross profit / gross loss |
| `CAGR` | Annualized return |
| `CalmarRatio` | CAGR / max drawdown |

### Analysis output

`dev/experiments/stop-buffer/report.md` with:
1. Comparison table of all 5 variants across all metrics
2. Recommended buffer value with rationale
3. Notes on non-determinism (variance across repeated runs)

### Golden validation

After identifying best 2-3 buffer values from smoke runs, create golden-period
variants (6-year-2018-2023) and run only promising candidates.

---

## 3. Files to change

### New files (scenario fixtures)

- `trading/test_data/backtest_scenarios/experiments/stop-buffer/buffer-1.02-recovery-2023.sexp` — control
- `trading/test_data/backtest_scenarios/experiments/stop-buffer/buffer-1.05-recovery-2023.sexp`
- `trading/test_data/backtest_scenarios/experiments/stop-buffer/buffer-1.08-recovery-2023.sexp`
- `trading/test_data/backtest_scenarios/experiments/stop-buffer/buffer-1.12-recovery-2023.sexp`
- `trading/test_data/backtest_scenarios/experiments/stop-buffer/buffer-1.15-recovery-2023.sexp`

### New files (results tracking)

- `dev/experiments/stop-buffer/hypothesis.md` — hypothesis statement
- `dev/experiments/stop-buffer/report.md` — comparative metrics table

### No code changes required

Entire experiment runs on existing infrastructure (#306, #315, #316).

---

## 4. Risks / unknowns

1. **Non-determinism.** `Hashtbl` ordering causes variance between runs (#298).
   Mitigation: run each variant 2-3 times, note variance band. If variance
   exceeds signal between buffer values, experiment is inconclusive.

2. **Performance / memory.** 5 variants parallel on smoke: ~5 min each, ~7 GB
   per child = ~35 GB total. If insufficient RAM, reduce `--parallel` to 2-3.
   Golden variants ~40 min each — run sequentially or `--parallel 2`.

3. **`initial_stop_buffer` semantics.** Buffer multiplies `suggested_stop` from
   screener's `base_low`. If `suggested_stop` already well below MA, 1.15 buffer
   may create stops >15% below entry. Experiment measures aggregate impact;
   per-trade stop logging would help diagnose but is out of scope.

4. **Smoke period representativeness.** 2023 recovery is a single regime. Golden
   validation mitigates but doesn't eliminate this risk.

5. **Position sizing interaction.** Wider stops = larger risk-per-trade at same
   `risk_per_trade_pct`. Should naturally result in smaller positions. Worth
   verifying in output.

---

## 5. Acceptance criteria

1. Five `.sexp` files at `experiments/stop-buffer/` loadable by `scenario_runner`
2. `scenario_runner --dir .../experiments/stop-buffer --parallel 5` completes,
   produces `actual.sexp` for all 5 variants
3. Comparison table in `dev/experiments/stop-buffer/report.md` shows all metrics
   for all 5 variants
4. Report identifies whether wider buffers reduce 0-1 day exits and names a
   recommended buffer value (or states inconclusive with rationale)
5. No existing scenario files modified
6. No source code files (`.ml`, `.mli`) modified

---

## 6. Out of scope

- Modify stop machine (`trading/trading/weinstein/stops/lib/`)
- Add new stop types (support-floor-based stops)
- Change `weinstein_strategy.ml` or any strategy code
- Modify existing scenario files in `goldens/` or `smoke/`
- Build formal experiment framework (deferred per backtest-infra.md)
- Per-trade stop logging
- Drawdown circuit breaker
- Bayesian/grid tuner (M6/M7)
- Fix Hashtbl non-determinism
