# Next-session priorities — 2026-05-30 PM

**Supersedes:** `dev/notes/next-session-priorities-2026-05-30.md`. That doc's P0
(entry-timing gap-closing on `late_stage2_admission`) was executed this session;
this doc carries forward what it surfaced.

## What shipped this session (2026-05-30 PM)

1. **Early-admission mechanism (PR #1378, MERGED).** Default-off
   `Stage.config.early_admission_ma_period : int option` — dual-MA early
   Stage-2 admission (fast SMA from `get_close`, promote+hold on the fast MA,
   defer to the slow 30-week MA otherwise). Bit-identical no-op when off. Both
   QC gates APPROVED; nesting + ocamlformat CI failures fixed mid-flight.
2. **Early-admission surface sweep → INCONCLUSIVE (PR #1379).** Swept
   `{5,7,10,13}` vs `None` over nominal 31-fold 2010-2026. Within-run signal was
   strong (every cell beat baseline on Sharpe; best ma=10 Sharpe 0.414 vs 0.251,
   DSR 0.9987) — **but the run is compromised** (see P0 below). Recorded in the
   ledger; full writeup `dev/notes/early-admission-surface-2026-05-30.md`.

## P0 — Fix the index/breadth data floor, then re-run (issue #1380)

**The headline finding.** `GSPC.INDX` golden covers only **2017-2026** (NYSE A/D
breadth only 2017-2020). With no index pre-2017 the Weinstein macro gate blocks
all 2010-2016 buys → every `sp500-2010-2026` walk-forward produces ~13
zero-trade folds and effectively tests **2017-2026, not 2010-2026**. This
silently truncated the early-admission run AND the exit-timing (#1375) +
hysteresis (#1366) verdicts (their REJECTs are conservative so probably still
hold, but the coverage claim is overstated). See
`memory/project_gspc_index_golden_2017_floor.md`.

Steps:
1. **ops-data:** extend `GSPC.INDX` + NYSE A/D breadth goldens back to ~2009 via
   EODHD fetch (issue #1380 acceptance criteria).
2. **Re-run the early-admission surface** (same spec) on the repaired full
   distribution. If ma=10 (or any cell) still beats baseline with a DSR clearing
   the baseline's, it's an **ACCEPT candidate** → wire default-on per
   `experiment-flag-discipline.md`. The 2017-2026 signal (incl. 2020 COVID
   bottom, a target regime) is the most promising entry-timing result so far.
3. **Sanity-re-check** exit-timing/hysteresis rejections on full coverage if
   cheap (lower priority — they were rejections, conservative under truncation).

**Before trusting ANY future `sp500-2010-2026` surface:** `grep total_return_pct
fold_actuals.sexp` and confirm folds 000-012 are non-zero.

## P1 — gap-closing loop continues (after data fix)

Entry-timing is the live lever (sanctioned-explorative per
`memory/feedback_strategy_mechanic_changes_too_explorative`). If the
early-admission re-run rejects on full data, the remaining entry-timing
candidates from the prior priorities doc are: volatility-adjusted MA period;
volume/breadth trend-establishment confirmation. Same loop:
default-off flag → `Variant_matrix` surface → WF-CV → DSR → ledger.

## P2 — `rank-variants` CLI (nice-to-have)

`Variant_ranking` / `Deflated_sharpe` have no in-repo driver; this session's
verdict used an ad-hoc throwaway exe. A committed CLI over
`aggregate.sexp` + `fold_actuals.sexp` (Pareto frontier + DSR) would make every
future verdict one reproducible command. Small, well-scoped feat PR.

## Still on the roadmap (unchanged)

- **Broader-universe** (Russell 3000 / 1998-2026) — orthogonal; BO program M4
  fixture exists. NOTE: also check its index/breadth coverage before trusting.
- **Wire `Deflated_sharpe` into the BO tuner** — shared lib; low urgency.

## Session state on return

- **Main CI:** check `gh run list --branch main --workflow CI --limit 1`.
- **Open:** PR #1379 (this writeup + ledger) merging on CI. Issue #1380 (data
  floor) open, unassigned. No active agents/sweeps.
