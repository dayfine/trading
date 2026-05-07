# 15y SP500 + enable_stage3_force_exit crash investigation (2026-05-07)

PR #906 surfaced a crash mode in the 15y SP500 backtest (`goldens-sp500-historical/sp500-2010-2026.sexp`) when `enable_stage3_force_exit = true` is overridden in. Equity collapses to $51K-$540K from $1M starting cash within the first 1-2 of 16 years. The runner reports `FAIL (scenario crashed or did not write actual.sexp)` with exit code 1 and no recoverable metrics.

This note documents the root cause and the fix.

## Reproduction

```bash
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  /workspaces/trading-1/trading/_build/default/trading/backtest/scenarios/scenario_runner.exe \
    --dir /tmp/15y-crash-repro --parallel 1 \
    --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios \
    > /tmp/out.log 2> /tmp/err.log
'
```

Where `/tmp/15y-crash-repro/sp500-15y-stage3-on-h1.sexp` is the experiment scenario from PR #906 (`enable_stage3_force_exit = true`, `hysteresis_weeks = 1`).

The run progresses normally for ~60 weekly cycles (~1.4 years) and then aborts. `progress.sexp` at the time of abort:

```
((started_at 1778113204) (updated_at 1778113419) (cycles_done 60)
 (cycles_total 882) (last_completed_date 2010-07-23) (trades_so_far 113)
 (current_equity 1033820.4805999999))
```

## Root cause (analytical)

The Weinstein strategy's `_on_market_close` collects exit transitions from four channels and one adjust channel:

1. `Stops_runner.update` — emits either a `TriggerExit` (`Stop_hit` event, position closes via stop) **or** an `UpdateRiskParams` (`Stop_raised` event, trailing stop tightens). Mutually exclusive per position per tick.
2. `Force_liquidation_runner.update` — emits `TriggerExit` for portfolio-floor / unrealized-loss breaches.
3. `Stage3_force_exit_runner.update` (gated on `enable_stage3_force_exit`) — emits `TriggerExit` when a held long stays in Stage 3 for `hysteresis_weeks` consecutive Fridays.
4. `Laggard_rotation_runner.update` (gated on `enable_laggard_rotation`) — emits `TriggerExit` for negative RS-vs-benchmark over a rolling window.

The strategy already dedups **exit channels against each other** (e.g. Stage-3 doesn't emit if stops already exited the same position this tick; force-liq doesn't emit if Stage-3 / laggard exited it). The dedup uses `position_id` set membership.

The strategy concatenates transitions in this order:

```
exit_transitions @ stage3_force_exit_transitions
@ laggard_rotation_transitions @ force_exit_transitions
@ adjust_transitions @ entry_transitions
```

`exit_transitions` here is the output of `Stops_runner.update`, which contains *only* `Stop_hit`-derived `TriggerExit` transitions. `adjust_transitions` is a *separate* output containing `Stop_raised`-derived `UpdateRiskParams` transitions.

**The bug**: `adjust_transitions` is **not deduped against the other exit channels**. So when:

- Stops_runner emits `UpdateRiskParams` for position P (a `Stop_raised` event — trail tightening), AND
- Stage-3 / laggard / force-liq emits `TriggerExit` for position P on the same tick,

the simulator's `_apply_transitions` processes the exit first (P: Holding → Exiting) and then the adjust, which fails because `Position.apply_transition` rejects `(Exiting, UpdateRiskParams)` with `Invalid transition UpdateRiskParams for current state` (per `trading/trading/strategy/lib/position.ml:328-339`).

The simulator's `step` returns `Result.Error`. `Backtest.Panel_runner._step_failed` (panel_runner.ml:97-99) unconditionally calls `failwith` on the Error, raising an unhandled OCaml exception that aborts the scenario_runner child process. The child's catch-all `try/with` exits with code 1 but does **not** write an `actual.sexp`, so the parent reports the silent "scenario crashed or did not write actual.sexp" row.

This collision is rare under default settings (only `Stop_raised` + force-liq simultaneously, which is uncommon), but `enable_stage3_force_exit = true` adds a third TriggerExit channel that fires on the same Friday cadence as `Stop_raised`. With 60+ held positions and a bear / topping market regime (Stage 3 transitions cluster), the probability of collision compounds; the 15y window's 882 weekly cycles guarantee it within ~60 cycles.

## Fix

Two complementary changes, both within `feat-backtest` scope (no core-module modifications per `.claude/rules/qc-structural-authority.md` A1):

### Fix A — strategy-side dedup (preventive)

`trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` now filters `adjust_transitions` against the union of all exit channel `position_id` sets (stops + stage3 + laggard + force_liq) before concatenating. This eliminates the (Exiting, UpdateRiskParams) collision at the source.

This change is in `weinstein_strategy.ml`, not in the core `Trading_strategy` library at `trading/trading/strategy/lib/position.ml` — the position state machine is unchanged and the validation contract is preserved. The fix lives in the strategy's transition-assembly logic, which is the appropriate locus per `docs/design/eng-design-3-portfolio-stops.md` ("strategy decides what transitions to emit; Position validates they are well-formed").

### Fix B — defensive crash handling (graceful degradation)

