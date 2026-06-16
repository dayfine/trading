# Factor-lens causal analysis — top-1000 2000-2026 rolling-start matrix

**Date:** 2026-06-16 · **Matrix:** `matrix-t1k-2000-26-raw.md` (38 starts, n=36
benchmarked) · Cell-E over PIT `top-1000-1999` universe, `snap_top3000_2000`
warehouse, stride 255, end 2026-04-30, `SNAPSHOT_CACHE_MB=1280` (no thrash, ~4.8h).
This is the in-container-feasible stand-in for the OOM-blocked top-3000 26y matrix
(see `../panel-runner-perf-2026-06-16/WINDOW-PRUNE-FINDINGS.md`). Tests the
deploy-when hypotheses H1/H2/H3 from `dev/notes/factor-decomposition-lens-design-2026-06-14.md`.

## Headline

- Median edge vs GSPC.INDX **−5.45%**, median **realized** edge **−8.90%**;
  only **8.3% of starts beat** the benchmark.
- Median MaxDD **34.4%** vs the forward index's **−33.9% to −56.8%** (dot-com +
  GFC) — the distribution-compressor signature, again.

## Hypothesis tests (Pearson r, realized edge unless noted; n=36)

| hypothesis | factor | result | verdict |
|---|---|---|---|
| **H1 dodge-correction** | forward index max-DD | **r = −0.79** (fdd negative → deeper DD ahead = higher edge); terciles −4.98 / −9.65 / −15.01 monotonic | **SUPPORTED (strong)** |
| **H2 melt-up tax** | (the H1 flip side) | shallowest-DD / smooth-bull starts have the worst realized edge (−15 mean) | **SUPPORTED** |
| **H3 fresh-supply** | Stage-2 candidate count | **r = +0.11** | **NOT supported** |
| (contamination check) | forward DD vs **MTM** edge | **r = +0.09** (vs realized −0.79) | MTM edge is noise; realized is the honest measure |

**Read:** the strategy's relative performance is governed by **how much index
drawdown there is to dodge** (regime), not by entry-supply. Realized edge tracks
forward drawdown at r=−0.79; entry Stage-2 count is ~uncorrelated (r=0.11). This
is the per-start-date confirmation of the structural-bar / barbell / regime-gating
thesis and a third independent re-derivation of
`project_accuracy_is_unreachable_diversify_instead` (entry-selection is a dead
end; regime is the lever).

## Deploy-when guidance (the lens output)

The strategy is **drawdown insurance**: deploy it (vs a SPY-timing floor) when a
correction/bear is likely — it sidesteps the drop and earns relative edge — and
prefer the floor in smooth melt-ups, where winner-touching taxes the mega-caps
and it lags hardest. **Regime, not entry quality, decides.**

## Caveats (what this lens can and cannot claim)

1. **All-negative realized edge — the effect compresses underperformance, it
   does not flip it.** Even the deepest-DD third averages −4.98 realized edge.
   So on top-1000 over 2000-26, the strategy trails GSPC-price on CAGR in *every*
   regime; H1 only makes the gap smaller (and halves drawdown).
2. **Breadth matters — top-1000 is too thin.** The 28y **top-3000** deep run beat
   on realized (+1552% vs +599%, `project_deep_1998_2026_contiguous`); this
   top-1000 matrix trails everywhere. The edge needs the top-3000 fat-tail
   winners (`project_edge_is_the_fat_tail`); top-1000 lacks enough of them. So
   the *sign* of the net edge is universe-dependent — this lens establishes the
   *regime-conditioning shape* (H1/H2/H3), not the net-edge sign for top-3000.
3. **Confounds inflate the H1 correlation.** Forward-DD correlates with calendar
   era (deep-DD = early 2000-2010 starts; shallow = recent), and recent starts'
   realized edge is partly depressed by unrealized-open-position stripping (they
   haven't had time to realize; mean realized edge −15.6 for ≥2018 starts vs −7.6
   for ≤2017). Both push the same direction as H1, so r=−0.79 is directional
   evidence, not a clean causal estimate. The cleanest read is the early,
   fully-realized deep-DD starts (2000-2007): realized edge −2 to −7 with MaxDD
   ~35% vs index −57%.
4. **Benchmark is GSPC.INDX (price-only, no dividends)** — flatters the strategy
   edge by ~2pp/yr; vs total-return SPX every realized edge is ~2pp worse.

## Why this came out this way (the transferable lesson)

The strategy's payoff is structurally a **bear-regime drawdown-dodge financed by
bull-regime CAGR lag** (Stage-4 exits cut the left tail; winner-touching cuts the
right tail). The factor lens confirms the *only* factor that conditions the edge
is forward drawdown (regime) — entry-supply (Stage-2 count) is inert. This rules
**in** regime-gating / barbell / long-short overlays as the levers and rules
**out** any entry-selection or supply-timing tweak, narrowing the search exactly
as the standing prior predicts. The next lever worth testing is therefore a
**regime-gated deploy rule** (strategy when forward-DD-risk high, SPY-floor else),
not another entry knob — but the deploy signal (forward DD) is only known ex-post
here; a *tradeable* proxy (the macro gate / breadth) would need its own validation.

## Artifacts
- `matrix-t1k-2000-26-raw.md` — the 38-start matrix with factor columns.
- `run.log` — run tail. Per-start DD columns: treat with the usual A2 caveat
  (the impossible-DD projection bug affects DD columns on some rows, not
  edge/CAGR which are computed from initial/final).
