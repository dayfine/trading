# Track Pacer Report — 2026-09-13

## Summary
- Tracks audited: 50 index rows (26 IN_PROGRESS + 1 PENDING = 27 non-MERGED; 23 MERGED exempt). Cadence run on the 27 non-MERGED rows.
- Active (≥1 PR last 7d): 8
- Slowing (7–30d since last PR): 6
- Stalled (>30d): 13 (12 IN_PROGRESS + 1 PENDING parked)
- `[info]` items needing decision: 0
- Capability gaps flagged: 10 (3 new, 7 carried)

**Headline: the GHA orchestrator has produced nothing since 2026-09-09.** Six
consecutive cron slots — 09-10 AM/PM, 09-11 AM/PM, 09-12 AM/PM — recorded
`total_cost_usd` of **exactly $0.0000** and wrote **zero** daily summaries, zero
fast health scans, and zero QC audit records. Every slot before that, back
through 09-06, spent $12–60. The break falls in the gap between the last funded
slot (`34378061508`, 2026-09-09T18:26Z) and the first dead one
(`34475636575`, 2026-09-10T12:19Z) — and **PR #2757, the only change to
`.claude/agents/lead-orchestrator.md` or `.github/workflows/` since 09-01,
merged at 2026-09-10T07:07Z, inside that gap.** That is a lead, not a verdict;
it needs a run-log read to confirm. But the correlation is as sharp as this
kind of evidence gets, and it is the first thing to check.

This is a different failure from the one three pacer reports in a row have
flagged. The old shape was *spend without output* ($7–17 slots that wrote no
summary). The new shape is *no spend at all* — the workflow fires, the budget
step works, and the agent never executes.

**It went three days unnoticed, and that is the more important finding.** The
detector for exactly this condition exists: `#2663` shipped the scheduled-
workflow health check on 2026-09-04. It is the **script half only**; the
wiring is blocked on the `workflow`-scoped PAT (`#2634`, `#1636`), which
`orchestrator-automation.md` proved on 09-04 to be refused on *every* route.
So the one credential gap this report has carried for eight weeks is now
directly responsible for a three-day silent outage of the whole automation
layer.

Two further governance instruments were down at the same time:

- **The track pacer itself did not run on 08-30 or 09-06** (`#2723`). This
  report covers a 21-day window, not 7. Two of the last three audit cycles
  produced nothing.
- **The weekly deep health scan has not run since 2026-08-31** — 09-07 missed,
  13 days stale.

So for the week in which the orchestrator died, none of the three watchers that
would have said so were running.

The good news is real and worth naming: **the snapshot-pipeline data-integrity
program is the strongest track in the program right now.** `backtest-infra` +
`post-run-validation` shipped eight and three PRs respectively this week, all
feature surface, closing five distinct classes of warehouse corruption
(delisting stubs, ticker-reuse splices, `prefix_misscale`, rename twins,
interleaved series). And `#2751`'s three-salt read on the deduped warehouse
correctly *retracted* a prior "drawdown floor" finding as twin double-funding —
a measurement program catching its own error is the behaviour the rules files
exist to produce.

