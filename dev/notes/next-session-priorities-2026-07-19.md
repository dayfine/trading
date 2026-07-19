# Next-session priorities — 2026-07-19

**Supersedes** `next-session-priorities-2026-07-17.md`. The 07-18/19
session executed the entire resistance-v2 promotion-evidence program,
built margin M1b (both halves) + M2, and specced the tax lens. Main
green; PRs #1997/#1998/#2001/#2002/#2004/#2005/#2010 all merged.

## P0 — the bundle studies (user-endorsed path B of the promotion memo)

`dev/notes/resistance-supply-promotion-memo-2026-07-19.md` — the
promotion candidate is the BUNDLE (w_overhead_supply=30 +
virgin_crossing_readmission + floors 0/0/0). Two studies gate it:

1. **Bundle confirmation grid** — sp500 cell (weights {15,30} adapted
   for breadth) + broad 2011-26 cell, bundle vs baseline. Specs follow
   the merged floor-axis spec pattern; warehouses of record are
   `/tmp/snap_top3000_dedup_v3_sketch` + `/tmp/snap_sp500_2000_2026_v3_sketch`.
   ~1 overnight chain (~10-14h serial).
2. **Bundle rolling-start** — 13 paired biennial starts, bundle vs
   baseline (`rolling_start_eval`, same grid as 07-18 run). THE
   question: do the 2000/2008/2010 recovery-window paths repair?
   (~15h; can pair with #1 back-to-back or on alternate nights.)

If both confirm → promotion PR for the bundle (single unit). If the
rolling-start still shows recovery-window losses → keep axes, route to
lever (f) (age-banded histogram, designed in `dev/status/resistance-v2.md`
§Next steps 3(f); moderate supporting signal from the floor surface).

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
