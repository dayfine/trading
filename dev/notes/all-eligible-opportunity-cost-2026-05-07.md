# All-eligible diagnostic — opportunity-cost grade sweep (2026-05-07)

## TL;DR

Refit the all-eligible diagnostic from "raw signal floor" to **opportunity-cost**
semantics by adding a configurable cascade-grade floor (`config.min_grade`,
default `C`). The runner gains `--min-grade <X>` and `--grade-sweep` flags;
the sweep iterates `F → D → C → B → A → A_plus` and emits one
`grade-<G>/` subdir per cell plus a top-level cross-grade summary.

The goal stated in issue #870: separate **portfolio rejections** from
**raw signal alpha**. PR #889 / #901 implemented the lower bound (raw signal
floor with `min_grade=F`); this PR adds the **upper bound that the live
cascade actually sees**: only candidates the cascade would have promoted to
the portfolio. The gap "live actual" → "min_grade=C cell" reads cleanly as
opportunity cost.

**Headline cell** (sp500-2019-2023, `min_grade=C`):

| Metric | Value |
|---|---:|
| trade_count | 5,300 |
| winners | 624 |
| losers | 4,676 |
| win_rate_pct | 11.77% |
| mean_return_pct | -10.01% |
| total_pnl_dollars | -$5.31M |

