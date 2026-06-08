# P1 — rolling-start dispersion on the honest PIT universe (2026-06-08)

**Task:** P1 from `next-session-priorities-2026-06-07.md` — run the rolling-start
dispersion runner (#1476) on the PIT universes to get start-date robustness
distributions (the primary lens per
`dev/plans/evaluation-objective-and-metrics-2026-06-07.md`). Follows directly
from the P0 verification (`p0-verify-broad-universe-790-2026-06-08.md`), which
showed single-window headlines are fat-tail-driven and unreliable.

## TL;DR

On the robust (drawdown-tail) lens, **breadth is a real robustness lever**: across
matched start dates, top-3000 **caps peak-MaxDD at ~24-33% on every start** while
top-1000 **blows out to 58-61%** on the bad starts — the catastrophic-DD tail is
eliminated, worst-case DD nearly halved. top-3000 also beats top-1000 CAGR in
**8/8 matched starts**, though the CAGR *levels* inherit the P0 terminal-MTM
inflation (read DD-tail contraction as the clean signal). Start-date sensitivity
remains large for both (top-1000 median CAGR only ~5.6%) — point estimates are
noise; the **distribution** is the signal, exactly the methodology reframe.
Separately, the experiment-ledger verdicts are survivorship-robust (§4) — the
broad-PIT re-baseline is about magnitude + the breadth lever, not flipping
verdicts.

## Method

`rolling_start_eval` (#1476): one Cell-E scenario, start dates at a fixed
cadence (yearly, `--start-stride-days 365`) up to a fixed end (2026-04-30), one
full backtest per start, collecting per-start CAGR, capital-relative drawdown
(`MaxUnderwaterVsInitial`, #1471 — the robust lens, not terminal-dependent), and
peak-relative MaxDD. Snapshot mode, `/tmp/snap_top3000_2011`, same Cell-E config
as P0 (identical except `universe_path`).

**Caveat carried from P0:** per-start **CAGR is terminal-NAV-based**, so it
inherits the mark-to-market inflation (a start whose path still holds the AXTI
monster at 2026-04-30 reports an inflated CAGR). The **capital-relative DD** and
the **median** (robust to the short-window outlier) are the trustworthy reads.
The latest start (≈4 months to end) annualizes wildly (fixed-end short-window
artifact) — exclude it from interpretation.

## 1. top-1000 PIT — dispersion across 16 yearly starts

| metric | median | p10 | IQR | min | max |
|---|---|---|---|---|---|
| CAGR % | 5.64 | -0.08 | 4.49 | -6.77 | 210.49* |
| Capital-rel DD % (#1471) | 6.46 | 2.75 | 18.73 | 0.43 | 39.92 |
| Peak MaxDD % | 27.33 | 19.04 | 36.27 | 14.93 | 60.53 |

*210.49 = 2025-12-28 start (~4 months); fixed-end short-window annualization
artifact — ignore.

Per-start CAGR: −6.77 (2021 start, into the 2022 bear) … ~10% (good starts),
**median only ~5.6%**. The standalone +142.9% total return (P0) is just the
**2011 start compounding** — and even that is **5.96% CAGR**. Capital-relative
DD spans 0.4%→39.9% (the 2021-top start went ~40% below the starting stake).

**Reading:** start-date sensitivity dominates. The strategy's *typical* (median)
outcome on top-1000 is a modest ~5–6% CAGR; the impressive totals are
start-luck. This is the methodology-reframe thesis in hard numbers — point
estimates are noise; the distribution is the signal.

## 2. top-3000 PIT — dispersion across 8 starts (2-year stride)

| metric | median | p10 | IQR | min | max |
|---|---|---|---|---|---|
| CAGR % | 17.67 | 7.04 | 20.26 | 6.84 | 102.46 |
| Capital-rel DD % (#1471) | 14.01 | 3.24 | 18.42 | 0.00 | 26.84 |
| Peak MaxDD % | 31.05 | 25.93 | **4.20** | 24.39 | 33.35 |

### 2a. Apples-to-apples — the SAME 8 starts, top-1000 vs top-3000

The top-1000 16-start (§1) set contains these 8 starts, so per-start is exact
(top-1000 was yearly; the 8 here are a subset). Lower stride count is the only
difference; the start *dates* match.

| start | CAGR t1k → t3k | Peak-MaxDD t1k → t3k |
|---|---|---|
| 2011-01-01 | 5.96 → **15.33** | 58.30 → **29.18** |
| 2012-12-31 | 6.55 → **18.14** | 58.61 → **26.59** |
| 2014-12-31 | −0.02 → **7.13** | 28.70 → 32.68 |
| 2016-12-30 | 3.51 → **6.84** | 18.18 → 24.39 |
| 2018-12-30 | 9.63 → **17.21** | 59.84 → **32.62** |
| 2020-12-29 | 8.75 → **32.74** | 60.53 → **33.35** |
| 2022-12-29 | 6.61 → **35.93** | 21.95 → 32.87 |
| 2024-12-28 | 5.69 → **102.46** | 20.71 → 29.47 |
| **median** | **6.08 → 17.67** | **~43.5 → 31.05** |

**Two robust findings:**

1. **top-3000 beats top-1000 on CAGR in 8/8 starts** (+3 to +97pp). The margin
   is largest for the late starts (2020/2022/2024) — those are the most
   AXTI-MTM-inflated (AXTI is a larger fraction of a shorter, smaller-base run;
   §3 / P0). But it is **positive even for the AXTI-diluted early starts**
   (2011-2018: +3 to +12pp over a 7-15y base where one open position is a small
   fraction) — a real return uplift, not purely the AXTI artifact.

2. **Breadth caps the drawdown tail — the load-bearing robustness result.**
   top-1000 peak-MaxDD **blows out to 58-61%** on the bad starts
   (2011/2012/2018/2020); top-3000 is **bounded 24-33% across every start**
   (IQR 4.20 vs top-1000's ~38). The worst-case top-3000 DD (33.4%) is **nearly
   half** the worst-case top-1000 DD (60.5%). Broad universe is not always lower
   DD (it is slightly higher on the calm 2014/2016/2022/2024 starts) — it
   **eliminates the catastrophic-DD tail**. This is diversification working as
   expected, and it is **DD-based → immune to the terminal-MTM caveat** that
   contaminates the CAGR comparison.

**Caveat:** capital-relative DD (#1471) median is *higher* for top-3000 (14.0 vs
6.5) — but this metric is noisy across the different early-underwater paths and
the 0.00 floor (2012 start never went below initial); the peak-MaxDD tail
contraction is the cleaner robustness signal. CAGR levels inherit the P0 MTM
inflation; read the *DD-tail contraction* as the robust breadth-robustness
evidence, not the absolute CAGR uplift.

## 3. Why headlines are fat-tail-driven — realized PnL concentration (P0 data)

Even the *realized* (closed-trade) return is dominated by a handful of names —
not a broad edge:

| universe | realized net | top-5 winners | top-5 share | biggest single |
|---|---|---|---|---|
| top-1000 | $682k | $811k | **119%** | GME $369k (2021 squeeze) |
| top-3000 | $1.998M | $2.577M | **129%** | SKYW $747k / CALX $746k |

In both, the top-5 winners **exceed the entire net** (everything else nets
negative) — the classic trend-following signature (win-rate ~35%, win/loss ~2.6,
skew 5.7–12.4). The broad-universe edge is concretely **bigger fat-tail
winners**: top-3000's top-5 = $2.58M vs top-1000's $811k (3.2×) ≈ the realized
return ratio (2.9×). Breadth = a higher max-order-statistic of winner size.

**Consequence:** every single-window headline (+790, +199, +143) is a draw from
a fat-tailed distribution. The only honest evaluation is the dispersion above —
not any point estimate. This is why the rolling-start lens (P1) and the
stale-exit fix (#1484, so terminal monsters realize consistently) are the
load-bearing methodology, not another strategy dial.

## 4. P0 second-half — do the ledger verdicts survive on honest data?

The priorities doc asked to "re-check past ACCEPT/REJECT verdicts on honest
data — some ACCEPTs may be survivorship artifacts, some REJECTs judged on
inflated numbers." Audited all 12 ledger entries (`dev/experiments/_ledger/`):

- **Every standing verdict is on an SP500 universe** — `sp500-2010-2026`
  (survivor-biased, ≤506 syms) or `sp500-2000-2026` (point-in-time-2000, incl.
  delistings LEH/BS/YHOO). **None has been tested on the broad top-3000 PIT.**
- **The relative verdicts are survivorship-robust.** Each is a *baseline-vs-
  variant comparison on the same universe*, so survivorship inflation hits
  baseline and variant equally and cancels in the comparison
  (`project_composition_golden_survivor_bias`). Survivorship inflated the
  **absolute** magnitude (237% survivor vs 142.9% / 29.6% PIT), **not** the
  sign of any verdict. → The REJECTs do not need re-running to stay valid.
- **No live promotable ACCEPT exists.** The only ACCEPT
  (`early-admission-surface-v2`, on the 2010-2026 survivor golden) was
  *already killed* by the deep 2000-2026 PIT test (`early-admission-deep-27y` =
  Reject). So there is no survivorship-inflated ACCEPT in danger of shipping.
- **Mechanistic REJECTs are universe-independent.** exit-timing / stage3-
  hysteresis are pure drag *because* deferring the Stage-3 exit costs more in
  bear regimes (confirmed on BOTH 2010-2026 AND deep 2000-2026 PIT). Breadth
  doesn't change that mechanism → **low priority** to re-check on top-3000.

**The two verdicts worth re-checking on broad top-3000 PIT** (because they are
intrinsically breadth/candidate-count-sensitive, unlike the exit-timing drag):
1. **laggard-rotation** (`laggard-disable-retracted`): "helps on 500-symbol
   panels, only hurt on a 12-symbol diagnostic." Rotating laggards→leaders needs
   a deep candidate pool; on top-3000 it may help *more*. Re-test.
2. **continuation-buy** (`continuation-combined-axis`): candidate-supply-
   sensitive; rejected as a 5y single-window overfit on 500 syms. Worth a
   broad-PIT re-look only if the breadth re-baseline motivates it.

**Bottom line:** the broad-PIT re-baseline is about **absolute magnitude + the
breadth lever**, not about flipping past verdicts. The verdict ledger stands.

## 5. Open items
- Fill §2 when the top-3000 rolling run completes.
- #1484 (stale-position force-exit) — re-run baselines on honest NAV after.
- Re-pin the top-1000 15y baseline (P0 §4: my 142.9% vs the doc's 29.6%).
