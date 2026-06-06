# Evaluation objective + metrics — methodology reframe and build plan

**Date:** 2026-06-07
**Status:** PLAN (proposed). Triggered by the macro-bearish-trim investigation
(`dev/notes/macro-bearish-trim-grid-2026-06-07.md`), which exposed that our
top-line risk metric (MaxDD%) misled the read, and that what we actually care
about is a multi-dimensional objective we were collapsing too early.

## 1. Evaluation methodology — the reframe

### 1.1 What broke
The macro-bearish-trim grid produced a case where **MaxDD% ranked a clearly
better outcome as worse**:

| 15y top-1000 (PIT) | return | MaxDD% | peak→trough (capital) |
|---|---|---|---|
| baseline | 29.6% | 42.2% | $1.14M → $0.66M (**below the $1M stake**) |
| cap=0    | 730.9% | 65.0% | $12.5M → $4.4M (**4.4× the stake, never near it**) |

Raw MaxDD% calls cap=0 (65%) "riskier" than baseline (42%) — backwards in
capital terms: baseline actually dipped *below the starting stake*; cap=0's worst
trough was 4.4× it. MaxDD% is **scale-dependent, a single noisy worst-point, and
conflates two different costs**. We had been treating it as a top-line gate.

### 1.2 MaxDD is not wrong — it was misused
The fix is not to drop MaxDD. It is to (a) never read it without return context
(that's what Calmar is for, and we already compute it), and (b) add measures that
capture what a single peak-relative worst-point cannot. MaxDD stays **one input,
demoted from king**.

### 1.3 What we are actually trying to evaluate
Four axes (the real objective):

1. **Long-term return** (CAGR). Necessary, meaningless alone — wildly
   start-date-sensitive (this study: same config, 2011-start vs 2006-start
   flipped cap=0 from +700pp to −half).
2. **Robustness — sensitivity to regime / start time.** *This should be the
   primary lens, above any single-window number.* The entire macro-trim verdict
   turned on it.
3. **Drawdown, split into its two real costs:**
   - **Opportunity-cost / integrated pain** — capital underwater = compounding
     lost. Captured by **Ulcer Index** (∫ underwater², already computed; it
     cleanly flagged the force-liq resonance: 41 vs ~10) and **time-underwater**
     (not yet computed).
   - **Psychological depth** — would a human have abandoned it? This is depth in
     **capital-relative** terms (vs initial stake / rolling high-water), NOT
     peak-relative %MaxDD. Being down to 4.4× feels nothing like being below your
     starting money. (Not yet computed — this is the new metric.)
4. **Antifragility** — does it *gain* from disorder, or merely survive it?
   Operationalize as **convexity**: tail-ratio (mean top-decile trade /
   |mean bottom-decile|), monthly-return skew, and **conditional return in the
   worst-volatility regimes**. NB: Weinstein's spine is already convex-shaped
   (bounded losses via stops, unbounded winners via trailing stops — the laggard
   winners +$1.9-3.3M vs capped stop-losses); we can measure whether a change
   *increases or flattens* that convexity. Treat antifragility metrics
   skeptically — easiest axis to fool yourself on.

### 1.4 The scorecard (what to report per strategy)
Replace "return + MaxDD (+Sharpe/Calmar)" with a small fixed dashboard:

| dimension | metric | status |
|---|---|---|
| return | CAGR | have |
| **robustness** | **rolling-start dispersion (median, 10th pct, spread)** | **build** |
| pain — integrated | Ulcer, time-underwater | Ulcer have; t-underwater build |
| pain — psychological | **capital-relative max drawdown** | **build** |
| antifragility | tail-ratio, skew, worst-vol-regime conditional return | prototype |
| summaries | Sharpe, Sortino, Calmar | have |

### 1.5 The discipline guardrail (so a richer objective isn't just more surface to overfit)
A 6-axis scorecard invites cherry-picking ("but it's great on axis 4!"). Keep the
existing gate discipline and extend *what* it scores, not *whether* it gates:
- **Pre-commit a dominance rule before looking at results**, e.g. "must be
  top-half on robustness AND not worst-decile on capital-relative DD before
  return is even considered."
- The promotion-confirmation grid (`.claude/rules/promotion-confirmation.md`) and
  Deflated-Sharpe best-of-N correction still apply — this reframe changes the
  metrics inside the grid, not the grid's gating role.

## 2. Build plan

Two genuinely-new, high-value metrics; one prototype; ordered by value.

### P1 — Rolling-start dispersion (robustness) [highest value]
The headline change: stop judging on one full-window run; judge on the
*distribution* over many start dates.
- New harness: given a (universe, config, total span), run the backtest from
  every quarter-start (or every 6mo) to a fixed end, collect terminal
  CAGR + capital-relative DD per start.
- Report: median, 10th percentile, IQR/spread across starts. A robust strategy
  has a tight, positive distribution; cap=0 would show huge spread (the tell).
- Cheap to build on top of snapshot mode (one snapshot, N runs clipping the
  start) — but N runs is the cost; start coarse (quarterly) and only on PIT
  universes.
- Deliverable: `rolling_start_eval` exe + a dispersion summary in the result.

### P2 — Capital-relative drawdown (psychological depth)
- Add to the backtest result alongside `max_drawdown_pct`:
  - `max_underwater_vs_initial_pct` — worst (NAV − initial_capital)/initial,
    i.e. how far below the *starting stake* it ever went (0 if never below).
  - optionally `max_drawdown_at_matched_return` for cross-strategy comparison.
- Pure post-processing of the existing `equity_curve.csv` — small, no strategy
  change. Pairs with keeping %MaxDD but de-emphasizing it.

### P3 — Time-underwater + antifragility prototypes [prototype, hold skeptically]
- `time_underwater_pct` (fraction of days below prior high-water) — trivial from
  equity_curve.
- Convexity prototypes: tail-ratio + monthly-return skew from `trades.csv` /
  equity_curve; worst-vol-decile conditional return (needs a vol/regime tag per
  period). Prototype, validate it isn't noise, before promoting to the scorecard.

### Sequencing
P2 first (smallest, pure post-proc, immediately useful), then P1 (the important
one, larger), then P3 (prototype). All land default-off / additive — they only
add reported columns, never change strategy behaviour, so no flag-discipline gate.

## 3. Related follow-ups this study surfaced (tracked elsewhere, linked here)
- **PIT re-baseline** (the survivorship finding — bigger than this metrics work):
  re-pin core baselines on the PIT composition series. See the findings note.
- **Snapshot cache fix** (unlocks N=3000 locally so PIT-breadth eval is
  tractable): make `panel_runner.ml:_snapshot_cache_mb` configurable + bump +
  add a hit/miss counter. See the findings note §infra.

## Related
- `dev/notes/macro-bearish-trim-grid-2026-06-07.md` — the experiment that
  surfaced all of this.
- `.claude/rules/promotion-confirmation.md` — the gate this scorecard feeds.
- `memory/project_snapshot_streaming_status`, `feedback_large_n_needs_snapshot_mode`.
