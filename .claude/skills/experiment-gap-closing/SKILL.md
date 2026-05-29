---
name: experiment-gap-closing
description: Systematic loop for closing a trading-performance gap — turn a hypothesis into a variant SURFACE (not a single point), evaluate it with walk-forward CV, rank with Deflated Sharpe + Pareto, gate the decision, and record it in the append-only ledger. Use when a trade-autopsy / metric shortfall / failed baseline comparison surfaces missed gain and you want to test a fix the disciplined way, when the user says "close this gap", "test this as a surface", "run an experiment", or before changing any strategy knob/mechanism default.
---

# Experiment / trading-performance gap-closing

The disciplined loop for the Weinstein system. It exists because ad-hoc
exploration repeatedly produced overfit decisions: a candidate that wins on one
window loses across the regime distribution (stage3-hysteresis, continuation
combined-axis). This loop makes the search systematic and the decisions
deflation-aware.

**Authority:** `dev/plans/experiment-platform-2026-05-29.md` (the program),
`memory/project_experiment_platform.md`.

## The two hard lessons this loop encodes

1. **The trade-autopsy tool is a failure-mode *labeller*, not a *knob
   recommender*.** Its suggestions are hypotheses, not answers — every one must
   survive this loop. (`memory/project_stage3_hysteresis_rejected_wfcv`.)
2. **Test a surface, not a point.** A single (knob=value) backtest that wins is
   almost always single-window overfit. Evaluate a *matrix* across many
   walk-forward folds, and deflate the best-of-N by the trial count.

## The continuous-vs-discrete reframe

- The continuous 11-knob *value* surface is already searched (the BO program)
  and proven **flat** — don't re-polish knob values expecting alpha.
- The lever is the **discrete feature/mechanism space**: which `enable_*` code
  paths are active, in what combination, with coarse values. "The module is the
  knob." This loop targets that space.

## The loop

### 1. Name the gap
From a trade-autopsy failure mode, a metric shortfall vs the promote gate
(Calmar/Sortino/CAGR), or a failed baseline comparison (vs BAH-SPY / BAH-BRK).
Write the gap as a falsifiable hypothesis: "mechanism X recovers gain Y."

### 2. Hypothesis → axes
Express the fix as **axes**, not a point. Prefer toggling/combining *existing*
flags (`enable_short_side`, `enable_stage3_force_exit`,
`enable_laggard_rotation`, `enable_continuation_buys`, `enable_pi_filter`,
`stage_method`). If the fix needs a **new** mechanism, land it behind a
**default-off flag first** per `.claude/rules/experiment-flag-discipline.md` —
it becomes an axis the day it merges; do NOT wire it into the default config
until it earns an ACCEPT here.

### 3. Check the ledger — don't re-test what's already rejected
`dev/experiments/_ledger/` is the append-only history. Before running, compute
each candidate variant's effective-config hash and look it up:
- `Experiment_ledger.config_hash overrides` → the dedup key (MD5 of the
  effective config, so logically-equal overrides collide).
- `Experiment_ledger.lookup index ~config_hash ~base_scenario ~window_id` →
  prior verdict, if any. Skip cells already `Reject`ed on the same base/window
  and **log the skip** (never silently drop).

### 4. Generate the matrix → run walk-forward CV
Author a WF spec with an `axes` block (`Walk_forward.Variant_matrix` expands it;
unknown axis keys raise at expansion time). Mirror an existing fixture under
`trading/test_data/walk_forward/`. Then run, observing
`.claude/rules/sweep-hygiene.md` (output to `/tmp/sweeps/<name>`, `df -h`
checks, no concurrent jj ops, no concurrent agent dispatches):

```bash
docker exec -d trading-1-dev bash -c \
  "mkdir -p /tmp/sweeps/<name> && cd /workspaces/trading-1/trading && eval \$(opam env) && \
   nohup dune exec --no-build trading/backtest/walk_forward/bin/walk_forward_runner.exe -- \
     --spec <spec.sexp> --out-dir /tmp/sweeps/<name> --parallel 4 \
     > /tmp/sweeps/<name>.log 2>&1 &"
```

Folds must be ≥ 12 months (the strategy needs a 30-week MA init; shorter folds
can't generate signals). Make `gate.n` match the generated fold count exactly,
or the gate SKIPs.

### 5. Rank — Pareto + Deflated Sharpe (best-of-N is N trials)
Per-variant pass/fail comes from `Fold_gate`. For the *cross-variant* winner:
- `Walk_forward.Variant_ranking.rank` → Pareto frontier over
  (Sharpe ↑, Calmar ↑, MaxDD ↓).
- `Backtest_stats.Deflated_sharpe.deflated_sharpe` → deflate the candidate's
  Sharpe by `n_trials` = the matrix size. A 12-cell matrix's "winner" at raw
  Sharpe 0.56 may not survive deflation. Do not promote a candidate whose
  deflated Sharpe doesn't clear the baseline's.

### 6. Verdict + ledger append
Write the verdict (`Accept` / `Reject` / `Inconclusive`) with per-variant
aggregates to a new `dev/experiments/_ledger/<date>-<slug>.sexp` via
`Experiment_ledger.save_entry` (append-only — never overwrite), regenerate
`index.sexp` (`build_index` + `save_index`), and write the human note under
`dev/notes/`. A REJECT is a real result — it stops the next session from
re-testing the same dead end.

### 7. If a winner survives — promote
Only an ACCEPT that survives DSR + holds on the Pareto frontier goes to
`dev/scripts/promote_config.sh` → the private tuned-configs repo
(`dev/plans/private-tuned-configs-repo-2026-05-18.md`). Promotion stays a
manual, ledger-backed decision; nothing auto-promotes.

### 8. Memory
Write the durable finding to `memory/` (project type), link
`[[project_experiment_platform]]`. Whether ACCEPT or REJECT, the *why* is the
institutional memory.

## What NOT to do

- Don't act on a single-window backtest win. Surface + folds + DSR, always.
- Don't wire a new mechanism into the default config before an ACCEPT verdict.
- Don't re-run a config-hash the ledger already rejected on the same base/window.
- Don't launch a multi-hour sweep without the `sweep-hygiene.md` pre-flight.
- Don't trust the autopsy's recommended value — it's a labeller; the surface decides.