## Active tracks (≥1 PR last 7d)
- **backtest-infra** — 8 PRs (#2758, #2733, #2724, #2713, #2708, #2705, #2695, #2691); theme: snapshot-pipeline data integrity at build time — end delisted series at `active_through`, cut ticker-reuse splices, cut the `prefix_misscale` class, expose the rename-twin dedupe pass on the vintage builder, `-incremental` manifest merge. All real feature surface.
- **harness** — 6 PRs (#2767, #2749, #2748, #2727, #2725, #2721); theme: repairs to the harness's own tooling — daily-summary publisher, its mutant-disagreement reconcile, goldens nested-field emitter, prune sanity probe, test fixture root. See §Diminishing returns.
- **post-run-validation** — 3 PRs (#2750, #2735, #2692); theme: V18 store-level implausible-series check, `validator_diff` cross-arm Invariant gate, V16 fallback-exit report. Directly serves the `mechanism-validation-rigor.md` check-8 gate.
- **support-floor-stops** — 2 code/plan PRs (#2718 per-macro-state `initial_stop_buffer` map, #2700 its plan) plus ~10 `docs(experiments)` item-3 PRs; theme: the per-state stop-width axis, measured to a ledger REJECT-as-default / keep-as-regime-axis verdict on 09-09.
- **simulation** — 2 PRs (#2709 cancel resting entry tickets past the delisting marker, #2692 shared with validation); theme: delisting-aware ticket lifecycle.
- **screener** — 2 PRs (#2759 `deteriorating_blocks_longs` default-off long gate, #2768 its pre-registered three-salt read); theme: breadth-state admission gating. Note both merged 2026-09-13 03:48–04:09 PT.
- **orchestrator-automation** — 1 PR (#2757, Step 8 publishes via `publish_daily_summary.sh` instead of `jj`); theme: the D2 summary-publication fix. See §Capability gaps for why this PR needs a second look.
- **rename-twin-dedup** — 1 PR (#2733, dedupe pass exposed on the vintage-rebuild builder); theme: the mechanism's last plumbing. The track's own file says "Next task: none required."

## Slowing tracks (7–30d since last PR)
- **arc-readiness** — last PR #2652 at 2026-09-03 (10 days); theme: the D1/D2 exit-basis default flip and the stale A/B item retirement; recommendation: KEEP_AS_INFO — Axis 1 and Axis 3 are complete; only A2-4 (picks chart) remains, and it is 23 days behind its own merged plan (#2453).
- **cleanup** — last PR #2637 at 2026-09-03 (10 days); theme: root-causing the csv-snapshot test flake; recommendation: KEEP_AS_INFO — the 09-09 run-2 audit found §Backlog holds **no actionable work** (1 policy decision + 2 archive entries + 1 fenced template). The `linter_coverage` test-file policy question this report flagged last cycle is correctly parked, not neglected.
- **experiment-platform** — last PR #2631 at 2026-09-01 (12 days); theme: the clock A-null ledger entry; recommendation: ESCALATE_TO_MAINTAINER — the *ledger* is in daily use, but the platform's own code has not moved since **#1372 (2026-05-29, 107 days)**, and its first Next Step is a struck-through 2026-06-21 supersession. The track is being credited with activity that belongs to its consumers.
- **stage-accuracy** — last PR #2450 at 2026-08-20 (24 days); theme: `late_stage2` retirement-eligibility inventory; recommendation: KEEP_AS_INFO — the 78-day stale head-of-list item the pacer flagged seven times **was fixed** (moved to `## Outcome`); all three remaining items are honestly marked "Not started; not currently queued."
- **weekly-snapshot** — last PR #2453 at 2026-08-20 (24 days); theme: the plan for making the picks chart answer "how was entry picked?"; recommendation: ESCALATE_TO_MAINTAINER — the track's shipped capability (the weekly picks run) is 30 days stale. See §Capability gaps.
- **trade-audit** — last PR #2348 at 2026-08-16 (28 days); theme: portfolio-rejected entry tickets resolving in `trade_audit.sexp`; recommendation: KEEP_AS_INFO — index next task ("retire `project_rest_time_pnl_is_cell_specific`, obligation now due") is a small, concrete, dispatchable item. It holds **9** open follow-ups, second-highest in the program.

## Stalled tracks (>30d since last PR)
- **resistance-v2** — last PR #2145 at 2026-07-28 (47 days); reason: promotion executed, remaining work (WF-CV vs w30) is data-gated and LOCAL; recommendation: ESCALATE_TO_MAINTAINER — this is the track whose **default-on** promotion (#2047) still has no re-certified relative margin (see §Capability gaps). 5th cycle asking whether it drops to axis-maintenance.
- **short-side-strategy** — last PR #2081 at 2026-07-26 (49 days); reason: next task (short-leg regime-P&L decomposition) marked LOCAL; recommendation: KEEP_AS_INFO.
- **tuning** — last PR #2113 at 2026-07-27 (48 days, and that was a Cholesky flake fix, not M2 work); reason: **M2 qNEHVI has been awaiting a maintainer enable-commit since #1327 (2026-05-26 — 110 days)**; recommendation: ESCALATE_TO_MAINTAINER. On the M7 critical path. 8th ask.
- **margin-realism** — last PR #2077/#2074/#2063 at 2026-07-24 (51 days); reason: M4 validation complete, leverage surface REJECT, no queued successor; recommendation: KEEP_AS_INFO — a candidate for closing to MERGED. The file has no `## Next Steps` section at all.
- **extension-stop** — last PR #1960 at 2026-07-13 (62 days); reason: only a default flip remains and it is human-gated on a further insurance-basis ACCEPT (R3); recommendation: KEEP_AS_INFO — correctly parked, not neglected.
- **data-foundations** — last PR #1939 at 2026-07-12 (63 days) on its own next task (`ATB.curated` arming + `General::Type` enrichment); reason: EODHD-gated; recommendation: KEEP_AS_INFO — note the `feat-data` agent *is* active, but on `#2732` store-sanity work booked to `backtest-infra`. The owner is busy; the track is not.
- **floor-quality** — last PR #1913 at 2026-07-10 (65 days); reason: P1b step 3 lens screen needs the deep warehouse, maintainer LOCAL; recommendation: KEEP_AS_INFO.
- **backtest-perf** — last PR #1722 at 2026-06-23 (82 days); reason: S4 proven, S5/v1-cleanup deferred by oversight decision, next step LOCAL; recommendation: ESCALATE_TO_MAINTAINER — 7th consecutive cycle of drift. Its `## Next steps` section exists but leads with April-2026 `(DONE)` entries. Fold into `backtest-infra` or give it a live owner boundary.
- **rolling-start-lens** — last PR #1645/#1648 at 2026-06-18 (87 days); reason: matrix shipped LOCAL, next step LOCAL/data-gated; recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (91 days); reason: NS2 impl human-gated, NS4 data-gated; recommendation: KEEP_AS_INFO — the correctness half (NS1/NS3) shipped and is default-on; what remains is genuinely gated.
- **sweep-perf** — last PR #1574 at 2026-06-13 (92 days); reason: **blocked on a manual ghcr.io flambda rebuild** — until it happens, `-O3` is a silent no-op in CI (`sweep-perf.md:41-42`); recommendation: ESCALATE_TO_MAINTAINER. 7th ask. (Note: `prune_candidates.sh` work did land this window — #2651, #2449 — but under `harness:` prefixes, not against this track's two open items.)
- **spy-only-reference** — last PR #1438 at 2026-06-03 (102 days); reason: item 1 explicitly "(Open question, not dispatched)"; file 102 days old; recommendation: ESCALATE_TO_MAINTAINER — decide whether the sector-rotation testbed is still wanted or close the track.
- **tuning-methods** (PENDING) — no PR ever attributed to this track; file last updated 2026-05-24 (112 days) and still reads "Follow-ups: None yet — track just opened"; reason: superseded in practice by the `experiment-gap-closing` skill and the ledger; recommendation: ESCALATE_TO_MAINTAINER — close it or re-scope it. It has been parked as PENDING for four months.

## Next Steps staleness (P2)

**Structural finding first: P2 is unrunnable on 11 of 27 non-MERGED tracks
(41%).** `margin-realism`, `post-run-validation`, `rolling-start-lens`,
`sweep-perf`, `trade-audit`, `support-floor-stops`, `short-side-strategy`,
`harness`, `orchestrator-automation`, `cleanup` and `screener` have **no**
`## Next Steps` or `## Next task` section at all. `status_file_integrity.sh`
requires `## Status`, `## Last updated` and `## Interface stable` — it does not
require a forward-looking section, so the index's `Next task` cell for these
tracks has no per-file source to be reconciled against. recommend:
KEEP_AS_INFO (it is a linter-scope question, i.e. a human decision).

Tracks with a stale first item:

- **cash-floor-correctness** — first Next Step (NS1) reads "✅ SHIPPED — see §Completed", merged via #1567/#1582 on 2026-06-14; file 91 days old; recommend refreshing status file.
- **resistance-v2** — `## Next steps` items 1 and 2 are both *completed events* ("CONFIRMATION GRID 3/3 — ACCEPT (2026-07-17)", "PROMOTION EXECUTED (2026-07-23)"). The file's own `## Last updated: 2026-07-17` predates the promotion it describes and #2145 (07-28); recommend refreshing status file.
- **experiment-platform** — first Next Step is struck through and tagged `[superseded 2026-06-21]`; 84 days at the head of the list; recommend refreshing status file.
- **tuning** — Next Steps 1–5 are all struck through as DONE/SUPERSEDED; the first live item (6) cites "track-pacer 2026-05-22 §Recommendations §1" — a 114-day-old recommendation to decide on a track that was never spawned; recommend refreshing status file.
- **weekly-snapshot** — first Next Step is "**[M6.6, DONE]** ~~`generate_weekly_snapshot` bin~~ — SHIPPED 2026-06-14"; recommend refreshing status file.
- **extension-stop** — first Next Step is "Acceptance audit — **DONE** via #1960's ledger insurance-ACCEPT"; additionally items 2 and 3 are near-verbatim duplicates of each other; recommend refreshing status file.
- **tuning-methods** — `## Follow-ups` reads "None yet — track just opened" on a file 112 days old; Next Step 1 ("Land safe-sweep infrastructure") shipped long ago; recommend refreshing status file.
- **data-foundations** — `## Next Steps` opens with a recital of merged PRs (#755/#775/#1028/#772/#1112/#1118/#1120/#1122) rather than a next step; file 63 days old; recommend refreshing status file.
- **spy-only-reference** — file 102 days old; first item self-describes as "(Open question, not dispatched)"; recommend refreshing status file.

Index-row drift (the `_index.md` side of P2):

- **`harness` row lists #2749 as its open PR** ("open at `6024976c` after 2 reworks — rework cap spent, next run re-QCs"). #2749 **merged 2026-09-09** as `cce6d073`. The index's only non-empty Open-PR cell in the whole table points at a merged PR.
- **`simulation` row** says "next: optional A-null (salts 1,2)". The A-null landed as **#2631 on 2026-09-01** (`ledger(clock): A-null — cell A return effect is sign-inconsistent`).
- **`backtest-infra` row** says "next: V18 store-sanity check (#2732 ask 2, dispatched 09-09 run 2)". V18 **merged as #2750** on 09-09 — `post-run-validation`'s own row already says so, so the index contradicts itself across two rows.
- **Index header is 19 PRs and 4 days behind** — it pins `main` at `df7922fb` (2026-09-09) and describes the 09-09 run-2 state.

## `[info]` items needing decision (P3)

None. `dev/status/_index.md` carries no `[info]`-tagged list and no
`[critical]` carryover block. **10th consecutive clean week** — this check has
never fired, and the index header's narrative-block format gives it nothing to
age. recommend: KEEP_AS_INFO.

## Tracks without owner (P4)

None. Every IN_PROGRESS and READY_FOR_REVIEW row carries an owner; every empty
Owner cell belongs to a MERGED row (`capital-management-scale-in`,
`cash-reserve`, `backtest-scale`, `cost-model`, `data-panels`, `hybrid-tier`,
`optimal-strategy`, `all-eligible`, `harvest-rotate`, `strategy-wiring`,
`sector-data`, `cost-tracking`, `data-layer`, `portfolio-stops`,
`trade-autopsy`, `stage3-hysteresis`, `experiments`). No new track has been
created since `arc-readiness` (2026-08-20, owned on creation), so the 14-day
window is empty. PASS.

## Recurring discussion topics (P5)

**`dev/decisions.md` has had zero entries in the last 30 days — and zero in the
last 121 days.** Last modified 2026-05-15 (#1110). Its `## Open Questions`
section still reads verbatim: `_(None yet — system just initialized.)_`. The
check as specified cannot run. The de-facto human→agent decision channel has
moved to `dev/notes/next-session-priorities-*.md` (8 files in the last 10 days)
and `dev/experiments/_ledger/`, neither of which `decisions.md` points at, while
`CLAUDE.md` and the agent definitions still name `decisions.md` as "the primary
channel for human → agent communication between sessions." recommend:
ESCALATE_TO_MAINTAINER — either retire the file with a pointer, or start using
it. A file that every agent is told to read at session start and that has been
empty for four months is a 121-day-old lie in the ramp-up path.

Scanning the channel that *is* live (handoffs + ledger, last 30d) for the same
signal the check was designed to find:

- **"What is the record of record?" — 4 re-bases in 20 days, unresolved.** `#2532` (08-24, canonical record at the book-faithful stops basis) → `#2657` (09-03, re-based onto the fixed exit basis, 302.65%) → `#2704` (09-07, salted re-base on the clean 2000 warehouse, 263% median) → `#2751` (09-09, band re-based on `_v10dedup` to 312/383/640%). Each re-base silently invalidates every number quoted against its predecessor, and `#2751`'s own note says so explicitly ("a new warehouse = a new three-salt band, always"). recommend: RECOMMEND_NEW_TRACK — a `record-of-record` track that owns the basis, its provenance, and the invalidation sweep, so this stops being re-derived monthly inside whatever experiment happens to notice.
- **Warehouse data-integrity defect classes — 5 filed in 30 days, ownership split.** Delisting stubs (#2672), ticker-reuse splices (#2646), `prefix_misscale` (#2732), rename twins (#2730), interleaved series (#2672/PR-B). Every one was found *after* it had corrupted a published measurement. Ownership is split across `backtest-infra`, `post-run-validation`, `rename-twin-dedup` and `data-foundations` — and `rename-twin-dedup.md` says so in its own text ("whether it lives here or on `post-run-validation` is part of the open question"). recommend: RECOMMEND_NEW_TRACK or an explicit merge of the four — the defect *class* is now a program, not four follow-ups.
- **"A maxDD improvement on a warehouse with V6 > 0 is not a read"** — surfaced as a correction at least twice (`#2730`/issue #2730 twin double-counting, then `#2751` retracting the `_v7mark` drawdown floor). Now encoded in `mechanism-validation-rigor.md` check 8 and enforced by `validator_diff` (#2735). recommend: KEEP_AS_INFO — this one is closing correctly; noting it because it is the model for how the two above should end.

## Diminishing returns (P6)

**Mechanical heuristic: 0 flags.** Applied to the last 5 merged PRs of each of
the 8 active tracks, the `chore|fix(linter)|golden|repin|fmt|format|ocamlformat`
subject test hits at most 1 of 5 anywhere (`harness`, via #2748's "goldens").
Every active track's recent PRs carry new feature surface. PASS.

**One qualitative flag the mechanical test does not catch — stated as such:**

- **harness** — all 5 of its last PRs are repairs to the harness's *own*
  tooling, with no new capability: #2767 (test fixture root), #2749 (reconciling
  a disagreement between two of its own QC passes on #2721), #2748 (golden
  emitter for nested defaults), #2727 (pinning a thesis about #2721, which was
  itself the replacement for a broken Step 8), #2725 (making a sanity probe
  self-referential-proof). #2749 is a fix to a review of a fix to a fix. The
  track also holds **33 of the program's 69 open follow-up items — up from 25
  three weeks ago**, the largest single-track increase in the program. This is
  the third consecutive pacer cycle where the harness suite, rather than any
  bug in it, looks like the unit of work. recommend: KEEP_AS_INFO — but if a
  fourth cycle looks the same, the question is whether the check suite's
  marginal return has gone negative, which is a maintainer call, not an agent
  dispatch.

## Capability gaps (P7)

- **[NEW] The GHA orchestrator has been dead since 2026-09-10 and nothing
  detected it.** Six consecutive slots at `$0.0000` (`34475636575`,
  `34501930703`, `34597781805`, `34622262330`, `34691534671`, `34702540272`),
  against $12–60 on every slot back through 09-06. Zero `dev/daily/` summaries,
  zero `dev/health/*-fast.md`, zero `dev/audit/` records across 09-10…09-12.
  The one edit to `.claude/agents/lead-orchestrator.md` or `.github/workflows/`
  in that window — **#2757, merged 2026-09-10T07:07Z** — lands between the last
  funded slot (09-09T18:26Z) and the first dead one (09-10T12:19Z). Mentioned
  in: `orchestrator-automation`, `harness`, `cost-tracking`. Milestone impact:
  all tracks with a GHA-dispatchable next task. recommend:
  ESCALATE_TO_MAINTAINER — read the run log for `34475636575` first; if #2757
  is the cause, it is a one-line revert.
- **[NEW] The detector for that outage exists and is unwired.** `#2663` shipped
  the scheduled-workflow health check on 2026-09-04 — **the script half only**.
  Wiring is blocked on the `workflow`-scoped PAT (`#2634`; `#1636`), which
  `orchestrator-automation.md` measured on 09-04 as refused on *every* route
  (403 on a workflow path against **201** on a `dev/notes/` control, same token,
  seconds apart). The credential gap this report has carried for eight weeks is
  now the direct cause of a three-day silent outage. Mentioned in:
  `orchestrator-automation`, `harness`. recommend: ESCALATE_TO_MAINTAINER —
  this single credential unblocks #2653, #2662, #2634 and #2427–#2432, and
  would have caught the item above on 09-10.
- **[NEW] All three governance watchers were down simultaneously.** The track
  pacer missed **08-30 and 09-06** (`#2723`; the index records the remaining ask
  as `show_full_output: true` alone, the `allowedTools` hypothesis now dead) —
  this report therefore covers 21 days, not 7. The weekly **deep** health scan
  has not run since **2026-08-31** (09-07 missed, 13 days stale; prior cadence
  08-03 / 08-17 / 08-24 / 08-31). Fast scans stop at 09-09 with the
  orchestrator. Mentioned in: `harness`, `orchestrator-automation`. recommend:
  ESCALATE_TO_MAINTAINER — restore the pacer and deep-scan crons independently
  of the orchestrator, so one failure cannot silence its own alarm.
- **The weekly live-picks run is 30 days stale — 4 consecutive Fridays missed;
  4th cycle, now materially worse.** Newest record is
  `dev/weekly-picks/f88c277d5/2026-08-14.*`, committed 2026-08-18 (#2377).
  **08-21, 08-28, 09-04 and 09-11 all produced nothing.** Last commit touching
  `dev/weekly-picks/` at all is #2554 (2026-08-25), and that was a config-value
  change, not a run. M6.6's shipped capability is the *cadence*; a verification
  harness that has not fired in a month is not a verification harness. Mentioned
  in: `weekly-snapshot`, `arc-readiness`, `resistance-v2`, `decision-audit`.
  Milestone: M6. recommend: ESCALATE_TO_MAINTAINER — wire the cadence to
  something that fires without a human, or formally de-scope M6.6's weekly
  cadence and say so in the status file.
- **The promoted bundle's relative margin is still uncertified — carried, 7th
  cycle.** `dev/backtest/DEEP_RESULTS.md` has not been touched since 2026-07-29
  (#2170, 46 days) and still reads verbatim: the re-pin "records the honest
  level of the promoted config, not a re-certification of the promotion
  decision." The bundle is **default-on since #2047**, and the basis it was
  promoted on was shown to flatter results by −322pp return / +6.8pp MaxDD
  (#2156). Under `promotion-confirmation.md` this is a live default whose
  justifying evidence is uncertified — and the record basis has since been
  re-based four more times (see P5), which widens rather than narrows the gap.
  Mentioned in: `resistance-v2`, `arc-readiness`. recommend:
  ESCALATE_TO_MAINTAINER — spend the ~7–8h grid or record the caveat as
  knowingly accepted.
- **EODHD / deep-data access absent in the GHA environment — carried, 8th
  cycle; still the dominant systemic blocker.** **17 of 27** non-MERGED index
  rows carry a next task explicitly marked LOCAL, data-gated, human-gated,
  maintainer-gated or blocked (mechanical grep of the `Owner` + `Next task`
  cells; the true figure is higher — it misses e.g. `spy-only-reference`'s
  "human session" and `weekly-snapshot`'s LOCAL picks generation). Every
  decisive experimental result this cycle (#2704, #2717, #2740, #2743, #2745,
  #2751) was produced LOCAL. This single gap explains most of the stalled
  bucket. Milestone: M6 + M7. recommend: ESCALATE_TO_MAINTAINER — provision
  the key, or formally re-scope the orchestrator to build/plan-only for the
  WF-CV tracks so their stall stops being reported as a pace problem.
- **`tuning` M2 qNEHVI blocked on a maintainer enable-commit (#1327) — 110
  days**, on the M7 critical path, on a one-line human action. Mentioned in:
  `tuning`, `tuning-methods`. Milestone: M7. recommend:
  ESCALATE_TO_MAINTAINER. 8th ask.
- **`sweep-perf` manual ghcr.io flambda rebuild — 92 days.** Until it happens,
  `-O3` is a **silent no-op in CI** (`sweep-perf.md:41-42`) — i.e. every perf
  number CI has produced for three months is measured on an un-optimised build.
  Mentioned in: `sweep-perf`, `backtest-perf`. recommend:
  ESCALATE_TO_MAINTAINER. 7th ask.
- **`arc-readiness` A2-4 is the track's last open sub-task and is 23 days
  behind its own merged plan.** #2453 (make the picks chart answer "how was
  entry picked?") merged 2026-08-21; the implementation has not started. Phase
  A needs no schema change. This is the only unchecked item on a track that is
  otherwise feature-complete on two of three axes. Mentioned in:
  `arc-readiness`, `weekly-snapshot`. Milestone: M6. recommend: KEEP_AS_INFO —
  small, well-scoped, dispatchable the moment an agent runner exists again.
- **Follow-up accumulation: 69 open `- [ ]` items across status files — up from
  64.** Deep-scan threshold is 10. `harness` **33** (up from 25), `trade-audit`
  **9**, `orchestrator-automation` **7**, `tuning-methods` 4, `cleanup` 4,
  `all-eligible` 3, `tuning` 2, `data-foundations` 2, `backtest-infra` 2. The
  entire net rise plus more is `harness` alone (+8); every other track is flat
  or down (`arc-readiness` 4 → 1 is real progress). recommend: KEEP_AS_INFO.

## Recommendations

1. **Read the run log for orchestrator run `34475636575` (2026-09-10T12:19Z) and revert #2757 if it is the cause.** Six consecutive cron slots have spent $0.00 and produced nothing since 09-10; #2757 is the only change to the orchestrator agent definition or workflows in the window, and it merged inside the gap. Everything else in this report is downstream of the automation layer being dead.
2. **Wire the scheduled-workflow health check (#2663 / #2634), which means provisioning the `workflow`-scoped PAT (#1636).** The detector for recommendation 1 already exists as a script and has been unwirable for eight weeks. One credential also unblocks #2653, #2662 and #2427–#2432. This is the highest-leverage single action available.
3. **Restore the track-pacer and deep-health-scan crons on a path independent of the orchestrator.** The pacer missed 08-30 and 09-06 (#2723 — remaining ask is `show_full_output: true`); the deep scan missed 09-07. A watcher that dies with the thing it watches is not a watcher.
4. **Decide who owns the weekly picks cadence, or de-scope it.** Four consecutive Fridays missed; newest record 30 days old. 4th ask, and the first at which the gap exceeds a month. Either it fires without a human or M6.6's cadence claim comes out of the status file.
5. **Unblock the two remaining one-action human gates**: `tuning` M2 enable-commit (#1327, **110 days**, M7 critical path) and the ghcr.io flambda rebuild for `sweep-perf` (**92 days**, without which every CI perf figure for three months was measured un-optimised). Neither is agent-dispatchable.
6. **Decide the bundle-vs-alternatives honest-margin grid (~7–8h).** A default-on promotion (#2047) rests on evidence measured on a basis its own results file says was inflated, and the record has been re-based four times since. Spend the grid or record the caveat as knowingly accepted. 7th ask.
7. **Spawn a `record-of-record` track — or explicitly refuse to.** The canonical record was re-based four times in 20 days (#2532 → #2657 → #2704 → #2751), each time invalidating quoted numbers elsewhere, each time inside whatever experiment happened to notice. Nobody owns the basis or the invalidation sweep.
8. **Consolidate the four tracks that share the warehouse data-integrity program** (`backtest-infra`, `post-run-validation`, `rename-twin-dedup`, `data-foundations`). Five defect classes were filed in 30 days, every one found after it corrupted a published measurement, and `rename-twin-dedup.md` already asks in its own text which track owns the residue. This is the program's strongest work and its ownership is the least clear.
9. **Retire or revive `dev/decisions.md`.** It has been empty for 121 days, its `## Open Questions` still says "system just initialized", and `CLAUDE.md` plus the agent definitions still name it as the primary human→agent channel that every agent reads at session start. Point it at `dev/notes/next-session-priorities-*.md` and the ledger, or start writing to it.
10. **Close or re-scope the four tracks that are parked rather than working**: `tuning-methods` (PENDING, 112 days, no PR ever, superseded in practice by the `experiment-gap-closing` skill), `spy-only-reference` (102 days, item 1 self-marked "not dispatched"), `margin-realism` (M4 complete, no successor, no `## Next Steps` section), `backtest-perf` (82 days, 7th cycle of drift — fold into `backtest-infra` or give it a live owner boundary).
11. **Refresh the nine stale status files and the four drifted index rows** listed in §P2 — and note that `_index.md`'s only non-empty Open-PR cell (`harness` → #2749) points at a PR merged on 09-09. Separately, consider whether `status_file_integrity.sh` should require a forward-looking section: P2 is currently unrunnable on 41% of the audited surface.
12. **Note what worked, so it is repeated.** The snapshot data-integrity program (#2691, #2692, #2695, #2708, #2709, #2713, #2724, #2733, #2735, #2750, #2758) closed five corruption classes in three weeks with real feature surface and zero maintenance padding. And #2751 *retracted its own prior finding* — the `_v7mark` "drawdown floor" was twin double-funding — which is `mechanism-validation-rigor.md` check 8 working exactly as written, now mechanised as `validator_diff` (#2735).

## Stats
- **64 PRs merged in last 7d** (26 `docs`, 15 `ops`/`ops(budget)`, 11 `feat`, 5 `harness`, 3 `fix`, 1 `test`, 1 `refactor`, 1 `plan`, 1 `chore`) — **down from 114**; only **22 (34%) touch product code**, 42 (66%) are docs/ops/plan
- **349 PRs merged in last 30d** — down from 376
- 8 tracks active / 6 slowing / 13 stalled (12 IN_PROGRESS + 1 PENDING) out of 27 non-MERGED rows
- 0 `[info]` items carried ≥3 reconciles (**10th consecutive week**; the index carries no `[info]` list to age)
- **14 orchestrator cron slots fired in the last 7d, totalling $218.32, against 3 `dev/daily/` summaries.** Breakdown: 09-06 $31.77 / no summary · 09-07 $32.95 / no summary · 09-08 $80.48 / summary ✓ · 09-09 $73.12 / 2 summaries ✓ · **09-10 $0.00 · 09-11 $0.00 · 09-12 $0.00 — all six slots, no output of any kind**
- **6 consecutive orchestrator slots at exactly $0.0000** since 2026-09-10T12:19Z; last funded slot 2026-09-09T18:26Z; #2757 merged 2026-09-10T07:07Z, inside the gap
- 0 `dev/daily/` summaries, 0 `dev/health/*-fast.md`, 0 `dev/audit/` records for 09-10, 09-11, 09-12
- **4 PRs merged 2026-09-13 03:48–04:09 PT** (#2758, #2759, #2767, #2768) after the 3-day gap, with no accompanying daily summary, audit record or budget record — provenance (GHA vs local session) unverified from the repo alone; note #2755, which #2759 implements, was queued in the 09-10 handoff as "local dispatch — **fenced, do not GHA-dispatch**"
- **0** `ops(budget)` PRs auto-merged production code past the QC gates — **4th consecutive clean week**; all 15 `ops` PRs this week are single-file `dev/budget/*.json` or `dev/daily/*.md` diffs
- Weekly deep health scan **13 days stale** (last 2026-08-31; 09-07 missed) — cadence broken after 4 clean cycles
- Track pacer **missed 2 of the last 3 cycles** (08-30, 09-06; #2723); this report covers a 21-day window
- Newest `dev/weekly-picks/` record is **30 days old** (2026-08-14); **4 consecutive Fridays missed** (08-21, 08-28, 09-04, 09-11) — worst in program history, up from 9 days three cycles ago
- **69** open `- [ ]` follow-up items across status files (up from 64); `harness` **33** (up from 25) accounts for the entire net rise and more
- **17 of 27** non-MERGED rows are LOCAL / data-gated / human-gated / blocked (mechanical grep; a floor, not a ceiling)
- **11 of 27** non-MERGED status files have no `## Next Steps` or `## Next task` section, so P2 cannot run on them
- 4 index-row drifts (`harness` lists merged #2749 as open, `simulation` A-null landed #2631, `backtest-infra` V18 landed #2750, header 19 PRs / 4 days behind)
- `dev/decisions.md`: **0 entries in 30d, 0 in 121d**; `## Open Questions` still reads "None yet — system just initialized" — P5 unrunnable as specified
- 10 capability-gap bottlenecks flagged: **3 new** (orchestrator dead since 09-10, its detector unwired, all three watchers down at once), 7 carried (picks cadence 4th ask, uncertified bundle margin 7th, EODHD-in-GHA 8th, tuning M2 #1327 8th, sweep-perf ghcr.io 7th, arc-readiness A2-4, follow-up count)
- 0 tracks created in the last 14 days; 0 IN_PROGRESS rows without an owner
- **Method note:** `gh` is unavailable in this environment, so open-PR and CI state are read from `dev/status/_index.md` and `git log` only; PR-level facts are cited from merge-commit subjects on `main`.
