# clock-26 golden A/B — the second cell, and it disagrees

A paired single-knob A/B of `entry_order_max_rest_weeks` on
`goldens-sp500/sp500-2019-2023-armed-stoplimit`, the **only one of 27 golden
specs that arms `enable_sim_entry_stoplimit`** and therefore the only one where
the clock can bite at all (Market entries fill immediately and never rest).

Run 2026-08-19 against PR #2384 (the user-directed `0 → 26` default flip), from
a worktree pinned at that PR's tip `4d079a54`.

## Result

| arm | return | trades | win% | maxDD | open positions |
|---|---:|---:|---:|---:|---:|
| `clock=0` (control) | **108.23%** | 238 | 35.3% | 16.0% | 1,878,875 |
| `clock=26` | **69.81%** | 227 | 35.2% | 14.5% | 1,473,782 |
| **delta** | **−38.42pp** | **−11** | −0.1pp | −1.5pp | −404,918 |

Raw runner lines: `raw-results.txt`.

### Why this is a clean measurement

- **One-line spec diff.** `diff` between the two staged specs is exactly
  `> ((entry_order_max_rest_weeks 0))`. Nothing else differs.
- **Deterministic.** Backtest nondeterminism was closed by #2279 / #2291.
- **The control validates itself.** `clock=0` lands **within 2.55pp** of the
  golden's own band floor (108.23 vs 110.78) on 238 vs 239.5 trades — i.e. the
  local run reproduces the pinned golden almost exactly. That residual is the
  known local-store-vs-CI difference. It is what makes the armed arm's
  **40.97pp** shortfall attributable to the knob rather than to the environment.
- **`TRADING_DATA_DIR` was set** to `<worktree>/trading/test_data`. Without it
  both arms read the live store and land near 55% — which is exactly how the
  superseded measurement below went wrong.

## What it supersedes

PR #2384's body reported this same spec as `clock=0 → 55.39%`,
`clock=26 → 56.79%`, **delta +1.40pp**, described as "small, positive, and in
the direction the mechanism predicts", with the note that both arms failing near
55% against a 110.78 floor was "a local artifact, not the flip".

The artifact was real but mis-scoped: it was **`TRADING_DATA_DIR` being unset**,
so both arms read the live market-data store instead of the pinned fixtures. The
**+1.40pp figure is withdrawn.** It is not a small-positive version of the truth;
it is a measurement of a different, unintended data set.

## What it means

The promotion rests on **+126.7pp** measured on top3000 × 2000-2026. This is a
different (period × universe) cell — sp500 × 2019-2023 — at **−38.42pp**.

`promotion-confirmation.md`: promote only if the value beats baseline in a strong
majority of cells **and is never badly dominated in any**. It is badly dominated
here. **Do not promote.** Keep the clock default-off as an axis (R1 / R2).

### The transferable why — window length, not regime

> **⚠ A first version of this section blamed market regime and is retracted.**
> It called sp500 2019-2023 "a near-uninterrupted bull run" where removing
> exposure merely forgoes gains. The window is **2019-01-02 → 2023-12-29** and
> contains **the COVID crash (−34% SPX) and the 2022 bear (−25%)** — one of the
> more crash-dense five-year windows available. The regime story was refuted by
> the very cell it was built on. **Check the window dates before attributing a
> result to regime.**

The account that survives is mechanical rather than narrative.

The clock exists to remove **multi-year resting orders** — defect E,
`FUL-wein-64` resting **21.7 years**, max fill age **865 weeks** on the 26-year
null. **That pathology is structurally impossible in a five-year window**: no
ticket can rest longer than the window itself.

So on sp500 2019-2023 a 26-week bound removes *none* of the tickets the
mechanism was designed for. It can only cut tickets that would have filled
inside the window — **all cost, no available benefit**. That is exactly the
shape of the measurement: −38.42pp on −11 trades, with drawdown falling too
(16.0% → 14.5%) because what was removed was exposure, not error.

On top3000 2000-2026 the same bound cuts 89 fills spanning 27 → 865 weeks, and
the multi-year tail is real money.

### The two measured cells are CONFOUNDED — this is the grid's job

They differ in **both** window length (26y vs 5y) **and** universe breadth
(3000 vs 500). Neither factor can be attributed from these two points alone.
The discriminating 2×2 completes the square:

| cell | window | universe | prediction if WINDOW LENGTH drives |
|---|---|---|---|
| sp500-2019-2023 ✓ measured | 5y | 500 | hurts — **−38.4pp** ✓ |
| top3000-2000-2026 ✓ measured | 26y | 3000 | helps — **+126.7pp** ✓ |
| `sp500-2010-2026` | **16y** | **510** | **helps**, despite the narrow universe |
| `six-year-2018-2023` | **6y** | **1000** | **hurts**, despite the broad universe |

If universe breadth is the driver instead, the two open predictions invert.
**One hypothesis dies either way**, which is what makes this a test rather than
the survey a generic "confirmation grid" would have been.

### What follows for the default

The window-length account is *less* forgiving than the regime one it replaces.
Regime-dependence would have left room for "fine in the windows we care about";
window-length says the clock is a **long-horizon correctness fix that charges a
real cost at every horizon**, and its benefit only materialises when the window
is long enough to contain the pathology. A single global default of 26 charges
every short-window user the cost with no access to the benefit.

## Process finding worth keeping

**The golden that catches this runs post-merge only.**
`.github/workflows/golden-runs-sp500-5y.yml` fires on push to `main`, not on
pull requests, and its step is `continue-on-error: true` during soak. So CI green
on the PR said nothing about it, and a merge would have moved the golden −38pp
while reporting success.

Generalisation: **when a PR changes a config default, identify which goldens arm
the affected knob and run them by hand.** "Only 1 of 27 goldens is affected" is a
statement about blast *breadth*, not blast *depth*.

## Reproducing

```sh
git worktree add --detach .claude/worktrees/golden-clock26 <sha>
# stage two copies of the golden differing only by ((entry_order_max_rest_weeks 0))
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/.claude/worktrees/golden-clock26/trading && \
  eval $(opam env) && export TRADING_DATA_DIR=$PWD/test_data && \
  dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
    --dir <staged-dir> --parallel 1 --fixtures-root $PWD/test_data/backtest_scenarios'
```

~20 minutes per arm.
