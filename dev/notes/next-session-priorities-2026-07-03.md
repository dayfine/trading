# Next-session priorities — 2026-07-03

**Supersedes** `next-session-priorities-2026-07-02.md`. Main is green; everything
from the scale-in arc is merged.

## What this session delivered (all merged)

**Scale-in v1: designed → built → validated → REJECTED-with-why, end to end.**

- **Mechanism (default-off):** #1830 side-aware `Fill_router`, #1831 per-ticker
  stop-advance memo, #1832 `Scale_in_detector` + config knobs, #1833
  `Scale_in_runner` + wiring. Architecture: the add is a **sibling position**
  (own id, same symbol, shared ticker stop) — zero core state-machine changes.
- **Docs:** #1835 (plan → BUILT), #1840 (verdict + ledger + artifacts).
- **Simulator hardening found by the experiment:** #1837 — same-state sibling
  fills mis-routed by id-order ("Filled quantity exceeds target"); fills now
  route by exact (order_id → position_id) links with heuristic fallback.
- **Verdict** (ledger `2026-07-03-scale-in-v1-surface`, note
  `dev/notes/scale-in-wfcv-2026-07-03.md`): REJECT for promotion. sp500 = tax
  (½-sizing halves recovery monsters; Sharpe .92→.78). Broad = return-flat mild
  risk-smoother (`either_loose` best: MaxDD 10/13 wins, 2022 fold −0.42→−0.03
  Sharpe) but no DSR-surviving edge. WHYs: ½-entry = explore-side fat-tail tax;
  `Either` dead at extension 0.15 (breakouts already 10–20% above the 30w MA);
  breadth reverses the sign (3rd breadth-dependent knob).

## P0 — measure the PARTICIPATION effect (user ask, planned this session)

The verdict used top-level metrics only. The mechanism's causal chain —
*½-sizing frees cash → previously `Insufficient_cash` near-misses get funded →
broader participation* — was inferred from the outcome shape, never measured.
Measure it directly:

**Metrics per variant (baseline / pullback / either_loose), per fold:**
1. Unique symbols entered + entries per Friday (participation breadth).
2. `Insufficient_cash` skip counts (did the skips actually drop?).
3. Adds funded (count, $, dates — the exploit side's activity level).
4. Average concurrent positions + deployed fraction (cash utilization).
5. Where the freed cash went: overlap of newly-entered symbols vs baseline's
   cash-skipped set (the decision-audit "near-miss" linkage).

**Tooling map (verified this session — the chain already exists):**
- `scenario_runner` **already writes** `trades.csv + trade_audit.sexp +
  summary.sexp` per scenario via `Backtest.Result_writer.write`
  (scenario_runner.ml:319) into `dev/backtest/scenarios-<ts>/<name>/`.
- `trade_audit.sexp` carries per-candidate entry decisions **including skip
  reasons** (`Insufficient_cash`, `Already_held`, …) + alternatives.
- Consumers: `decision_audit --audit <trade_audit.sexp>` (funded vs
  cash-rejected faithfulness), `trade_audit_report --scenario-dir <dir>`
  (markdown), or direct sexp grep for counts.
- Adds are identifiable by `entry_reasoning` description
  `"Weinstein scale-in add (revealed strength)"` (`Scale_in_runner.add_reasoning_description`).

**Already on disk** (from this session's repro runs):
`dev/backtest/scenarios-2026-07-03-062259/scale-in-repro-fold001{,-either}/trade_audit.sexp`
— sp500 fold-001, pullback + either. Missing: the *baseline* fold-001 twin.

**Plan:**
1. Author solo scenarios for the informative **broad** folds — fold-010
   (2019-12-27..2021-12-25, the big bull divergence) and fold-011
   (2021-12-26..2023-12-25, the bear fold either_loose nearly neutralized) —
   × {baseline, pullback@0.5, either_loose@0.5+ext0.25}, mirroring
   `dev/experiments/scale-in-wfcv-2026-07-03/base_top3000.sexp` (+ the sp500
   fold-001 baseline twin, cheap). Run via `scenario_runner --dir <dir>
   --fixtures-root test_data/backtest_scenarios --snapshot-dir
   /workspaces/trading-1/dev/data/snapshots/wfcv-top3000-1998` (broad folds
   ~15–30 min each; 6 runs ≈ 2–3 h; serialize with nothing else on the
   container).
2. Diff the audits per fold: skip counts, unique entries, adds, deployment.
   Answer: **did the freed capacity actually reach the near-misses, and is the
   broad risk-smoothing attributable to broader participation or just smaller
   bites of the same names?**
3. Fold into the scale-in writeup (+ledger notes amendment if material) — this
   also sharpens the *untested shape* recommendation (full-size entries +
   continuation adds) with mechanism-level evidence.

## Other open threads

- **Untested promising shape** (from the verdict's forward guidance): full-size
  initial entries + continuation adds only (drop the ½-sizing = keep the
  un-taxed press-the-winner half). Fresh surface; needs no new code (set
  `initial_entry_fraction 1.0` + `enable_scale_in true` + `add_trigger Either`
  + `extension_max_pct 0.25` — adds then size `1.0 − 1.0 = 0`… **NOTE: v1 sizes
  the add as `(1 − initial_entry_fraction)`, so full-size entries currently get
  zero-size adds — this shape needs a tiny knob change (an explicit
  `add_fraction` field) before it can be tested.**
- **Catastrophic-stop sibling alignment** (from #1831 behavioral review):
  second sibling evaluates the post-advance state; inert while
  `catastrophic_stop_pct = 0.0` + scale-in off; align to the memoized
  pre-advance state if a spec ever arms both.
- **Docker.raw at 55 GB** (> 30 GB preflight threshold) — recompact via Docker
  Desktop GUI (user action) before the next multi-hour sweep.
- P2/P4 from the 2026-07-02 doc (≤4-week gate tuning; continuous-RS display)
  remain open, unchanged.

## Process notes (bit this session)

- The jj `@`-left-behind hazard bit **twice more** (experiment sexps + ledger
  files written while `@` sat on a pushed branch commit, then orphaned by
  `jj new`). Rule stands: **position `@` first, write second**; recover via
  `jj file list -r <old-commit>` + `jj restore --from <old-commit> <paths>`.
- `gh pr update-branch` merges with the bot token **do not trigger CI** →
  "no checks reported" + auto-merge stuck. Fix: rebase + push with your own
  token.
- Long dune runs whose harness wrapper dies keep running in-container and hold
  the dune lock; a killed wrapper's `dune build` can also hang forever on the
  dead stdout pipe (40+ min) — check `ps -o etime` and kill the orphan.
