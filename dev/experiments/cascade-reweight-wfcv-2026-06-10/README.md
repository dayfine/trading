# cascade-reweight-wfcv-2026-06-10

WF-CV surface over the **early-Stage2 scoring weight** (`w_early_stage2`), the axis
shipped by PR #1512 + #1513. Tests the cascade-selection-inversion fix:
confirmed `Stage1→2` breakouts (scored +30) under-perform `Early Stage2` entries
(scored +15) on win-rate across breadths (`dev/notes/cascade-selection-inversion-2026-06-10.md`).

## Hypothesis
Raising `w_early_stage2` from the implicit 15 (`= w_stage2_breakout/2`, via
default `None`) toward / past the breakout's 30 should let the higher-win-rate
early entries out-rank (or tie) the breakouts in the cascade, improving
risk-adjusted return — IF the in-sample edge generalises.

## In-sample screen (already run, top-1000 full 2011-2026)
| | baseline (None=15) | `w_early_stage2=30` |
|---|---|---|
| return | 29.6% | **187.4%** |
| win% | 31.8% | 35.8% |
| Sharpe | 0.19 | **0.36** |
| MaxDD | 42% | 60% (worse) |

Strong in-sample on return + risk-adjusted ratios; higher MaxDD. **But single-window
in-sample — the 2019-26 era showed the early>breakout return edge collapses, so
budget for a likely no-promote under WF-CV.**

## Surface
`spec_top3000.sexp`: axis `screening_config.weights.w_early_stage2 ∈ {Some 22, Some
30, Some 38}` + `None` baseline, Rolling WF-CV on top-3000-2011 2011-2026
(test_days 365, step 365 → ~15 folds), gate Sharpe m=8/n=15 worst_delta 0.30.

## Launch (fork-per-fold for N=3000, per `project_laggard_broad_recheck`)
```
docker exec -d trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && \
  nohup dune exec --no-build trading/backtest/walk_forward/bin/panel_runner.exe -- \
    --spec dev/experiments/cascade-reweight-wfcv-2026-06-10/spec_top3000.sexp \
    --snapshot-dir /tmp/snap_top3000_2011 --fixtures-root / \
    --out-dir /tmp/sweeps/cascade-rw-wfcv --fork-per-fold \
    > /tmp/sweeps/cascade-rw-wfcv.log 2>&1 &'
```
(Verify panel_runner's exact flag names before launch — `--fork-per-fold` /
`--snapshot-dir` per the laggard re-check recipe.)

## Decision
Rank with Variant_ranking (Pareto) + Deflated_sharpe. If a value beats baseline on
the frontier / positive-DSR across folds → confirmation grid (`.claude/rules/promotion-confirmation.md`:
deep regime + different-breadth cells) before any default flip. Per
`experiment-flag-discipline` R3, no default change without a ledger ACCEPT.

## ⚠ Cross-check with the liquidity-realism work
The cascade-inversion finding and the breadth question may both be **liquidity**
stories (`dev/plans/trade-realism-liquidity-2026-06-10.md`). Before promoting any
reweight, check whether A+/breakout entries are systematically in thinner names —
if the inversion is a fill-realism artifact, a liquidity-aware position cap is the
better lever than the scoring reweight.
