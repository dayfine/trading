# Tuning methodology — design questions (2026-05-21)

Filed in response to user feedback on V3 promotion design. Lists the
non-trivial methodology questions the team needs to answer (or
explicitly defer) before the trading-parameters promotion workflow
becomes routine.

## 1. Codebase-version pinning

**Question:** when we promote a parameter set, what code version produced it? If the strategy mechanics change (e.g., new screener rule, different MA period semantics), an old parameter set may behave differently — the cell tuned against pre-change code is not necessarily optimal post-change.

**Recommendation:** every promoted config records the trading repo commit SHA in `provenance.md`. The `promote_config.sh` script reads `git rev-parse HEAD` from the trading repo at promotion time and embeds it. Specifically:

```markdown
## Provenance
- Trading repo commit: `<full sha>`
- Trading repo tag/branch: `main@origin` at promotion time
- Tuner spec: `dev/experiments/.../spec_prod_v3.sexp`
- Walk-forward spec: `dev/experiments/.../walk_forward_v2_baseline.sexp`
- BO run output: `dev/experiments/.../output-v3-parallel4/`
- Promotion date: 2026-05-21
```

**Stronger version (deferred):** parameter sexp itself carries the SHA as a header comment, so a deserialized parameter cell can be validated against the running binary's git version. Requires discipline at deserialize time (loud warning on mismatch). Skip in MVP; add as follow-up when version-skew bug bites.

## 2. End-of-training validation across baseline scenarios

**Question:** the BO winner is selected by walk-forward CV on ONE universe + window. But we also have other canonical baselines — 5-year SP500, 15-year SP500, broad universe, French 49-industry, Shiller 100y. Should the winner be regressed against ALL of these before promotion, with metrics recorded?

**Recommendation:** yes — `promote_config.sh` runs a fixed set of scenarios at promotion time. Each baseline produces a row in `provenance.md`:

| Scenario | Cell-E (current live) | V3-winner | Delta |
|---|---:|---:|---:|
| sp500-2010-2026 (16y, 510 sym) | Sharpe 0.56 | Sharpe 0.81 | +0.25 |
| sp500-2019-2023 (5y, 500 sym) | TBD | TBD | TBD |
| broad-universe-2019 | TBD | TBD | TBD |
| french-49ind-1926-2026 | TBD | TBD | TBD |
| shiller-1871-2025 | TBD | TBD | TBD |

If any scenario regresses by more than X (X = ~1pp Sharpe? need to decide), the promotion is rejected — the winner is overfit to its training universe and would degrade overall.

This is the practical version of "axis-6: no-regression on out-of-universe scenarios" which would be a 6th axis if we wanted to codify it. For now, it lives in `promote_config.sh` as a procedural check rather than a codified gate.

**MVP scope:** start with 2 scenarios (sp500-2010-2026 + sp500-2019-2023 since both exist as goldens). Add the others (broad universe, French, Shiller) when we re-pin their goldens or have a stable scenario for them.

## 3. Open questions on training methodology

These don't block V3 promotion but should be considered before the NEXT BO sweep (V5 / V6 / multi-param Phase-3).

### 3.1 Path dependency of folds

Current walk-forward folds are SEQUENTIAL (2010 → 2026). The Bayesian optimizer's GP-phase suggestions depend on the COMBINED in-sample aggregate, but the per-fold sequence matters for evaluation:

- Each fold is evaluated independently (no leakage within a fold).
- BO selects based on the AGGREGATE over folds.
- If 2010-2015 is a stable bull regime and 2018-2022 is choppy, a cell tuned to "win on aggregate" may be biased toward the LARGER fold count in the bull regime.

Should fold order be randomized to test the cell against random fold-permutations? Argument for: tests cell's regime-independence. Argument against: walk-forward is inherently chronological (a 2024-vintage backtest can't use post-2024 calibration data); randomizing fold ORDER doesn't break that but changes the BO's exploration trajectory in a way that may not be meaningful.

**Defer:** add as a section in the next sweep plan, not blocking V3.

### 3.2 Synthetic samples

We have French 49-industry (1926-) and Shiller (1871-) data — these extend backtest horizon by 50-100 years. Should the BO training include folds drawn from these, alongside the SP500 folds?

Pros: more diverse market regimes (Great Depression, WWII inflation, 1970s stagflation). Better generalization.
Cons: data quality is different (Shiller is monthly + index-level, not daily symbol-level). The strategy mechanics don't directly transfer.

**Defer:** would require a `strategy_data_source` abstraction that maps sparse historical data to per-symbol bar approximations. Big lift. Document as "Phase 5 (synthetic-historical extension)" in the next sweep plan.

### 3.3 Training-set bias (time + universe)

The current training universe is SP500 510-sym 2010-2026. The 5-axis gate's baseline is cell-E on THIS universe. A winner that beats cell-E on this universe is not guaranteed to beat cell-E on:
- Other universes (Russell 2000, NASDAQ, broad market)
- Other time windows (2026-2030 — the future)
- Different sector mixes

End-of-training validation (§2) partially addresses universe bias by re-running on other goldens. Time bias is fundamental — backtest is necessarily retrospective. Mitigation: walk-forward OOS validation (already in place for the most recent 4 folds) is the best we can do without forward sample data.

**Action:** §2's multi-scenario validation IS the universe-bias check. Codify the regression threshold (e.g., "OOS Sharpe across all canonical scenarios within 0.10 of cell-E baseline") as `axis-6` if we ever want to formalize it.

### 3.4 Local optima

Bayesian optimization with a GP surrogate is susceptible to local optima — once the GP commits to a region, it may not explore enough to find a globally-better region.

Mitigations in current setup:
- `initial_random = 10` seeds the GP with 10 uniformly-random samples before GP suggestions begin. Provides initial coverage.
- `expected_improvement` acquisition function has built-in exploration via the σ(x) term — explores high-uncertainty regions.
- 60-iteration budget. For 4-D this is comfortable; for 11-D (multi-param-scaling), it's borderline.

Open question: should we run multiple BO sweeps with different seeds + initial_random samples, then pick the best across them? This is the "random restart" mitigation. Compute cost: N× more wall time per sweep.

**Defer:** consider for the next sweep if we end up running multiple configurations side-by-side anyway. The V3 vs V4 experiment was unintentionally a 2-seed restart (different random init samples) and showed identical convergence — suggests local-optima risk is low at 4-D, but unknown at 11-D+.

## 4. Action items

For V3 promotion:
- [x] §1 codified: `promote_config.sh` accepts (optionally) the tuner spec + walk-forward spec paths and embeds them along with the trading repo SHA + BO output path in provenance.md.
- [ ] §2 MVP: `promote_config.sh` writes a TBD-placeholder validation table; the operator runs the 2 scenarios manually via `backtest_runner` and fills the table in by hand. Codifying the automated run is the followup (~50 LOC bash + backtest_runner invocation + sexp metric extraction).
- [ ] §2 deferred: add French 49-industry + Shiller scenarios once their goldens stabilize.
- [ ] §3 deferred: document in next sweep plan, not blocking V3.

For next sweep (V5 / multi-param V6):
- [ ] Decide §3.1 path-dependency question.
- [ ] Decide §3.4 random-restart question.
