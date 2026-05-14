# P3-followup — Continuation-buy combined-axis tuning (REJECTED on 16y)

## Hypothesis

PR #1091's one-at-a-time sweep identified two best single-axis movers in
the continuation-buy detector knobs:

- `consolidation_weeks = 2` (vs default 4) — 5y Sharpe 0.61 vs 0.59 baseline
- `consolidation_range_pct = 0.15` (vs default 0.10) — 5y Sharpe 0.61 vs 0.59 baseline

Both produced Calmar lifts of 2-3 pp on the 5y window. Combining them on
the same backtest tests two things:

1. **Stacking** — do the effects add (combined > 0.61), or are they
   substitutes (combined ≈ 0.61), or harmful when combined (combined < 0.61)?
2. **Cross-window validity** — does whatever the 5y combined cell shows
   survive the 16y goldens horizon? Per `memory/project_m5-5-tuning-exhausted.md`,
   single-window 5y wins without 10y+16y validation aren't actionable.

## Cells

3 cells × 2 windows = 6 runs.

| Cell | Cont. buys | Knobs |
|---|---|---|
| `combined` | ON | `consolidation_weeks=2` + `consolidation_range_pct=0.15` |
| `baseline-anchor` | ON | ship defaults (`weeks=4`, `range=0.10`) |
| `continuation-off-anchor` | OFF | n/a (Cell E sans continuation) |

Universe + period:
- 5y: sp500.sexp (500 syms), 2019-01-02 → 2023-12-29
- 16y: sp500-historical/sp500-2010-01-01.sexp (510 syms), 2010-01-01 → 2026-04-30

All other config_overrides match PR #1091's Cell E ship config: Stage-3
force exit ON (hysteresis 1), laggard rotation ON (hysteresis 2),
`max_position_pct_long=0.14`, `max_long_exposure_pct=0.70`,
`min_cash_pct=0.30`.

## Results

### 5y window (sp500-2019-2023)

| Cell | Sharpe | Calmar | MaxDD | CAGR | Total return | Trades |
|---|------:|------:|-----:|-----:|------------:|------:|
| `combined` | **0.73** | **0.52** | n/a* | n/a* | n/a* | 548 |
| `baseline-anchor` | 0.59 | 0.41 | n/a* | n/a* | n/a* | 537 |
| `continuation-off-anchor` | 0.56 | 0.40 | n/a* | n/a* | n/a* | 535 |

*MaxDD / CAGR / total-return / win-rate fields for the 5y cells were not
extracted at the time of analysis. The summary.sexp files under
`summaries-5y/` carry the full metric set.

### 16y window (sp500-2010-2026)

| Cell | Sharpe | Calmar | MaxDD | CAGR | Total return |
|---|------:|------:|------:|-----:|------------:|
| `combined` | 0.68 | 0.49 | **15.71%** | 7.63% | 232.15% |
| `baseline-anchor` | 0.69 | 0.46 | 16.99% | 7.80% | 240.76% |
| `continuation-off-anchor` | **0.71** | 0.45 | 19.92% | **8.98%** | **307.16%** |

## Verdict — REJECTED

The 5y → 16y cross-window inverts. On 5y, the combined cell wins by a
big margin (Sharpe 0.73 vs 0.56 off-anchor — +0.17 absolute, bigger than
the sum of the two single-axis lifts of +0.05 each). On 16y, the order
reverses: **continuation-off has the highest Sharpe + CAGR + total return**.
The combined cell achieves the lowest MaxDD (15.71%) but pays for it with
~13 pp of CAGR and ~75 pp of total return.

So:

1. **Continuation-buys are a net drag on 16y** regardless of tuning. The
   defaults already cost ~17 pp of total return (240.76 vs 307.16); the
   tuned combined cell costs ~75 pp.
2. **The 5y win was a single-window artifact.** Exactly the failure mode
   `project_m5-5-tuning-exhausted.md` flags — single-window 5y wins
   without 10y+16y validation are not actionable.
3. The 5y signal isn't completely vacuous — continuation-buys do
   contribute alpha in the 2019-2023 regime (Sharpe +0.17 over off).
   But the regime-specific edge is more than wiped out across the 2010-
   2026 horizon, which includes 2010-2014 (post-GFC recovery), 2014-2018
   (chop), and 2022-2023 (rate-hike grinder). The detector likely catches
   QE-bull-market patterns and stumbles on everything else.

## Next-step follow-up

Continuation-buys should stay default-off. Three live options for the
follow-up:

1. **Regime-gated continuation buys.** Make `enable_continuation_buys`
   conditional on macro regime — eg only fire when `enable_short_side`
   is OFF (defensive proxy for "trend regime"). 4-cell sweep of
   {off, on-always, on-when-bullish, on-when-trend} on both 5y and 16y.
2. **Retire Interpretation B.** The mechanism may simply be unsuitable
   to Cell E's portfolio constraints (slot-budget bind documented in
   PR #1091 + this long-horizon drag). Move on to Interpretation A
   (pyramid adds to existing holdings) — deferred behind a `Position.t`
   core-module decision per `dev/notes/next-session-priorities-2026-05-14.md`
   §"Defer".
3. **Investigate the regime where continuation does work.** 5y window
   was 2019-2023; split into sub-windows and check whether the lift is
   localized to the 2020-2021 post-COVID melt-up. If so, the mechanism
   is a momentum-bull detector dressed up as a Weinstein continuation
   detector, and it should be replaced with an explicit macro gate.

Recommendation: option **(1)** — cheap to test, decisively answers
whether the regime-conditioned variant survives 16y. If it fails, fall
back to (2).

## Reproducibility note

The original experiment worktree was deleted before commit. Six scenario
sexp files reconstructed from PR #1091's `axis3-consolidation_weeks-2`
template; the summary.sexp results under `summaries-5y/` and
`summaries-16y/` are the original outputs (preserved under
`dev/backtest/scenarios-2026-05-14-201358/` and `-201409/` at run time).
