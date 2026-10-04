# 2025 reopen: picks vs the screener's pool vs the equal-weight universe vs SPY (read-only screen, 2026-10-03)

## Question

Item 4(e) in `dev/notes/next-session-priorities-2026-10-03.md`: the 26y investor preset was invested through the
2025-05 reopen and lagged (picks' 26-week forward median +4.7 % vs SPY +14.5 % from the reopen;
`project_recovery_reentry_gap`). Is that a **selection** problem the ranker could fix, or the **tape** (a
narrow cap-weighted rally that the average stock did not join)? This screen decides whether to design a
selection-side experiment. It cannot reject any mechanism (`mechanism-validation-rigor.md`).

## Method

`screen.sh` (host only, no container). Input: the 26y investor trade audit
(`.sweep-output/investor-preset/inv26sc-investor-s{0,1,2}-v11-trade_audit.sexp`, build 650b18e2a).
For every entry decision dated 2025-05-23 → 2025-12-31 (19 decision dates):

- **pick**: the 24 names entered;
- **alt**: the 431 (name, date) rows in `alternatives_considered` that were skipped (427 `No_structural_stop`,
  2 `Sized_to_zero`, 2 `Insufficient_cash`); 419 have a bar at the horizon end and enter the table;
- **univ**: every name in the PIT top-3000 2025 list (`pit-v11/composition/top-3000-2025.sexp`), split by
  dollar-volume rank;
- **SPY**.

Statistic: 26-week (182-day) forward return on `adjusted_close`, from the last bar on or before the
decision date. Each (name, decision date) is one observation. Bootstrap: 20,000 draws of 24 names (seed 7)
from the alt pool and from the universe pool; how often is the draw's median ≤ the picks' median?

The three salts give byte-identical candidate lists and tables (2025 decisions do not depend on the path
seed), so only s0 is committed.

## Result

| group | n | mean | p10 | p25 | median | p75 | p90 | negative |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| SPY | 19 | 9.6 % | 4.5 % | 6.6 % | 9.4 % | 11.9 % | 15.1 % | 5 % |
| pick | 24 | 13.5 % | −43.2 % | −29.1 % | −2.5 % ¹ | 22.1 % | 47.8 % | 54 % |
| alt (skipped) | 419 | 15.8 % | −29.8 % | −10.6 % | 6.1 % | 29.2 % | 69.7 % | 40 % |
| universe, all | 55,414 | 12.5 % | −33.5 % | −12.4 % | 6.4 % | 26.3 % | 57.3 % | 40 % |
| rank 1–100 | 1,900 | 11.6 % | −27.3 % | −11.2 % | 5.3 % | 24.3 % | 52.0 % | 41 % |
| rank 101–500 | 7,496 | 7.6 % | −27.9 % | −11.6 % | 4.3 % | 20.5 % | 41.9 % | 42 % |
| rank 501–1500 | 18,656 | 12.4 % | −28.8 % | −11.1 % | 6.9 % | 26.1 % | 54.6 % | 40 % |
| rank 1501–3000 | 27,362 | 14.0 % | −40.2 % | −13.9 % | 6.6 % | 28.6 % | 64.3 % | 40 % |

¹ True median of 24 (mean of the 12th and 13th); `results/distribution.md` prints the lower-middle quantile, −4.6 %.

Bootstrap (`results/bootstrap.txt`): P(median of 24 alternatives ≤ −2.5 %) = **0.072**; P(median of 24
universe draws ≤ −2.5 %) = **0.083**. Per-pick table paired with SPY: `results/picks.md`.

Economic scale: 26 weeks ≈ half a year, so the SPY-vs-universe median gap (3.0 pp) is ~6 pp/yr and the
picks-vs-universe median gap (8.9 pp) ~18 pp/yr — large if real, which is why the bootstrap matters.

## Reading

1. **The tape explains part of it.** The equal-weight top-3000 median (+6.4 %) lagged SPY (+9.4 %) at every
   size tier; ranks 101–500 lagged most (median +4.3 %, mean +7.6 %). The universe *mean* (+12.5 %) beat SPY
   because of a fat right tail. The average stock did not join this rally.
2. **The screener's pool carries no selection edge, positive or negative.** Skipped alternatives (+6.1 %
   median) sit on the universe distribution almost exactly. The ranker is not choosing worse names than the
   market; it is not choosing better ones either. This agrees with `project_rs_trend_dead_and_rs_value_unpredictive`
   and `project_cascade_selection_inversion` from a new angle.
3. **The 24 picks lagged further, but n = 24 cannot separate that from chance.** A random 24-name draw from
   the same pool does this badly about 1 time in 13. The picks' *mean* (+13.5 %) beat SPY, carried by AAOI
   (+265 %), AIP (+120 %) and GILT (+100 %); the realised loss (−$267k, `project_recovery_reentry_gap`) came
   from stops cutting names before their move (AIP) and from the losers, which is path, not this statistic.

## Rigor checks (`mechanism-validation-rigor.md`)

1. **Estimand.** Forward return from the decision date is the selection quantity, not realised P&L (fills,
   resting tickets, stops). The realised gap is larger because of stops; this screen does not attribute it.
2. **Distribution.** Full quantiles above.
3. **Scale.** Annualised in "Result".
4. **Selection / survivorship.** The universe is the 2025-05-31 list (decision-time information). A name
   with no bar at the horizon end (delisted) drops out, biasing the universe rows *up*; the picks lost none
   that way. So the picks-vs-universe gap is, if anything, overstated.
5. **Surface.** One horizon (26 weeks), one window. No knob was swept; this is a pool-quality check, not a
   mechanism screen.
6. **Paired.** Per-pick vs SPY on the same date in `results/picks.md`; 9 of 24 beat SPY.
7. **Power.** Bootstrap p ≈ 0.07–0.08 at n = 24: underpowered for the picks; the pool and universe rows are
   well powered.
8. **V6.** Not applicable (one arm, no paired backtest).

## Verdict

**No-build decision for a selection-side experiment on the 2025 shape.** The pool the ranker draws from is
the universe's distribution; of the 11.9 pp median gap between the picks and SPY, about a quarter (3.0 pp, SPY vs the equal-weight
universe) is the narrow tape, and the rest (8.9 pp) is the picks lagging their own pool, which a random
24-name draw matches 1 time in 13: indistinguishable from chance at this n, not attributable to the tape. Leaning on the standing
prior that selection levers have repeatedly found no edge (`project_entry_selection_closed_powered`), there is
no specific lever to test. This is a prioritisation decision, not evidence that selection cannot matter.

**Why, and what it rules out:** a ranker that does no better or worse than the universe cannot be "fixed" for
one regime by re-weighting the same inputs. The tape part of the 2025 lag (the equal-weight universe trailing a cap-weighted
rally) is the only part this screen can attribute. Levers that would address it are benchmark/construction levers (equal-weight vs
cap-weight benchmark, size tilt), not ranking levers, and the SPY sleeve that would directly address it is
user-declined. An equal-weight benchmark (RSP/IWM) is still missing from the data store
(`dev/notes/next-session-priorities-2026-10-03.md` §6); with it, the review pack could show the
equal-weight tape next to SPY.

## Files

- `screen.sh` — the whole screen; rerun with
  `sh dev/experiments/selection-2025-screen-2026-10-03/screen.sh <audit> <out_dir>` from the repo root.
- `results/cands.csv` — picks and alternatives per decision; `results/distribution.md`,
  `results/bootstrap.txt`, `results/picks.md` — outputs above.
