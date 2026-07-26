# Next-session priorities — 2026-07-19

**Supersedes** `next-session-priorities-2026-07-17.md`. The 07-18/19
session executed the entire resistance-v2 promotion-evidence program,
built margin M1b (both halves) + M2, and specced the tax lens. Main
green; PRs #1997/#1998/#2001/#2002/#2004/#2005/#2010 all merged.

## P0 — the bundle studies (USER GREEN-LIT 2026-07-19; chain LAUNCHED same night)

`dev/notes/resistance-supply-promotion-memo-2026-07-19.md` option B —
candidate = BUNDLE (w_overhead_supply + virgin_crossing_readmission +
floors 0/0/0). **Chain launched 07-19 ~20:00 EDT** (detached; markers
in `/tmp/sweeps/bundle-studies/status.log`; first launch aborted on a
wedged-dune lock — five stale dunes killed, `_build/.db` reset,
relaunched clean; stage-1 banner verified: variants=3, folds=26):

1. sp500 grid cell (`bundle-grid-SP500-2000-2026.sexp`, weights {15,30},
   26×1y, catstop-golden base) → `/tmp/sweeps/bundle-sp500/` (~4-6h);
2. broad 2011-26 cell (`bundle-grid-BROAD-2011-2026.sexp`, 7×2y, record
   convention base) → `/tmp/sweeps/bundle-2011/` (~4-5h);
3. bundle rolling-start
   (`staging-rolling-start/top3000-2000-2026-rc-bundle.sexp`, stride-730
   paired grid, parallel 2) → `/tmp/sweeps/bundle-rolling/` (~9h). THE
   question: do the 2000/2008/2010 recovery-window paths repair? Compare
   against the 07-18 baseline/w30 reports in
   `.sweep-output/rolling-start-promo/`.

Next session: read all three → both confirm ⇒ draft the bundle
promotion PR (flip the three defaults together as ONE unit, citing
ledger + grid + rolling-start + this chain). Recovery windows don't
repair ⇒ keep axes; lever (f) becomes the escalation.

## P0b — lever (f) CODE build (user-directed 07-19: "closely follows")

Build the age-banded-histogram CODE PR early next session, parallel to
reading the studies: `Res_hist int×20` → 20 price buckets × 4 age bands
(0-26w / 26-78 / 78-130 / 130-520) = 80 int columns in
`Snapshot_pipeline` (schema-hash bump), score-time per-band weights in
`Resistance_supply` (Overlay_validator axis — NOT a baked decay
half-life, which would be a warehouse parameter and R2-hostile).
Default = bit-identical to current semantics on merge. The WAREHOUSE
REBUILD (v4) + (f) surfaces stay gated on the bundle verdict — do NOT
rebuild while the bundle evidence basis is v3. Design:
`dev/status/resistance-v2.md` §Next steps 3(f).

## P1 — margin M3 (after M2's merge, per the levered-realism plan)

`dev/plans/levered-longshort-margin-realism-2026-07-14.md` §M3: borrow
availability heuristic, HTB tiered rates + maintenance tier table,
buy-in stress mode. Then M4 (validation protocol) before ANY levered
number is quoted. M2 decision-item worth a human glance sometime: the
maintenance ratio uses LONG-BOOK equity (excludes short marked P&L) —
documented in `long_maintenance.mli`.

## P2 — carried

- Tax lens issue #2006 (Phase 1 report-layer exe; spec + acceptance
  targets pinned in the issue comments; $26.84M Run-D reference).
- Trader-preset bundle audit; floor-quality P1b step 3; decision_audit
  Phase-2 (also unlocks direct rank-table evidence for AXTI-class
  forensics instead of mechanism-level inference).

## Operational lessons (07-18/19)

- Fold-reset WF-CV structurally under-powers rare long-memory admission
  levers (vc-flag: 9/13 folds zero firings) — use contiguous or
  rolling-start lenses for that mechanism class.
- 0%-CPU dune/walk_forward parents are FORK-POOL COORDINATORS, not
  wedges — an agent kill -TERM'd one and nearly destroyed a 6h surface.
  Dispatch briefs must say "kill nothing" whenever sweeps share the
  container.
- "running variant" lines in walk_forward logs batch ahead of
  completion — don't read them as progress.
- GitHub auto-merge does NOT self-update a BEHIND branch under strict
  checks; orchestrator cron merges (2/day) re-strand armed PRs — check
  `mergeStateStatus` and `gh pr update-branch` again after each cron
  slot.
- jj rebase of @ orphans uncommitted files into parked commits
  (recover: find via per-commit `jj diff --summary` grep, then
  `jj restore --from <commit> <paths>`).
- Agent worktree reaped mid-flight (cleanup job) with zero loss BECAUSE
  the WIP-push-in-30-min rule was followed — keep it mandatory in every
  brief.
