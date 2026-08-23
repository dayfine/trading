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

---

## Addendum (2026-08-22 ~24:00 PT) — issue burn-down after the pause

A post-handoff burn-down closed **7 issues**, all through full gates:

| closed | via | what |
|---|---|---|
| #2428, #2470 | PR #2480 | orchestrator merge-gate + Stage 3 now honour do-not-merge/draft/timeline holds; GHA subagents get their own `git worktree` + `_build` |
| #2386 | PR #2479 | QC agents build their OWN checkout with plain git — parent-tree contradiction resolved in the rules |
| #2427 | PR #2481 | 15y golden: root cause = 3 scenarios > 90-min cap (since #1050, 05-13); cap 240 + per-cell 4200s + summary-less runs fail loudly. First honest nightly run = next cron |
| #2457 | PR #2484 | book-as-authority: environment-aware protocol (BOOK-CHECK-NEEDED queue for GHA reviewers; book never leaves the local machine) |
| #2393 | PR #2482 | `goldens-affected` PR check is LIVE on every PR — config-default changes touching a postsubmit golden now block; `paired-run-done` label = documented ack path; rule `config-default-blast-radius.md` |
| #2412 | PR #2485 | `fold_actual` carries `total_trades` + `max_trade_pnl_dollars` — the fewer-positions-vs-better-picks columns for the next surface |

Also: issue-grading taxonomy (`kind/*`, `P0-P4`, `impact/*`, `size/*`) created, applied to all open issues, codified in `.claude/skills/triage-labels.md` (PR #2483). Filter: `gh issue list --label P1`.

**⚠ New for the decision menu:** **#2486 (kind/bug P1 impact/H)** — the #2485 rework agent proved (in fixture) that a fallback initial stop FREEZES the trailing ratchet: the correction-cycle anchor candidate sits permanently below the stop, so fallback-stop positions never trail. Fallback is the common path (`project_fallback_stop_half_book_band`). **Verify on real data before or alongside decision §2.1 (`initial_stop_buffer` flip)** — the flip widens exactly the stop that this bug says is also frozen; the two interact.

Remaining open issues: 13. P1 set: #2408 (stop surface, feeds §2.1), #2403 (goldens track live), #2440 (CI flake), #2486 (ratchet freeze).

---

## Addendum 2 (2026-08-23 ~00:30 PT) — user-queued research pair, and the opening move

The user queued two analysis programs (filed + labeled `kind/research P1 impact/H`):

- **#2489 — representative-trade audit** (`size/M`): are our realized trades the
  book's population? Three populations on distribution tables — executed trades,
  the §4.2 fill-week ejections (72%), funding-death tickets — across base length,
  breakout volume ratio, stage/RS at entry, holding weeks, exit reason. Feeds
  decision §2.2 directly (are we ejecting the representative trades?).
- **#2490 — monster capture funnel** (`size/L`): the counterfactual, scoped to
  CAPTURE not picks (pick-selection is a closed powered null — do not re-measure)
  and to decision-time-visible monster criteria (no hindsight oracles). Funnel per
  rule-visible monster: existed → surfaced → gated → ticketed → funded → filled →
  held. Output = per-stage leak table, each stage mapped to an existing dial.
  This operationalizes "protect MONSTER entries" from the funding-grid why.

**Opening move for the next session:** #2486 (did the installed stop ever rise,
split fallback-vs-support), #2489, and #2490 all want per-position fields from
the same instrumented 26y record-convention run. **Design the instrumentation
once, run once, analyze three ways** — then take decisions §2.1/§2.2 with all
three results in hand. Do not launch three separate multi-hour runs.

P1 queue after this addendum: #2486 → #2489/#2490 (shared run) → decisions
§2.1/§2.2; then #2408, #2403, #2440. Filter: `gh issue list --label P1`.
