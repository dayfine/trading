# Next-session priorities — 2026-06-25 PM (handoff)

**Supersedes** `next-session-priorities-2026-06-25.md`. This session worked **P1 —
capacity levers** and, after a key user correction, produced an **ACCEPT for
concentration = 0.30 on the broad basis**. The promotion (goldens re-pin) is endorsed
but **was not executed** — blocked on a data-store-provenance landmine (see P0).

## Done this session (2026-06-25 PM)
- **Capacity lever 1, concentration — SP500-515 surface: INCONCLUSIVE** (#1748, merged).
  Knife-edge 0.25 spike, no robust value. **Now known to be the WRONG basis.**
- **Capacity lever 2, turnover (laggard hysteresis) — SP500-515: INCONCLUSIVE** (#1749,
  merged). Weak/noisy/non-monotonic.
- **USER CORRECTION:** SP500 is too narrow to exercise the capacity bottleneck (few
  breakout winners competing for cash). The optimal-lens capacity diagnosis came from
  the broad top-3000 run. → re-ran on the correct basis.
- **Capacity lever 1, concentration — BROAD top-3000: ACCEPT at 0.30.** Clean interior
  optimum (Sharpe 0.442→0.508→0.470, CAGR 7.2→10.2→9.3% across {0.14,0.30,0.50}),
  monotonic to 0.30 then 0.50 declines; +3pp/yr CAGR vs the deep-base 0.14, robust 9/13
  folds, loses-less in the worst folds. Ledger `2026-06-25-capacity-concentration-broad`.
  Note `capacity-concentration-broad-2026-06-25.md`. **The SP500 washout was a
  narrowness artifact.** (In the PR below, with the broad base scenario + WF specs.)
- **Cross-cutting confirmed:** the deep+broad goldens pinned at `max_position_pct_long
  0.14` **understate the strategy** vs the production default 0.30.
- **Laggard-broad lever:** launched then **stopped ~15% in** to free the container for
  the promotion work — re-run next session if the turnover question still matters.

## P0 next session — execute the concentration=0.30 goldens re-pin (user-authorized)
The user authorized promoting 0.30 by updating the scenario goldens. **This is NOT a
live-behavior change** — the canonical default is already 0.30; production already runs
it. The goldens artificially override down to 0.14. So the re-pin = **remove the 0.14
override → 0.30** so the research basis matches production (stops understating by ~3pp/yr
CAGR). Because no live behaviour changes, the confirmation grid does not gate it.

**⚠ The blocker (why I did not execute it autonomously):** a data-store-provenance trap.
The SAME long-only golden, **config unchanged at 0.14**, produces **23.5%** via local
`data/` CSV, **49.1%** via the warehouse (`/tmp/snap_top3000_1998_2026`), and is pinned to
a **≤30%** band (the CI `test_data` store, not present locally). Different goldens are
pinned against different stores. Setting `expected` bands from the wrong store breaks
main's postsubmit goldens after merge — unacceptable to risk while AFK.

**Procedure (resolve the store, then mechanical):**
1. Decide the canonical re-measure store (recommend the **warehouse**, the
   delisting-complete standard #1733/#1738 moved to). Confirm whether
   `golden-runs-sp500-15y` / perf-tier postsubmit use it or test_data — GHA doesn't host
   the 2 GB warehouse, so these goldens may be **local-verify-only / not PR-gated**, in
   which case the re-pin can't break PR CI at all.
2. **Scope = long-only regression goldens ONLY.** Re-pin 0.14→0.30 in:
   `goldens-sp500-historical/{sp500-1998-2026, sp500-2010-2026}`,
   `goldens-sp500/sp500-2019-2023-long-only`, long-only `goldens-broad/*`
   (decade-2014-2023, six-year-2018-2023, bull-crash-2015-2020, covid-recovery-2020-2024,
   sp500-30y-capacity-1996). **DO NOT touch:** `experiments/*` (frozen records), any
   `*-longshort* / enable_short_side true` golden (0.14 has a real
   force-liquidation-cascade rationale short-side — re-pin separately if at all), the
   catstop WF experiment bases.
3. Per golden: edit config → `scenario_runner --dir <stage> --snapshot-dir <store>
   --fixtures-root test_data/backtest_scenarios --no-emit-all-eligible` → read actuals →
   set `expected` bands around the new 0.30 actuals (match the file's tolerance style) →
   re-run to PASS. Then verify via the matching postsubmit; PR + qc-behavioral.

## P1 — harden the broad ACCEPT (optional, if more rigor wanted before/after re-pin)
- 1-year/26-fold broad re-run (match SP500 geometry) + a period-disjoint broad cell
  (e.g. 2010-2026) → a fuller robustness picture. The 2y/13-fold result is already a
  clean optimum; this is belt-and-suspenders.
- Re-run the laggard/turnover lever on the broad basis (the stopped run) — does the
  cross-cutting "deep base too aggressive" hold for turnover with breadth too?
- Re-run the optimal-strategy lens on the 0.30-corrected basis once the re-pin lands;
  the `Insufficient_cash` miss rate should shrink.

## Process notes
- **WF-CV on broad needs `--snapshot-dir /tmp/snap_top3000_1998_2026 --parallel 1`**
  (N=3000 fits the 7.75 GB container only one fold at a time; parallel>1 OOMs). 2y folds
  ~4min each; a 4-variant×13-fold run ~3.3h. Warehouse must include the 15 macro/ETF
  context symbols (it does → 3015 syms) or the macro gate blocks all entries.
- The `Fold_gate worst_delta=0.0` is mis-specified for return-amplifying capacity levers
  (FAILs every cell) — read Pareto + win-rate + the full curve, not the gate.
- Broad base scenario created this session: `goldens-sp500-historical/top3000-2000-2026-catstop.sexp`
  (top-3000-2000 PIT, mirrors the sp500 catstop deep base, universe-swapped).

## Operational (unchanged)
- Deep gitignored bar store is repo-root `data/` (735 syms 1998-2026 + `data/breadth/`).
- Warehouse `/tmp/snap_top3000_1998_2026` (2 GB, 3015 syms, ephemeral; rebuild recipe in
  `broad-golden-complete-data-2026-06-24.md`).
