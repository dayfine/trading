---
name: project_gspc_index_golden_2017_floor
description: "RESOLVED #1383: GSPC.INDX golden extended 2017→2009; pre-fix every sp500-2010-2026 walk-forward silently tested only 2017-2026 (macro gate blocks buys with no index). Exit-timing/hysteresis REJECTs re-validated #1391."
metadata: 
  node_type: memory
  type: project
  originSessionId: b9b9ed30-f921-4bfd-a0ea-792e77271fa4
---

`trading/test_data/G/X/GSPC.INDX/.../data.csv` covers only **2017-01-03 →
2026-04-09**; NYSE A/D breadth (`trading/test_data/breadth/nyse_*.csv`) only
**2017-01-02 → 2026-02-14**. Per-symbol bars DO span 2009→2026 — it's only the
market-regime data that's truncated.

**Consequence:** the Weinstein macro gate needs the index to read market trend.
With no index before 2017 it blocks all buys in 2010-2016, so **every**
walk-forward run on `goldens-sp500-historical/sp500-2010-2026.sexp` produces
~13 zero-trade folds (folds 000-012) and effectively tests **2017-2026, not the
nominal 2010-2026**. Discovered 2026-05-30 when the early-admission surface had
13 zero folds for every variant; first nonzero fold (013) is the one whose test
window first reaches 2017.

**RESOLVED 2026-05-31 (#1383, issue #1380 closed).** GSPC.INDX golden extended
to 2009-01-02 (4344 rows). All sp500-2010-2026 walk-forwards now trade the full
window.

**This had compromised ALL experiments on that scenario** — exit-timing (#1375)
and stage3-hysteresis (#1366) "31-fold 2010-2026" verdicts only exercised
2017-2026. **Both were RE-VALIDATED on the repaired golden 2026-05-31 (PR #1391):
all 31 folds now trade, baseline Sharpe 0.540→0.6225, and every behaviour-
changing exit-timing cell is still strictly dominated by baseline. Both REJECTs
hold and strengthen** — asterisk removed. (The hysteresis h2-m02 point is a cell
of the exit-timing surface, so one re-run covered both.) Ledger
`2026-05-31-exit-timing-hysteresis-revalidated.sexp`; writeup
`dev/notes/exit-timing-hysteresis-revalidated-2026-05-31.md`.

**Still: before trusting any sp500-2010-2026 surface, confirm folds 000-012
traded** (`grep total_return_pct fold_actuals.sexp` non-zero) — but the golden is
now fixed, so this should pass. The deep 2000-2026 path
(`build_deep_universe.sh`, #1388) extends coverage to 1999 for macro-regime
cells.

Related: [[project_experiment_platform]], [[project_sp500_baseline_conflict]].
