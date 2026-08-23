# Next-session priorities — 2026-08-22 EOD

Supersedes `next-session-priorities-2026-08-21-am.md`. Written at the agreed
pause point: **the tracked task list is 14/14 complete** and everything still
open is a user decision, not a measurement. Next session should open by
making decisions from §2, not by dispatching work.

## 1. What is DONE (since the 08-21 AM handoff)

- **Funding program CLOSED** (#2463 G2a, #2468 G2b, #2469 G3 arming, #2473
  grid). Verdicts: saved tickets net-profitable (+$47k…$490k on the pure
  522-ticket cohort); top-line ordering is a monster lottery inside the
  132.5pp floor (CLS null-only vs SKYW arm-only; one monster ≈ 66pp); **G3 =
  terminal REJECT as a default** (53 trades/26y); G2a/G2b stay default-off
  axes. Transferable why: fund/protect *monster* entries, not ticket counts.
  (`project_funding_grid_monster_lottery`.)
- **A2-1 shipped** (#2475): `effect_null_report` — the Rule-4 table as a
  tested CLI (paired-not-means pinned; NO-BAND guard; universe/window
  refusal). Already caught one hand-rounding slip in the #2448 record.
- **Both held PRs resolved on user decision**: #2433 merged reframed (broad-5y
  SPLITS the 26y result — only MaxDD survives both cells); #2456 merged (gate
  reader HOLDs on conflicting verdicts at one SHA, fails loudly without gh).
- **Compression done**: #2476 pruned 78 superseded priorities docs (−8,888
  lines, salvaged from an unopened cron branch); #2477 compressed the config
  .mli 1,911 → 1,362 (−28.7%, code skeleton byte-identical, contracts
  verified from the deleted side; rt-anchor prerequisite now ⚠ on both
  fields). Remote branches: 14 stale deleted; only main remains.
- Process: `feedback_fence_local_dispatch_in_track_file` (cron built G2a in
  parallel — fence tracked Next-Steps before local dispatch);
  `feedback_harness_reaps_uncommitted_agent_worktrees` (commit+push after
  SCOPED verification; full gates post-push — 747 lines were lost learning
  this); timed progress reports + hourly heartbeat re-affirmed.

## 2. THE DECISION MENU (all user calls; evidence linked)

1. **`initial_stop_buffer` global default 1.02 → 1.0.** The 2.08%
   fallback-stop bug is fixed in the arc bundle only. A default flip moves
   every fallback-path golden and breaks record-baseline comparability.
   Evidence: `project_fallback_stop_half_book_band`,
   `test_fallback_stop_width.ml` (flips to in-band on the fix).
2. **The arc's faithfulness/performance trade.** Faithful bundle = −62.4%/26y
   vs record +287%; the driver is §4.2's fill-week volume gate ejecting 72% of
   entries (book-faithful, verified against the primary text). Options:
   accept the faithful reference as-is; license the era dial
   (`strong_threshold` 2× → sweep {1.2,1.5,2.0} — **requires plumbing
   `Volume.config` into the overlay first**, a small PR); or build the
   eject-into-advance timing dial. Evidence:
   `project_arc_faithful_costs_the_tail_at_scale`,
   `dev/notes/arc26y-corrected-writeup-2026-08-21.md`.
3. **Grade-tiered reservation** (from the user's 08-22 sizing idea, screened):
   expected-cost/ETA sizing fails three checks (74% fill rate ⇒ converges to
   G3-lite; rejections burst; concentration finding opposes dilution), but
   **reserve-only-for-A+-tickets** survives all three and matches the grid's
   transferable why. Candidate default-off mechanism if funding is ever
   revisited. Evidence: `project_funding_grid_monster_lottery`,
   `project_record_gap_is_concentration`.
4. **rt promotion path**: needs a genuinely disjoint broad cell (pre-2009,
   macro-diverse) — a data+run project, only worth it if drawdown-lever
   value is wanted as a default. Evidence:
   `project_rangetop_freshness_is_a_drawdown_lever` (post-#2433 reframe).

## 3. Small loose ends (no decision needed, any session can take them)

- `dev/experiments/funding-grid-2026-08-22/specs/grid1-null.sexp` is malformed
  on main (mis-terminated leading comment → stray second top-level sexp);
  the effect-null tool tolerates it, but fix the file.
- Salvage issue #2466 (duplicate-G2a elements: revert_rejected_exits
  symbol-hazard test on the retry path; cap-discrimination test port).
- The `unclear` adjudication open question in `dev/status/harness.md` (an
  in-band exit for gate deadlocks; first live near-instance documented).
- Container hygiene: TaskStop does not kill the in-container half of a
  docker exec — check `pgrep -x dune` + zombie count before build-heavy
  dispatches.
