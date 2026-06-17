# top-3000 2011-2026 rolling-start matrix — IN FLIGHT

Launched 2026-06-17 (autonomous, off next-session-priorities-2026-06-17.md
"RECOMMENDED NEXT" — macro-regime-diverse confirmation cell per
promotion-confirmation.md).

## Why this cell
2000-26 matrix (#1639) is the bear-INCLUSIVE cell (dotcom 2000-02 + GFC 2008).
2011-26 is the bull-DOMINATED contrast cell — tests whether H1 dodge-correction
(realized_edge ~ forward_index_maxDD, r=-0.744 at top-3000) holds when there is
much less index drawdown to dodge. 1998_2026 deferred (macro-near-duplicate of
2000-26; lower marginal value).

## Invocation (container, detached)
- scenario `/tmp/cell-e-top3000-2011-15y.sexp` (PIT top-3000-2011 universe)
- warehouse `/tmp/snap_top3000_2011_v2` (columnar mmap, 3015 sym incl GSPC.INDX)
- stride-days 255, parallel 2, benchmark GSPC.INDX, SNAPSHOT_CACHE_MB=1024
- window 2011-01-03 -> 2026-04-30, ~22 starts
- out `/tmp/matrix-t3k-2011-v2/matrix-t3k-2011-26-raw.md`, log `.../run.log`

## On completion
Run the same factor-lens analysis as the 2000-26 ANALYSIS.md (H1/H2/H3 Pearson r
+ terciles vs forward index max-DD), compare the H1 r against 2000-26 (-0.744)
and t1k (-0.79). Confirmation = H1 replicates in the bull-dominated regime too.

## DONE 2026-06-17
22/22 starts, ~5.5h, 0 errors. H1 r=-0.892 (strongest of 3 cells), terciles
monotonic -7.79/-8.61/-23.40. See ANALYSIS.md. Confirmation grid: H1 robust
across universe (t1k/t3k) AND macro regime (bear-incl 2000-26, bull-dom 2011-26).
