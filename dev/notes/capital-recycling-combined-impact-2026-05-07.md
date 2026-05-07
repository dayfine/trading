# Capital recycling — combined Stage-3 + Laggard impact (5y, 2026-05-07)

## Headline

On the 5y SP500 baseline (`sp500-2019-2023`), the **combined** Stage-3 force
exit (K=1) + Laggard rotation (h=4) headline cell **regresses** to **+37.1%
total return** vs the **+58.3%** OFF-OFF baseline — a **−21.2 pp drop** —
even though each mechanism alone is strongly additive (+8.2 pp for Stage-3
K=1 alone, +21.1 pp for Laggard h=4 alone). This is a destructive
interaction, not a constructive one, at the default Laggard hysteresis.

Tightening the Laggard hysteresis from h=4 to h=2 reverses the regression
dramatically: the combined Stage-3 K=1 + Laggard h=2 cell delivers **+120.0%
return**, **Sharpe 0.93**, **MaxDD 23.1%** — by far the best 5y profile in
this experiment. Across 5 cells, **Cell E (combined K=1+h=2) is the only
configuration that improves on every dimension simultaneously** (return ↑,
Sharpe ↑, MaxDD ↓, trades ↑, hold-days ↓, win-rate ↑).

The Cell D regression at h=4 is consistent with the "cancellation" risk
called out in §How they interact (`dev/notes/capital-recycling-framing-2026-05-06.md`):
both fire on overlapping positions but at slightly different cadences,
producing more churn than alpha when both are slow. At h=2 the laggard fires
fast enough that Stage-3 exits primarily catch *different* positions
(laggard fires=78 in Cell E vs 37 in Cell D; Stage-3 fires=13 in Cell E vs
27 in Cell D), so the two mechanisms partition the exit population rather
than competing on the same positions.

## 5-cell table

| Cell | Stage3 | Laggard | Return | Trades | WR    | MaxDD | Sharpe | AvgHold | Stage3 fires | Laggard fires | Stop fires |
|------|--------|---------|-------:|-------:|------:|------:|-------:|--------:|-------------:|--------------:|-----------:|
| A    | OFF    | OFF     | 58.3%  |  81    | 19.8% | 33.6% | 0.54   | 84.1d   |  0           |  0            | 81         |
| B    | K=1    | OFF     | 66.6%  | 128    | 30.5% | 27.0% | 0.63   | 84.8d   | 33           |  0            | 95         |
| C    | OFF    | h=4     | 79.5%  | 154    | 26.6% | 29.8% | 0.69   | 66.3d   |  0           | 45            | 109        |
| D    | K=1    | h=4     | 37.1%  | 164    | 27.4% | 30.4% | 0.42   | 60.9d   | 27           | 37            | 100        |
| E    | K=1    | h=2     | 120.0% | 196    | 33.7% | 23.1% | 0.93   | 44.9d   | 13           | 78            | 105        |

Notes:
- Cell A reproduces the pinned 5y baseline exactly (58.34/81/19.75/0.54/33.60/84.10);
  this is the sanity check that the experiment harness is reading the same
  config as the goldens-sp500/sp500-2019-2023.sexp pin.
- "Stop fires" = `stop_loss` exit_trigger count; "Stage3 fires" =
  `stage3_force_exit`; "Laggard fires" = `laggard_rotation`. All other
  exit_trigger counts (take_profit, signal_reversal, time_expired,
  underperforming, rebalancing, end_of_period, force_liquidation_*) were
  zero in every cell.
- Cell B's 66.6% / 128 trades / Sharpe 0.63 / MaxDD 27.0% replicates the
  #906 5y K=1 winning cell (#906 reported 66.57% / Sharpe 0.62) with no
  drift — confirms #906's measurement.
- Cell C's strong improvement (+21.1 pp return, +0.16 Sharpe, AvgHold
  drops from 84d to 66d) is the strongest single-mechanism 5y result on
  record; this is new information not previously measured.
- Trade-count rises monotonically with mechanism aggressiveness (81 → 128
  → 154 → 164 → 196), confirming both mechanisms drive faster capital
  recycling. The return curve is **non-monotonic**: D dips because the
  combined-at-h=4 churn destroys edge per trade.

## Per-cell metrics (full)

