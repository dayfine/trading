# Next-session priorities — 2026-06-12

**Supersedes** `next-session-priorities-2026-06-11-PM.md`. That doc's P0 (rolling-start
runner) and P1 (universe-composition policy) **both shipped this session**; this doc
carries the follow-ons. Check main CI green before dispatching.

## Done this session (2026-06-11 overnight/AM)

- **P0 — rolling-start runner v2 MERGED (#1536).** Extends
  `trading/trading/backtest/rolling_start/`: `enumerate_starts_jittered`
  (deterministic seeded jitter, 3/6/9-mo stride), BAH benchmark overlay
  (`bah_cagr_pct`, per-start `benchmark_cagr_pct` + `edge_pct`), richer matrix
  columns (Sharpe, time-underwater, `realized_return_pct` stripping UnrealizedPnl —
  the AXTI-mark guard), edge-robustness summary (median edge, % beating benchmark,
  worst start), fork-per-start parallelism (mirrors #1494). CLI: `--stride-days
  --jitter-seed --benchmark --parallel --snapshot-dir`.
- **P1 — universe-composition policy MERGED (#1537 / #1540 / #1539).** New
  `analysis/data/universe/` modules: `composition_policy_types` + `dual_class`
  (known-pairs + suffix heuristic; GOOG/GOOGL double-hold bug now detectable at
  universe level), `composition_policy` (dedup → REIT flag → ADR $-volume floor →
  preferred exclusion, per-filter drop report; default = no-op),
  `composition_policy_report` + `apply_composition_policy.exe` CLI.
  **Known limit:** `Snapshot.t` carries no per-symbol dollar volume → ADR floor is
  inert until volumes are wired (documented in .mli, pinned by test).
- **QC cycle:** every stack PR went through structural + behavioral with one
  rework iteration each (all single-finding test-coverage gaps; fixed inline).
- **Stack-merge lesson (cost ~1.5h):** squash-merging #1537 with `--delete-branch`
  auto-CLOSED stacked child #1538 (base branch deleted before retarget) — GitHub
  cannot reopen a PR whose base branch is gone; had to open replacement #1540.
  Also, pushing rework commits to a stack BASE leaves children with conflicting
  drift (the children fork pre-rework) → each child needed a manual
  merge-main-with-union-resolution before merging. **Next time: retarget children
  to main BEFORE merging/deleting the parent branch, and land rework commits on
  every branch of the stack (or rebase children) immediately.**
- **P2 — `snap_top3000_2000` warehouse:** build launched in-container
  (`/tmp/snap_top3000_2000`, spec `/tmp/cell-e-top3000-2000-26y.sexp`, 3015
  symbols, window 1999-06-07 → 2026-04-30, log `/tmp/snapbuild_2000.log`,
  ~26 min). Check `verify: .../3015 files OK` in the log; status at session
  close recorded below.

## P0 — Run the start-date edge-vs-SPY matrix (the deliverable the runner exists for)

Two-stage, per the rerun-dependency note in the 06-11-PM doc:

1. **Preliminary (runnable now):** top-3000 PIT snapshot warehouse
   (`/tmp/snap_top3000_2011`), Cell-E overrides, `--stride-days ~120
   --jitter-seed 42 --benchmark SPY --parallel 1` (N=3000 must stay fork-per-start
   serial — memory wall), end 2026-04-30. ≈25-35 starts × ~30 min/run — budget a
   day of wall-clock or trim the start count. Output = the honest replacement for
   the coarse `rolling_t3k` table (capital-honest via `realized_return_pct`).
2. **Definitive:** same matrix on the composition-policy universe — gated on P1'
   below.

Note: SPY bars must be present in the snapshot warehouse for the overlay
(`Daily_panels.read_history` on adjusted close); verify before the long run.

## P1' — Finish the composition-policy data path

1. **Wire per-symbol dollar volume** into the snapshot→candidate adapter so the
   ADR floor stops being inert (the EODHD inventory / bar store has the data; the
   adapter currently defaults absent volumes to +inf).
2. **Emit the policy universe artifact** (~top-4000: operating companies + liquid
   ADRs, dual-class deduped, REIT flag explicit) via `apply_composition_policy.exe`
   and check it into `goldens-custom-universe/composition/`.
3. **Weekly >1%-of-ADV liquidity gate** in the screener — weinstein-side dispatch,
   still pending (deliberately split from P1).

## P2' — Dot-com + GFC regime read

When the `snap_top3000_2000` warehouse verifies: Cell-E full run (or 2000-2011
sub-window first — 26y N=3000 full run may exceed the 7.75 GB container; the
15y run peaked ~5.8 GB RSS, 26y scales past it; sub-window or accept the risk)
+ rolling-start matrix over 2000-2011 starts. This is the macro-regime-diversity
cell `promotion-confirmation.md` demands.

## Carried / demoted

Unchanged from 06-11-PM: trade-forensics tooling (LOW), MFE/MAE harness gap,
prior-reweight docs reconcile (DEMOTED), steady-state tracks per
`dev/status/_index.md`.

## Key references

- `dev/plans/rolling-start-v2-2026-06-11.md` (runner design, merged with #1536)
- `dev/plans/universe-composition-policy-2026-06-11.md` (policy design)
- `project_evaluation_methodology_reframe`, `project_broad_universe_790_mtm_inflated`,
  `.claude/rules/promotion-confirmation.md` (macro-regime diversity),
  `project_edge_is_the_fat_tail`.
