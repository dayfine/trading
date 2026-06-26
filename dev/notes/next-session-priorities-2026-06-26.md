# Next-session priorities — 2026-06-26 (handoff)

**Supersedes** `next-session-priorities-2026-06-25-PM.md`. Strategic pivot this
session: the longshort backtest numbers are **not trustworthy** (inflated by
unmodeled short mechanics), so **fixing short-side realism is the new P0** and
**concentration work is tabled**.

## P0 — fix short-side realism (the new priority)
**Plan: `dev/plans/short-side-realism-2026-06-26.md`** (full scope + PR sequence).

Why: the A-D grid's longshort numbers (e.g. +3408% deep ~1999-2026, 2026-06-23) are
inflated by **broken/missing short mechanics** — no margin model (G5: free leverage,
NAV can go negative), short stops fire wrong (G1), no borrow/locate, cash floor only
gates Buys (G3). The recent June 21-22 short work was **selection faithfulness**
(decline-character, neutral_blocks_shorts), all **default-off**, and touched **none**
of the realism mechanics. Until these land, no longshort absolute return is believable.

Sequence (from the plan):
1. **G1 short-stop firing** — SMALL, already diagnosed, DRAFT fix + reproducer tests
   exist (`Stops_runner` stage-hardcode + side-aware `actual_price`). Land it first.
2. **G2 short round-trip metrics** — SMALL legibility fix (`simulation/lib/metrics.ml`)
   so the short leg is auditable.
3. **Margin model (G3+G5+G4 unified)** — LARGE, the core fix. Reg T initial (150%
   collateral on short entry) + FINRA maintenance tiers (≥$5: max($5/sh,30%); <$5:
   max($2.50/sh,100%); keep `short_min_price≈17`) + margin-call force-liquidation
   (logged + signalled). Config-driven, default-off-safe. Regulatory spec already
   researched in `dev/notes/long-short-margin-mechanics-2026-06-12.md`.
4. (Later) borrow/carry cost.

**Acceptance:** re-run an inflated longshort number before/after the margin model;
expect it to drop substantially + NAV never negative. Then longshort absolutes (and the
A-D-live grid) become trustworthy, not just relative.

## TABLED — concentration (do after shorts are legible)
- The long-only **0.30 re-pin (#1753) stays merged** — it's correct + orthogonal to
  shorts (long-only, aligns goldens to the already-existing production default 0.30).
- **No further concentration work** until shorts are fixed: skip the broad
  long-only/longshort × A-D matrix, the concentration confirmation grid, and the
  goldens-small 0.14→0.30 alignment. They were nice-to-haves; the basis is muddied by
  unreliable shorts anyway.
- The in-flight broad long-only 0.30 measurement was **killed** mid-run (no longer
  needed). The committed broad WF base + specs remain for whenever concentration
  resumes.

## Context that drove the pivot (this session)
- Concentration=0.30 promoted to the long-only goldens (#1751 ACCEPT, #1753 re-pin,
  #1755 comment fix, #1756 handoff) — DONE. 0.30 is regime-dependent (helps long
  windows + aggregate, hurts some short windows); goldens now reflect it honestly.
- Reconciled the broad 1998-2026 numbers: **pre-A-D-live ~1552% realized / 1785% MTM**
  (06-14, top-3000, 0.14) vs **post-A-D-live 698.8% MTM** (06-25) — the A-D-live flip
  (#1725) costs long-only bull-return (short-timing edge long-only can't use).
- Longshort 3408% (sp500-515, not top-3000) is **not real** — short mechanics broken;
  led to this P0.

## Operational
- Main green at `bad6a5d0` (this session's last merge). All session PRs merged.
- Deep bar store: repo-root `data/`; warehouse `/tmp/snap_top3000_1998_2026` (ephemeral).
- Container had orphaned QC-agent runner processes eating 6GB this session (killed) —
  watch for stale `scenario_runner` procs from crashed agents; `pkill -f <dir-token>`.
