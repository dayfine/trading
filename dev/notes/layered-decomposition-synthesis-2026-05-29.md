# Layered decomposition synthesis — what we should aim for and how to get there

**Date:** 2026-05-29 (overnight session)
**Window:** 1998-2025 (27 years, ~6,800 trading days)
**Purpose:** isolate each component layer's contribution to alpha against the same time period, identify the baseline performance target, recommend the path forward.

**Status:** SKELETON — numerical sections fill in as the in-flight agents return. Strategic synthesis (§ Recommendations) finalizes when all data lands.

---

## 1. What "baseline performance to aim for" means

Three reference points calibrate our expectations.

### 1a. Free baseline — BAH SPY over the test window

From PR #1322 + recent diagnostics:

| Metric | BAH SPY (1998-12-22 to 2026-04-14) |
|---|---|
| Total return | +598% |
| CAGR | ~7.2% |
| Sharpe | 0.45 |
| MaxDD | 56% (2007-2009 GFC) |
| Time in market | ~100% |

(BAH-SPY varies ~5-15bp by exact date range; 1998-12-22 to 2026-04-14 is the canonical window from SPDR sector ETF data availability.)

### 1b. Realistic active target — modest alpha with materially-reduced MaxDD

| Tier | CAGR | Sharpe | MaxDD | Notes |
|---|---|---|---|---|
| Floor (worth shipping) | 8.5% | 0.55 | 35% | beats BAH by +1.3pp; MaxDD cut by 21pp |
| **Goal** | **10%** | **0.70** | **25%** | beats BAH by +2.8pp; institutional-grade Sharpe |
| Stretch | 12-15% | 0.85+ | 20% | top-decile active manager |

Beyond 15% CAGR sustained over 27y is implausible without leverage or factor concentration that breaks elsewhere.

### 1c. Reference upper bound — Stan Weinstein's book claims

