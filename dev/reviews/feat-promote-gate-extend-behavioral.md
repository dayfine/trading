Reviewed SHA: 31e7f0a327f11c6ce3e55de82bb53012ece7f2d7

---

# Behavioral QC — feat-promote-gate-extend
Date: 2026-05-23
Reviewer: qc-behavioral
PR: #1255

## Authority documents consulted

- `dev/plans/bayesian-production-sweep-2026-05-18.md` §6 — Option E gate spec.
- `dev/notes/next-session-priorities-2026-05-22-pm.md` §P0 — task spec + V3 regression case study.
- `dev/scripts/promote_config.sh` header — script's contract.
- `dev/scripts/lib/extract_metrics.sh` header — helper library contract.
- `trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp` headers — baseline pinning source.
- `trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp` headers — baseline pinning source.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in script doc-strings / headers has an identified pin (test or fixture) | PASS | `regresses_by_more_than` (Sharpe form) — pinned by 3 assertions (lines 55-62). `regresses_by_more_than` (swapped-arg MaxDD form, doc lines 60-63) — pinned by 3 assertions (lines 67-74). `trades_out_of_ratio` (doc lines 70-73) — pinned by 4 assertions (lines 79-88) including boundary case. `extract_metric` (doc lines 19-21) — pinned by 3 assertions (lines 98-100). All 5 documented helpers have at least one assertion; new helper `trades_out_of_ratio` has 4 covering within / above / below / at-boundary. |
| CP2 | Each claim in PR body "Summary" / "Smoke test" / "Test plan" has a corresponding pin in committed test file | PASS | PR body advertises "13 assertions: Sharpe (3 cases) + MaxDD (3 cases) + total_trades (4 cases) + extract_metric (3 cases)". File contains exactly 13 `check` calls split 3+3+4+3 — matches PR body precisely. PR body claim that "today's V3 promotion (sp500-2019-2023: candidate MaxDD 30.58 vs cell-E 21.56, +9pp) would be caught" is pinned by line 67-68 assertion `regresses_by_more_than 21.56 30.58 5.0` → exit 0 = fail. Trades-ratio boundary semantics (strict `>`, not `>=`) pinned at line 87-88. PR body "Test plan" claim that `dune runtest devtools/checks/ --force` is all OK — verified by running it. |
| CP3 | Behavior changes that affect call-sites are detectable | PASS | New gate failure modes are each individually pinned: Sharpe regression FAIL (line 55-56), MaxDD increase FAIL (line 67-68), trades-above-ratio FAIL (line 81-82), trades-below-ratio FAIL (line 83-84). Plus matching PASS cases (no false positives). The validation.sexp schema extension (`maxdd_increase_threshold_pp`, `trades_ratio_max`, per-row `total_trades` in cell_e_baseline/candidate/delta) is structurally observable from promote_config.sh lines 379-381, 396-397 — no test pins this, but it's a string-construction extension consumed by humans/scripts downstream, not a function whose return value gates a code path. |
| CP4 | Each guard called out in script docstrings has a pin | PASS | The boundary guard "Ratio must be > 1.0; ratio=2.0 means within 2x in either direction" (extract_metrics.sh:73) and strict-inequality semantics (`a > b * r`, not `a >= b * r`) are pinned by the at-boundary assertion (line 87-88): actual=528, baseline=264, ratio=2 → 528 > 528 is false, exit 1 (pass). Without the strict `>`, this assertion would fail. The cell-E baseline values pinned in `PROMOTE_VALIDATION_PANEL` (sp500-2010-2026: 0.78/341.69/18.36/806; sp500-2019-2023: 0.56/50.66/21.56/264) match the scenario sexp headers exactly (verified via grep). |

## Behavioral Checklist

Pure infra / harness / refactor PR; domain checklist not applicable. This PR extends a shell-script gate around the promote pipeline and adds a dune-runtest smoke test; no OCaml domain logic (stage classifier, screener, stops, etc.) is touched. The Weinstein S*/L*/C*/T* rows do not apply per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely".

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | No core module touched; only shell scripts and a dune wiring. |
| S1-S6 | Stage 1-4 + Buy criteria | NA | No domain logic. |
| L1-L4 | Stop-loss rules | NA | No domain logic. |
| C1-C3 | Screener cascade | NA | No domain logic. |
| T1-T4 | Domain tests | NA | No domain logic. |

## Additional verification — gate semantics against authority

Option E spec from `dev/plans/bayesian-production-sweep-2026-05-18.md` §6:
- "OOS Sharpe ≥ baseline Cell-E Sharpe − 0.10" → script default `PROMOTE_SHARPE_REGRESSION_THRESHOLD=0.10` (promote_config.sh:198) — MATCHES.
- "MaxDD ≤ baseline Cell-E + 5pp" → script default `PROMOTE_MAXDD_INCREASE_THRESHOLD=5.0` (promote_config.sh:199) — MATCHES.
- "N_trades within 2x of baseline" → script default `PROMOTE_TRADES_RATIO_MAX=2.0` (promote_config.sh:200) — MATCHES.

P0 task spec from `dev/notes/next-session-priorities-2026-05-22-pm.md` §P0:
- "MaxDD gate (MISSING): MaxDD ≤ baseline + 5pp" → implemented at promote_config.sh:362-367.
- "N_trades gate (MISSING): within 2x of baseline" → implemented at promote_config.sh:368-373.
- "~50 LOC change" → actual diff is 52 additions to promote_config.sh + 13 to extract_metrics.sh + 106 in smoke test = on-budget.
- "Same pattern as `regresses_by_more_than`" — `trades_out_of_ratio` follows the same awk-BEGIN-exit pattern (extract_metrics.sh:74-78).

Smoke-test motivation from `feedback_promote_config_3_bugs_one_week.md`:
- 3 fix-forward bugs in 24h (#1241, #1243, #1247) all surfaced at first real usage. The PR addresses this by pinning runtime semantics in a dune-runtest-wired smoke test BEFORE shipping the new gate logic — correct mitigation per the memory's "smoke-test future production-tooling scripts before shipping; first real run shouldn't be PR #1" recommendation.

## Test run

```
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune runtest devtools/checks/ --force'
```

Result (smoke-test section):
```
  ok: Sharpe regression > threshold flags fail
  ok: Sharpe regression within threshold flags pass
  ok: Sharpe improvement flags pass
  ok: MaxDD increase > 5pp flags fail
  ok: MaxDD increase within 5pp flags pass
  ok: MaxDD improvement flags pass
  ok: trades within ratio flags pass
  ok: trades above 2x ratio flags fail
  ok: trades below 0.5x ratio flags fail
  ok: trades at exactly 2x boundary flags pass
  ok: extract_metric sharpe_ratio
  ok: extract_metric total_trades
  ok: extract_metric max_drawdown_pct
OK: extract_metrics_gate_smoke — all gate-helper smoke checks passed.
```

All 13 assertions pass. No other check fails in `devtools/checks/`.

## Quality Score

5 — Exemplary harness PR: every gate-helper claim has at least one positive + one negative assertion, boundary semantics are pinned (strict `>` for trades-ratio), the swapped-arg MaxDD form is documented and tested, the V3 regression case study is reproduced as a concrete failing assertion, and the smoke-test motivation directly responds to the 3-bug fix-forward pattern. Cell-E baseline values pinned in `PROMOTE_VALIDATION_PANEL` are traceable to the scenario sexp headers (verified). Gate defaults match the Option E plan §6 numbers exactly. Schema extensions are structurally observable downstream.

## Verdict

APPROVED
