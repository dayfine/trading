# Next-session priorities (post 2026-05-20)

Written end of session 2026-05-20 before user went off. Substantive work
shipped in this session:

- **Bayesian leak hunt + fix** (PRs #1199, #1200, #1201, #1202, #1203,
  #1197 merged): Random.State.make_self_init DLS-key leak in
  price_path.ml identified; bandaid in place; Fork_pool library +
  wire-in + `--parallel N` CLI shipped. Production sweeps now run
  forked-per-fold (no parent-heap accumulation) at parallel=4.
- **V1 Bayesian production sweep** running in background at parallel=4
  (4-knob spec_prod.sexp, budget=60, init_random=10, seed=2026). Should
  complete within ~1-2 hr of session-end (was at 87.7% / 3264/3720
  backtests at handover).
- **M1 cross-cycle Weinstein validation** (#1207 merged): Shiller
  monthly fixture pinned + decade-by-decade reduction + β + Stage 1-4
  classifier + ASCII charts + MA-window sweep. **Major finding**:
  framework at MA=10 months beats B&H on every dimension over 155y
  (CAGR +1.59pp, Sharpe ~2×, MaxDD -34% vs -85%, 10.3× more wealth).
  Original 30-month MA was 4× too slow.
- **Plans #1206** (hold-period deep-dive + cross-cycle Weinstein
  validation roadmap) merged.

## P0 — Process the v1 sweep result

The sweep may have finished by next session start. To check:

```sh
docker exec trading-1-dev pgrep -f bayesian_runner.exe
# Empty → sweep done. Output files at:
ls /workspaces/trading-1/dev/experiments/bayesian-production-sweep-2026-05-18/output-v1-parallel4/
# Expect: best.sexp, bo_log.csv, convergence.md, oos_report.md
```

### If sweep done

1. Read `oos_report.md` — the Oos_validator already computes a verdict
   (`promotable` / `reject_*`) using the holdout folds 27-30. Bayesian
   runner has this baked in.
2. Read `best.sexp` for the winner's 4 knob values.
3. Read `bo_log.csv` to see convergence trajectory (60 rows, columns
   include `iter`, the 4 params, scenario, all metrics, and
   `objective_Sharpe`).
4. Apply plan §6 promote-gate (5 axes) — note `oos_report.md` covers
   only the OOS axis; the other 4 (median composite, worst fold,
   MaxDD vs baseline, n_trades vs baseline) need manual check from
   the BO log + best-cell aggregate.
5. Write `dev/notes/bayesian-prod-v1-result-2026-05-XX.md` with
   findings + decision.

### If verdict is PROMOTABLE

Follow `dev/plans/private-tuned-configs-repo-2026-05-18.md`:

- Create `dayfine/trading-configs-private` repo (if not already created).
- Commit the best.sexp as `configs/2026-05-XX-bayesian-prod-v1/config.sexp`.
- Open a tracking issue in this repo (NOT a PR — configs live in the
  private repo, not main).

### If verdict is REJECT

Write `dev/notes/bayesian-prod-v1-result-2026-05-XX.md` with:

- Which axis failed + per-fold breakdown.
- Hypothesis for v2 (likely either widen knob bounds OR add a knob).
- Whether plan #1196 (composite scorer) becomes load-bearing.

## P1 — Hold-period deep-dive probes (dev/plans/hold-period-deep-dive-2026-05-19.md)

5 probes (P1-P5 in that plan) sequenced cheapest-first. P1 + P3 already
ran inline this session — findings:

- 66% of cell-E 15y trades exit on `stop_loss` with P50=10d.
- Those stop_loss trades are NET-NEGATIVE: mean −0.90% pnl, 23.9% win
  rate. ~37% drag on laggard_rotation's edge (+5.54% mean, 61.7% wr).
- 54.7% of stop_loss exits trigger within 10 days of entry (whipsaw).

Implications already in the plan:

- v2 sweep should widen stop-knob bounds (`initial_stop_buffer` up to
  1.20, `installed_stop_min_pct` up to 0.20).
- Add a 5-10 day post-entry settling window as a tunable knob.
- These can be tested via P2 ablation sweep (~6 hr at parallel=4 with
  the now-shipped Fork_pool).

## P2 — M2 French 49-industry rotation

Per `dev/plans/cross-cycle-weinstein-validation-2026-05-19.md` §M2.
~1k LOC, 2 weeks. Tests whether the cross-sectional ranking value-add
(the 0.20 Sharpe gap between M1's MA=10 reduction at 0.75 and cell-E's
production 0.94) holds across 100y of French portfolios.

NOT urgent if v1 sweep promotes — the cell-E production strategy is
already calibrated correctly.

## Drafts still open (P3)

- **#1196** (Composite scorer plan, draft) — not blocking v1 sweep
  promotion. Implement only if v2 needs multi-objective Bayesian
  scoring (e.g., to penalise short median-hold).

## Background processes to verify

If next session is started while sweep still running:

- The bayesian_runner.exe process should still be alive in
  `trading-1-dev` container.
- The /tmp cleanup sidecar should still be alive
  (`docker exec trading-1-dev pgrep -af "find /tmp"` — should match).
- If either died, check the log tail for crash:
  `tail -50 /workspaces/trading-1/dev/logs/bayesian-prod-v1-parallel4.log`.

## Branch state (end of 2026-05-20)

- `main`: at PR #1207 (Shiller M1) merged.
- Only `feat/wire-spec-objective-score-cell-plan` (#1196 draft) remains
  open. All other PRs merged or branches deleted.
- Working copy: clean (the v1 sweep output files in
  `dev/experiments/bayesian-production-sweep-2026-05-18/` are
  uncommitted but expected).

## Files of interest

- `dev/notes/bayesian-int-rounding-bug-2026-05-19.md` — full leak hunt
  writeup, including root cause + mitigation matrix.
- `dev/notes/bayesian-leak-rootcause-memprof-2026-05-19.md` — memprof
  attribution of the DLS-key leak.
- `dev/plans/hold-period-deep-dive-2026-05-19.md` — 5-probe sequence.
- `dev/plans/cross-cycle-weinstein-validation-2026-05-19.md` — 4
  milestones (M1 done, M2-M4 sequenced).
- `dev/plans/parallelise-walk-forward-executor-2026-05-18.md` — the
  fork-pool plan that landed.
