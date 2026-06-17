# Factor-lens causal analysis — top-3000 2000-2026 rolling-start matrix

**Date:** 2026-06-17 · **Matrix:** `matrix-t3k-2000-26-raw.md` (38 starts, all
benchmarked) · Cell-E over PIT `top-3000-2000` universe, `snap_top3000_2000_v2`
warehouse (columnar mmap), stride 255, end 2026-04-30, `SNAPSHOT_CACHE_MB=1024`,
parallel 2, ~10.3h wall.

**This is the top-3000 run the whole snapshot-format-v2 project unblocked** — the
in-container OOM ceiling that forced the top-1000 stand-in
(`../rolling-start-matrix-t1k-2000-2026/ANALYSIS.md`) is gone (see
`../../notes/next-session-priorities-2026-06-16-PM2.md`, `project_snapshot_format_v2`).
It answers the question the t1k lens explicitly could not: the **net-edge sign at
top-3000 breadth**, and whether the H1/H2/H3 regime-shape replicates.

## Headline

- **MTM edge flips POSITIVE: median edge vs GSPC.INDX +1.93%, and 60.5% of starts
  beat** the benchmark — vs t1k's −5.45% median / **8.3% beat**. Breadth delivers
  the fat-tail winners the thesis predicts (`project_edge_is_the_fat_tail`).
- **But realized edge stays NEGATIVE in every single start** (median −5.82%, mean
  −9.41%, **max −0.31%** — not one start has positive realized edge). Breadth
  *compresses* the realized lag (−5.82 vs t1k −8.90) and flips the beat-rate, but
  does **not** flip the honest realized sign positive.
- The ~7.7pp gap between edge (+1.93) and realized edge (−5.82) is terminal
  mark-to-market on **still-open fat-tail winners** — the let-winners-run
  signature. It is largest on mid-bull starts (2018-11 edge +16.4 / realized
  −4.4; 2020-04 +18.9 / −7.0).
- Median MaxDD **44.6%** (vs t1k 34.4%) — top-3000 is more volatile; the fat-tail
  names swing harder.

## Hypothesis tests (Pearson r, realized edge unless noted; n=38)

| hypothesis | factor | top-3000 | t1k (ref) | verdict |
|---|---|---|---|---|
| **H1 dodge-correction** | forward index max-DD | **r = −0.744**; terciles (by fwd-DD) **−4.21 / −6.46 / −16.39** monotonic | r = −0.79; −4.98/−9.65/−15.01 | **SUPPORTED (strong) — REPLICATES across breadth** |
| **H2 melt-up tax** | (H1 flip side) | shallowest-DD / smooth-bull starts have the worst realized edge (−16.4 mean third) | same | **SUPPORTED** |
| **H3 fresh-supply** | Stage-2 candidate count | r = +0.44 | r = +0.11 | **NOT clean** — higher than t1k but confounded with regime (Stage-2 count tracks the macro tape; bear-onset starts have low counts AND distinct edge), so it is not independent evidence for entry-supply |

**Read:** the strategy's *relative* performance is governed by **how much index
drawdown there is to dodge** (regime), at top-3000 just as at top-1000 — r=−0.74
vs −0.79, near-identical, with monotonic terciles. The regime-conditioning shape
is **universe-robust**. Entry-supply (H3) is not a clean lever even where its raw
correlation rose. This is the **fourth independent re-derivation** of
`project_accuracy_is_unreachable_diversify_instead` / `project_factor_lens_regime_governs_edge`:
regime is the lever, entry-selection is inert.

## What breadth changed (top-3000 vs top-1000)

| metric | top-1000 | top-3000 | direction |
|---|---|---|---|
| Median MTM edge | −5.45% | **+1.93%** | breadth flips it positive |
| Starts beating benchmark | 8.3% | **60.5%** | breadth flips the beat-rate |
| Median realized edge | −8.90% | −5.82% | breadth compresses the lag (still negative) |
| Best realized edge (max) | (negative) | −0.31% | still no positive-realized start |
| Median MaxDD | 34.4% | 44.6% | top-3000 more volatile |
| H1 r | −0.79 | −0.744 | regime-shape replicates |

**The net-edge-sign answer:** *universe-dependent and metric-dependent.* On the
**MTM/beat-rate** view, top-3000 breadth flips the strategy to beating GSPC in a
majority of starts. On the **honest realized-CAGR-vs-GSPC-price** view, it remains
negative everywhere — breadth narrows but does not close the structural lag of a
drawdown-dodger. Both are true; the gap is the unrealized fat tail.

## Caveats (what this lens can and cannot claim) — carried + sharpened from t1k

1. **Realized edge is negative in all 38 starts (max −0.31%).** Even at top-3000
   breadth, the strategy trails GSPC-price on *realized* annualised CAGR in every
   regime; H1 only governs the *size* of the gap (and halves drawdown vs the
   forward index's −34% to −57%).
2. **Recent-start MTM/realized divergence is severe and partly artefactual.**
   2020+ starts show large negative realized edge (−15 to −29) with positive MTM
   edge — they simply haven't had time to realise their open winners
   (`project_broad_universe_790_mtm_inflated`). The realized mean −9.41 is dragged
   by these; the cleanest reads are the early, fully-realised deep-DD starts
   (2000-2007: realized edge −3 to −7, MaxDD ~30-53% vs index −57%).
3. **H1 confounded with calendar era** (same as t1k): forward-DD is −56.78 for all
   2000-2008 starts (GFC dominates their forward window) and shrinks toward −9 for
   2025 — recent starts have both small forward-DD and depressed (open) realized
   edge, pushing r=−0.74 partly by era. Directional evidence, not a clean causal
   estimate. The monotonic tercile means survive this.
4. **Benchmark GSPC.INDX is price-only (no dividends)** — flatters the edge by
   ~2pp/yr; vs total-return SPX every realized edge is ~2pp worse.

## Why this came out this way (the transferable lesson)

The payoff is structurally a **bear-regime drawdown-dodge financed by bull-regime
CAGR lag** (Stage-4 exits cut the left tail; winner-touching + un-realised opens
cut the realised right tail). Breadth (top-3000) adds more fat-tail winners → the
MTM edge and beat-rate flip positive → but those winners are disproportionately
*still open*, so the realised CAGR edge stays negative while the lag compresses.
The factor lens confirms — now at two breadths — that the **only** factor
conditioning the edge is forward drawdown (regime); entry-supply is inert. This
rules **in** regime-gating / barbell / long-short overlays as the levers and rules
**out** entry-selection tuning, robustly across universe size.

**Deploy-when (unchanged, now breadth-confirmed):** the strategy is drawdown
insurance — deploy it (vs a SPY-timing floor) when a correction/bear is likely;
prefer the floor in smooth melt-ups where winner-touching taxes the mega-caps and
it lags hardest. **Regime, not entry quality, not breadth, decides the edge sign.**
