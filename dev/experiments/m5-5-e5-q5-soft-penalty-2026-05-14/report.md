# M5.5-E5 Q5 soft-penalty sweep — **negative result**

## TL;DR

**The Q5 soft-penalty hypothesis is wrong.** None of the 3 penalty cells
(E5a/E5b/E5c) beat baseline on ANY of the 4 acceptance gates from
`dev/notes/q5-score-feature-attribution-2026-05-13.md` (PR #1077). All cells
degrade return AND MaxDD AND win rate vs baseline. Q5 candidates (score ≥80,
WR 28.6%) cannot be improved away via score adjustment — neither hard cap
(entry-caps arm B, 2026-05-12) nor soft penalty.

**Pin the result and move on**: continue tuning on `installed_stop_min_pct`
(PR #1079 winner) and `min_correction_pct`; don't waste more sweep budget on
score-distribution manipulation.

## Method

4 cells over `sp500-2019-2023.sexp` (5y, Cell E baseline). Overlays vary
`screening_config.weights.{w_strong_volume, w_bullish_rs_crossover, w_positive_rs}`:

- `baseline` — defaults (20/10/20)
- `E5a soft` — 15/5/20 (cap Q5 at 95)
- `E5b moderate` — 14/0/20 (cap Q5 at 89, primary recommendation per #1077)
- `E5c aggressive` — 12/0/18 (cap Q5 at 85)

Local docker container, parallel-3, `--no-emit-all-eligible`. Wall: ~5 min for
4 cells. Output: `dev/backtest/scenarios-2026-05-13-231437/`.

## Results

| Cell | Return | Trades | WR | Sharpe | MaxDD | Calmar | AvgHold |
|---|---:|---:|---:|---:|---:|---:|---:|
| **baseline** | **50.66%** | **264** | **37.50%** | **0.56** | **21.56%** | **0.40** | **40.78d** |
| E5a soft | 43.37% | 277 | 35.02% | 0.52 | 26.09% | 0.29 | 38.36d |
| E5b moderate | 47.01% | 264 | 35.61% | 0.54 | 28.75% | 0.28 | 39.09d |
| E5c aggressive | 49.35% | 263 | 36.12% | 0.56 | 27.62% | 0.30 | 39.25d |

## Acceptance gates (from #1077 §4)

| Gate | Target | E5a | E5b | E5c | Met? |
|---|---|---|---|---|---|
| Sharpe ≥ 0.80 | 0.80 | 0.52 | 0.54 | 0.56 | ❌ none |
| WR ≥ 42% | 42% | 35.0% | 35.6% | 36.1% | ❌ none |
| MaxDD ≤ 25% | 25% | 26.1% | 28.8% | 27.6% | ❌ none |
| AvgHold ≥ 35d | 35d | 38.4d | 39.1d | 39.3d | ✓ all |

**Only AvgHold passes**. Every cell fails Sharpe + WR + MaxDD gates.

## Mechanism — why soft penalty fails

The #1077 attribution note hypothesized that Q5 candidates (score ≥80,
WR 28.6%) are over-confident. Dampening `w_strong_volume` and
`w_bullish_rs_crossover` should push these candidates leftward in the score
distribution, letting Q3/Q4 candidates compete.

What actually happens on the data:

1. **Q5 candidates are still admitted** — the cascade gate is grade-driven
   (`min_grade = C` ≡ `score ≥ 40`), and the dampened weights still keep most
   Q5 candidates ≥ 40. So they enter as before.
2. **Rank reshuffle doesn't help** — the entry-walk admits ~1.3 of ~12.5
   candidates per Friday (capacity-limited by cash + per-position cap).
   Dampening high-confidence features re-ranks the top end but the same set
   of candidates enters across cells; just in different order.
3. **Calmar drops anyway** — the small re-ranking shifts trade timing in ways
   that drift MaxDD higher without lifting return. The 28.6% WR is real but
   the per-trade profit factor on Q5 winners is large enough that admitting
   them is net positive — capping/dampening drops the asymmetry.

This is the same mechanism as entry-caps arm B (hard cap), just at smaller
amplitude. Q5's WR is not the actionable signal; the score-weighted profit
factor is.

## Verdict — do not promote any cell

None of E5a/E5b/E5c improves over baseline. The Q5-feature-attribution
recommendation in #1077 §3 is **rejected by data**.

## Follow-ups

- **Don't sweep score weights to dampen Q5 further** — both hard cap and soft
  penalty have been falsified. Move budget elsewhere.
- **Tuning roadmap stays on the legitimate axes** from PR #1064:
  - axis 1 (`installed_stop_min_pct`) — winner 0.08 confirmed, validate on
    10y/16y (K1 in flight).
  - axis 2 (`min_correction_pct`) — not yet tested; can interact with axis 1.
  - axis 3 (`min_score_override` floor tightening) — distinct from score
    re-weighting; might still work because it's a hard gate, not a
    re-distribution.
- **Update the P4 weights note** (`dev/notes/screener-weights-inertness-2026-05-13.md`)
  to record: weights DO move metrics, but Q5-targeted re-weighting in either
  direction (cap or penalty) degrades. The lever is not "Q5 confidence";
  it's somewhere else (likely stop distance, score floor, or holding cap).

## Reproduction

Cell sexp shape (rebuild from `sp500-2019-2023.sexp` + appropriate overlay):

```sexp
;; E5b moderate
(config_overrides
 (... existing Cell E overrides ...
  ((screening_config
    ((weights
      ((w_strong_volume 14)
       (w_bullish_rs_crossover 0)
       (w_positive_rs 20))))))))
```

Then:

```sh
dev/lib/run-in-env.sh dune exec --no-build \
  trading/backtest/scenarios/scenario_runner.exe -- \
  --dir <stage_dir> --parallel 3 \
  --fixtures-root trading/test_data/backtest_scenarios \
  --no-emit-all-eligible
```
