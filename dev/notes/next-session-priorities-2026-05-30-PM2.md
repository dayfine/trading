# Next-session priorities — 2026-05-30 PM (session 2)

**Supersedes:** `next-session-priorities-2026-05-30-PM.md`. That doc's P0 (fix the
GSPC data floor → re-run early-admission) was executed this session.

## What shipped this session (2026-05-30 PM session 2)

1. **GSPC.INDX data floor FIXED (issue #1380).** Prepended EODHD 2009-2016 to the
   index golden (2017+ bytes untouched). The macro gate now trades the full
   2010-2026 window (was 13 zero-trade folds). Baseline reconciles with the
   canonical exit-timing baseline → confirms the truncation was the artifact.
   sp500-2010-2026 scenario `expected` ranges re-baselined to the now-correct
   full-window behaviour.
2. **Early-admission surface re-run → ACCEPT (mechanism).** On the repaired data,
   baseline is Pareto-**dominated** on BOTH 2010-2026 (31 folds) and the
   independent 2019-2023 (9 folds, different universe). **First program mechanism
   to beat baseline out-of-window.** Ledger:
   `2026-05-30-early-admission-surface-v2.sexp`; writeup
   `early-admission-surface-v2-2026-05-30.md`.

## P0 — Promotion decision for early-admission (needs human sign-off)

The mechanism earned an ACCEPT, **but two cautions gate the global-default flip:**

1. **No single period generalises.** The 15y DSR-1.0 winner **ma=10 does NOT
   generalise** (≈baseline on 5y). Robust value is **ma=13** (best cross-window
   aggregate) or **ma=7** (only both-window-frontier cell). DO NOT promote ma=10.
2. **Flipping `Stage.default_config.early_admission_ma_period` None→Some 13 is
   high-stakes:** it re-baselines *every* golden (5y, 15y, custom-universe) and
   changes **live-strategy** behaviour.

**Recommended sequence before flipping the default:**
- (a) **Broader-universe confirmation** to pin the period — run the {7,10,13}
  surface on the Russell-3000 / broad golden (check its index/breadth coverage
  first per `project_gspc_index_golden_2017_floor` — it may have the same floor).
  If ma=13 (or the 10-13 region) holds on a third independent context, the value
  is pinned.
- (b) Then a **promotion PR**: `early_admission_ma_period` default → `Some 13`,
  cite the ledger ACCEPT, and re-baseline ALL affected golden `expected` ranges
  in the same PR. This is a large mechanical change — scope it carefully.
- (c) Human sign-off on the live-behaviour change (entry-timing is sanctioned-
  explorative per `feedback_strategy_mechanic_changes_too_explorative`, but a
  default flip that changes live trading warrants explicit go-ahead).

## P1 — Re-validate prior verdicts on the repaired golden

The exit-timing (#1375) and hysteresis (#1366) surfaces were run on the
GSPC-truncated golden (effective 2017-2026). Their REJECTs are conservative
under truncation, but a cheap re-run on the repaired full window would confirm
they still reject (and remove the asterisk on those ledger entries).

## P2 — Commit a real `rank-variants` CLI

`Variant_ranking` / `Deflated_sharpe` still have no in-repo driver — this session
rebuilt a throwaway one 3×. A committed CLI (Pareto + DSR over
`aggregate.sexp`+`fold_actuals.sexp`) + the analogous ledger-writer would make
every verdict reproducible. Small feat PR with tests.

## Still on the roadmap

- **Broader-universe** program (also gates P0(a)).
- **Wire `Deflated_sharpe` into the BO tuner** — shared lib; low urgency.

## Session state on return

- **Main CI:** `gh run list --branch main --workflow CI --limit 1`.
- Early-admission mechanism stays **default-off** (no promotion yet).
- No active agents/sweeps. Throwaway run specs + rank_tool live only in the
  ephemeral data-fix worktree (not committed).
