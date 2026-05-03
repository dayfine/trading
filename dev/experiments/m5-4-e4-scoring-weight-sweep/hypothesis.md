# M5.4 E4 — Scoring-weight sweep: hypothesis

## Date
2026-05-03

## Hypothesis

> The screener's current scoring weights (`Screener.default_scoring_weights`)
> were hand-set in 2026-Q1 against a single qualitative ordering — stage
> > rs ≈ volume > resistance > sector. A one-axis-at-a-time perturbation
> sweep on the canonical sp500-2019-2023 multi-regime golden will reveal
> which axis materially moves risk-adjusted return (Sharpe, Calmar) and
> which is noise relative to the win-rate / total-return surface.

Per `dev/plans/m5-experiments-roadmap-2026-05-02.md` §M5.4 E4.

## Why this experiment exists

The plan calls for a 3×3×3×3 grid (~81 cells) over the four primary
weights — too expensive to run as a flat sweep without a tuner. This is
the **manual prequel**: 8 single-axis perturbations that establish which
weight has signal before T-A grid search (M5.5) wires up. If the sweep
shows one axis dominates Sharpe, the tuner's grid can collapse to 1-D
on that axis. If three axes look interchangeable, the tuner needs the
full grid and an interpretable objective to decide which.

The weights being swept (per `Screener.default_scoring_weights`):

| Field | Default | Signal it captures |
|---|---|---|
| `w_stage2_breakout` | 30 | Clean Stage1→Stage2 transition (highest single weight) |
| `w_strong_volume` | 20 | Volume confirmation at breakout |
| `w_adequate_volume` | 10 | Half-credit volume confirmation |
| `w_positive_rs` | 20 | Steady positive RS trend |
| `w_bullish_rs_crossover` | 10 | RS crossing from negative to positive |
| `w_clean_resistance` | 15 | Virgin territory / clean overhead |
| `w_sector_strong` | 10 | Sector rated Strong |
| `w_late_stage2_penalty` | -15 | Late-Stage2 (the only negative weight) |

## Sweep grid

8 cells, each perturbing one axis from default while leaving the others
unchanged:

| Cell | Description | Override (vs default) |
|------|-------------|------------------------|
| `baseline` | control | (none) |
| `equal-weights` | 4 primary axes equalised | `w_stage2_breakout=20 w_strong_volume=20 w_positive_rs=20 w_clean_resistance=20` |
| `stage-heavy` | stage transition 2x | `w_stage2_breakout=60` |
| `volume-heavy` | both volume tiers 2x | `w_strong_volume=40 w_adequate_volume=20` |
| `rs-heavy` | both RS levers 2x | `w_positive_rs=40 w_bullish_rs_crossover=20` |
| `resistance-heavy` | clean overhead 2x | `w_clean_resistance=30` |
| `sector-heavy` | sector strong 2x | `w_sector_strong=20` |
| `late-stage-strict` | late-stage penalty 2x harsher | `w_late_stage2_penalty=-30` |

All on `goldens-sp500/sp500-2019-2023` (491-symbol S&P snapshot,
2019-01-02 .. 2023-12-29; same window as canonical golden + E3).

The "2x default" choice is uniform across cells so the magnitude axis
stays comparable. `equal-weights` is the only multi-axis cell; it tests
whether the relative weighting matters at all (if equal-weights ≈
baseline, the weighting hierarchy is informational not behavioural).

## Falsification criteria

The hypothesis is **not supported** if:

1. **All 7 perturbations land within fuzz IQR of baseline.** The
   sp500-2019-2023 fuzz baseline (PR #788) spans +37.92%–+60.86% on
   total return; if every weight cell falls in that band, the cascade's
   weighting is dominated by upstream filtering (stage classifier, RS
   gate, sector pre-filter) and the score-rank is just choosing among
   already-acceptable candidates.
2. **`equal-weights` matches `baseline` within ±5% return.** Strong
   evidence the four-axis hierarchy doesn't affect candidate selection
   — likely because the cap (`max_buy_candidates=20`) dominates and the
   relative order within top-20 doesn't change which positions actually
   get traded.
3. **No single axis consistently dominates the others.** If
   `stage-heavy`, `volume-heavy`, `rs-heavy`, and `resistance-heavy`
   produce statistically indistinguishable Sharpe/Calmar, then T-A
   tuner work is unwarranted and effort should redirect to grade
   thresholds, the entry/stop pricing block (`candidate_params`), or
   structural changes upstream.

Conversely, the hypothesis is **supported** if:

- Two or more cells differ from baseline by ≥10% on Sharpe AND the
  ordering is consistent with a clear directional bet (e.g., RS-heavy
  improves Sharpe, sector-heavy does not).
- `late-stage-strict` materially reduces total trades while preserving
  return — direct evidence the default penalty under-cuts marginal
  setups.

## Expected qualitative shape

Naive priors (to be falsified or confirmed):

- **`stage-heavy`**: Tightens the score top-end without changing which
  symbols enter the top-20. Expectation: marginally fewer trades,
  marginally higher win rate, ambiguous total return.
- **`volume-heavy`**: Promotes high-volume names that were borderline
  on stage. Expectation: noticeable shift in which symbols trade, with
  unclear directional return effect — depends on whether high-volume
  breakouts on this universe are good signal or noise.
- **`rs-heavy`**: Same shape as volume-heavy but on a Weinstein-purer
  signal. Best bet for a positive Sharpe move per Ch. 4.
- **`resistance-heavy`**: Smaller cardinality of "virgin territory"
  candidates than other axes; doubling its weight may not even reorder
  the top-20. Expectation: smallest behavioural change.
- **`sector-heavy`**: Sector context already filters via the
  Strong/Weak gate; the bonus is additive on top. Doubling it likely
  has small effect on return but visible shift in sector composition.
- **`equal-weights`**: Almost certainly indistinguishable from baseline
  unless the score's tail (rank 15–20) matters more than rank 1–10.
- **`late-stage-strict`**: The clearest predicted effect — reduce trade
  count by ~5–15% while improving win rate, since the doubled penalty
  cuts trades that scored just-barely-above-min-grade.

## What this experiment does NOT prove

1. **One window is one regime ensemble's worth of data.** sp500-2019-2023
   covers five regimes but is one universe; the same sweep on a 2008
   GFC window may invert the verdict.
2. **One-axis-at-a-time misses interactions.** A tuner-driven grid is
   needed to detect whether `rs-heavy + volume-heavy` jointly outperform
   either alone.
3. **The score weights don't dominate the cascade.** If macro gate +
   sector pre-filter + min-grade cut + max_buy_candidates cap
   collectively select 95% of positions before scoring matters, the
   sweep may just measure noise on the residual 5%. This itself would
   be a useful finding — it would redirect tuner work upstream.
4. **Survivorship bias.** Universe is today's S&P 500. Norgate fix
   forthcoming (M5.3).

## Relationship to M5.5 (tuning)

If this sweep identifies one or two dominant axes, T-A grid search
(M5.5) collapses from 4-D to 1-D or 2-D — order-of-magnitude wall
saving. If the sweep shows no single axis matters, T-A still runs the
full 4-D grid but with an empirical noise floor from this sweep to
stop early when no cell beats baseline by the noise threshold.

This sweep is the **prior** that informs how T-A is parameterised. It
is not itself a tuning step — it doesn't search; it samples 8 specific
points to see whether the search is worth running.
