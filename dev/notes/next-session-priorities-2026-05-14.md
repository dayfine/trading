# Next-session priorities (2026-05-14)

> **Superseded by `dev/notes/next-session-priorities-2026-05-15.md`** —
> strategic pivot to broader-first + ML-discipline tuning. The P1-P3
> priorities below all landed today (PRs #1089, #1090, #1091, plus
> followups #1094 + #1095); the P4-P5 priorities are demoted to a new
> P1 tier behind the broader-universe data-foundation work that's now
> the P0. See the successor note for the new framing.

## Context

The 2026-05-13 → 2026-05-14 marathon landed 29 PRs, including the M5.5
4-axis parameter sweep run-to-completion. Headline result:

- Axis-1 (`installed_stop_min_pct`): partial CONDITIONAL GO; broad-1000 neutral.
- Axis-2 (`min_correction_pct`): **catastrophic STOP** on 16y long-only
  (MaxDD 19.9%→60.1%, 0→26 force-liqs).
- Axis-1 × Axis-2: destructive.
- Axis-3 (`min_score_override`): neutral, no winner.
- Q5 hard cap + soft penalty: both rejected.

See `memory/project_m5-5-tuning-exhausted.md` for the full verdict. Cell E
is near-optimal on the levers it exposes; **single-lever tuning under Cell
E is exhausted**. Bottleneck is elsewhere.

Today's other landed work:
- `Daily_price.active_through` field (#1076) — survivorship-aware foundation
- Sweep-path validation linter (#1069) — closes PR #1051 silent-no-op
- 5 design plans merged (continuation buys #1074, short-side margin #1075,
  P3 tuning #1064, P5 universe #1062, Q5 attribution #1077)
- Continuation buys Interpretation B (#1078) default-off — wiring works but
  ship-defaults too selective (2 fires / 5y / 500 syms in #1082)
- Stability + turnover metrics (#1073)
- Release-report alpha/beta sub-table (#1072)

## Priorities

### P1 — Wire screener point-in-time filter (universe plan phase 5)

**Why:** PR #1076 landed `Daily_price.active_through` but nothing reads it
yet. Adding a `membership_at` callback to `Screener.screen`, plumbed before
stage classification, unlocks **survivorship-aware 16y backtests** on the
existing 510-symbol `sp500-2010-01-01.sexp` universe.

The M5.5 verdicts (especially axis-2's catastrophic 16y failure) were
measured on **survivorship-biased data** — the current 16y goldens treat
delisted symbols as if they were active forever. Re-running validation
gates with PI filter ON may produce different verdicts. The −0.24 ΔCalmar
on 16y long-only could be partly survivorship artifact.

**Effort:** M, ~250–400 LOC. New `membership_at : symbol -> date -> bool`
callback in `Screener.screen`. qc-structural A1 won't flag (screener is
not on core watchlist; the consumer is). Touch points:
- `analysis/weinstein/screener/lib/screener.ml{,i}` — add the callback to
  `screen`, gate stage-classification on `membership_at sym current_date`.
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` — wire
  the callback from `Daily_price.active_through` lookups.
- New `dev/experiments/p5-pi-filter-validation-2026-05-XX/` — re-run 16y
  goldens with PI filter on/off and compare.

**Reference:** `dev/notes/historical-universe-status-2026-05-13.md` (#1062)
phase-3 action item #2.

### P2 — Cost-model slippage sweep on Cell E

**Why:** Cell E Sharpe is 0.56 on 5y main. M5.5 exhausted the screener
+ stops surface; the unswept lever is `engine_config.slippage_bps`. Real-
world cost of 5–10bps may explain the 0.56 ceiling. A 5-cell sweep
`{0, 5, 10, 20, 50}` quantifies cost-sensitivity:

- If Cell E collapses at 10bps, the strategy isn't viable under realistic
  execution.
- If it survives at 20bps, transaction-cost robustness is real evidence.

**Effort:** S, ~30min sweep + report. No code changes (knob exists per
PR #920). Sweep cells under `dev/experiments/m5-6-slippage-sweep-2026-05-XX/`.

### P3 — Continuation-buys parameter tuning

**Why:** PR #1078 landed Interpretation B default-off; PR #1082 measured
ship defaults fire only **2 continuation trades / 5y / 500 symbols** —
too selective to evaluate. The detector wiring is correct (per QC), it's
the thresholds. Tune to admit ~5–15 continuation trades per year so we can
actually measure the lever's effect.

**Sweep grid:**
- `ma_slope_min`: 0.005, 0.01 (default), 0.02
- `pullback_band` width: ±3%, ±5% (default), ±8%
- `consolidation_weeks`: 2, 4 (default), 6
- `consolidation_range_pct`: 0.05, 0.10 (default), 0.15

**Effort:** M. Full 3×3×3×3 grid = 81 cells (expensive); one-at-a-time =
~10 cells (faster). Start one-at-a-time per #1082's recommendation.

### P4 — Sector-concentration cap

**Why:** Cell E caps `max_long_exposure_pct = 0.70` but has **no per-sector
limit**. On 16y long-only, the axis-2 catastrophic result coincided with
26 force-liquidations — likely positions clustered in same-sector losers
during bear regimes. A `max_sector_exposure_pct = 0.30` cap could
decorrelate the failure mode that breaks long-horizon Calmar.

**Hypothesis:** sector cap reduces 16y MaxDD AND keeps 5y Sharpe within
±0.05 of Cell E baseline. Tests independently of stop-distance levers
(orthogonal axis).

**Effort:** M, ~200–400 LOC. New config field + portfolio_risk gate.
qc-structural A1 will FLAG (Portfolio is core). Touch points:
- `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.{ml,mli}`
  — add sector-cap check in pre-trade gate.
- `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml` —
  new field `max_sector_exposure_pct : float option`.
- Test on 16y long-only first (where the failure mode is loudest).

### P5 — Short-side margin Phase 1 (from #1075 plan)

**Why:** #1075 design plan landed today. Phase 1 = `enable_margin_accounting`
flag (default-off, preserves goldens) + Reg-T initial/maintenance margin
in Portfolio. Realistic margin accounting makes shorts more expensive;
current 16y long-short Sharpe 0.70 is measured under "broker flatters
shorts" pricing. Phase 1 establishes the seam for the 2-stage validation.

**Effort:** L, ~300–500 LOC. qc-structural A1 will FLAG (Portfolio is core).
Touch points per the plan:
- `trading/trading/portfolio/lib/portfolio.{ml,mli}` — initial + maintenance
  margin arithmetic on short entry/exit.
- New `trading/trading/portfolio/lib/margin_state.{ml,mli}` — state
  module for Reg-T margin tracking.
- Config field + tests. 2 new goldens (margin-on vs margin-off bit-equal
  on long-only).

### P6 — Defer

- **Continuation buys Interpretation A (pyramid)** — gated behind
  Position.t core-module decision (need `AddToHolding` transition).
- **Norgate data adoption** — low ROI until live trading.
- **Russell 3000 broader universe** — premature; needs P1 first.
- **Axis-3 long-horizon validation** — neutral result on 5y doesn't
  warrant 16y wall-time.

## Recommended sequencing

1. **P1 first** — biggest correctness unlock; could invalidate today's
   M5.5 verdicts (especially axis-2 catastrophic STOP) if survivorship
   bias was the real culprit.
2. **P2 in parallel with P1** — fast, independent, doesn't need PI filter.
3. **P3 in parallel** — independent of P1/P2; just needs careful grid
   design.
4. **P4 and P5** — larger code changes; do once P1–P3 land + Cell E
   baseline metrics re-pinned post-PI-filter.

## Things NOT to keep trying

- More stop-distance single-lever sweeps (axis-1/2/cross exhausted).
- Q5 score-weight manipulation (hard cap + soft penalty both rejected).
- Single-window 5y wins without 10y+16y validation gates — load-bearing
  lesson from #1086.
