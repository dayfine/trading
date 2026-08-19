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
| **delta** | **−38.42pp** | **−11** | −0.1pp | −1.5pp | −405,093 |

Raw runner lines: `raw-results.txt` (salt 0) and `null-control-raw.txt` (salts
1-2, both arms — added 2026-08-19 after qc-behavioral pointed out that four of
the six draws lived only in prose, which is the same defect this file levels at
the promotion side).

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

### The transferable why — a tail-touching lever

> **⚠ Two earlier mechanisms are retracted.** Both were derived from window
> characteristics **before opening `trades.csv` once**:
>
> 1. ~~"Regime-dependent — pays in crash-spanning windows"~~ — refuted by the
>    window dates. 2019-01-02 → 2023-12-29 **contains the COVID crash and the
>    2022 bear**; it is one of the more crash-dense 5y windows available.
> 2. ~~"Window length — the multi-year pathology can't exist in 5 years"~~ —
>    explains an absence of *gain*, not a **−38pp loss**. (qc-structural passed
>    this one; the dissection below disproves it anyway, which is worth noting —
>    a reviewer without the trade files could not have caught it.)
>
> The dissection that found the real answer took four commands.
> `.claude/rules/mechanism-validation-rigor.md` and
> `feedback_always_dissect_before_reporting` both say to do it first.

Joined on `symbol|entry_date`. **`position_id` does not join across arms** —
only **99 of 238** overlap, because the global ticket counter shifts as soon as
the clock cancels anything. It remains the correct *within*-run key.

| cohort | n | net P&L |
|---|---:|---:|
| in control, **not** in armed (what the clock removed) | **59** | **+248,545** |
| in armed, **not** in control (what the freed cash bought) | 48 | **−84,172** |
| shared | 179 | +5,846 (noise) |

So this is **not** "11 trades removed" — it is **59 out, 48 in**. Cancelling a
ticket frees cash that funds entirely different later tickets. Net realized:
control **751,808** vs armed **424,937**.

**The removed cohort is mostly junk.** Median **−2,840**; **40 losers vs 19
winners**. Its positive total is entirely a tail:

| symbol | entry | held | P&L | % |
|---|---|---:|---:|---:|
| **SMCI** | 2022-10-31 | 292d | **+258,902** | **+240.0%** |
| MU | 2020-11-05 | 177d | +62,096 | +63.8% |
| AXON | 2022-10-24 | 117d | +52,080 | +43.7% |
| MPWR | 2021-07-21 | 150d | +41,135 | +19.9% |
| AZO | 2021-03-11 | 107d | +28,608 | +15.0% |

Top 5 = **+442,821 = 178%** of the cohort's net. **SMCI alone exceeds the entire
cohort's net.**

Tracing those five across arms:

- **MU, AZO** — simply **absent** when armed. Ticket cancelled, never re-issued.
- **AXON, MPWR** — keep their small early losers, **lose the later winner**.
- **SMCI** — re-enters *earlier* (2022-08-18), is stopped out at **−17.4%**
  after 33 days, and never catches the real breakout.

**The clock cuts the resting-ticket population blind, and that population is
where the fat-tail winners live.** The −38.42pp is, to a first approximation,
one trade.

### Why this settles the promotion question

The clock's effect in **both** directions is dominated by whether it happens to
cancel a monster. That explains the promotion cell (+126.7pp on top3000 ×
2000-2026) with no additional hypothesis — and is precisely why that figure sits
**below its own base's 132.5pp seed-noise floor**.

**A coin flip on the tail is not a promotable mechanism**, whatever its sign on
one window. This is the 12th+ confirmation of `project_edge_is_the_fat_tail`;
the clock joins harvest-rotate, trim, re-time and cap.

**If a bound is wanted for correctness** — defect E, `FUL-wein-64` resting 21.7
years, 865-week max fill age — that argues for a value like **156 weeks** that
touches only the genuinely absurd tail, not **26**, which cuts deep into the
live distribution where the monsters are.

### Why the 2×2 grid in `grid.sh` was NOT run

The script is committed for the record and is still correct as written, but it
was **deliberately not run**.

It was designed to separate *window length* from *universe breadth* across four
single runs. Once the effect is understood as a tail lottery, **single runs
cannot resolve it** — this base's own seed spread is 132.5pp, larger than the
promotion cell's entire measured gap. More *cells* is the wrong axis; more
*salts per cell* is the right one, and the conclusion (do not promote) is
already established by mechanism.

Running it would have spent ~4 container-hours re-measuring noise, which is the
error `feedback_run_the_null_control_first` exists to prevent. Anyone reviving
it should add salts first.

## CI reproduces the salt-0 pair independently — to the cent

Reading the scenario `summary.sexp` from the two postsubmit runs' artefacts
(`9359806063` on the parent, `9361240272` on the merge commit):

| metric | parent (`clock=0`) | merge commit (`clock=26`) |
|---|---:|---:|
| `totalreturnpct` | 108.23 | 69.81 |
| `numtrades` | 238 | 227 |
| `totalpnl` | 751,808.07 | 424,936.24 |
| `largestwindollar` | **258,902.38** | 170,802.85 |

The control's `largestwindollar` is **SMCI to the cent**, and it is absent from
the armed arm — the decomposition above, confirmed on different hardware in a
different environment.

> **⚠ Correction, 2026-08-19.** An earlier version of this section claimed the
> golden "was `success` on the parent commit and **FAIL** on the merge commit".
> **That is false and is withdrawn.** The workflow *job* was `success` on both
> (the step is `continue-on-error`), and the *scenario* has FAILED on every run
> back to `e00bb5a90` on 08-18 — a full day before the promotion merged. It is a
> **standing pre-existing red** against a 110.78 floor, not a status flip. The
> claim compared a job conclusion against a step result.
>
> The artefact comparison above is the honest form and is strictly stronger: a
> status flip would prove nothing about *which* change caused it, whereas two
> reproduced metric sets pin the paired effect directly. Caught by qc-behavioral
> on PR #2397.

**Note this revert does not return the golden to green.** 108.23 still sits
below the 110.78 floor. That gap is a separate, older problem; the clock is
responsible for the 38-42pp on top of it, not for the whole shortfall.

## Process finding worth keeping

**The golden that catches this runs post-merge only.**
`.github/workflows/golden-runs-sp500-5y.yml` fires on push to `main`, not on
pull requests, and its step is `continue-on-error: true` during soak. So CI on
the PR said nothing about it either way.

**And a standing red is worse than a flipping one**: because the scenario was
already failing, there was no transition for anyone to notice. A regression
landed inside an existing failure and was invisible by construction. A check
that is allowed to stay red indefinitely stops being a check.

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