The five-cell sweep table is below. The raw `min_grade=F` floor is 5,836
trades (the pre-quality-gate baseline from PR #904); each grade tier above
admits strictly fewer first-admissions but with monotonically-improving
win rate.

## What changed structurally

**`All_eligible.config`**: gained a `min_grade : Weinstein_types.grade`
field (default `C`, sexp-default-tagged for backward-compat config files).

**`All_eligible.filter_by_min_grade`**: pure helper that drops scored
candidates whose `entry.cascade_grade` is below the threshold using
`Weinstein_types.compare_grade` — the same ordering the live cascade's
`Screener._passes_score_floor` uses with `min_score_override = None`.

**`All_eligible_runner` CLI**:
- `--min-grade <F|D|C|B|A|A+>` — single-cell mode; default `C`.
- `--grade-sweep` — runs the full ladder; emits one subdir per grade plus
  a cross-grade `summary.md`.

**On-disk shape change**: per-cell artefacts now live under
`<out_dir>/grade-<G>/{trades.csv,summary.md,config.sexp}` rather than at
`<out_dir>/` directly. This is consistent across single and sweep modes —
consumers don't have to branch on flag.

**`Grade_sweep` module** (new, sibling to `All_eligible_runner`): owns the
post-scan-and-score half — filter + dedup + grade per cell, plus per-cell
artefact emission and the cross-grade summary table. Splitting this out of
the runner kept the runner under the file-length linter's hard cap and
gave the cell-construction logic its own home with focused unit tests.

**Filter-then-dedup ordering**: the sweep applies the grade filter
*before* dedup, not after. Reasoning: the live cascade gates by grade
first (`min_grade` → grade gate), then per-symbol exclusion via
`held_tickers`. Dedup is the diagnostic's stand-in for `held_tickers`. So
filter-then-dedup mirrors what the live cascade would actually have
admitted at each grade floor — a high-grade re-fire whose primary
lower-grade trade was below the floor becomes the first admission at that
cell. Pinned by the test
`filter — min_grade=A produces strictly fewer than min_grade=C`.

## Sweep results — `goldens-sp500/sp500-2019-2023.sexp`

Run: `dev/all_eligible/sp500-2019-2023/2026-05-06T22-40-23Z-grade-sweep/`
Universe: 491-symbol 2019-2023 SP500 snapshot (510 with extras + 1 index).
Period: 2019-01-02 to 2023-12-29.
Wall: scan + score ~12 minutes (single-threaded). Filter+dedup+grade per
cell ~10ms. Re-using one scan across six cells is essentially free.

| min_grade | trade_count | winners | losers | win_rate_pct | mean_return_pct | total_pnl |
|---|---:|---:|---:|---:|---:|---:|
| F   | 5,836 | 627 | 5,209 | 10.74% | -10.83% | -$6.32M |
| D   | 5,836 | 627 | 5,209 | 10.74% | -10.83% | -$6.32M |
| **C** (default) | **5,300** | **624** | **4,676** | **11.77%** | **-10.01%** | **-$5.31M** |
| B   | 3,067 | 493 | 2,574 | 16.07% |  -6.77% | -$2.08M |
| A   | 1,576 | 270 | 1,306 | 17.13% |  -6.06% | -$0.96M |
| A+  |     0 |   0 |     0 |  0.00% |   0.00% |   $0.00 |

Notes on the cells:

- **F == D**: no candidate scores below 25 (the D-grade floor) post-breakout
  predicate. The breakout gate inside the screener (price above MA, recent
  Stage 1→2 transition) implicitly clears the F-grade tier. So `min_grade=D`
  is the *effective* floor — `F` is a no-op below it.
- **F → C**: drops 536 trades (9.2% of the F floor). These are D-grade
  trades that the live cascade would not have promoted. They're the worst
  cohort: their absence shifts win rate +1.0pp and mean return +0.8pp.
- **C → B**: drops 2,233 trades (42.1% of C). This is the biggest
  marginal-quality jump. Win rate moves from 11.77% to 16.07%; mean return
  from -10.01% to -6.77%.
- **B → A**: drops 1,491 trades (48.6% of B). Win rate moves modestly to
  17.13%; mean return improves by 0.7pp.
- **A → A+**: drops to zero. No candidate in the 5y window scores ≥85
  (A+ floor) under default scoring weights. This is consistent with the
  weights' design: A+ requires nearly-maxed signal across volume + RS +
  resistance, which is genuinely rare.

### Alpha-tail counts

The histogram bucket [0.50, 1.00) plus [1.00, +inf) gives the count of
trades that returned ≥50%; [1.00, +inf) alone gives ≥100%.

| min_grade | trades | n[≥+50%] | %[≥+50%] | n[≥+100%] | %[≥+100%] |
|---|---:|---:|---:|---:|---:|
| F | 5,836 | 88 | 1.51% | 20 | 0.34% |
| C | 5,300 | 86 | 1.62% | 18 | 0.34% |
| B | 3,067 | 76 | 2.48% | 15 | 0.49% |
| A | 1,576 | 36 | 2.28% |  8 | 0.51% |

**Headline observation**: the cascade grade filter culls alpha tails
*proportionally faster than overall trades* once you get above C. The
absolute count of "+50% or better" trades drops from 88 (at F) to 36
(at A) — a 59% drop — while the trade count drops from 5,836 to 1,576
(a 73% drop). Per-trade alpha-tail incidence ticks up modestly (1.51%
→ 2.28%), but the strategy gets fewer total opportunities to ride a
+50% winner. This matters for portfolio sizing: with 20-position cap
and ~5y holds, the strategy needs the alpha-tail count to be high
enough that 1-2 trades actually compound.

## Comparison to the live 81-trade / 58.34% baseline

The live SP500 5y baseline (`goldens-sp500/sp500-2019-2023`):
- Total trades: 81
- Total return: 58.34%
- Win rate: ~46% (per `goldens-performance-baselines-2026-04-28.md`)

The opportunity-cost cell at `min_grade=C` (the matching cascade floor):
- Total trades: 5,300
- Total return-of-equal-weight-portfolio (sum of return%): -530%
- Win rate: 11.77%

**The 5,300 vs 81 ratio is striking**: even at the cascade's actual
quality bar, the diagnostic admits 65× more opportunities than the live
strategy actually took. The portfolio gates cut the volume by ~98.5%.

Three factors compose to that 65× factor:

1. **Top-N cap (20)**: the live cascade emits at most 20 per Friday. With
   261 Fridays in the window, the maximum cascade-emit count is ~5,200.
   That's already close to the diagnostic's 5,300 cell.
2. **Cash gate**: the live runner skips re-firings while cash is below
   one position's worth. With $1M starting cash and ~5% target risk,
   ~20 simultaneous positions saturate the book — every subsequent
   admission while saturated is rejected for `Insufficient_cash`.
3. **Held-ticker exclusion**: the live cascade's `held_tickers` arg
   excludes already-open symbols. The diagnostic's dedup is the
   equivalent — same semantics by construction.

So the gap "5,300 → 81" is roughly: top-N cap × cash gate. The dedup
already accounts for held-ticker exclusion (both the diagnostic and the
live strategy cap re-firings while a position is open).

**Win rate gap**: 11.77% (diagnostic at C) vs ~46% (live actual). The
diagnostic's win rate is dragged down by the long left tail of trades
that stop out within ~7 days at the 8% suggested-stop level (typical
`risk_pct`). The live strategy's 46% is partly survivorship — the
top-N cap and cash gate happen to push the strategy toward the 81 trades
where the cascade ranking + portfolio admission happened to align with
positive outcomes. That's the **picking gap** described in issue #870 —
it's what the optimal-strategy track measures.

**Tentative conclusion** (subject to alpha-tail follow-up):

> Most of the gap between the live 58.34% return and a perfect-information
> upper bound is the top-N cap and cash gate combined. The cascade
> grade-quality bar contributes only ~10% of the trade-count culling
> (F → C drops 9.2% of trades) but accounts for most of the
> *win-rate* improvement seen in the picking diagnostic. Portfolio
> loosening (loosen top-N or risk-per-trade) could materially expand
> capacity without diluting per-trade quality.

## What this measurement does NOT yet do

Three orthogonal extensions left as follow-ups:

1. **Real macro stamping**. All cells run with `passes_macro=true`
   uniformly because the runner doesn't consume a `macro_trend.sexp`
   from a sibling backtest. So the diagnostic doesn't see when the
   bearish-macro gate would have blocked a long. Wiring this in requires
   teaching the all-eligible runner to read `macro_trend.sexp` (same
   shape the optimal-strategy runner consumes) and pass through the real
   trend per Friday. Inert in this PR; documented as a follow-up.

2. **Sector-rating gate**. The cascade in the live strategy uses real
   per-sector ratings; the diagnostic stamps every sector as `Neutral`
   (see `_build_sector_context_map`). Plumbing real sector ratings would
   tighten the diagnostic further at every grade floor.

3. **Per-Friday cascade-rejection counting**. The diagnostic answers
   "what would the cascade admit?" but doesn't count *how many* the
   live runner actually rejected per Friday by reason (cash / sector /
   top-N). That's the second half of issue #870 — pair the
   opportunity-cost cell with a `cascade_rejections.csv` from the live
   run for a per-Friday attribution.

These are scoped as separate PRs. The present PR establishes the
opportunity-cost surface; subsequent PRs can sharpen it.

## Reproduction

```sh
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/.claude/worktrees/opportunity-cost-*/trading
  eval $(opam env)
  dune build trading/backtest/all_eligible/bin/all_eligible_runner.exe
  _build/default/trading/backtest/all_eligible/bin/all_eligible_runner.exe \
    --scenario test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp \
    --grade-sweep
'
```

Default output dir: `dev/all_eligible/sp500-2019-2023/<UTC-timestamp>/`.

For a single-cell run at `min_grade=A`:
```
... --min-grade A
```

## Authority

GitHub issue #870 (opportunity-cost diagnostic). Builds on PR #904
(consecutive-Friday dedup). Falsifiable conclusion: if a future
fix/loosening of the top-N cap moves the live strategy's trade count
toward the `min_grade=C` cell's 5,300 without degrading per-trade
return, the portfolio-mechanism diagnosis is correct. If trade count
doesn't move or per-trade return drops sharply, the cascade-quality
diagnosis (tighten min_grade) is the better fix.
