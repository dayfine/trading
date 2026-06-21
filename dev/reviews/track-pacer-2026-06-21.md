# Track Pacer Report — 2026-06-21

## Summary
- Tracks audited: 17 (16 IN_PROGRESS + 1 PENDING; MERGED rows excluded)
- Active (≥1 PR last 7d): 8
- Slowing (7–30d since last PR): 7
- Stalled (>30d): 0 (2 exempt — reactive/demoted by design)
- [info] items needing decision: 0
- Capability gaps flagged: 3

Cadence note: throughput remains very high — 95 merge commits in 7d
(29 `feat`/`fix`/`perf`/`test`/`chore`/`ci`; the rest `ops`/`docs`
orchestrator summaries, handoffs, experiment writeups, memory
snapshots) and 404 in 30d (165 code). The dominant theme this week is
**strategy-validation experiments** (barbell weighting overlay, the
decision-grading lens, two default-off stop levers, factor-lens across
breadth, short-supply screen) — and most of that work has **no track
row in `dev/status/_index.md`**. The named feature tracks are largely
gated/parked with status files weeks stale, while the live work lives
in handoff docs + the experiment ledger. That index/work divergence is
the headline this week, not throughput.

Positive signal: last week's Recommendation §4 ("queue a new hypothesis
*class*, not another single dial") was acted on — the **barbell 70/30
overlay PASSED a promotion grid (#1670), the first lever ever to clear
one** (#1673 confirms transfer to top-3000, gate #1 closed). The
program pivoted off the single-dial REJECT treadmill onto a
concentration/breadth lever, exactly as advised.

## Active tracks (≥1 PR last 7d)
- **backtest-perf** — 4+ PRs (#1624/#1626/#1629/#1631 snapshot-format-v2 columnar mmap; #1614 Gc.compact); theme: snapshot v2 S1–S4 PROVEN, top-3000 memory ceiling removed.
- **rolling-start-lens** — many PRs (#1639/#1642/#1645 factor-lens t3k cells; the entire decision-grading lens stack #1646/#1647/#1649/#1650/#1652/#1653/#1668); theme: read-only causal lenses (factor-lens + decision-grading exit classifier). High volume, all analysis/screen output.
- **short-side-strategy** — 4 PRs (#1659 reserved short-sleeve cash budget default-off; #1612 screener Virgin/Clean split; #1654/#1669/#1678 long-short + short-supply screens); theme: short-side levers + screens, all default-off / NO-BUILD verdicts.
- **backtest-infra** — 1 PR (#1617 readme_toplines four top-line numbers over pinned full-history); theme: reporting surface.
- **weekly-snapshot** — 3 PRs (#1588 generate_weekly_snapshot bin M6.6/Initiative A; #1598 first live baseline 2026-06-12; #1596 C2 bearish-macro gate test); theme: M6 weekly-picks artifact pipeline — the one track making live-cycle (M6) progress.
- **data-foundations** — 3 PRs at the 7d edge (#1594 eligibility-filter universe builder; #1589 volume-only enrichment; #1595 bar-store refresh, all 06-14); theme: eligibility-builder universe machinery.
- **harness** — 2 PRs (#1636 ci free-disk-headroom in build-and-test; #1604 wire record_qc_audit_test into dune runtest); theme: CI/harness maintenance.
- **cash-floor-correctness** — 1–2 PRs at the 7d edge (#1582 exempt_closing_trades flip→ON 06-14; #1606 sizing_cash spendable-cash cap 06-15, attribution borderline); theme: cash-accounting correctness.

Untracked but high-activity (no index row, no status file, no owner — see Capability gaps §1):
- **barbell overlay** — #1670 (promotion grid PASS, 70/30), #1673 (breadth-confirm top-3000, gate #1 closed), #1674 (gate #2 deployable-overlay design note). Maintainer-driven overnight; gate #2 explicitly HUMAN-GATED.
- **stop levers** — #1655 (weekly-close stop trigger, default-off), #1662 (vol-scaled ATR installed-stop distance, default-off). No home track.

## Slowing tracks (7–30d since last PR)
- **sweep-perf** — last PR #1574 (Win #4 production wiring) 2026-06-13, 8 days ago; theme: sweep-speedup opt-in wiring. Next task is "manual ghcr.io flambda rebuild + enable prune opt-in" — a maintainer-local op. Status file 26 days stale (05-26). Recommendation: KEEP_AS_INFO.
- **orchestrator-automation** — last PR #1573 (8x daily cadence) 2026-06-13, 8 days ago; status says "Phase 1 stable; Phase 2 deferred; no outstanding work." Effectively parked. Recommendation: KEEP_AS_INFO.
- **simulation** — last PR #1556/#1558 (cash-floor exit revert / Fold_health wiring) 2026-06-12, 9 days ago; theme: exit-path correctness. Next Steps are old "Future slices" catch-all items. Recommendation: KEEP_AS_INFO.
- **stage-accuracy** — last PR #1509 (cascade-selection inversion forensics) 2026-06-09, 12 days ago; theme: forensics + REJECTED grids. Next concrete surface (broad-universe WF-CV / partial-trim) is data-/scope-gated. Recommendation: KEEP_AS_INFO (see Diminishing returns).
- **experiment-platform** — last PR #1503 (force-exit-off grid REJECT) 2026-06-09, 12 days ago; "single-dial surface exhausted." Recommendation: KEEP_AS_INFO (the program's live experiment energy has moved to barbell/lens work, untracked).
- **spy-only-reference** — last attributable PR #1438 (sector-rotation) 2026-06-03, 18 days ago; Next Steps still "(open question, not dispatched)" / "maintainer's local experiment." Paused two weeks awaiting the same human session flagged last week. Recommendation: ESCALATE_TO_MAINTAINER (schedule the sector-rotation K-sweep run, or mark the track parked — it now reads as drift, not a pause).
- **tuning** — last PR #1333 2026-05-27, 25 days ago; M2 qNEHVI still "awaiting maintainer enable-commit per #1327." Human-gated 25+ days. Recommendation: ESCALATE_TO_MAINTAINER (single decision unblocks; same item as last week).

## Stalled tracks (>30d since last PR)
None. Two non-MERGED tracks have no recent PR but are exempt by design:
- **cleanup** (code-health) — "no active backlog; next finding via weekly deep scan." Reactive; idle is expected. Exempt.
- **tuning-methods** (PENDING, feat-backtest) — "Step 0 done; steps 1-3 demoted (surface is the bind)." Deliberately demoted. Exempt.

## Next Steps staleness (P2)
- **experiment-platform** — header `## Last updated: 2026-05-30` (22 days stale). First Next Step ("Repair the index/breadth golden coverage — extend `GSPC.INDX` + NYSE A/D breadth back to ~2009 … then re-run the early-admission surface") is **overtaken by events**: deep contiguous windows now run routinely this week — PIT-2000 SP500 2000-2026 (dot-com+GFC), top-3000 1998-2026 (#1593/#1645), 28y WF-CV baseline (#1605). The "extend back to 2009" repair the item is waiting on has effectively been superseded by the deeper builds. Recommend refreshing the date + retiring/closing Next Step #1.
- **sweep-perf / orchestrator-automation / tuning** — all three carry `## Last updated: 2026-05-26` (26 days). tuning's first live (unstruck) item is a track-creation decision pending since the 2026-05-22 pacer (cross-scenario validation, #1237); the others have no `## Next Steps` body and read as parked. Recommend reconciling header dates; for tuning, resolve or formally park the #1237 decision (see Recommendations).
- **stage-accuracy** — header `2026-06-06` (15 days). First Next Step is explicitly marked "DONE 2026-06-06: REJECTED," so not a false-pending item, but the file has not been touched since despite the program moving on; mild staleness only.

(Not flagged: backtest-perf, rolling-start-lens, weekly-snapshot, short-side-strategy, data-foundations, harness, cash-floor-correctness — status files current to within a week.)

## [info] items needing decision (P3)
None. `dev/status/_index.md` carries no `[info]`-tagged items; its header is a single freshly-reconciled "Last updated: 2026-06-21" line (orchestrator run 27895278155), not a multi-reconcile carryover block.

## Tracks without owner (P4)
None among index rows — every IN_PROGRESS/READY_FOR_REVIEW row has an owner, and no new ownerless track was created in the last 14 days.

Adjacent finding (not literal P4): the week's highest-value strategy
work — the **barbell overlay** (first grid PASS, #1670/#1673/#1674) and
the two **default-off stop levers** (#1655/#1662) — has **no track row,
no status file, and no recorded owner** (maintainer-driven overnight).
It is acknowledged only in the index header prose. See Capability gaps
§1 and Recommendations §2.

## Recurring discussion topics (P5)
- `dev/decisions.md` has had **no new entry in ~36 days** (most recent: the two 2026-05-16 vendor-pivot entries, both resolved). Active decision-making continues to live in the per-session priorities docs (`dev/notes/next-session-priorities-*.md`), handoff docs, and the append-only experiment ledger (`dev/experiments/_ledger/`). No unresolved topic recurs ≥2× in decisions.md. Recommendation: KEEP_AS_INFO — decisions.md is dormant as a channel (unchanged from the last several pacer runs); not a defect, but P5 as scoped to that file yields no signal.

## Diminishing returns (P6)
No track meets the literal heuristic (≥3 of last 5 PRs being `chore`/`fix(linter)`/`golden`/`repin`/`fmt`/`format`); the only pure-maintenance PR this week is #1601 (weekly opam update). The codebase is shipping default-off flags, screens, and experiment verdicts, not linter churn.

Two tracks show *strategic* diminishing returns (unchanged from last week, now more pronounced):
- **experiment-platform** — "single-dial surface exhausted"; no attributed code PR since #1503 (06-09). The single-dial search space has produced a long run of REJECTs and no ACCEPTs. The program's live energy has correctly moved to a new class (barbell concentration overlay) — but that work is untracked, leaving this track reading as idle. Consider folding the barbell/overlay validation into this track (or a new one) so the track reflects where experiment work actually happens.
- **stage-accuracy** — recent work is forensics + REJECTED grids (late-stage2-stop-tighten REJECT 06-06, cascade-inversion #1509). Next surfaces (partial-trim; broad-universe WF-CV) are scope-/data-gated. Effectively winding down on the single-dial stage-classifier hypothesis.

## Capability gaps (P7)
- **Untracked strategy-validation surface + the barbell gate-#2 decision (cross-cutting).** The barbell 70/30 overlay is the first lever to clear a promotion grid (#1670) and transfer to top-3000 (#1673, gate #1 closed). Gate #2 (deployable overlay) is **explicitly HUMAN-GATED** — "needs greenlight before build" plus open architecture decisions (#1674). This is simultaneously (a) the highest-value forward item in the strategy program and (b) blocked on a single human decision, and (c) tracked nowhere in the index. Milestone: M5/M7 (strategy validation). RECOMMEND: ESCALATE_TO_MAINTAINER — make the gate-#2 greenlight decision and give the overlay/stop-lever work a track + owner.
- **tuning M2 qNEHVI** — blocked ~25 days awaiting a maintainer enable-commit (#1327). Unchanged from the 2026-06-14 pacer. Milestone: M7 (parameter optimization). RECOMMEND: ESCALATE_TO_MAINTAINER (single decision unblocks the track).
- **M6.6 live cycle (live DATA_SOURCE + cron + alerts + state-durability)** — not started; the system remains backtest/experiment-only. weekly-snapshot shipped the generator (#1588) + first live baseline (#1598), so the M6 artifact spine exists, but the live wiring is human-gated. Deepest milestone gap (M6 "Full Automated Cycle"), but a deliberate verification-first sequencing choice. Milestone: M6. RECOMMEND: KEEP_AS_INFO.

Note: last week's #1 gap (broad-universe / composition-policy data blocker across ≥6 tracks) has **substantially eased** — the eligibility-filter universe builder shipped (#1594) and deep/broad windows (PIT-2000 SP500, top-3000 1998-2026, 28y WF-CV) ran this week. Remaining gating is local execution + data refresh, not missing capability. Dropping it from the active-gap list.

## Recommendations
1. **Make the barbell gate-#2 greenlight decision (P7 §1).** The 70/30 overlay is the program's first grid PASS and the single highest-value forward item; it is stalled on one human architecture decision (#1674) and has no track. Decide go/no-go on building the deployable overlay this week.
2. **Give the untracked strategy-validation work a home (P4-adjacent / P6).** Barbell overlay (#1670/#1673/#1674), the two stop levers (#1655/#1662), and the decision-grading lens (#1646–#1653) are substantial, high-value efforts with no track row, owner, or status file — visible only in index-header prose. Create a track (or fold into experiment-platform/stage-accuracy) so pace and gates are auditable. This is the week's clearest tracking hygiene gap.
3. **Resolve the tuning M2 enable-commit decision (#1327).** Idle 25 days purely awaiting a maintainer commit. Either enable qNEHVI or formally park M2 so the track stops reading as "next-task pending." (Carried unchanged from the last two pacer runs — now the longest-standing human-gated item.)
4. **Confirm or park spy-only-reference.** Its top Next Steps have been "open question, not dispatched" / "human session" for two weeks (last PR 06-03). Schedule the sector-rotation K-sweep run or mark the track parked so 18-day silence stops reading as drift.
5. **Refresh four stale status files (P2).** `experiment-platform.md` (22d; retire the superseded golden-coverage Next Step), `sweep-perf.md`, `orchestrator-automation.md`, and `tuning.md` (all 26d). Docs-only PRs — admin-mergeable. The fresh index header is masking weeks-stale per-track files.

## Stats
- 95 merge commits in last 7d (29 `feat`/`fix`/`perf`/`test`/`chore`/`ci`; remainder `ops`/`docs`)
- 404 merge commits in last 30d (165 code)
- 8 tracks active / 7 slowing / 0 stalled (2 exempt: cleanup, tuning-methods)
- 0 `[info]` items carried ≥3 reconciles
- 3 capability gaps flagged (barbell gate-#2 decision + untracked strategy work; tuning M2 enable-commit; M6.6 live cycle). Last week's broad-universe data blocker has eased and is dropped.