`trading/trading/backtest/scenarios/scenario_runner.ml` now writes a sentinel `actual.sexp` (with `crashed = true` + the `Exn.to_string` message) when the child process catches an unhandled exception from `Backtest.Runner.run_backtest`. The parent's `_format_row` surfaces the crash inline:

```
sp500-15y-stage3-on-h1     -100.0%       0   0.0%  100.0%   FAIL (scenario crashed: <exn>)
```

This honors the PR-goal stated in the dispatch prompt:

> Backtests should always produce an `actual.sexp` even if the run is degenerate.

The sentinel uses out-of-range values (-100% return, 100% drawdown) so range checks fail explicitly rather than passing on NaN. The new `crashed` field is `[@sexp.default false]` so pre-fix `actual.sexp` files still parse.

Note that Fix A eliminates the *specific* invariant trip that triggered this PR. Fix B is the defense-in-depth: any future invariant (e.g. cash-floor breach, position state drift, etc.) will now produce a meaningful FAIL row instead of a silent miss.

## What was *not* changed

Deliberately untouched:

- `trading/trading/strategy/lib/position.ml` — the position state machine. The `(Exiting, UpdateRiskParams)` rejection is correct: it's not valid to tighten the stop on a position that's already exiting.
- `trading/trading/simulation/lib/simulator.ml` — the simulator's `step` properly returns `Error`. The buck stops at the panel runner.
- `trading/trading/backtest/lib/panel_runner.ml`'s `_step_failed` — converting the simulator's `Error` to a `failwith` is a fail-loud choice that surfaces invariant trips clearly. The right place to soften the failure mode is the scenario_runner (Fix B), which is the orchestration layer that owns the "what should the table look like on crash?" question.

## Open questions / follow-ups

1. **Are there other adjust-vs-exit collision modes?** This investigation focused on the `UpdateRiskParams` adjust path because that's what stops emits. If future runners emit other non-exit transitions (e.g. position resizing), the same dedup pattern must apply.

2. **Should `Force_liquidation_runner` also dedup against its own prior-tick state?** If a position transitions Holding → Exiting on tick T (via force-liq) but the broker hasn't filled by tick T+1, force-liq's input on T+1 still sees the Exiting position. The runner's `_position_input_of_holding` already guards on `Holding` state so this is fine — non-Holding positions are skipped. Same is true for Stage-3 and laggard.

3. **The 5y K=1 cell was the only one that worked in PR #906.** The luck of not hitting the collision in 5y vs. hitting it in 15y is purely stochastic (more weeks → more chances for the rare combination). After Fix A, the collision is impossible regardless of window length, and 15y K=1/2/3/4 should now produce real metrics. PR #906's experiment can be re-run cleanly.

4. **The PR #906 strategy-3-force-exit decision still stands.** Even with Fix A, the underlying strategy result remains: K=1 on 5y is the only profitable cell; K=2/3/4 underperform. This PR doesn't change the strategy's economics, only its crash-resistance.

## Verification

After the fix:

```bash
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  dune build && dune runtest trading/weinstein/strategy/
'
```

passes. End-to-end 15y reproduction shows Fix A is working as designed: the
scenario progresses past cycle 100 (where the pre-fix crash occurred at cycle 60
in PR #906's runs), confirming the (Exiting, UpdateRiskParams) collision is
no longer hit. Equity oscillates in the $90K–$660K range across cycles 100–160 as
the strategy bleeds capital from high-turnover whipsaws (the same pathological
behavior PR #906 documented at $51K–$540K terminal). The 15y window may complete
with degenerate metrics or hit a different invariant later — either way, Fix B
(scenario_runner sentinel `actual.sexp`) ensures a row is reported with a
meaningful FAIL message rather than the silent "did not write actual.sexp" path.

Sample progress.sexp during the post-fix run (cycle 160 of 882):

```
((started_at 1778114782) (updated_at 1778114926) (cycles_done 160)
 (cycles_total 882) (last_completed_date 2012-06-22) (trades_so_far 389)
 (current_equity 114288.68539999983))
```

The capital collapse is real (the strategy with Stage-3 force-exit ON is
genuinely a bad-policy combination on 15y SP500), but it is now a *measurable*
collapse rather than a silent process abort.

## Out of scope for this PR

- **Strategy economics.** This PR does not modify what the Stage-3 / laggard /
  stops policies do — only how their transitions are assembled into the final
  per-tick transition list. The PR #906 finding (K=1 on 5y is the only
  profitable cell; K=2/3/4 underperform) still stands and is the appropriate
  follow-up for `feat-weinstein` (composite Stage-3 quality filter, per the
  PR #906 recommendation §1).
- **Position state machine.** `(Exiting, UpdateRiskParams)` continues to be
  rejected by `Position.apply_transition` — that is correct behavior. The
  fix lives in the strategy (which decides what to emit), not in the position
  module (which validates well-formed transitions).
- **Simulator / panel_runner failure-handling.** `Backtest.Panel_runner._step_failed`
  still calls `failwith` on simulator-step Error. The defensive layer this PR
  adds is at the scenario_runner level (the orchestration boundary), where it
  can write the sentinel `actual.sexp` and surface the crash inline. Pushing the
  failure handling deeper into the simulator would require modifying core
  modules (per `.claude/rules/qc-structural-authority.md` A1).