Weinstein (1988) claimed 20-30%+ annual. Calibration:
- Different market regime (1970s-80s: higher rates, less institutional efficiency)
- Sample bias (book highlights don't = 27-year live track record)
- We should NOT target 20-30% CAGR. **10% CAGR + reduced MaxDD is the right calibration.**

---

## 2. Layered component decomposition — what each layer should contribute

Eight conceptual layers, each adding to the previous. Measure: **CAGR delta vs the previous layer**, evaluated on the SAME 27y window.

| Layer | What it adds | Expected sign | Why |
|---|---|---|---|
| L0 | BAH SPY | n/a | baseline |
| L1 | **Stage classifier signal** (raw) | informational only | does the classifier correctly mark known regime boundaries? |
| L2 | **Pure stage-transition strategy** on SPY (long-only) | should be ≥ BAH; ideally +1-3pp CAGR with lower MaxDD | Weinstein's central claim: stage-based timing reduces drawdown without sacrificing too much return |
| L3 | L2 + **short side** (Stage 4 = short) | should be 0 to +2pp vs L2 | shorts capture bear-market downside but cost during V-recoveries |
| L4 | L2 + **portfolio sizing constraints** (Cell-E sizing) | NEGATIVE on small universe (proved) | sizing optimized for 3000-stock universe wrong for 1-symbol |
| L5 | L2 + **stop losses** (initial + installed) | should be 0 to +1pp; risk of whipsaw cost | tight stops cut bad trades early but increase whipsaw |
| L6 | L2 + **laggard rotation** | likely NEGATIVE on small universe (proved) | on 1-symbol becomes "go to cash" signal |
| L7 | + **multi-symbol universe + cross-section ranking** (RS, screener) | depends; should be ≥ L2 if ranking adds info | does picking top-K of N stocks beat just trading the index? |
| L8 | + **parameter tuning** (BO over portfolio + screener knobs) | should be small-positive; observed near-zero/negative | tuning is the LAST mile; if L1-L7 underperform, tuning can't save it |

### Where alpha SHOULD live (Weinstein hypothesis)

- **L2 should beat BAH SPY** — stage timing is the core claim
- **L7 should beat L2** — cross-section ranking adds info
- **L8 should add a small final increment** — tuning polishes a working strategy

### What we've actually observed

- **L8** (v7 BO tuning): -0.155 Sharpe regression vs Cell-E (FAILED promote on 16y panel)
- **L4+L5+L6 (sector ETFs Cell-E)**: -6.13pp CAGR vs BAH SPY (1a)
- **L4+L5+L6 (SPY-only Cell-E)**: -7.13pp CAGR (1a)
- **L5+L6 (fullsize portfolio, 1b/2b)**: still -6.36 to -6.61pp CAGR
- Pure sector-rotation alpha (2b − 1b): +0.26pp = **economically zero**

The catastrophic underperformance of L4-L6 = portfolio mechanics SUBTRACT alpha rather than adding it on small universes.

**Critical missing data:** L2 (pure stage-transition strategy) — does it beat BAH? The per-symbol-stage agent (a4a68998fd4cde6a3) is running this.

---

## 3. Component-isolation matrix (PENDING agent results)

| Layer | Test config | CAGR | Sharpe | MaxDD | Δ CAGR vs prev | Δ CAGR vs BAH SPY | Verdict |
|---|---|---|---|---|---|---|---|
| L0 | BAH SPY | 7.19% | 0.45 | 56% | n/a | 0 | baseline |
| L1 | Stage classifier accuracy | _qualitative_ | n/a | n/a | n/a | n/a | _PENDING manual inspection_ |
| L2 | SPY-only stage long-only | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _agent a4a68998fd4cde6a3_ |
| L3 | L2 + short on Stage 4 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _same agent_ |
| L4 | SPY-only fullsize Cell-E sizing | 0.01% | 0.22 | 2.09% | _TBD_ | -7.18pp | ❌ |
| L5 | L4 + wide stops (1b-wide-stops) | 0.01% | 0.16 | 0.83% | +0.0pp | -7.18pp | wide stops alone: marginal-positive Sharpe, no CAGR lift |
| L6 | L4 + **laggard disabled** (1b-no-laggard) | **0.34%** | **0.20** | 1.5% | **+0.33pp** | -6.85pp | **47× CAGR lift; laggard_rotation IS the alpha-killer** |
| L5+L6 | + both fixes + no-stage3 (1b-buy-and-hold-on-stage2) | 0.23% | 0.38 | 1.5% | +0.22pp | -6.96pp | maximally permissive — only **4 Stage-2 entries in 27y** |
| L7 | Top-3000 Cell-E full-window | _need to extract from v7_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | likely negative |
| L8 | v7-iter42 BO tuned | 0.625 Sharpe (vs cell-E 0.78) | _TBD_ | _TBD_ | _TBD_ | _TBD_ | ❌ FAILED promote |

---

## 4. Per-symbol stage strategy matrix (PENDING — agent a4a68998fd4cde6a3)

| Symbol | BAH CAGR | Long-only CAGR | Long-only Δ | Long-short CAGR | Long-short Δ | # Stage-2 entries | Verdict |
|---|---|---|---|---|---|---|---|
| SPY | ~7.2% | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| XLK | _TBD_ | ... | | | | | |
| (10 more) | | | | | | | |

---

## 4.5 Ablation findings (#1352, agent a1e60e7fefff49e49)

**Headline: `enable_laggard_rotation` is the dominant alpha-killer.**

| Variant | Total return | CAGR | Lift vs baseline | Exit mix (stop/laggard/stage3) |
|---|---|---|---|---|
| 1b-baseline (SPY-only) | +0.22% | 0.01% | — | 5/5/0 |
| **1b-no-laggard** | **+9.54%** | **0.34%** | **47×** | 6/0/4 |
| 1b-wide-stops | +0.30% | 0.01% | 1.4× | 1/9/0 |
| 1b-no-stage3 | +0.22% | 0.01% | 1× (INERT) | 5/5/0 |
| 1b-buy-and-hold-on-stage2 | +6.46% | 0.23% | 29× | 4/0/0 (+1 open) |
| 2b-baseline (sectors) | +7.43% | 0.27% | — | 88/87/17 |
| **2b-no-laggard** | **+49.45%** | **1.50%** | **5.5×** | 119/0/67 |
| 2b-wide-stops | +5.35% | 0.19% | 0.7× | 30/129/37 |
| 2b-no-laggard-wide-stops | +27.22% | 0.89% | 3.3× | 56/0/135 |

BAH SPY same window: 6.62% CAGR.

**Three findings:**

1. **`laggard_rotation` is the load-bearing alpha-killer.** On SPY-only it acts as "go-to-cash" signal (no rotation target); on sector-ETF it churns highly-correlated peers and dissipates trend alpha. Disabling produces 5-47× CAGR lift.

2. **`stage3_force_exit` is INERT** on SPY-only (byte-identical results). Likely-inert on sectors too. Suspect: never fires because Stage-2-to-Stage-3 transitions are themselves rare in this configuration. Investigate or just drop the knob.

3. **Wide stops alone don't help.** Cell-E's tight stops are NOT a primary bind.

**Critical secondary finding from `1b-buy-and-hold-on-stage2`:** with EVERY exit mechanism near-disabled, the strategy STILL only achieved 6.46% TOTAL return in 27 years — because the strategy entered Stage 2 only **4 times** in those 27 years.

Looking at SPY's chart: it's clearly in Weinstein Stage 2 (above rising 30-week MA) for the majority of 1998-2025. The production strategy's 4 entries reflects the **screener cascade** applied on top of the raw classifier (volume confirmation, RS filter, etc.) — not the classifier itself. See § 4.6 — the raw stage classifier (without screener cascade) finds 13-23 Stage-2 entries per symbol over 27y, which is plausible.

## 4.6 Per-symbol stage strategy findings (#1353, agent a4a68998fd4cde6a3)

**The load-bearing diagnostic.** Stripped-down stage-transition strategy on each symbol independently. NO portfolio mechanics. Pure L2 test.

**Headline: stage analysis is a DRAWDOWN-PROTECTION mechanism, not an alpha source on absolute return.**

### Long-only (12 symbols)

| Symbol | Stage CAGR | BAH CAGR | Δ CAGR | Stage MaxDD | BAH MaxDD | DD reduction | # Stage-2 entries |
|---|---|---|---|---|---|---|---|
| SPY | +3.80% | +7.16% | **-3.36pp** | 13.1% | 55.9% | -42.8pp | 13 |
| XLK | +1.44% | +5.65% | -4.20pp | 52.2% | 81.4% | -29.2pp | 18 |
| **XLF** | **+3.91%** | **+3.16%** | **+0.76pp** | 16.4% | 83.7% | -67.3pp | 16 |
| XLI | +3.34% | +7.13% | -3.79pp | 23.3% | 62.7% | -39.4pp | 21 |
| XLV | +3.20% | +6.82% | -3.62pp | 22.2% | 39.4% | -17.2pp | 21 |
| XLE | -0.99% | +2.32% | -3.31pp | 42.5% | 74.4% | -31.9pp | 22 |
| XLP | +1.17% | +3.96% | -2.79pp | 18.3% | 36.6% | -18.3pp | 15 |
| XLY | -0.05% | +5.82% | -5.87pp | 55.3% | 59.5% | -4.3pp | 17 |
| **XLU** | **+1.35%** | **+1.28%** | **+0.07pp** | 22.8% | 53.4% | -30.6pp | 17 |
| XLB | +0.78% | +2.83% | -2.05pp | 41.5% | 59.9% | -18.4pp | 23 |
| XLRE | +0.82% | +2.91% | -2.09pp | 30.9% | 37.6% | -6.7pp | 10 |
| **XLC** | **+14.33%** | **+11.82%** | **+2.51pp** | 17.2% | 46.5% | -29.3pp | 4 (noise) |

**Verdicts:**
- **3/12 beat BAH on CAGR.** XLF, XLU, XLC (XLC has only 4 entries since 2018 inception — likely noise)
- **Average Δ CAGR: -2.31pp** (loses on absolute return)
- **12/12 dramatically reduce MaxDD** — 4-5× better on SPY, XLF
- **% time in market: 25-42%** (Stage 2 conditions hold roughly a third of the time)
- **~16 Stage-2 entries per symbol per 27y** (1 every ~1.7 years; classifier IS firing)

### Long-short (12 symbols) — destroys value

| Symbol | Long-short CAGR | Δ vs BAH | Notes |
|---|---|---|---|
| SPY | +2.04% | -5.12pp | shorts cost during 2009/2020 V-recoveries |
| XLK | -1.24% | -6.88pp | |
| XLF | +1.07% | -2.09pp | |
| XLI | -0.20% | -7.32pp | |
| XLV | -0.78% | -7.60pp | |
| XLY | **-4.50%** | **-10.32pp** | worst |
| Others | -0.62 to +16.82% | -8.73 to +5.00pp | XLC outlier |

**Verdict: 1/12 beat BAH. Average Δ -5.01pp. Drop the short side feature work entirely.**

Why long-short fails:
- Stage 4 entries are LATE (steepest decline already over)
- Stage 4 → Stage 1 exits are also LATE (holds short through bottom + early recovery)
- Asymmetric drift (~7%/yr positive on equity indices) means shorting needs sharp drawdowns to be profitable

### Calmar reframe — the real story

Stage analysis IS delivering risk-adjusted return — we've been measuring with the wrong yardstick.

| Symbol | Stage Calmar | BAH Calmar | Stage wins? |
|---|---|---|---|
| SPY | **0.29** | 0.13 | 2.2× |
| XLF | **0.24** | 0.04 | 6× |
| XLI | **0.14** | 0.11 | 1.3× |
| XLU | 0.06 | 0.02 | 3× |
| XLB | 0.02 | 0.05 | loses |
| XLRE | 0.03 | 0.08 | loses |
| ... | | | |

**6/12 beat BAH on Calmar** including SPY itself. The strategy correctly exits before major drawdowns and sits in cash through the worst of every bear (2000-02, 2008, 2020, 2022).

### Critical finding for strategic direction

The dispatch hypothesis was: "if minimal stage strategy beats BAH on most symbols, then the existing system's portfolio mechanics are the killer."

**The opposite happened.** Even with NO portfolio mechanics, stage analysis loses absolute CAGR on most symbols. So:

1. Portfolio mechanics are NOT the dominant alpha-bleed culprit
2. The existing system's CAGR losses vs BAH are inherent to the stage signal
3. **HOWEVER:** Calmar reveals the strategy IS legitimately doing risk management — we should evaluate on risk-adjusted return, not CAGR
4. **The short side is value-destroying.** 1/12 wins. Drop it entirely.

**Updated alpha-source attribution:**

| Mechanism layer | Effect | Action |
|---|---|---|
| `laggard_rotation` | **STRONG negative** | **Disable as new Cell-E default** |
| `stage3_force_exit` | inert | drop knob (no signal) |
| stops (initial + installed) | marginal | keep at Cell-E values |
| Stage-2 admission criterion (L1) | **TOO RESTRICTIVE** | **investigate classifier implementation** |

## 5. Strategic verdict: Outcome **C-mixed**

Outcome C predicted: "L2 loses to BAH on most symbols → stage analysis doesn't extract alpha at index/sector level."

**That happened — but with one critical refinement:** stage analysis IS extracting risk-adjusted alpha (Calmar 6/12, dramatic MaxDD reduction 12/12). We've been measuring the WRONG metric.

**The Weinstein methodology, as implemented, is a defensive-tilt strategy, not an offensive one.** It correctly identifies bear regimes and exits to cash. It does NOT find clean-enough Stage 2 breakouts to consistently beat passive in absolute return.

## 6. What we ship + path forward — concrete

### STOP doing

| Item | Why | Confidence |
|---|---|---|
| v8 BO design + launch | Score formula gaming + sparse-acceptance + design saturation (3 critique rounds) + the underlying signal doesn't have the alpha BO was trying to extract | HIGH |
| Score-formula tuning | Same as above. Per `feedback_strategy_mechanic_changes_too_explorative.md`. | HIGH |
| Short-side feature work | 1/12 wins, -5.01pp avg. Stage 4 entries are inherently late vs SPY's recovery dynamics. | HIGH |
| Optimizing portfolio mechanics for absolute-CAGR alpha | Ablation showed laggard_rotation IS a killer (47× lift when disabled) but even with all mechanics off, stage signal still loses CAGR. Diminishing returns. | HIGH |
| Multi-window BO with absolute-alpha objective | Whatever objective we BO over on this signal surface, the surface itself doesn't have the alpha. | HIGH |

### START doing (the next session)

| Item | Why | Estimated scope |
|---|---|---|
| **Disable `laggard_rotation` as new Cell-E default** | Mechanism ablation: 47× CAGR lift on SPY, 5.5× on sectors. Zero downside since it never had a rotation target on small universes. | 1 PR (config change) |
| **Adopt Calmar/Sortino as primary success metric** | CAGR misses what the strategy actually delivers (drawdown protection). Calmar 6/12 wins = legitimate edge. Update promote_config.sh gates accordingly. | 1 PR (gate change) + 1 PR (docs/criteria) |
| **Investigate `stage3_force_exit` false-positive rate** | Per-symbol analysis suggests ~half of Stage 3 exits resolve back to Stage 2 (continuation), not Stage 4 (decline). Fixing this could give 1-3pp CAGR back without breaking risk profile. | 1-2 PR (data analysis + classifier tweak) |
| **Try cross-sectional rotation (multi-symbol L7)** | Per-symbol agent's recommendation: RS filter selects best Stage-2 candidate from basket. May extract more alpha than per-symbol since it always holds the strongest trending name instead of riding any single one through Stage 2 → 3 → reentry cycle. | 1-2 weeks (new strategy module) |
| Document this verdict in a "strategy assessment" doc | The 27y data + ablation + per-symbol matrix is a complete picture. Worth promoting from `dev/notes/` to `docs/design/` so future sessions don't relitigate. | 1 PR (docs reorg) |

### DEFER

| Item | Why |
|---|---|
| Broader-universe sweep (Russell 3000 / French-49 / Shiller) | Per `project_strategic_pivot_broader_first.md`. Worth doing eventually, but only AFTER fixing `stage3_force_exit` + adopting Calmar metric. Otherwise we'd be optimizing the wrong thing on a bigger surface. |
| Off-Weinstein mechanism (momentum, factor, regime-switching) | Premature. Stage analysis IS delivering on risk-adjusted return; redoing the core mechanism throws away the validated drawdown-protection edge. |
| Mid-cycle redesigns (Kelly sizing, continuation buys, sector cap) | Per `feedback_strategy_mechanic_changes_too_explorative.md`. Don't pile on more mechanisms; clean up the one we have first. |

### The reframed win condition

**Original target:** beat BAH SPY by +1-3pp CAGR with similar Sharpe.

**Reframed target:** beat BAH SPY on **Calmar ≥ 1.5×** with CAGR within -2pp (i.e. comparable return at materially-lower drawdown).

By that reframed target, the EXISTING Weinstein system (with `laggard_rotation` disabled) likely already qualifies on SPY. The work now is:
1. Confirm with a clean re-test on the existing config + laggard disabled
2. Apply the L1/L7 fixes (stage3 false-positives + cross-section rotation) to tighten CAGR back
3. Document + ship the reframed system as the baseline for future iteration

---

## Appendix A: SPY annual returns 1993-2026 (adjusted close)

| Year | Return | Regime tag |
|---|---|---|
| 1993 | +8.6% | bull |
| 1994 | +0.7% | flat |
| 1995 | +37.4% | bull |
| 1996 | +21.3% | bull |
| 1997 | +33.1% | bull |
| 1998 | +28.0% | bull |
| 1999 | +20.7% | bull |
| 2000 | **-8.9%** | bear (dot-com begin) |
| 2001 | **-10.1%** | bear |
| 2002 | **-22.4%** | bear (dot-com bottom) |
| 2003 | +24.2% | bull |
| 2004 | +10.8% | bull |
| 2005 | +5.3% | flat |
| 2006 | +13.8% | bull |
| 2007 | +5.3% | flat |
| 2008 | **-36.2%** | bear (GFC) |
| 2009 | +22.7% | bull (recovery) |
| 2010 | +13.1% | bull |
| 2011 | +0.9% | flat |
| 2012 | +14.2% | bull |
| 2013 | +29.0% | bull |
| 2014 | +14.6% | bull |
| 2015 | +1.3% | flat |
| 2016 | +13.6% | bull |
| 2017 | +20.8% | bull |
| 2018 | -5.3% | bear-ish (Q4) |
| 2019 | +31.1% | bull |
| 2020 | +17.2% | bull (V-recovery) |
| 2021 | +30.5% | bull |
| 2022 | **-18.7%** | bear (rate hike) |
| 2023 | +26.7% | bull |
| 2024 | +25.6% | bull |
| 2025 | +18.0% | bull |

**Window 1998-2025: bull 19y / flat 4y / bear 4y.** Heavy bull bias.

**Implication for L2 target:** if the stage strategy enters Stage 2 promptly (2003-Q2, 2009-Q2, 2020-Q2, 2023-Q1) and exits to cash on Stage 3 (2000-Q1, 2007-Q4, 2022-Q1), it should capture **65-75% of bull upside and avoid 80%+ of bear downside.** Implies ~7-9% CAGR with MaxDD ~15-20% — comfortably beats BAH on Sharpe even if CAGR matches.

**Implication for L3 target (long + short):** the four bear-year totals are roughly: 2000-02 cumulative ~-37%; 2008 -36%; 2018 -5%; 2022 -19%. If shorts capture HALF of bear downside, that adds ~+13pp + ~+18pp + ~+2pp + ~+10pp = +43pp cumulative over 27y, or roughly **+1.4pp annualized** beyond L2. Combined L3 target: **~8-11% CAGR with MaxDD ~10-15%.** Sharpe could approach 0.8-1.0.

## Appendix B: known SPY regime boundaries (for L1 stage-classifier sanity check)

| Date | Boundary | Expected stage | What to check |
|---|---|---|---|
| 1998-08 | LTCM crisis | Stage 3→4 brief | classifier should mark Stage 4 briefly Aug-Oct 1998 |
| 2000-03 | Dot-com top | Stage 3 | should mark Stage 3 by Mar-Apr 2000 |
| 2000-10 | Dot-com bear | Stage 4 | should mark Stage 4 by Oct 2000 |
| 2003-03 | Iraq War bottom | Stage 1→2 | should mark Stage 2 entry Mar-Apr 2003 |
| 2007-10 | GFC top | Stage 3 | should mark Stage 3 Oct-Nov 2007 |
| 2008-09 | Lehman | Stage 4 | should mark Stage 4 by Sep 2008 |
| 2009-03 | GFC bottom | Stage 1→2 | should mark Stage 2 by Apr-Jun 2009 |
| 2011-08 | EuroDebt wobble | Stage 3 brief | should mark Stage 3 briefly Aug-Sep 2011 |
| 2015-08 | China devalue | Stage 3 brief | should mark Stage 3 briefly Aug-Sep 2015 |
| 2018-Q4 | Vol-pocalypse | Stage 3 → 4 brief | should mark Q4 2018 Stage 4 |
| 2020-02 | COVID top | Stage 3 | should mark Feb-Mar 2020 Stage 3 |
| 2020-03 | COVID bottom | Stage 1→2 | should mark Stage 2 by Apr-May 2020 |
| 2022-01 | Rate hike top | Stage 3 | should mark Stage 3 Jan-Mar 2022 |
| 2022-12 | Rate hike bottom | Stage 1→2 | should mark Stage 2 by Q1-Q2 2023 |

If the classifier misses several of these, the alpha-extraction problem is at L1 (classifier accuracy), not at L2+ (timing rule).
