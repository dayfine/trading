# Capacity levers — the deep basis is mis-calibrated vs production defaults (2026-06-25)

**The cross-cutting finding from two WF-CV capacity surfaces.** Both the
concentration lever (`max_position_pct_long`) and the turnover lever
(`laggard_rotation_config.hysteresis_weeks`) were tested on the deep 2000-2026
sp500-PIT basis. Neither produced a robustly-promotable value — but together they
expose something more important than either individual verdict:

> **The deep-golden research basis is tuned MORE capacity-suppressing than the
> production defaults, and in both surfaces the production default beats the
> deep-base value.**

| lever | deep-golden base | canonical default | which wins |
|-------|-----------------:|------------------:|:-----------|
| `max_position_pct_long` (concentration) | **0.14** | 0.30 | default (Sharpe 0.64 vs 0.56, Calmar 1.44 vs 1.03) |
| `laggard hysteresis_weeks` (turnover) | **2** (aggressive) | 4 | default (Sharpe 0.63 vs 0.56, Calmar 1.12 vs 1.03) |

The deep goldens cap each position tighter (0.14 vs 0.30 → more, smaller slots)
AND churn faster (rotate after 2 negative-RS weeks vs 4 → more turnover). Both
choices suppress how much capital reaches each cascade-identified winner — exactly
the `Insufficient_cash` symptom the optimal-strategy lens
(`dev/notes/optimal-lens-insights-2026-06-25.md`) diagnosed.

## Why this reframes the optimal-lens "capacity gap"

The optimal lens concluded the strategy's misses are `Insufficient_cash`: winners
identified but unfunded because capital is sprayed across ~280 churned trades. That
lens was run on the deep-golden basis. **Part of that capacity bottleneck is an
artifact of the basis being tuned 0.14 / hysteresis-2 — more conservative than the
production strategy actually runs (0.30 / hysteresis-4).** The gap measured on the
deep goldens overstates the gap in the production configuration.

This does **not** mean the capacity gap is fake — the production default (0.30 /
hysteresis-4) is itself untested by the optimal lens. It means the honest next step
is to **measure the gap on a basis that matches production**, not on the more
conservative deep-golden basis.

## The two individual lever verdicts (both INCONCLUSIVE / no-promote)

### Concentration — `max_position_pct_long` {0.14…0.40}
Real, live lever (amplifies the fat tail) but a return-for-DD/dispersion tradeoff;
the apparent 0.25 optimum is a knife-edge single-point overfit (fold-000 return
non-monotonic 52→131→97% across the cap). `max_long_exposure_pct` is inert
(per-position cap is the sole binding constraint). Default 0.30 already favourable.
Full writeup: `dev/notes/capacity-concentration-surface-2026-06-25.md`. Ledger:
`2026-06-25-capacity-concentration-surface`.

### Turnover — `laggard hysteresis_weeks` {2,4,6,8}
Weak directional support: return + Calmar rise across 4/6/8 with mild DD cost and
**gentler dispersion** than concentration (σ →17 vs →27) — turnover is a distinct,
less-variance-cranking capacity lever, as hypothesised. But Sharpe is non-monotonic
(0.56→0.63→**0.55**→0.67; hysteresis=6 dips below baseline) and the best cell (8)
wins only 17/26 folds — noisy, modest, no robust value. Ledger:
`2026-06-25-laggard-cadence-surface`.

## Recommended next action (next-session P0)

**Re-pin the deep long-only goldens to the production defaults, then re-run the
optimal lens on the corrected basis.**

1. Change the deep sp500-historical goldens (`sp500-2000-2026-catstop`,
   `sp500-1998-2026`, `sp500-2010-2026`, and the catstop/longshort variants) from
   `max_position_pct_long 0.14 → 0.30` and `laggard hysteresis_weeks 2 → 4` to
   match production. This re-pins their expected-metric goldens — a deliberate,
   oversight-worthy change (golden tests will shift), **best confirmed with the
   user before executing**, and run through the confirmation grid
   (`.claude/rules/promotion-confirmation.md`) since it changes the research basis
   every recent result sits on.
   - NB the long-only catstop base has `enable_short_side = false`, so 0.14's
     original short-diversification / force-liquidation-cascade rationale does not
     apply to it. The longshort goldens may have a real reason to keep 0.14/2 and
     should be re-pinned separately, if at all.
2. Re-run the optimal-strategy / missed-trades lens on the corrected basis. The
   `Insufficient_cash` miss rate should shrink; what remains is the *honest*
   production capacity gap.
3. Only then decide whether further capacity levers (e.g. `max_positions` count
   cap) are worth surfacing — they were the planned lever 3, but if the gap shrinks
   after recalibration, the priority drops.

## Process note carried from the concentration surface

The per-variant `Fold_gate` (`worst_delta = 0.0`) is **mis-specified for
return-amplifying capacity levers** — it FAILs every cell because concentration /
slower turnover necessarily makes some folds worse while winning on aggregate. Read
the Pareto frontier + fold-win-rate + the full response curve, not the strict gate.
Future capacity surfaces should use a return/Calmar gate or a `worst_delta` budget.
