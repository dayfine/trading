# Next-session priorities — 2026-07-23

**Supersedes** `next-session-priorities-2026-07-19.md`. The 07-19→07-23
sessions completed the ENTIRE resistance-v2 program: bundle evidence
chain (grid split + rolling-start repair) → lever-(f) built, surfaced,
REJECTED at both fold and 28y-path lenses → sketch v5 sparse storage
(user-designed) shipped + certified at every scale → **THE BUNDLE
PROMOTED (PR #2047, user R3 approval 07-23)** → first live picks on the
promoted screen (#2050) → README deep-headline generator (#2054).
Margin M1-M3 also merged (#2016 M3a tiers, #2017 M3b buy-in stress).

## P0 — Margin M4 validation protocol (user-queued 07-23)

`dev/plans/levered-longshort-margin-realism-2026-07-14.md` §M4. Three
stages, run in order; no levered number is quoted anywhere before all
three pass:

1. **Parity gates** (cheap, run first): margin-off ≡ baseline and
   `req=1.0/rate=0` ≡ E-capped, bit-identical (R1 per milestone).
2. **Squeeze stress cells**: GME-window + 2008 + dot-com, short book
   armed WITH M3a tier tables + M3b `short_buyin_stress_mode`;
   force-cover ordering audited per event.
3. **Leverage surface**: `initial_long_margin ∈ {1.0, 0.75, 0.5}` ×
   short sleeve on/off via experiment-gap-closing (WF-CV + DSR), then
   promotion-confirmation grid WITH a bear-regime cell. Bar: priced
   leverage must clear the UNLEVERED frontier (leverage amplifies both
   tails — MTM-up is not the question).

Basis notes: warehouses of record `/tmp/snap_top3000_dedup_v5thin`
(1.3G) + `/tmp/snap_sp500_2000_2026_v5thin` (324M); the promoted
default config IS the new baseline (28y record +8,689%/DD 30.3,
`staging-leverf-28y/top3000-2000-2026-rcb-f000.sexp`, all four arms'
actuals in `trading/dev/backtest/scenarios-2026-07-22-231614/`).

## P1 — small follow-ups from the picks run (#2050 findings)

- `render_weekly_report.exe` does not surface the v2 resistance grade
  in Markdown (sexp-only today) — small renderer fix.
- Stray `"Weinstein_types."` prefix in grade strings (cosmetic).
- `fetch_finviz_sectors` manifest never built (~3h scrape; didn't skew
  07-17 picks — sector labels came from the pinned universe).
- Optional: prior-week picks backfill (as-of 07-10) if the user wants
  the comparison.

## P2 — carried

- Tax lens issue #2006 (Phase 1 report-layer exe; Run-D reference
  numbers need updating to the promoted-bundle basis).
- Trader-preset bundle audit; floor-quality P1b step 3; decision_audit
  Phase-2.
- Lever (b) regime-softener remains the designed default-off axis for
  the bundle's known bull-era-broad wash (2011-cell); no build gate
  currently.
- v3 warehouses (`snap_top3000_dedup_v3_sketch` 3.3G + sp500 851M)
  deletable on user OK (certified basis preserved in goldens).

## Operational lessons (07-20→23) — all in memory files

- Chain scripts: `flock` single-instance + hard abort after EVERY
  stage (`feedback_chain_scripts_single_instance` — the double-launch
  race cost 6h + a phantom bug hunt).
- Agents STILL end turns "waiting for build events" despite lead
  constraints (4× this session) — kick template in
  `feedback_agents_background_wait_stall`; expect to use it.
- Background `sleep`-based polls get reaped; persistent Monitors
  survive. Merge polls: re-arm on kill.
- The worktree reaper bit two agents mid-task — WIP-push-first is
  mandatory in every brief.
- Panel cache materializes whole files: warehouse SIZE is the memory
  ceiling, not column count read (that's why v5 PR 4 dropped the dense
  columns rather than relying on lazy paging).
- jj gotcha (recurred this session): writing a file then `jj new
  main@origin` strands it in the old @; write files AFTER settling @.
