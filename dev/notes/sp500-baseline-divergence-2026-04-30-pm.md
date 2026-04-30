# sp500-2019-2023 baseline divergence on rerun — 2026-04-30 evening

Two independent reruns this evening produce results wildly outside
the pinned baseline ranges in
`trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp`,
on the same code SHA (`4a5ea5c1` = `feat(result_writer): emit ... reconciler`,
PR #712).

## Pinned baseline (set 2026-04-30 by PR #711)

| Metric | Pin (range) | Pin (point) |
|---|---|---|
| total_return_pct | -15..+15 | -0.01 |
| total_trades | 27..37 | 32 |
| win_rate | 31..44 | 37.50 |
| sharpe_ratio | -0.5..0.5 | 0.01 |
| max_drawdown_pct | 3..9 | 5.81 |
| avg_holding_days | 37..50 | 43.03 |
| unrealized_pnl | 330k..450k | 391,949 |
| force_liquidations_count | (no range) | 0 |

Findings-note rerun at 15:06 today (`scenarios-2026-04-30-150622`)
confirmed ~30 round-trips with 0 force-liquidations — i.e. consistent
with the pin (modulo G6 nondeterminism on the 0-vs-4 short count).

## Tonight's reruns (16:21Z and 16:53Z)

Two reruns, same code, same env, same `goldens-sp500/sp500-2019-2023.sexp`
with `(config_overrides ())`:

| Metric | 162116 | 165326 (clean rebuild) |
|---|---:|---:|
| total_return_pct | 26.82 | 32.76 |
| total_trades | 1466 | 1425 |
| win_rate | 53.41 | 53.05 |
| sharpe_ratio | 0.50 | 0.58 |
| max_drawdown_pct | 8.63 | 10.27 |
| avg_holding_days | 3.60 | 3.65 |
| unrealized_pnl | 0 | 1,238,453 |
| force_liquidations_count | 862 | 836 |

trade composition (165326):
- 1403 LONG / 22 SHORT
- 1418 closed via `stop_loss` / 7 empty `exit_trigger` (the same gap
  PR #717 closes by tagging `end_of_period`)

force-liquidation reason breakdown (165326): all `Portfolio_floor`,
firing as early as 2019-01-15 on **profitable** shorts (e.g. ALB short
2019-01-** entered at $109.28, current $73.64, unrealized_pnl
+$40,736.52, force-liquidated at portfolio_floor anyway).

## What this rules out

- **Code drift**: SHA matches; `_build/default/.../weinstein_strategy.ml`
  bit-equal to source.
- **Universe data drift**: `universes/sp500.sexp` unchanged since
  2026-04-28 (#606); 491 symbols intact.
- **G6 amplification alone**: G6 swings are documented as a 0-vs-4
  short count — not a 30-vs-1425 round-trip swing.

## Active hypotheses (not yet diagnosed)

1. **Daily-bar cache drift in `/workspaces/trading-1/data/`**: top-level
   mtime is 2026-04-30 12:53 but per-symbol subdirs (A/, B/, ...) show
   2026-04-15. Something in the dir was touched today; what?
   The 150622 baseline rerun was at 15:06Z (after the 12:53 mtime), so
   if data drift is the cause, it's not THIS rerun's cache that differs.
   Possible: agent worktrees reading the cache cause extra files (logs,
   tmp) to bump the dir mtime, but the bar files themselves are stable.

2. **Portfolio_floor force-liquidation regression**: 836 force-liqs all
   fire on Day 1 (2019-01-15) on shorts with positive unrealized_pnl.
   The semantics of "Portfolio_floor" is "portfolio value below floor",
   and a large basket of shorts with large notional cost basis may
   collectively drag portfolio value below the floor even when each
   individual short is profitable on paper. If so, the `Portfolio_floor`
   trigger's accounting may double-count the short notional. This would
   be a regression vs G3 / G7 / G9 fixes.
   The pinned baseline shows `force_liquidations 0`, so this regression
   is post-pin OR unique to my env.

3. **Build cache contamination from concurrent agent worktrees**:
   ruled OUT by direct diff of `_build/default/<file>.ml` vs source —
   they match. Both the parent worktree and the agent worktrees share
   the same `_build/` (different file inodes but identical content), so
   any contamination would have shown up as a diff. None did.

4. **Some default config that flips on by environment variable**:
   not yet checked. The strategy `default_config` has
   `enable_short_side = true`, which matches the pin's "shorts re-enabled"
   intent. No env-var-keyed default observed in source grep, but
   not exhaustively verified.

## Reproducer

From a clean checkout of `4a5ea5c1`:

```sh
cd trading
dune build
./_build/default/trading/backtest/scenarios/scenario_runner.exe \
  --dir ../trading/test_data/backtest_scenarios/goldens-sp500 \
  --parallel 1 \
  --fixtures-root ../trading/test_data/backtest_scenarios
```

Output lands in `dev/backtest/scenarios-<TS>/sp500-2019-2023/`. Inspect
`actual.sexp` for the metric block and `force_liquidations.sexp` for the
day-1 short-side liquidations.

## Next steps

1. Re-run from a truly clean checkout (`git clean -fxd && dune build`)
   to absolutely rule out `_build/` contamination.
2. If repro confirms, the regression is in
   `trading/trading/weinstein/strategy/lib/force_liquidation_runner.ml`
   or `trading/trading/portfolio/lib/portfolio_risk.ml` — the
   `Portfolio_floor` trigger fires too eagerly when a basket of shorts
   collectively touches the floor.
3. The pinned baseline may need to be re-pinned against the
   reproduced behaviour (or — if the rerun's behaviour is a
   regression — the regression must be fixed first).

## What this is NOT

- Not a build / compile issue.
- Not a "the strategy was changed today" issue (PR #714/#716/#717/#718
  are all default-disabled / test-only / writer-side; none touch the
  Default config behaviour).

## Cross-reference

- Pinned-baseline source: `dev/notes/sp500-shortside-reenabled-2026-04-30.md`
  (PR #711's pinned-rerun report).
- Trade-quality follow-up findings: `dev/notes/sp500-trade-quality-findings-2026-04-30.md`
  (this PR — PR #715).
- G6 nondeterminism investigation: `dev/notes/short-side-gaps-2026-04-29.md`
  §G6 + PR #703.
