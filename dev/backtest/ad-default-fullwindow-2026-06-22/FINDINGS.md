# A-D-default flip — full-window 1999-2026 evidence (2026-06-22)

Decides whether to make **A-D-live the default basis** (Build 0). The 2000-2010
deep-screen showed A-D-live lifting long-only +92pp — but that was a bear-heavy
window. This is the full 1999-2026 (~27y) A-D-live vs A-D-inert comparison, both
long-only and long-short, to see the real-regime tradeoff before the
behavior-changing golden re-pin.

- Same config; only `skip_ad_breadth` toggles (false = A-D live via generated
  `data/breadth/`, true = inert/degraded). sp500-as-of-2000 PIT, CSV mode.
- Scenarios: `experiments/adlive-{longonly,longshort}-fullwindow-2026-06-22/`.

## The 2×2

| config | A-D | Return | MaxDD | Sharpe | Calmar | Sortino | Ulcer |
|---|---|---|---|---|---|---|---|
| long-only | inert | **1787.6%** | 32.5% | 0.785 | 0.349 | 1.274 | 11.46 |
| long-only | live | 1575.8% | 28.9% | 0.791 | 0.376 | 1.299 | 10.43 |
| long-short | inert | **3408.6%** | 27.3% | 0.884 | 0.509 | 1.481 | 9.71 |
| long-short | live | 3077.4% | **25.6%** | **0.933** | **0.528** | **1.583** | **8.80** |

## Read

1. **A-D-live consistently trades ~10% raw return for better risk** — lower return
   (it makes the macro gate more conservative → fewer trades, less bull upside)
   but lower MaxDD, better Sortino/Ulcer, higher win rate, in both configs.
2. **The +92pp "broad lift" was a 2000-2010 bear-window artifact.** Over the full
   27y, A-D-live *reduces* raw return (−212pp long-only, −331pp long-short).
3. **With shorts (the real strategy) the risk-adjusted edge is MEANINGFUL, not
   marginal.** Long-only A-D-live: Sharpe basically tied (+0.006). Long-short
   A-D-live: **Sharpe +0.049, Sortino +0.102, Calmar +0.019, MaxDD −1.7pp, Ulcer
   better** — every risk metric clearly better. A-D's breadth reads make the
   **shorts land better** (the A-D-lead identifies genuine distribution → better
   short timing).

## Recommendation: FLIP (make A-D-live the default)

In the *actual* long-short config A-D-live is **clearly better risk-adjusted on
every metric** at a ~10% raw-return cost, and it is the **doctrinally faithful**
default (the A-D line is Weinstein's primary breadth gauge; running without it is
unfaithful). For a risk-managed Weinstein strategy this is the correct default —
the raw-return give-up is the price of the more conservative, better-risk-adjusted,
faithful gate. **Decision: flip** (user-confirmed direction; execute next session).

## ⚡ Do FIRST: optimize the A-D macro perf (the 3-5× slowdown is O(n²))

A-D-live runs are 3-5× slower because the macro **recomputes the cumulative A-D
array from the full breadth history on every weekly tick** instead of caching it:
- `macro.ml:_build_cumulative_ad_array` `List.fold`s the entire `ad_bars` list
  (O(n)); `_compute_momentum_ma_scalar` likewise folds the full list.
- `Macro.analyze` → `callbacks_from_bars ~ad_bars` rebuilds those each call, and the
  strategy calls macro analysis **every weekly tick** → O(n²) over the run
  (~1400 weekly ticks × ~1400-bar rebuild for a 27y window).
- The **MA path is already cached** (`ma_cache` threaded via
  `Panel_callbacks.macro_callbacks_of_weekly_views ?ma_cache`); the **A-D path is
  not** — that asymmetry is the 3-5× cost.

**Fix (do BEFORE the re-pin):** precompute the cumulative-A-D prefix-sum (and the
momentum-MA scalar series) ONCE and index by date — an `ad_cache` mirroring the
existing `ma_cache`, or hoist `_build_cumulative_ad_array` out of the per-tick
path. The cumulative A-D is a monotonic prefix sum, trivially incremental. This is
a pure perf change (no behavior change → no golden re-pin) and it makes every
A-D-live backtest — including the golden re-pin runs below — cheap. Verify
bit-identical output before/after. **This is the first next-session task; it
de-risks and speeds the whole flip.**

## Execution plan (next session) + ETA ~2-4h (much less once A-D perf is fixed)

**Gating unknown first (~20 min):** determine which data dir the committed goldens
read in CI — `data/` (no breadth → A-D-inert today) vs `test_data/` (Unicorn
breadth present 1965-2020, no synthetic tail → maybe already partly A-D-live). This
sets the blast radius (re-pin ~4 vs ~30 goldens). Check `default_data_dir`
(`/workspaces/trading-1/data`), the CI data setup, and whether goldens currently
load Unicorn breadth.

Then:
1. Generate synthetic ADL into **committed** `test_data/breadth/`
   (`compute_synthetic_adl.exe -data-dir <test_data>`); commit `synthetic_advn/
   decln.csv` (~100KB each). test_data/breadth currently has only Unicorn nyse_*.
2. **Re-pin affected goldens** — the dominant cost. ~30 committed golden scenarios
   across `goldens-sp500-historical` (~4 core; 3 of the 7 there are this session's
   research bases, not pins), `goldens-broad` (7), `goldens-small` (3),
   `goldens-sp500` (4), `panel_goldens` (2), etc. Each: re-run → read new metrics →
   update expected bands. **A-D-live is 3-5× slower** — the 27y long-short goldens
   are ~15 min *each* live.
3. Verify the full golden suite passes with new pins (docker, in-container).
4. Behavior-change PR → full CI + QC (changes backtest behavior).

ETA: ~2h if only a handful shift; ~4h if the whole suite does. Biggest variables:
the data-path blast radius + A-D-live slowness on the long-window goldens.

## Caveats
- sp500-as-of-2000 static universe (survivorship-stale late); the A-D-live-vs-inert
  *comparison* is internally valid (same universe both arms). Synthetic breadth
  0.92-0.93 corr vs official NYSE. Single universe — the flip should also spot-check
  a different universe golden during the re-pin.
