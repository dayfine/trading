---
name: pit-drawdown-2021-25-macro-veto
description: ⭐ The PIT band's NAV story is one episode — 2021-11 peak → 2024/25 trough, −38 to −53 % on every arm and universe; largest lever found = the macro COMPOSITE outvotes a Stage-4 index (2022: SPX below a falling 30-wk MA all year, trend still Bullish 25+ weeks → 126 entries, 82 % losers, −$0.8M/salt). Proposed first experiment: default-off index-stage veto, 3-salt surface vs the PIT band. Winners ≥+20 % fell 10 % → 2 %. (09-16)
metadata:
  type: project
---

**Like-for-like the PIT universe is NOT worse on NAV**: salt 0 ends 5.57 vs 4.83 $M and leads 2004–2021. The band's
spread (152/188/457) is the last five years: every arm peaks late 2021 ($4.7–6.1M) and gives back 38–53 %; PIT s1/s2
never recover (CAGR 4.1 / 3.6 %). Record: `dev/experiments/pit-universe-2026-09-14/README.md` §"Drawdown dissection".

**Mechanisms, by size (3 salts pooled, entries 2021-11..2025-04: 453 trades −$5.18M; old universe 402 / −$2.29M):**
1. **Macro composite outvotes the index.** `Macro.analyze`: index stage 3.0 vs breadth-type indicators 7.0,
   `confidence > 0.65 → Bullish` — four bullish gauges on a bear rally beat a Bearish index (0.70). 2022: SPX below
   its 30-wk MA from 01-21 through Nov, MA falling from April, yet `trend` = Bullish Jan–Feb / Jun–Jul / Oct–Dec.
   126 entries in 2022, 82 % losers, median hold 15 d (baseline 37), 55 % stopped ≤ 20 d. The gate never fired.
2. **No fat tail for three years**: ≥+20 % winners 2.0 % of entries vs 10.0 % baseline (1 vs 24 at ≥+50 %); avg win
   halved, avg loss same. Both universes.
3. **Recent-vintage cohort** (names absent from every list ≤ 2018): 18–22 % of entries, 40–50 % of the loss, 90 %
   losers — the honest universe's cost, universe-specific.
4. Marks on positions open at the peak: −$0.9 to −1.9M.

**How to apply:** first experiment on the band = `macro_index_stage_veto` (default-off; a Stage-3→4/4 primary index
blocks long entries regardless of composite confidence), pre-registered, 3 salts vs `a0-pit-null-s{0,1,2}-v11`,
V6 gate, realised AND Calmar ≥ 2/3 salts, paired 2022 cohort as the mechanism read. Book check first: the reference
§2.1 calls the index stage the most important single indicator; whether it is a veto or one vote is tier 2.
Top-of-funnel moves behind this. Never quote the band level as "worse than the old universe" without this split.
Related: [[record-rebase-2026-09-15]], [[edge-is-the-fat-tail]], [[melt-up-lag-anatomy]], [[warehouse-vintage-coverage]].
