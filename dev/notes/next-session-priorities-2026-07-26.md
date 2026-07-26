# Next-session priorities — 2026-07-26

**Supersedes** `next-session-priorities-2026-07-24.md`. The 07-25/26 stretch
closed that doc's P0 chain end-to-end: leverage-dawn B1 rework landed via the
GHA takeover (#2077 merged), the orchestrator shipped the whole bug queue
(#2085 exit labels, #2081 ADV aggregation, #2087 failed-breakout gate, #2090
sparse-tail gate), the structural-stop fix (#2091) merged after a local QC
cycle (2 rework tests added), and the **first fully-hardened weekly record**
ran as-of 2026-07-24 (#2092, auto-merging): RS-ranked, sparse-gated (27
zombies dropped incl. SNSE), failed-breakout armed at 0.05 (fired zero this
cohort), structural stops + sized tickets (risk 2.1-38.3%, no longer flat 8%).

## P0 — leverage-dawn surface RESULTS analysis

The WF-CV surface **launched 2026-07-26 16:55Z** and runs ~10h:
`.sweep-output/leverage-dawn-surface/` (spec
`leverage-dawn-BROAD-2000-2026.sexp`, 7 dawn variants + baseline × 13 folds,
v5thin warehouse, HEAD 96c4c5f + merged funding fix). When done
(`SURFACE_DONE` in status.log; report at `walk_forward_report.md`):

1. Gate read per the spec (Sharpe, m=7/13, worst_delta 0.0) — **fold-012
   (2024-25) is the named falsifier**; report its per-variant deltas
   explicitly even if the gate fails elsewhere.
2. Per `mechanism-validation-rigor`: distributions not point estimates;
   score DD continuously across fold boundaries (fold-reset forgiveness was
   the P1b headline's biggest flattering bias); attribute the why.
3. Survivor → DSR + Pareto → ledger entry; then the confirmation grid with
   a macro-regime-diverse deep cell BEFORE any promotion talk (R3).
   No survivor → ledger Reject + transferable why. Either way: ledger +
   memo + memory update.

## P1

- **Picks Phase C**: native HTML renderer + per-candidate SVG charts
  (plan §Phase C in `weekly-picks-execution-protocol-2026-07-24.md`; the
  hand-built artifact page is the design reference). Include the
  structural/fallback stop tag + drop-reasons section.
- **#2083-F2 rename tracking**: run the returns-basis twin matcher live on
  fetch (27 sparse-dropped zombies this week say renames are systemic);
  universe re-pin belongs to the same pass.
- **User action**: real cash into `dev/weekly-picks/portfolio.sexp`
  (still the $100k template — tickets scale linearly).

## P2 — carried

Tax Phase 2 (parked); trader-preset audit; floor-quality P1b step 3;
decision_audit Phase-2; `Loader.load_exn` follow-ups all shipped.

## Ops notes (07-26)

- QC agents AGAIN built/ran dune in the PARENT tree despite explicit
  worktree fences (two instances; one orphaned `dune runtest` held the
  lock and was TERM-killed). The parent tree is not a safe assumption
  while QC runs — always verify `ps` for dune before parent builds.
- Weekly pipeline invocations now fully recorded in
  `dev/notes/weekly-picks-2026-07-26.md` (fetch batches, warehouse
  window, superset universe construction with the 15 context symbols).
- EODHD key lives in the HOST shell env (`EODHD_API_KEY`), passed into
  the container via `docker exec -e` — no secrets file exists.