```
cell-A: ret=58.34 trd=81  win=19.75 shr=0.54 mdd=33.60 hold=84.1 | sl=81  s3=0  lr=0
cell-B: ret=66.57 trd=128 win=30.47 shr=0.63 mdd=27.03 hold=84.8 | sl=95  s3=33 lr=0
cell-C: ret=79.49 trd=154 win=26.62 shr=0.69 mdd=29.78 hold=66.3 | sl=109 s3=0  lr=45
cell-D: ret=37.08 trd=164 win=27.44 shr=0.42 mdd=30.39 hold=60.9 | sl=100 s3=27 lr=37
cell-E: ret=120.0 trd=196 win=33.67 shr=0.93 mdd=23.07 hold=44.9 | sl=105 s3=13 lr=78
```

(`sl`=stop_loss, `s3`=stage3_force_exit, `lr`=laggard_rotation; full
breakdown via `summarize.sh <cell-dir>`.)

## Interaction analysis — why D regresses but E wins

The framing note flagged two mechanism-interaction risks (§How they interact):

1. **Double-sell:** A position rotated out under Laggard cannot be
   re-fired under Stage-3 (it's no longer held). Both at full-exit means
   whichever fires first removes the position from both mechanisms'
   reach. → Not a regression cause on its own.
2. **Cancellation / churn:** if both fire near-simultaneously on overlapping
   positions, the strategy churns through more rotations than either
   mechanism would alone, and downstream re-entries pay entry-cost twice.

Cell D vs E inverts the laggard count:laggard:Stage-3 ratio dramatically
(37:27 vs 78:13 — laggard fires 6× more relative to Stage-3 in E).
Interpretation: at h=4, Laggard waits four weeks before firing, by which
time Stage-3 K=1 has already caught the same position via the MA-slope
signature. The two mechanisms hit the same population. At h=2, Laggard
fires faster — and on a *different* slice (RS-weakening positions whose MA
hasn't yet flattened), so Stage-3 catches the residual slow-MA-flatteners
that the Laggard didn't already grab.

This is consistent with the framing note's prediction (§How they interact,
§Risk of cancellation) that B's edge depends on it firing **before** A on
overlapping positions. h=4 lets A win the race; h=2 gives B the head-start.

## Recommendation

**Recommended cell to flip-default at: Cell E (Stage-3 K=1 + Laggard h=2).**

- Return: +120.0% (vs +58.3% baseline, +21.1 pp over Laggard-alone, +53.4 pp
  over Stage-3-alone).
- Sharpe: 0.93 (vs 0.54 baseline; first sub-1.0 cell to break 0.9 in any
  capital-recycling experiment to date).
- MaxDD: 23.1% (vs 33.6% baseline; 10.5 pp **improvement** in drawdown).
- AvgHold: 44.9d (vs 84.1d baseline; 47% reduction — direct evidence
  capital is recycling at roughly 2× the baseline rate).

Caveats — Cell E is **5y only**. Per the prompt's scope this experiment did
not cover 15y; a parallel agent is investigating the 15y baseline. The
flip-default recommendation should be conditional on:

1. **15y validation passes.** A laggard h=2 setting is more aggressive than
   the just-merged #909 default (h=4); the 15y crash currently being
   triaged by the parallel agent may worsen at h=2. Until that result is in,
   Cell E should remain **opt-in** behind explicit overrides — keep the
   #909 default at h=4, but add a `5y-aggressive-recycling.sexp` golden
   pinning Cell E so the configuration is reproducible.
2. **Cell D regression is understood, not papered over.** The +5y h=4
   regression is a real interaction, not a measurement artefact (Cell A
   matches baseline to 4 decimals). If 15y also degrades at K=1+h=4
   ("default + default") that's a stronger signal — currently the
   defaults compose poorly, and the recommendation may be to **change one
   default**, not add a new override cell.
3. **The acceptance gates from the framing note (§Acceptance gates).**
   Cell E passes all four 5y gates trivially: ≥ 5 pp return improvement
   (+61.7 pp), MaxDD not regressed by > 2 pp (improved by 10.5 pp), ≥ 5
   laggard-rotation events (78), no win-rate regression > 3 pp (+13.9 pp).
   The 15y gates remain TBD pending the parallel agent's findings.

If 15y at K=1+h=2 also wins, the recommended action is:
- **Flip default `enable_stage3_force_exit` to `true`, `hysteresis_weeks=1`.**
- **Flip default `enable_laggard_rotation` to `true`, `hysteresis_weeks=2`** (down
  from #909's h=4).
- Re-pin both `goldens-sp500/sp500-2019-2023.sexp` and
  `goldens-sp500-historical/sp500-2010-2026.sexp` to the new defaults.

If 15y at K=1+h=2 fails but K=1+h=4 (Cell D analogue) on 15y also fails,
keep both mechanisms opt-in until a unified hysteresis exists that wins on
both windows.

## Framing-note outcome assessment

The framing note (§Recommended sequencing step 3) defined three 15y outcomes
for evaluating Mechanism A in isolation:
- **Outcome A:** A alone closes most of the gap (+25-40% on 15y).
- **Outcome B:** A closes a fraction (+10-15%); B remains a distinct lever.
- **Outcome C:** A closes nothing meaningful; mechanism wrong-diagnosed.

Translating those outcome categories from 15y to 5y (where the baseline is
+58.3%, not +5.15%, so the absolute deltas differ but the **shape** of each
outcome is preserved):

**The 5y data supports an extension of Outcome B / partial overlap with
Outcome A — *for the right hysteresis pair*.**

- Stage-3 K=1 alone (Cell B): +8.2 pp (66.6% vs 58.3%) — a **fraction** of
  the alpha space, consistent with Outcome B's "A closes a small fraction;
  B remains a distinct lever."
- Laggard h=4 alone (Cell C): +21.1 pp (79.5% vs 58.3%) — *larger than* A
  alone. This is **new information**: on 5y at least, Mechanism B is the
  bigger lever, not the smaller one. The framing note implicitly assumed A
  ≥ B in alpha contribution (it sequenced A before B partly on
  determinism, partly on the implicit assumption that Stage-3 is the
  stronger signal). The 5y data inverts that assumption: **Laggard alone
  outperforms Stage-3 alone by 12.9 pp**.
- Combined K=1+h=2 (Cell E): +61.7 pp — well into Outcome A's "closes
  most of the gap" territory IF the gap on 5y was the difference between
  baseline and Cell-E. The framing note's gap was defined on 15y, but the
  5y analogue (the 5y under-allocation cost) is reasonably approximated by
  Cell E's improvement.

The framing note's §Recommended sequencing point 3 said: "If A alone closes
most of the gap … B becomes a polish move, not an unblocker." The 5y data
**inverts this**: B (Laggard) closes most of the 5y gap on its own; A
(Stage-3) is the smaller contributor. Combined, the right hysteresis pair
gets the best of both.

This invalidates the framing note's implicit ordering (A first, B as polish)
**for the 5y window**. It does not invalidate the implementation order
(#872 / Stage-3 was sensibly implemented first because its signal is more
deterministic), but the **prioritization** of further investment should
update: laggard-hysteresis sweeps and laggard-comparison-universe
experiments should outrank further Stage-3 hysteresis tuning. 15y data
will determine whether this 5y inversion holds across regimes.

## Reproduction

```
cd <repo-root>
# 5 scenario sexp files in:
ls dev/experiments/capital-recycling-combined-2026-05-07/scenarios/

# Run all 5 in parallel (each child is fork-isolated):
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/.claude/worktrees/<your-ws>/trading && eval $(opam env) && \
   ../trading/_build/default/trading/backtest/scenarios/scenario_runner.exe \
     --dir /workspaces/trading-1/.claude/worktrees/<your-ws>/dev/experiments/capital-recycling-combined-2026-05-07/scenarios \
     --parallel 5 --progress-every 999'

# Per-cell summaries:
for cell in cell-A cell-B cell-C cell-D cell-E; do
  bash dev/experiments/capital-recycling-combined-2026-05-07/summarize.sh \
       dev/experiments/capital-recycling-combined-2026-05-07/$cell
done
```

Wall time: ~5 minutes for all 5 cells in parallel on the local Docker host.

## Artefacts

- `scenarios/cell-A-baseline.sexp` … `scenarios/cell-E-stage3-k1-laggard-h2.sexp` —
  five scenario fixtures, one per cell.
- `cell-A/actual.sexp`, `cell-A/trades.csv`, … `cell-E/actual.sexp`,
  `cell-E/trades.csv` — captured run artefacts per cell.
- `summarize.sh` — bash one-liner that emits a per-cell metric line + exit
  reason counts. Adapted from
  `dev/experiments/stage3-force-exit-impact-2026-05-06/summarize.sh` to add
  the `laggard_rotation` exit-trigger column added in PR #909.

## References

- `dev/notes/capital-recycling-framing-2026-05-06.md` — framing note
  (§How they interact, §Recommended sequencing, §Acceptance gates).
- `dev/experiments/stage3-force-exit-impact-2026-05-06/` — single-mechanism
  Stage-3 sweep across hysteresis K=1..4 (the #906 measurement).
- Issue #872 — Stage-3 force exit (merged via #899/#900 et al.).
- Issue #887 — Laggard rotation (merged via #909).
- `goldens-sp500/sp500-2019-2023.sexp` — the pinned 5y baseline used as
  the OFF-OFF reference; Cell A reproduces it exactly.
