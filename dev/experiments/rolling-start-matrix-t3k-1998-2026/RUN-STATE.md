# top-3000 1998-2026 rolling-start matrix — IN FLIGHT

Launched 2026-06-17 (autonomous, last recommended confirmation cell from
next-session-priorities-2026-06-17.md). Deepest contiguous window.

## Why this cell
3rd/final confirmation cell. 2011-26 (bull-dom, H1 r=-0.892) + 2000-26 (bear-incl,
-0.744) + t1k-2000 (-0.79) already agree. 1998-28y adds PRE-DOTCOM starts whose
huge forward DD the H1 lens predicts should yield the BEST (possibly first
POSITIVE) realized edge — reconciling with the deep-contiguous run that BEAT
(+1552% vs +599%, project_deep_1998_2026_contiguous). Tests whether the
all-negative-realized-edge pattern (every start in 2000-26 + 2011-26) breaks for
the deepest-DD pre-dotcom starts.

## Invocation (container, detached)
- scenario `/tmp/cell-e-top3000-1998-28y.sexp` (PIT top-3000-1998 universe)
- warehouse `/tmp/snap_top3000_1998_2026_v2` (columnar mmap, 3015 sym)
- stride-days 255, parallel 2, benchmark GSPC.INDX, SNAPSHOT_CACHE_MB=1024
- window 1998-01-01 -> 2026-04-30, ~40 starts, ~10-11h
- out `/tmp/matrix-t3k-1998-v2/matrix-t3k-1998-28-raw.md`, log `.../run.log`

## On completion
Same factor-lens (H1 r + terciles vs fwd index max-DD, H2, H3). Compare H1 r to
the other 3 cells. KEY: do the earliest (pre-dotcom, deepest-fwd-DD) starts show
POSITIVE realized edge? If yes → reconciles the deep-run beat + sharpens the
regime-gated-deploy lever (deploy into deep-DD regimes earns positive edge).
