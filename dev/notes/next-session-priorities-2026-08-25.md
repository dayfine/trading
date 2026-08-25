# Next-session priorities — 2026-08-25 (~23:50 PT 08-24 handoff)

Supersedes `next-session-priorities-2026-08-24-eod.md`. **All four 08-24 user
decisions are executed** (the deferred §2.2 one is parked by design):
#2530 stops flips, #2529 picks no-fill, #2532 canonical baseline (closed
#2503), #2486 closed. **The user's directive for this session: keep burning
down the issue list.**

## The new world every session must know

- **THE record baseline** = `dev/experiments/record-baseline-2026-08-24/`
  (build c7660cac3, params committed): **731.6% / 780 trades / Sharpe 0.666 /
  MaxDD 26.6 / hold 57.6d**. Book-faithful stops basis (buffer 1.0, reset
  anchor on) is the shipped DEFAULT — arms needing the old basis must pin
  `((initial_stop_buffer 1.02))` + `((stops_config ((reset_anchor_on_stalled_cycle false))))`.
- sp500 goldens re-pinned ±15% at the new basis (5/5 verified twice
  independently). Broad/custom postsubmit goldens NOT yet re-pinned (soak
  mode, warnings only) — part of #2403.
- Memories to trust: `project_ratchet_freeze_real_data`,
  `project_monster_funnel_top_of_funnel`, `project_record_basis_divergence_0823`.

## Issue burn-down queue (user preference: keep grinding this)

0. **Warm-up chore**: fix `record-baseline.sexp`'s carried-over header comment
   (behavioral finding ⑥ on #2532 — it still describes the instrumented null;
   the exact defect class #2503 was about) + README "five→three" wording (⑦).
   One tiny PR, spec-comment-only.
1. **#2531 (P2/S)** goldens_affected_check blind spots — just bit us on #2530;
   mechanical (add nested-config files + default_config record-literal region
   to the scan; audit other embedded configs).
2. **#2403 (P1/L)** goldens track live config + declare deviations — UNBLOCKED
   (its worst-instance field resolved by the #2404 decision). Includes
   re-pinning broad/custom postsubmit goldens to the new basis and flipping
   the soak workflows' continue-on-error once stable.
3. **#2405 (P3/S)** re-flip entry_order_max_rest_weeks→26 — gated on #2403's
   re-pins; the clock26 ledger entry is the record to cite.
4. **#2521 (P3/S)** shellcheck-over-workflow-run-blocks linter (the #2517
   defect class; check shellcheck availability in the CI image).
5. **#2394 (P3/S)** long cascade RS phase in diagnostics (also serves #2533's
   decomposition).
6. **#2533 (P3/M, new)** per-drop sub-reason inside Dropped_at_breakout —
   decomposes the funnel's 51% bucket into its dials.
7. **#2380 (P3/S)** RS-trend structurally dead — likely a Rule-4 retirement
   PROPOSAL (ledger/memory already says REJECT-ish: Positive_flat always,
   rs_value unpredictive); classify do-not-revive vs keep-as-axis first,
   don't just fix the window math.
8. **#2524 (P3/M)** simulator.ml extraction (487/500, trigger documented).
9. **#2502 (P3/S)** streaming trades.csv; then P4s (#2407, #2409, #2006) and
   **#1729 (P3/L data)** as capacity allows.

Parked: **#2408** stop surface (behind #2403/#2405 correctness chain; its
buffer sweep now composes with the shipped 1.0 basis — refresh the issue's
value grid when picked up). **#2489 stays OPEN** solely as the carrier of the
deferred §2.2/arc reclassification decision (user: revisit after 1-3 — which
are now done, so it is ASKABLE next session).

## Operational notes

- Worktrees: `pairs-run` and `sweep-instr-0823` are now both DELETABLE
  (baseline pinned; funnel artifacts committed; candidates.sexp only feeds
  #2533 which needs a code change first — regenerable via run_chain.sh,
  ~4.5h). Reclaims ~20GB. Verify no live process first.
- Two structural-QC environment false-positives this weekend (dune-collision;
  parent-reproduced H3) — both adjudicated by the same rule: a finding
  reproduced on the parent/identical-to-green-main is the reviewer's
  environment. Pattern is now well-worn; adjudicate fast, don't burn rework
  iterations.
- Cron slots 00:17/05:17 PT still active — fence issues before local dispatch;
  check `git log origin/main` at session start.
