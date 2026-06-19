# Overnight autonomous plan — 2026-06-19 (user AFK, ~6-8h)

User left for the night, asked for ~6-8h of planned autonomous work. This is the
queue + the discipline. Surfacing progress in-session; durable record here.

## Invariants (apply to every step)
- **Every change default-off** (`experiment-flag-discipline`); goldens stay
  bit-identical; no default flip / no goldens re-pin (those are human-gated).
- **Full `dune runtest` before every push** (the linter gate the scoped form
  skips — cost 3 rework cycles already this session).
- **3-gate merge** (CI + qc-structural + qc-behavioral) for code PRs; docs-only →
  admin-merge. Verify `gh pr checks` green before every merge; main green before
  the next.
- **Serialize the container** — never two backtests/builds at once; never
  `jj new`/`restore`/dispatch-agent while a backtest is writing (kills output,
  `feedback_jj_restore_killed_sweep` / `feedback_no_parent_backtest_during_jj_agent`).
- **Worktree isolation + docker dune** for any dispatched QC/feat agent.
- Screens calibrated per `screen-rigor`/`mechanism-validation-rigor` (distribution
  not point-estimate; a screen says promising/no-build, never "proven").

## Phase 1 — close out (c) long-short screen  [~30 min, run already in flight]
- Wait for `b24pd4vg0` (deep long-short, margin-on). Grade + compare top-level
  (return/Sharpe/MaxDD) AND decision-level vs the long-only deep baseline
  (+1934.5% / 1061 / 48.7% MaxDD). Does the Stage-4 short leg diversify/improve?
- Write `dev/experiments/decision-grading-longshort-2026-06-18/FINDINGS.md` with a
  calibrated verdict. Docs-only PR → admin-merge.
- This completes a→b→c (all three measured at the decision level).

## Phase 2 — build the weekly-close stop flag (default-off)  [~2h]
Per `dev/plans/weekly-close-stop-2026-06-19.md` + `project_weekly_close_stop_lever`.
- TDD: add `stop_trigger_on_weekly_close : bool [@sexp.default false]` to the
  stops config; close-based trigger variant in `Weinstein_stops`; wire in
  `stops_runner` (non-Friday = no intraday check; Friday = trigger on
  `close_price`). The stop state machine's `update`/`Stop_hit` path needs the flag
  too. Unit tests pin: default-off = current low-based behaviour bit-identical;
  on = close-based, intra-week wick below stop does NOT trigger if the week closes
  above.
- FULL `dune runtest` (goldens replay bit-identical at default-off). PR → QC
  (structural + behavioral; W1/W2 spine-faithful, R1/R2 flag-discipline) → merge.
- Build with NO backtest running (container free post-Phase-1). Do it myself
  (TDD, careful subsystem) rather than dispatch, to keep tight control; if it
  balloons, dispatch one feat-weinstein agent with the plan as brief.

## Phase 3 — lens screen the flag (before/after)  [~2.5h, serialized backtests]
- Re-run deep 1998-2026 Cell-E with `stop_trigger_on_weekly_close=true` (~1h),
  then 2011 (~30m). Serialize.
- Re-grade both with `decision_grading`: does `stop_loss` mean upside-foregone
  shrink, disaster-dodged hold, net value-add improve? Top-level return/Sharpe/
  MaxDD vs the long-only deep/2011 baselines.
- Write findings + calibrated verdict (promising → escalate to WF-CV / no-build).
  Docs PR → admin-merge.

## Phase 4 — WF-CV the flag IF Phase-3 promising  [~1.5h]
- `Variant_matrix` axis `((flag stop_trigger_on_weekly_close)(values (true false)))`
  under walk-forward CV on the deep window (fork-per-fold, N=3000 path). Deflated
  Sharpe + Pareto.
- Record ACCEPT/REJECT in `dev/experiments/_ledger/`. Docs PR.
- **Do NOT flip the default** — that's the promotion grid + human oversight
  (`promotion-confirmation.md`). Leave it default-off as an axis with the verdict.

## If a phase is blocked / no-build verdict
- If the long-short screen or the stop screen says "no edge", record the verdict +
  the why (transferable) and STOP that thread — don't force it. Move to the next
  phase. A clean no-build is a valid 6-8h outcome.
- Hard cap: if QC returns NEEDS_REWORK twice on the same PR, leave it draft, note
  in the handoff, move on (`feat-agent-dispatch` rework cap).

## Morning handoff
- Update `project_weekly_close_stop_lever` + write `next-session-priorities-2026-06-20.md`
  with: what shipped, the stop-lever verdict, and the remaining promotion-grid
  step (human-gated default flip).
- Refresh `dev/agent-memory/` snapshot (`sh dev/scripts/export-memory.sh`).
