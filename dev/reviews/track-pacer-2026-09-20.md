# Track Pacer Report — 2026-09-20

## Summary
- Tracks audited: 50 index rows (26 IN_PROGRESS + 1 PENDING = 27 non-MERGED; 23 MERGED exempt). Cadence run on the 27 non-MERGED rows.
- Active (≥1 PR last 7d): 7
- Slowing (7–30d since last PR): 5
- Stalled (>30d): 15 (14 IN_PROGRESS + 1 PENDING parked)
- `[info]` items needing decision: 0
- Capability gaps flagged: 10 (2 new, 8 carried)

**Headline: the orchestrator went dark again — 09-17 through 09-19, six
consecutive cron slots at exactly `$0.0000` — and this time the cause is almost
certainly the account's weekly rate limit, not the repo.** The evidence is in
this repo's own handoff: `dev/notes/next-session-priorities-2026-09-20.md:3`
records the local session's gap as **"rate-limit gap 09-16 19:35 → 09-20 00:00"**
and line 58 says "the weekly rate limit reset 09-20 00:00 PT". That window
brackets all six dead slots exactly, and the first post-reset merges land
2026-09-20 (#2862, #2863, #2870, #2871). Local and remote stopped together, on a
shared credential, and restarted together.

State that as a **lead, not a verdict** — deliberately, because last cycle's
headline lead was sharp and wrong. The 09-13 report named PR #2757 as the
suspect for the 09-10…09-12 outage; `dev/daily/2026-09-13.md:52-57` disproved it
with a byte-identical `git diff --stat` across the failure boundary and
attributed it instead to a Claude Code CLI build regression (2.1.266 → 2.1.270).
That disconfirmation is the model for how to treat this one.

**Two three-day outages in ten days, from two unrelated causes, both invisible
from inside the repo** is the durable finding — not either cause. And both times
the budget step wrote a well-formed JSON recording `total_cost_usd: 0`, which is
the open defect class (`#2741`, `#2747`, `#2771`, `#2803`, `#2810`) in its
purest form: a run that produced nothing is byte-indistinguishable from one that
had nothing to do.

**The more useful finding is why there was so little for it to do.** 19 of 27
non-MERGED rows are now LOCAL-fenced, data-gated, human-gated or blocked (up
from 17). Of the 8 that are not, **four carry no next task at all** —
`rename-twin-dedup` ("next: none"), `weekly-snapshot` ("next: none queued"),
`support-floor-stops` ("next: UNSET"), `cleanup` ("NO actionable work"). That
leaves roughly **four rows in the entire program with an ungated, concrete,
dispatchable next task.** The index header says this outright ("Feature tracks
are fenced, by design… harness is where the throughput is"). The orchestrator is
not starved of capability; it is starved of queue. That reframes §Diminishing
returns below, and it is the single most important context for reading this
report's pace numbers.

The good news is specific and real. **The PIT top-3000 universe migration
shipped end to end this week** — plan (#2808), fetch record (#2809), the
`universe_schedule` / `membership_at` seam (#2816), the 3-salt record band at
152 / 188 / 457 % with `V6 = 0` (#2843), and a CI smoke golden pinning the seam
(#2846) — six steps, merged, with the validator gate clean. And the **index-stage
veto went from an open book question to a running pre-registered arm in one
session**: tier-2 book write-back (#2861, corrected in #2870), mechanism merged
default-off (#2863), arm pre-registered and pushed before any cell ran. That is
`book-as-authority.md` tier-3 and `experiment-flag-discipline.md` R1/R2 working
as written, in sequence, in four days.

## Active tracks (≥1 PR last 7d)
- **harness** — ~30 PRs (#2857, #2860, #2855, #2852, #2851, #2853, #2859, #2840, #2834, #2836, #2831, #2830, #2826, #2824, #2821, #2820, #2814, #2812, #2806, #2798, #2797, #2789, #2786, #2785, #2779, #2778, #2772 …); theme: the orchestrator's own verify gate (assert a FULL-mode summary was published, assert claimed dispatches produced artifacts, refuse a stale-dated summary), the disk guard, the gate parser's curl projection, and the new Codex cross-agent review integration. Roughly a third of all merges this week. See §Diminishing returns.
- **backtest-infra** — 10 PRs (#2862, #2856, #2849, #2846, #2845, #2843, #2828, #2816, #2809, #2808); theme: the PIT top-3000 universe migration, steps 1–6, plus the 2021-11 → 2025-04 drawdown dissection (#2856) that motivated this week's experiment. All real feature surface.
- **orchestrator-automation** — 5 PRs (#2841, #2842, #2857, #2819, #2772); theme: scheduled-workflow health reporting and failure streaks, failing closed on draft holds, and publishing the weekly sweep PR through REST instead of `gh`. Landed under `harness:` / `fix:` prefixes by harness-maintainer, but they are this track's surface. **Note #2842 edited `.github/workflows/weekly-start-sweep.yml`** — see §Capability gaps.
- **screener** — 5 PRs (#2863, #2861, #2792, #2776, #2768); theme: closing out the deteriorating-breadth long gate as REJECT-do-not-revive on three `_v10dedup` salts, then opening the index-stage veto — book check (#2861), then mechanism default-off (#2863) with a qc-behavioral rework that pinned the fresh-candidate wiring after M2/M3 mutations survived.
- **trade-audit** — 3 PRs (#2800, #2813, #2827); theme: breaker exits labelled `force_liquidation` in `trades.csv`, R7 = Fail pinned for them, and the §5.1 book-reference write-back that settled the rule regardless of stage.
- **rename-twin-dedup** — 2 PRs (#2862, #2870); theme: the twin detector's direct-match requirement plus a hub guard, merged default-off, and the status correction that the alias sidecar is armed-pass only.
- **post-run-validation** — 1 PR (#2773); theme: `Series_level` build-time absolute price-level sanity, report-only and default-off — the build-time sibling of #2732. Still unwired to `Build_runner`, which is the track's own stated next step.

## Slowing tracks (7–30d since last PR)
- **support-floor-stops** — last PR #2718 at 2026-09-08 (12 days); theme: the per-macro-state `initial_stop_buffer` map, landed as a default-empty axis; recommendation: KEEP_AS_INFO — but note the index cell literally reads **"next: UNSET"**, so this track has no queued work at all. Candidate for closing to MERGED, or for an explicit next item.
- **simulation** — last PR #2709 at 2026-09-08 (12 days); theme: cancelling resting entry tickets past the delisting marker; recommendation: KEEP_AS_INFO — index cell reads "next: none queued".
- **arc-readiness** — last PR #2652 at 2026-09-03 (17 days); theme: the D1/D2 exit-basis default flip; recommendation: KEEP_AS_INFO — Axes 1 and 3 complete; only **A2-4 (picks chart)** remains, now **30 days** behind its own merged plan (#2453). See §Capability gaps.
- **cleanup** — last PR #2637 at 2026-09-03 (17 days), plus the recurring `chore: weekly opam dependency update` (#2805, 09-14); theme: dependency hygiene only; recommendation: KEEP_AS_INFO — the 09-16 re-audit found §Backlog holds no actionable work (3 self-marked deliberate non-actions + 1 fenced template). Correctly parked, not neglected.
- **experiment-platform** — last PR #2631 at 2026-09-01 (19 days); theme: the clock A-null ledger entry; recommendation: ESCALATE_TO_MAINTAINER — **2nd consecutive cycle**. The *ledger* is in daily use (9 entries in 30 days, newest 2026-09-15), but the platform's own code has not moved since **#1372 (2026-05-29, 114 days)**, and its first Next Step is still a struck-through 2026-06-21 supersession. The track is being credited with activity that belongs to its consumers.

## Stalled tracks (>30d since last PR)

Two tracks crossed the 30-day line this week:

- **stage-accuracy** — last PR #2450 at 2026-08-20 (**31 days — newly stalled**); reason: broad-universe WF-CV re-run is data-gated; recommendation: KEEP_AS_INFO — all three remaining items are honestly marked "Not started; not currently queued", and last cycle's 78-day stale head-of-list item was genuinely fixed. This is an honest park, not drift.
- **weekly-snapshot** — last PR #2453 at 2026-08-20 (**31 days — newly stalled**); reason: index cell reads "next: none queued"; recommendation: ESCALATE_TO_MAINTAINER — the track's shipped capability (the weekly picks run) is now **37 days** stale. See §Capability gaps. M6.4 (split/dividend verification harness) is specified in the status file at line 1053 and in the design doc, and has never been started.

Carried:

- **resistance-v2** — last PR #2145 at 2026-07-28 (54 days); reason: promotion executed, remaining work (WF-CV vs w30) data-gated and LOCAL; recommendation: ESCALATE_TO_MAINTAINER — this is the track whose **default-on** promotion (#2047) still has no re-certified relative margin. 6th cycle.
- **tuning** — last PR #2113 at 2026-07-27 (55 days, and that was a Cholesky flake fix, not M2 work); reason: **M2 qNEHVI awaiting a maintainer enable-commit since #1327 (2026-05-26 — 117 days)**; recommendation: ESCALATE_TO_MAINTAINER. On the M5.5 / M7 critical path. 9th ask.
- **short-side-strategy** — last PR #2081 at 2026-07-26 (56 days); reason: next task (short-leg regime-P&L decomposition) marked LOCAL; recommendation: KEEP_AS_INFO.
- **margin-realism** — last PR #2077/#2074/#2063 at 2026-07-24 (58 days); reason: M4 validation complete, leverage surface REJECT, no queued successor, and the file has **no `## Next Steps` section at all**; recommendation: KEEP_AS_INFO — candidate for closing to MERGED. 2nd ask.
- **extension-stop** — last PR #1960 at 2026-07-13 (69 days); reason: only a default flip remains and it is human-gated on a further insurance-basis ACCEPT (R3); recommendation: KEEP_AS_INFO — correctly parked.
- **data-foundations** — last PR #1939 at 2026-07-12 (70 days) on its own next task (`ATB.curated` arming + `General::Type` enrichment); reason: EODHD-gated; recommendation: KEEP_AS_INFO — the `feat-data` owner *is* active, but on PIT-migration fetch work booked to `backtest-infra` (#2809). Second consecutive cycle where the owner is busy and the track is not. M7.0 on the design-doc dependency graph.
- **floor-quality** — last PR #1913 at 2026-07-10 (72 days); reason: P1b step 3 lens screen needs the deep warehouse, maintainer LOCAL; recommendation: KEEP_AS_INFO.
- **backtest-perf** — last PR #1722 at 2026-06-23 (89 days); reason: S4 proven, S5/v1-cleanup deferred by oversight decision, next step LOCAL; recommendation: ESCALATE_TO_MAINTAINER — **8th consecutive cycle of drift**. Its `## Next steps` section still leads with April-2026 `(DONE)` entries. Fold into `backtest-infra` or give it a live owner boundary.
- **rolling-start-lens** — last PR #1645/#1648 at 2026-06-18 (94 days); reason: matrix shipped LOCAL, next step LOCAL/data-gated; recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (98 days); reason: NS2 impl human-gated, NS4 data-gated; recommendation: KEEP_AS_INFO — the correctness half (NS1/NS3) shipped and is default-on.
- **sweep-perf** — last PR #1574 at 2026-06-13 (99 days); reason: **blocked on a manual ghcr.io flambda rebuild** — until it happens, `-O3` is a silent no-op in CI (`sweep-perf.md:41-42`); recommendation: ESCALATE_TO_MAINTAINER. 8th ask.
- **spy-only-reference** — last PR #1438 at 2026-06-03 (109 days); reason: item 1 explicitly "(Open question, not dispatched)"; file 109 days old; recommendation: ESCALATE_TO_MAINTAINER — decide whether the sector-rotation testbed is still wanted, or close the track.
- **tuning-methods** (PENDING) — no PR ever attributed to this track; file last updated 2026-05-24 (119 days) and still reads "Follow-ups: None yet — track just opened"; reason: superseded in practice by the `experiment-gap-closing` skill and the ledger; recommendation: ESCALATE_TO_MAINTAINER — close it or re-scope it. Parked as PENDING for four months. 2nd ask.

## Next Steps staleness (P2)

**[NEW] A mechanical defect the linter does not catch: 14 status files carry a
`## Last updated` date older than their own most recent commit.** The extreme
case is **`dev/status/harness.md`, edited by 46 commits since its header date of
2026-08-21** — most recently on 09-16 (#2860, #2852, #2851, #2853) — so the
field is **30 days stale on the most-actively-edited status file in the
program**. `status_file_integrity.sh` requires the field to *exist*, not to be
*current*, so this passes CI every time. Full list with drift:
`harness` (46 commits), `resistance-v2` (9), `cleanup` (5), `barbell-overlay` (4),
`strategy-wiring` (4), `arc-readiness` (2), `cash-floor-correctness` (2),
`data-foundations` (2), `hybrid-tier` (2), `orchestrator-automation` (2),
`rename-twin-dedup` (2), `backtest-infra` (1), `experiments` (1), `screener` (1).
recommend: KEEP_AS_INFO — whether the linter should compare the field against
`git log -1` is a human decision, but it is a one-line check.

**Structural finding, carried: P2 is unrunnable on 11 of 27 non-MERGED tracks
(41%)** — unchanged from last cycle. `margin-realism`, `post-run-validation`,
`rolling-start-lens`, `sweep-perf`, `trade-audit`, `support-floor-stops`,
`short-side-strategy`, `harness`, `orchestrator-automation`, `cleanup` and
`screener` have no `## Next Steps` / `## Next task` section at all, so the
index's `Next task` cell for these tracks has no per-file source to reconcile
against. recommend: KEEP_AS_INFO.

Tracks with a stale first item — **all eight carried unchanged from 2026-09-13;
none of the eight files was touched this week**:

- **cash-floor-correctness** — first Next Step (NS1) reads "✅ SHIPPED — see §Completed", merged via #1567/#1582 on 2026-06-14; file 98 days old; recommend refreshing status file.
- **resistance-v2** — `## Next steps` items 1 and 2 are both *completed events* ("CONFIRMATION GRID 3/3 — ACCEPT (2026-07-17)", "PROMOTION EXECUTED"); the file's `## Last updated: 2026-07-17` predates both the promotion it describes and its own last commit (07-23); recommend refreshing status file.
- **experiment-platform** — first Next Step is struck through and tagged `[superseded 2026-06-21]`; **91 days** at the head of the list; recommend refreshing status file.
- **tuning** — Next Steps 1–5 are all struck through as DONE/SUPERSEDED (#893, #914 …); the first live item cites a **121-day-old** track-pacer recommendation about a track that was never spawned; recommend refreshing status file.
- **extension-stop** — first Next Step is "Acceptance audit — **DONE** via #1960's ledger insurance-ACCEPT"; items 2 and 3 remain near-verbatim duplicates; recommend refreshing status file.
- **tuning-methods** — `## Follow-ups` reads "None yet — track just opened" on a 119-day-old file; Next Step 1 ("Land safe-sweep infrastructure") shipped long ago; recommend refreshing status file.
- **data-foundations** — `## Next Steps` opens with a recital of merged PRs (Synth-v1 #755 / v2 #775 / v3 #1028 / #772 …) rather than a next step; file 70 days old; recommend refreshing status file.
- **spy-only-reference** — file 109 days old; first item self-describes as "(Open question, not dispatched)"; recommend refreshing status file.
- **weekly-snapshot** — `## Next Steps` opens "M6.1–M6.5 are SHIPPED (see the 2026-06-14 reconcile above)" and the remaining queue is a recital; the index cell says "next: none queued" while M6.4 sits fully specified and unstarted at line 1053; recommend refreshing status file.

Index-row drift (the `_index.md` side of P2):

- **`_index.md`'s only non-empty Open-PR cell — `harness` → `#2851, #2852, #2853` — lists three PRs that all merged on 2026-09-16.** This is the same failure shape as last cycle, when the same cell pointed at the merged #2749. The one column whose whole job is to show what is open has now been wrong two cycles running.
- **`backtest-infra` row** says "next #2823, #2839, top-of-funnel screen". **#2823 shipped as #2862 on 09-20.**
- **`rename-twin-dedup` row** says "next: none (optional V6 report-consult tweak)" — but the track took two PRs on 09-20 (#2862, #2870) and its own file was updated.
- **`screener` row** says "next: run that pre-registered read" — the read ran (#2776/#2792, REJECT-do-not-revive) and the track has since shipped a whole new mechanism (#2863). `screener.md` itself was last touched 09-06 and was **not** updated by #2863.
- **Index header is 4 days and ~14 PRs behind** — pinned at `3ce4381f` (09-16); main is `d59ad4be` (09-20).

## `[info]` items needing decision (P3)

None. `dev/status/_index.md` carries no `[info]`-tagged list and no `[critical]`
carryover block (mechanical grep: zero matches). **11th consecutive clean week** —
this check has never fired, and the index header's narrative-block format gives
it nothing to age. PASS. recommend: KEEP_AS_INFO.

## Tracks without owner (P4)

None. Every IN_PROGRESS and PENDING row carries an owner; every empty Owner cell
belongs to a MERGED row. **No new track has been created since `arc-readiness`
(2026-08-20, owned on creation)**, so the 14-day window is empty. PASS.

Worth noting against §Recommendations: two of this report's recommendations
propose *new* tracks, and P4 exists to catch a new track landing without an
owner. If either is spawned, it needs an owner in the same commit.

## Recurring discussion topics (P5)

**`dev/decisions.md` has had zero entries in 30 days — and zero in 128 days.**
Last modified 2026-05-15 (#1110). Its `## Open Questions` section still reads
verbatim `_(None yet — system just initialized.)_`. The check as specified
cannot run. Meanwhile `CLAUDE.md` and the agent definitions still name it "the
primary channel for human → agent communication between sessions" that "agents
read at the start of every session", while the de-facto channel is
`dev/notes/next-session-priorities-*.md` (5 files in the last 8 days) plus
`dev/experiments/_ledger/` (9 entries in 30 days). recommend:
ESCALATE_TO_MAINTAINER — 2nd ask, unchanged.

Scanning the channel that *is* live (handoffs + ledger, last 30d) for the signal
this check was designed to find:

- **"What is the record of record?" — now 5 re-bases in 23 days, and a 6th is already queued.** `#2532` (08-24, book-faithful stops basis) → `#2657` (09-03, fixed exit basis, 302.65%) → `#2704` (09-07, clean 2000 warehouse, 263% median) → `#2751` (09-09, `_v10dedup`, 312/383/640%) → **`#2843` (09-16, `_v11pit`, 152/188/457%)**. And `next-session-priorities-2026-09-20.md:40-41` already queues the next one ("PIT warehouse rebuild with #2862's guards armed… a rebuild is a new 3-salt band"). Each re-base silently invalidates every number quoted against its predecessor. Meanwhile **`dev/backtest/DEEP_RESULTS.md` has not been touched since 2026-07-29 (#2170, 53 days)** and still publishes the 07-29 basis. recommend: RECOMMEND_NEW_TRACK — a `record-of-record` track that owns the basis, its provenance, and the invalidation sweep. **2nd ask, and materially worse than when first raised.**
- **Warehouse data-integrity ownership is split across four tracks, and the index now contradicts itself about it.** `#2862` (twin detector direct-match + hub guard) landed under a `fix(warehouse):` prefix, updated `dev/status/rename-twin-dedup.md`, and closes an item the index books to **`backtest-infra`** ("next #2823"). `rename-twin-dedup.md` has asked in its own text since 09-08 which track owns the residue. Ownership spans `backtest-infra`, `post-run-validation`, `rename-twin-dedup` and `data-foundations`. recommend: RECOMMEND_NEW_TRACK or an explicit merge of the four. **2nd ask.**
- **The book-as-authority tier-3 write-back loop fired twice this week and worked both times** — `#2827` (§5.1: breaker exits are R7 Fail regardless of stage, Ch. 6) and `#2861` + the `#2870` correction (§2.1: Stage 4 = unconditional buying suspension, Stage 3 = caution only). Both resolved a live faithfulness question *before* the mechanism was built, and both cached the answer in `weinstein-book-reference.md` where a GHA reviewer can reach it. recommend: KEEP_AS_INFO — noting it because it is the model for how the two items above should end.

## Diminishing returns (P6)

**Mechanical heuristic: 0 flags.** Applied to the last 5 merged PRs of each of
the 7 active tracks, the `chore|fix(linter)|golden|repin|fmt|format|ocamlformat`
subject test hits at most 1 of 5 anywhere. Every active track's recent PRs carry
new surface. PASS.

**One qualitative flag, carried and now at the threshold the last report set:**

- **harness** — the last 5 harness PRs are #2857 (share a prior-summary timestamp
  lookup between two of its own scripts), #2860 (a docs backfill of #2851's own
  status entry), #2852 (pin an N3 projection mutation in its own gate), #2855
  (constrain Codex's unattended pushes), #2851 (pin the disk-guard constant split
  uniquely). Every one is a repair to the harness's own tooling. The track took
  roughly **a third of all merges in the program this week**. This is the
  **fourth consecutive cycle** with that shape, and the 09-13 report said
  explicitly: "if a fourth cycle looks the same, the question is whether the
  check suite's marginal return has gone negative."

  **Two facts argue the opposite, and they should be weighed before acting.**
  First, the work is producing real closures: #2853 fixed a gate that had
  **already validated a 2-day-old summary and reported its rows as that run's**
  (run `35096884441`) — a live defect, not a hypothetical. Follow-ups on the
  track **fell 33 → 28**, the first decline in three cycles. Second, and more
  important: per §Summary, `harness` is close to the **only unfenced track in
  the program**. It is absorbing the work because it is the only place work can
  go, not because the suite is generating its own demand.

  recommend: KEEP_AS_INFO — the honest reading is that this is a **queue**
  problem wearing a diminishing-returns costume. The maintainer decision is not
  "is the harness suite worth it" but "what should the agent runner be pointed
  at instead", which is §Recommendations 3.

## Capability gaps (P7)

- **[NEW] Second orchestrator outage in ten days, different cause, same
  invisibility.** Six consecutive slots at exactly `$0.0000` — `35222092194`,
  `35250052670`, `35343656590`, `35368301543`, `35441465645`, `35453227622` —
  across 09-17, 09-18 and 09-19, against $12–60 on every slot back through
  09-13. Zero `dev/daily/` summaries, zero `dev/health/*-fast.md`, zero
  `dev/audit/` records for those three days. The likely cause is the **account
  weekly rate limit**: `next-session-priorities-2026-09-20.md:3` records the
  local gap as 09-16 19:35 → 09-20 00:00 PT and line 58 confirms the reset, a
  window that brackets all six slots and explains why local and remote stopped
  and restarted together. Lead, not verdict — last cycle's equally sharp lead
  was disproved. Mentioned in: `orchestrator-automation`, `harness`,
  `cost-tracking`. recommend: ESCALATE_TO_MAINTAINER — if it is the rate limit,
  the fix is a budget/plan decision, not an engineering one, and the actionable
  part is that **nothing in the repo can currently distinguish "rate-limited"
  from "crashed" from "nothing to do"**: all three write a well-formed
  `total_cost_usd: 0`.
- **[NEW] The `workflow`-scope blocker is narrower than the record claims, and
  one instance of it is a one-line fix on a proven route.** The index header
  carries "`workflow` scope unavailable by push **and** contents API" as a
  standing constraint blocking #2770, #1636, #2113 and #2810. But **#2842
  edited `.github/workflows/weekly-start-sweep.yml` and merged on 09-16** —
  through a human-merged PR, the same route #2828 used for a rules file. So the
  gate is on *agent push*, not on the repo. Meanwhile
  **`prune-candidates-weekly.yml:131` still calls `gh pr create`**, which does
  not exist in that image — verified by grep — so it will fail with exit 127 on
  its next cron exactly as it has for four weeks (#2847, streak 4), while its
  sibling workflow was fixed by #2842. Mentioned in: `orchestrator-automation`,
  `harness`. recommend: ESCALATE_TO_MAINTAINER — apply #2842's REST fix to
  `prune-candidates-weekly.yml` via the same human-merged-PR route. Highest
  actionability-to-effort ratio in this report.
- **The dispatchable queue is nearly empty — 19 of 27 non-MERGED rows are
  gated, and 4 of the remaining 8 have no next task at all.** Up from 17 of 27
  last cycle. The four ungated rows with any content are `trade-audit` (retire
  one memory), `spy-only-reference` (self-marked "not dispatched", human
  session), `tuning-methods` (PENDING, never shipped), `data-foundations`
  (EODHD-gated in practice). Mentioned in: every track. Milestone: M6 + M7.
  recommend: ESCALATE_TO_MAINTAINER — this is the root cause that §Diminishing
  returns, the harness concentration, and much of the stalled bucket all reduce
  to. Either provision the agent runner with deep-data access, or formally
  re-scope it to build/plan/harness-only and stop reporting the fenced tracks'
  stall as a pace problem. **9th cycle for the underlying data-access gap.**
- **The weekly live-picks run is 37 days stale — 5 consecutive Fridays missed;
  5th cycle, worst in program history.** Newest record is
  `dev/weekly-picks/f88c277d5/2026-08-14.*`, committed 2026-08-18 (#2377).
  **08-21, 08-28, 09-04, 09-11 and 09-18 all produced nothing.** Last commit
  touching `dev/weekly-picks/` at all is #2554 (2026-08-25), a config-value
  change rather than a run. M6.6's shipped capability is the *cadence*; a
  verification harness that has not fired in five weeks is not a verification
  harness. Mentioned in: `weekly-snapshot`, `arc-readiness`, `resistance-v2`,
  `decision-audit`. Milestone: M6. recommend: ESCALATE_TO_MAINTAINER — wire the
  cadence to something that fires without a human, or formally de-scope M6.6's
  weekly cadence and say so in the status file.
- **The promoted bundle's relative margin is still uncertified — carried, 8th
  cycle, and the gap widened again.** `dev/backtest/DEEP_RESULTS.md` has not
  been touched since 2026-07-29 (#2170, **53 days**) and still reads that the
  re-pin "records the honest level of the promoted config, not a
  re-certification of the promotion decision." The bundle is **default-on since
  #2047**, and the basis it was promoted on was shown to flatter results by
  −322pp return / +6.8pp MaxDD (#2156). Under `promotion-confirmation.md` this
  is a live default whose justifying evidence is uncertified — and the record
  basis has now been re-based **five** times since (see P5), which widens rather
  than narrows the gap. Mentioned in: `resistance-v2`, `arc-readiness`.
  recommend: ESCALATE_TO_MAINTAINER.
- **`tuning` M2 qNEHVI blocked on a maintainer enable-commit (#1327) — 117
  days**, on the M5.5 / M7 critical path, on a one-line human action. Mentioned
  in: `tuning`, `tuning-methods`. Milestone: M7. recommend:
  ESCALATE_TO_MAINTAINER. **9th ask.**
- **`sweep-perf` manual ghcr.io flambda rebuild — 99 days.** Until it happens,
  `-O3` is a **silent no-op in CI** (`sweep-perf.md:41-42`) — every perf number
  CI has produced for over three months is measured on an un-optimised build.
  Mentioned in: `sweep-perf`, `backtest-perf`. recommend:
  ESCALATE_TO_MAINTAINER. **8th ask.**
- **`arc-readiness` A2-4 is the track's last open sub-task and is now 30 days
  behind its own merged plan.** #2453 (make the picks chart answer "how was
  entry picked?") merged 2026-08-21; implementation has not started. Phase A
  needs no schema change. The only unchecked item on a track otherwise
  feature-complete on two of three axes. Mentioned in: `arc-readiness`,
  `weekly-snapshot`. Milestone: M6. recommend: KEEP_AS_INFO — small,
  well-scoped, and one of the very few genuinely dispatchable items left.
- **M6.4 (split/dividend verification harness) is fully specified and has never
  been started.** `weekly-snapshot.md:1053` carries the complete scenario table
  (AAPL 4:1 2020-08, TSLA 5:1 2020-08, GOOG 20:1 2022-07, NVDA 10:1 2024-06) and
  the design doc lists it as a direct dependency of the M5.5/M7 tuning node.
  The endpoints (`/splits`, `/div`) are already paid for. Its stated purpose is
  "catches G14-class bugs deterministically before live trading" — and
  `dev/decisions.md` records exactly such a bug costing a −144.5% phantom
  baseline. Mentioned in: `weekly-snapshot`, `simulation`, `backtest-infra`.
  Milestone: M6. recommend: KEEP_AS_INFO — but it is the largest fully-specified
  unstarted item on the M6 path, and unlike most of the queue it is **not**
  data-gated in a way that blocks a GHA agent.
- **Follow-up accumulation: 64 open `- [ ]` items across status files — down
  from 69.** `harness` **28** (down from 33), `trade-audit` 9,
  `orchestrator-automation` 7, `tuning-methods` 4, `cleanup` 4, `all-eligible`
  3, `tuning` 2, `data-foundations` 2, `backtest-infra` 2, `rolling-start-lens`
  1, `cost-model` 1, `arc-readiness` 1. **First net decline in three cycles**,
  and `harness` alone accounts for the whole of it. recommend: KEEP_AS_INFO —
  this is a positive trend and worth naming as such.

## Recommendations

1. **Confirm or disprove the rate-limit explanation for the 09-17…09-19 outage, then make the three states distinguishable in the repo.** The evidence (local gap 09-16 19:35 → 09-20 00:00 PT, six `$0.0000` slots inside it, simultaneous restart) is strong but is the same *kind* of evidence that was wrong last cycle. Whatever the answer, the durable fix is that a rate-limited run, a crashed run, and a run with an empty queue currently all write an identical `total_cost_usd: 0` — the budget step should record the result's `is_error` / `num_turns` / `modelUsage` shape alongside the cost, which `dev/daily/2026-09-13.md` already proved is the diagnostic signal.
2. **Apply #2842's REST fix to `prune-candidates-weekly.yml:131`.** It still calls `gh pr create` in an image with no `gh`, and will fail with exit 127 on its next cron for the fifth week running (#2847). #2842 proved the route works — a human-merged PR can edit a workflow file. This is the cheapest open item in the report.
3. **Decide what the agent runner is *for*, given that 19 of 27 rows are fenced and only ~4 carry a dispatchable task.** This is the root cause behind the harness concentration, most of the stalled bucket, and the low value of restarting the orchestrator. Either provision deep-data access so the fenced tracks become dispatchable, or formally re-scope the runner to harness/build/plan work and stop counting fenced tracks in the pace numbers. **M6.4 and `arc-readiness` A2-4 are the two best candidates for a non-data-gated queue** if the runner stays as-is.
4. **Decide who owns the weekly picks cadence, or de-scope it.** Five consecutive Fridays missed; newest record 37 days old. 5th ask, and each cycle the claim in the status file gets further from the artifact on disk.
5. **Unblock the two standing one-action human gates**: `tuning` M2 enable-commit (#1327, **117 days**, M5.5/M7 critical path) and the ghcr.io flambda rebuild for `sweep-perf` (**99 days**, without which every CI perf figure for three months was measured un-optimised). Neither is agent-dispatchable; both have been asked 8–9 times.
6. **Spawn a `record-of-record` track — or explicitly refuse to.** The canonical record has been re-based **five times in 23 days** (#2532 → #2657 → #2704 → #2751 → #2843) and a sixth is already queued in the 09-20 handoff, while `dev/backtest/DEEP_RESULTS.md` still publishes the 07-29 basis, 53 days old. Nobody owns the basis or the invalidation sweep, and each re-base happens inside whatever experiment happens to notice. 2nd ask.
7. **Consolidate the four tracks that share the warehouse data-integrity program** (`backtest-infra`, `post-run-validation`, `rename-twin-dedup`, `data-foundations`). #2862 landed this week under a `fix(warehouse):` prefix, updated `rename-twin-dedup.md`, and closed an item the index books to `backtest-infra` — the ambiguity is now visible in the index itself. 2nd ask.
8. **Fix the `harness` Open-PR cell, and consider making the `Last updated` field checkable.** `_index.md`'s only non-empty Open-PR cell lists #2851/#2852/#2853, all merged 09-16 — the second cycle running that this one cell points at merged PRs. Separately, 14 status files carry a `Last updated` older than their own last commit, `harness.md` by 46 commits and 30 days; `status_file_integrity.sh` checks the field exists but never that it is current.
9. **Close or re-scope the five tracks that are parked rather than working**: `tuning-methods` (PENDING, 119 days, no PR ever), `spy-only-reference` (109 days, item 1 self-marked "not dispatched"), `margin-realism` (M4 complete, no successor, no `## Next Steps` section), `backtest-perf` (89 days, 8th cycle of drift), and now `support-floor-stops` / `weekly-snapshot` / `rename-twin-dedup`, whose index cells read "UNSET" / "none queued" / "none". An IN_PROGRESS row with no next task is a MERGED row that nobody closed.
10. **Refresh the nine stale status files** in §P2 — all nine are carried unchanged from 2026-09-13 and none was touched this week. Add `screener.md` (not updated by #2863, its own biggest merge in a month) to the list.
11. **Retire or revive `dev/decisions.md`.** 128 days empty, `## Open Questions` still says "system just initialized", and `CLAUDE.md` plus the agent definitions still name it the primary human→agent channel that every agent reads at session start. Point it at `dev/notes/next-session-priorities-*.md` and the ledger, or start writing to it. 2nd ask.
12. **Note what worked, so it is repeated.** Three things this week: (a) the **PIT universe migration shipped all six steps** (#2808 → #2846) with a clean `V6 = 0` band, which is a plan executed end to end rather than re-derived; (b) the **book-as-authority loop fired twice and both times cached the answer** (#2827 §5.1, #2861/#2870 §2.1) *before* the mechanism was built — the index-stage veto went from open question to pre-registered running arm in four days, with the arm pushed before any cell ran; (c) the **09-13 report's own headline lead was disproved by the 09-13 daily summary** with a byte-identical diff across the failure boundary. A governance instrument whose findings get falsified in public is working correctly, and it is why this report's headline is labelled a lead.

## Stats
- **89 PRs merged in last 7d** (36 `docs`, 20 `ops`/`ops(budget)`, 13 `harness`, 10 `fix`, 6 `feat`, 2 `chore`, 1 `test`, 1 `exp`) — up from 64; **30 (34%) touch code** (`feat`+`fix`+`harness`+`test`), 56 (63%) are docs/ops
- **333 PRs merged in last 30d** (96 `docs`, 71 `ops`, 42 `feat`, 39 `harness`, 37 `fix`, 21 `experiments`, 5 `test`, 5 `cleanup`, 4 `chore`) — down from 349
- 7 tracks active / 5 slowing / 15 stalled (14 IN_PROGRESS + 1 PENDING) out of 27 non-MERGED rows — vs 8 / 6 / 13 last cycle; `stage-accuracy` and `weekly-snapshot` crossed the 30-day line
- 0 `[info]` items carried ≥3 reconciles (**11th consecutive week**; the index carries no `[info]` list to age)
- **12 orchestrator cron slots fired in the last 7d, totalling $299.83, against 6 `dev/daily/` summaries.** Breakdown: 09-13 $59.67 + $28.30 · 09-14 $18.30 + $48.44 · 09-15 $45.18 + $46.30 · 09-16 $12.68 (no summary) + $40.98 · **09-17 $0.00 · $0.00 · 09-18 $0.00 · $0.00 · 09-19 $0.00 · $0.00 — all six slots, no output of any kind**
- **6 consecutive orchestrator slots at exactly `$0.0000`** since 2026-09-17; last funded slot 2026-09-16T17:28Z; the 09-20 handoff records a weekly rate-limit window of 09-16 19:35 → 09-20 00:00 PT that brackets all six
- **Second three-day outage in ten days** (09-10…09-12, then 09-17…09-19), from two unrelated causes; the first was diagnosed as a Claude Code CLI build regression (`dev/daily/2026-09-13.md`), disconfirming the prior pacer report's #2757 lead
- 0 `dev/daily/` summaries, 0 `dev/health/*-fast.md`, 0 `dev/audit/` records for 09-17, 09-18, 09-19
- **4 PRs merged 2026-09-20** (#2862, #2863, #2870, #2871) — the first merges after the rate-limit reset; no budget record for 09-20 yet
- Weekly **deep** health scan **ran 2026-09-14** — cadence restored after last cycle's 13-day gap; next due 09-21. Fast scans stop at 09-16 with the orchestrator
- This report is a **manual make-up run**: no cron-produced report for 09-20 exists, and the scheduled slot (Sun 06:00 UTC = Sat 23:00 PT) falls inside the rate-limit window
- Newest `dev/weekly-picks/` record is **37 days old** (2026-08-14); **5 consecutive Fridays missed** (08-21, 08-28, 09-04, 09-11, 09-18) — worst in program history, up from 30 days last cycle
- **64** open `- [ ]` follow-up items across status files (**down from 69** — first net decline in three cycles); `harness` **28** (down from 33) accounts for the entire fall
- **19 of 27** non-MERGED rows are LOCAL / data-gated / human-gated / blocked (up from 17); of the 8 remaining, **4 carry no next task at all** — roughly **4 genuinely dispatchable rows program-wide**
- **11 of 27** non-MERGED status files have no `## Next Steps` or `## Next task` section, so P2 cannot run on them (unchanged)
- **14 status files carry a `Last updated` date older than their own last commit**; `harness.md` by **46 commits / 26 days**; `status_file_integrity.sh` checks existence, not currency
- 5 index-row drifts (`harness` Open-PR cell lists 3 merged PRs, `backtest-infra` #2823 shipped as #2862, `rename-twin-dedup` "next: none" took 2 PRs, `screener` read already ran and a new mechanism shipped, header 4 days / ~14 PRs behind)
- **`prune-candidates-weekly.yml:131` still calls `gh pr create`** (verified by grep) in an image with no `gh` — 4th week (#2847); sibling `weekly-start-sweep.yml` was fixed by #2842, which **did edit a workflow file** via a human-merged PR
- Record-of-record re-based **5 times in 23 days** (#2532 → #2657 → #2704 → #2751 → #2843); a 6th is queued in the 09-20 handoff; `dev/backtest/DEEP_RESULTS.md` last touched 2026-07-29 (**53 days**)
- `dev/decisions.md`: **0 entries in 30d, 0 in 128d** (last modified 2026-05-15, #1110); `## Open Questions` still reads "None yet — system just initialized" — P5 unrunnable as specified
- Experiment ledger: **9 entries in 30d**, newest `2026-09-15-pit-universe-record-baseline.sexp`; the index-stage-veto entry is pending its running 3-salt arm
- 10 capability-gap bottlenecks flagged: **2 new** (second orchestrator outage / the three indistinguishable zero-cost states; the `workflow`-scope blocker being narrower than recorded, with `prune-candidates-weekly.yml` a one-line fix on a proven route), 8 carried (empty dispatchable queue 9th, picks cadence 5th, uncertified bundle margin 8th, tuning M2 #1327 9th, sweep-perf ghcr.io 8th, arc-readiness A2-4, M6.4 unstarted, follow-up count)
- 0 tracks created in the last 14 days; 0 IN_PROGRESS or PENDING rows without an owner
- **Method note:** `gh` is unavailable in this environment (`which gh` → not found), so open-PR and CI state are read from `dev/status/_index.md` and `git log` only; PR-level facts are cited from merge-commit subjects on `main`. Window is 2026-09-13 → 2026-09-20 and overlaps the prior report by a few hours on 09-13.
