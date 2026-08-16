# Track Pacer Report — 2026-08-16

## Summary
- Tracks audited: 49 index rows (26 IN_PROGRESS/READY_FOR_REVIEW + 1 PENDING = 27 non-MERGED; 22 MERGED). Cadence run on the 26.
- Active (≥1 PR last 7d): 9
- Slowing (7–30d since last PR): 7
- Stalled (>30d): 10 IN_PROGRESS + 1 PENDING parked
- `[info]` items needing decision: 0
- Capability gaps flagged: 11 (2 new, 3 recurrences/worsened, 6 carried)

Headline: **throughput held (94 merges vs 67 last week) and the code-health
side had its best week of the program — but every finding that needs a human
decision is unmoved, and two of last week's severe governance findings got
worse rather than better.**

The good news is real. `#2257` landed the **Rule 4 mechanism-retirement
protocol** and the `cleanup` track immediately used it: `#2299` (scale-in),
`#2283` (`harvest_rotate`), `#2286` (`cash_reserve_pct`), `#2284`
(`early_admission_ma_period`) — four dead default-off mechanisms deleted
outright, goldens bit-identical, plus `#2307`/`#2312` correctly *refusing* to
retire two more that fail the eligibility test. Separately `#2279` +
`#2293` found and fixed a genuine correctness defect — **backtests were not
reproducible** because the intraday path was not seeded per bar — and turned a
single run into a distribution. And `#2317`/`#2323` closed the audit-join
defect the `trade-audit` row had carried (date-proximity → `position_id`),
resolving last week's #6.

The bad news is that this is the **second consecutive week in which the human-gated
queue did not move at all**, and three items regressed:

1. **The `ops(budget)` QC-bypass recurred a third time.** `#2309`
   (`ops(budget): record 2026-08-13-31700595897`) carried **447 lines of
   linter shell code** (`linter_file_length.sh` +192, a new 255-line
   `linter_file_length_test.sh`), a `dune` edit and two status files into
   `main` on an auto-merged ops PR that ran neither QC gate. This was
   recommendation **#1** last week (after `#2224` and `#2235`); nothing was
   dispatched against it.
2. **The weekly live picks run has now missed two consecutive Fridays**
   (2026-08-07 and 2026-08-14). Newest record in `dev/weekly-picks/` is still
   `3e10a92c7/` = 2026-07-31, **16 days old**. M6.6 critical path.
3. **Silent orchestrator slots persist and acquired two new shapes.** 5 of 13
   slots (**$113.50**) produced no `dev/daily/` summary; the 08-15 08:42Z
   record carries `total_cost_usd: null`; and the 08-15 PM slot wrote no
   budget record at all.

**1 of last week's 10 recommendations was resolved** (the `trade-audit` status
reconcile), down from 6 of 9 the week before. Every unresolved one requires a
maintainer decision rather than an agent dispatch.

## Active tracks (≥1 PR last 7d)
- **harness** — 15 PRs (#2252 `tracked_artifact_linter`, #2266 SHA-keyed rework audit records, #2269 blind-judge tooling, #2272 OCaml `magic_numbers_linter.exe`, #2280 `docker_dune.sh`, #2300 PR-gate-loop + container-scheduling rules, #2301 linter self-test, #2303 comment-stripping in the universe-deps scan, #2314 declared-large cap fixture, #2315 developer-local exclude leak, #2322 path-qualified run-targets, #2327 dune-comment stripping, #2328 `REPO_ROOT` hard-error, #2334/#2335 gh failure-mode classification); theme: **the check suite auditing itself**. Top-volume track for the 4th straight week. See P6.
- **cleanup** (code-health) — 13 PRs (#2257 Rule-4 protocol + flag inventory, #2299/#2283/#2286/#2284 four mechanism retirements, #2271/#2296 flag-inventory corrections, #2307/#2312 retirement *ineligibility* rulings, #2273 `adjusted_close` guard pin, #2285 short-stop citation, #2302 prefilter precondition pin, #2324 segmentation weight caveats); theme: **executing `experiment-flag-discipline.md` Rule 4** — the strongest code-health week on record.
- **trade-audit** — 8 PRs (#2249 split-safe not-exercised assertions, #2251 adjusted price basis in `trade_audit_report_bin`, #2254 E-provenance fields, #2270 ticket-lifecycle fields, #2316 diagnosis that "#18 and #4 are one bug", #2317 join by `position_id`, #2318 spec-header caveat, #2323 the report-path half); theme: **replacing the date-proximity audit join** — the track's carried next-task, closed.
- **backtest-infra** — 4 PRs (#2279 per-bar intraday path seeding — *backtests were not reproducible*, #2293 path-seed salt turning one run into a distribution, #2311 candidate-universe builder, #2319 candidate-universe payoff measurement); theme: **run-level reproducibility and a middle test tier**. Highest-value correctness work of the week.
- **simulation** — 4 PRs (#2258 F3 `stop_width_mode` + nearest-floor anchor, #2263 F2 `entry_order_ttl_weeks` + re-screen cancel, #2270 ticket-lifecycle audit fields, #2291 StopLimit-armed golden); theme: the **entry-ticket async-v2** flag ladder.
- **support-floor-stops** — 3 PRs (#2249, #2251, #2265 G4 `Html_report` mark-callback basis split); theme: split-safe basis plumbing reaching the report layer. Volume down from 5.
- **screener** — 2 PRs (#2261 F1 `entry_freshness_basis`, #2267 F5 `volume_confirm_at_fill`); theme: async-v2 placement-side timing corrections.
- **orchestrator-automation** — 1 PR (#2337 recovering a stranded 2026-08-13 run-2 summary + health report). Manual recovery, not a systemic fix.
- **rename-twin-dedup** — 1 PR (#2302 prefilter-precondition pin in `test_rename_detector`).

_(Not attributable to any index row: **~12 PRs of the entry-ticket-async-v2 /
ladder-v4 program** — #2255, #2262, #2275, #2288, #2310, #2319, #2332, #2340,
#2341, #2342, plus the experiment/docs spine. Same finding as last week; see
P4.)_

_(Governance/main-health: `#2331` `[main-fix] index_size_linter` — `_index.md`
had grown to 21,972 bytes against the 20,480-byte cap and reddened main; ten
inlined orchestrator run summaries were moved to `dev/daily/`. Resolved
same-day.)_

## Slowing tracks (7–30d since last PR)
- **post-run-validation** — last PR #2236 was 9 days ago (2026-08-07, V12 stop-distance gate-consistency invariant); remaining golden-run V3/V4/V7 integration test is data-gated. recommendation: KEEP_AS_INFO.
- **weekly-snapshot** — last PR #2197 was 12 days ago (2026-08-04); index says "next: none queued". The track's *output* (the Friday picks run) is the P7 gap, not its code. recommendation: KEEP_AS_INFO.
- **margin-realism** — last PR #2196 was 12 days ago (2026-08-04); the #2076 report-layer remainder closed and nothing new is queued. recommendation: KEEP_AS_INFO.
- **data-foundations** — last PR #2191 was 13 days ago (2026-08-03, live rename detection armed); next is `ATB.curated` arming + `General::Type` enrichment. Status file last updated 2026-07-12. recommendation: KEEP_AS_INFO.
- **resistance-v2** — last PR #2170 was 18 days ago (2026-07-29); the promotion shipped (#2047), the record was honestly re-pinned, and what remains is a data-gated WF-CV plus a lever-b axis. recommendation: KEEP_AS_INFO (4th ask on dropping to axis-maintenance — see P6).
- **short-side-strategy** — last PR #2081 was 21 days ago (2026-07-26, robust dollar-ADV); next is a short-leg regime-P&L decomposition marked LOCAL. recommendation: KEEP_AS_INFO.
- **backtest-perf** — last own-track PR #2024 was 27 days ago (2026-07-20); status file last updated 2026-06-16 (**61 days**) and has **no `## Next Steps` section at all**. Its subject matter is now shipping under `backtest-infra` (#2279/#2293/#2311). Will tip stalled next week. recommendation: ESCALATE_TO_MAINTAINER (the ownership boundary has drifted for five weeks — see P2).

## Stalled tracks (>30d since last PR)
- **extension-stop** — last PR #1960 at 2026-07-13 (34 days) — **newly stalled**; reason: only a default flip remains, human-gated on a further insurance-basis ACCEPT (R3). recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 at 2026-07-10 (37 days) — **newly stalled**, exactly as predicted last week; reason: P1b step 3 (lens screen vs TR-SPY) is deep-warehouse maintainer-LOCAL. recommendation: KEEP_AS_INFO.
- **stage-accuracy** — last PR #1864 at 2026-07-06 (41 days); reason: a rejection streak, not churn; broad-universe WF-CV re-run is data-gated. Status file untouched since 2026-06-06 (71 days). recommendation: ESCALATE_TO_MAINTAINER (status refresh, 6th ask).
- **decline-character** — last PR #1740 at 2026-06-24 (53 days); reason: the track **self-declares "WORKSTREAM EXHAUSTED (2026-06-25, #1739)"**. recommendation: ESCALATE_TO_MAINTAINER (mark closed — 7th consecutive ask).
- **rolling-start-lens** — last own PR #1648 at 2026-06-18 (59 days); reason: next steps self-tagged deep-warehouse maintainer-LOCAL. recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (63 days); reason: NS1 shipped and flipped ON, NS2 impl human-gated, NS4 DD-validation data-gated. recommendation: KEEP_AS_INFO.
- **sweep-perf** — last substantive PR #1574 at 2026-06-13 (64 days); reason: the only remaining step is the **manual ghcr.io flambda rebuild**, a human action. recommendation: ESCALATE_TO_MAINTAINER (5th ask).
- **spy-only-reference** — last PR #1438 at 2026-06-03 (74 days); reason: next is explicitly a human session. recommendation: KEEP_AS_INFO.
- **experiment-platform** — last own PR #1372 at 2026-05-29 (79 days); reason: the platform is in continuous use — every default-off flag shipped this week (#2258/#2261/#2263/#2267) is an R2 axis routed through it — but the code track's single-dial surface is exhausted. recommendation: KEEP_AS_INFO (steady-state infra, not a real stall).
- **tuning** — last PR #1333 at 2026-05-27 (81 days); reason: M1 complete 5/5; **M2 qNEHVI still awaiting a maintainer enable-commit per #1327**. On the M7 critical path. recommendation: ESCALATE_TO_MAINTAINER (6th ask).
- **tuning-methods** (PENDING) — parked since 2026-05-24 (84 days); Step 0 done, steps 1–3 demoted, component-decomposition objective queued but never dispatched. recommendation: KEEP_AS_INFO.

## Next Steps staleness (P2)
- **screener** — **WORSENED.** The file was refreshed on 2026-08-10 (good), but the refresh **added a new stale claim**: the 2026-08-10 F5 entry is written as "(branch `feat/volume-confirm-at-fill`, **PR OPEN**)" while #2267 merged the same day. The narrative now carries **seven** "PR OPEN" claims, every one of them for a merged PR (#2267 08-10, #2087 07-26, #2079 07-24, the #1941 threading PR 07-13, #1428, and two more). The refresh convention itself is producing the staleness. ESCALATE_TO_MAINTAINER (3rd ask, now regressing).
- **simulation** — header is current (2026-08-10) with detailed entries for #2258/#2263/#2270, but `## Next Steps` (line 671) is still the May "### Future slices" list whose second item is struck through as DONE via `walk-forward-cv`. The entry-ticket ladder that four of this week's PRs advanced appears nowhere in it. ESCALATE_TO_MAINTAINER (3rd ask).
- **stage-accuracy** — `## Last updated: 2026-06-06` (**71 days**). First `## Next Steps` item is self-marked "**DONE 2026-06-06: REJECTED**". Flagged 07-12, 07-19, 07-26, 08-02, 08-09. ESCALATE_TO_MAINTAINER (6th ask).
- **backtest-perf** — file last updated 2026-06-16 (61 days) and it has **no `## Next Steps` section**, so the P2 check cannot even run against it. Its index "Next task" cell describes LOCAL work with no file backing. Carried five weeks. ESCALATE_TO_MAINTAINER.
- **rolling-start-lens** — file last updated 2026-06-15 (62 days). Carried five weeks. KEEP_AS_INFO.
- **backtest-infra** — `## Next Steps` item 1 still defers Step 3 to `backtest-scale.md` and names "the Tiered loader flip" as a prerequisite; `backtest-scale` has been MERGED for months. Carried from 08-02 and 08-09. Note the file was *touched* twice this week (#2317, #2318) without the stale item being corrected. KEEP_AS_INFO.
- **`_index.md` header** — `Last updated: 2026-08-15 (orchestrator run 31872019203)`, but it lists `#2335` in the harness row's **Open PR(s)** column and #2335 merged on 2026-08-15; seven later PRs (#2337, #2340–#2345) are unreflected. Minor drift, no escalation. The `#2331` size-cap main-fix that restructured this file is a separate governance note (P7).
- **RESOLVED since 2026-08-09:** **trade-audit** — the 3-week P2 finding is closed. `## Status` is now `READY_FOR_REVIEW` (was `MERGED`), `## Last updated: 2026-08-14`, and the `position_id` join it carried as its next task shipped (#2317/#2323). This was last week's recommendation #6, first half.
- **Pattern note (carried):** on 7+ tracks the first `## Next Steps` entry is a struck-through or DONE-marked completed item. This is a formatting convention, not a defect — but the P2 "first item" heuristic still cannot be read mechanically on this repo.

## `[info]` items needing decision (P3)
- **None.** `dev/status/_index.md` carries **0** `[info]`-tagged items. After `#2331` moved the inlined run history to `dev/daily/`, the header block is a single-run reconcile pointer with no carried-forward `[info]` list, so there is nothing to age. **Eighth consecutive week** with the same structural answer — the check has no surface to read on this repo.

## Tracks without owner (P4)
- **No IN_PROGRESS or READY_FOR_REVIEW row is missing an owner.** Every `—` in the Owner column belongs to a MERGED row (exempt). No new track rows were created in the last 14 days — the index still has 49 rows, unchanged.
- **CARRIED (2nd week) — the entry-ticket / fill-model program still has no index row.** ~12 of this week's 94 merges belong to the `entry-ticket-async-v2` + `ladder-v4` arc (#2255, #2262, #2275, #2288, #2310, #2319, #2332, #2340, #2341, #2342 plus the F1–F5 flag PRs), and the program's own next step — the `#2342` "entry anchor + TTL defect queue, graded and ordered" and the `#2341` finding that **TTL's clock structurally cannot capture slow breakouts, and the record arm is 84% one trade** — is named on no index row. Its state remains split across `screener`, `simulation` and `trade-audit`, each cell describing only its own slice. recommend: RECOMMEND_NEW_TRACK (or designate one of the three rows as program owner).

## Recurring discussion topics (P5)
- **None from the P5 scan surface.** `dev/decisions.md` has **no entries in the last 30 days** — the newest is 2026-05-16 (the Norgate→EODHD/IWV vendor pivot), **92 days** old. Standing observation, now carried for the **7th week**: `dev/decisions.md` has been retired in practice as the human→agent decision channel in favour of `dev/notes/next-session-priorities-*.md` handoffs, the experiment ledger (`dev/experiments/_ledger/`), and the daily orchestrator summaries — none of which P5 scans. Re-pointing the check is a human decision. KEEP_AS_INFO.

## Diminishing returns (P6)
- **No track trips the strict heuristic** (≥3 of the last 5 PRs matching `chore` / `fix(linter)` / `golden` / `repin` / `fmt` / `ocamlformat`). Only **3 of 94** subjects match any maintenance keyword at all (#2260 weekly opam update, #2248 untrack `compile_commands.json`, #2291 goldens). Two softer signals:
  - **harness — soft flag, 4th consecutive week, and the self-referential rate is now measurable.** All 15 PRs are meta-work on the check suite, and the *same defect classes recur inside the same week*: `#2252` added `tracked_artifact_linter` on 08-09, then `#2301` (fixture self-test) and `#2315` (it was reading developer-local excludes) both landed on 08-13 to fix it — a **4-day** defect-to-fix cycle on a brand-new check. `#2303` and `#2327` are the *same* comment-stripping bug found in two different scanners, two days apart. `#2334` and `#2335` are two passes at one gh-fallback classification on the same day. This is the identical pattern flagged last week for `write_audit.sh`/`record_qc_audit.sh`, now migrated to the linter/check suite: the *suite*, not the individual bug, looks like the unit of work. The track also still holds **30 of the repo's 58** open `- [ ]` items. recommend: KEEP_AS_INFO — but the "clean-slate rewrite" question from last week now applies to a second component.
  - **resistance-v2** — the promotion it existed to produce shipped (#2047) and its record was honestly re-pinned (#2170). What remains is one open evidence caveat (P7) plus a default-off lever-b softener. 4th ask on whether it drops to axis-maintenance.
- **Explicitly NOT a diminishing-returns flag: `cleanup`.** 13 PRs, dominated by four Rule-4 mechanism deletions (#2299, #2283, #2286, #2284) executed against a protocol that landed the same week (#2257). Deleting dead default-off mechanisms with bit-identical goldens is the `code-health-discipline.md` behaviour the flag has been asking for since July, and `#2307`/`#2312` correctly declined to retire two ineligible ones rather than clearing the list mechanically. Last week's `cleanup` soft flag is **fully resolved**. Note the corollary: `#2312` records that **every remaining row on the seeded RETIRE list fails Rule 4**, so this seam is now exhausted — expect `cleanup` volume to fall next week without that being a regression.

## Capability gaps (P7)
- **`ops(budget)` PRs auto-merge production code past both QC gates — THIRD occurrence, unactioned after being last week's #1 recommendation.** `#2309` (2026-08-13) is titled `ops(budget): record 2026-08-13-31700595897 ($32.1972)` and its diff contains `trading/devtools/checks/linter_file_length.sh` (+192), a new `linter_file_length_test.sh` (+255), a 26-line `dune` change, and two status files — **447 lines of shell that gates every other PR in the repo**, merged with neither qc-structural nor qc-behavioral. Prior instances: `#2224` (08-06), `#2235` (08-07). `.claude/rules/pr-merge-gates.md` allows a QC skip only for docs-only diffs; none of the three qualifies, and the fact that the swept-in content is *itself the linter suite* makes this the highest-leverage failure of the merge gate available. Milestone impact: all tracks. recommend: **ESCALATE_TO_MAINTAINER — highest priority, and now a repeat non-action.**
- **The weekly live picks run has missed two consecutive Fridays — WORSENED, M6.6 critical path.** `dev/weekly-picks/` newest record is `3e10a92c7/` = **2026-07-31**, committed 08-03 (#2192). Both 2026-08-07 (last week's finding, and the explicit P0 of `next-session-priorities-2026-08-04.md`) and 2026-08-14 produced nothing. That is three misses in five weeks, with the 07-31 run itself recovered two days late. The cadence *is* the M6.6 capability — a verification harness that does not run weekly is not a verification harness. recommend: ESCALATE_TO_MAINTAINER.
- **The weekly deep health scan skipped a cycle — NEW.** `dev/health/` deep reports run every 7 days (07-06, 07-13, 07-20, 07-27, 08-03) and then stop: **no deep scan on 2026-08-10**, so the newest is 13 days old. Fast scans ran on 08-09 and 08-12–08-15 but not 08-10 or 08-11 — the same two days the orchestrator produced no summary (below). The deep scan is the only source of the follow-up-accumulation and linter-exception-expiry warnings this report cites, so a skipped cycle degrades the next audit too. recommend: ESCALATE_TO_MAINTAINER.
- **Silent orchestrator slots persist, in two new shapes — carried and worsened.** Across 2026-08-09…08-15 there are **13 budget records** (14 expected at 2 slots/day) totalling **$504.33**, against only **8** `dev/daily/` summaries:
  - **5 slots spent $113.50 and wrote no summary** — 08-10 (2 slots, $77.46), 08-11 (2 slots, $21.65), 08-12 PM ($14.40). 08-10 was the week's second-most-productive day (**15 merges**) and has no orchestrator record at all.
  - **08-15 08:42Z wrote a record with `total_cost_usd: null`** — the `$0.0000` failure mode that #2180/#2195 closed has returned as a *null* rather than a zero, so the fix's guard does not catch it.
  - **08-15 PM wrote no budget record at all** — the only missing slot in a 15-day run.
  `#2337` manually recovered one stranded 08-13 run-2 summary, which is evidence the gap is noticed but handled by hand. `A-NOOP-BUDGET-ORPHAN` on `orchestrator-automation` still describes the old $0.00 shape. recommend: ESCALATE_TO_MAINTAINER — re-scope it to cover spend-without-output and null-measurement.
- **The promoted bundle's relative margin has still not been re-certified on the honest basis — carried, 3rd week.** `dev/backtest/DEEP_RESULTS.md` states it verbatim: the re-pin "records the honest level of the promoted config, not a re-certification of the promotion decision". The bundle is **default-on since #2047** and the basis it was promoted on was shown to flatter results by −322pp return / +6.8pp MaxDD (#2156). Under `promotion-confirmation.md` this is a live default whose justifying evidence is uncertified. Scoped at ~7–8h of grid time. recommend: ESCALATE_TO_MAINTAINER — spend the grid or record the caveat as knowingly accepted.
- **EODHD data access absent in the GHA orchestrator environment — carried, 6th week; still the dominant systemic blocker.** Data-gated next-tasks on `backtest-perf`, `stage-accuracy`, `experiment-platform`, `cash-floor-correctness` (NS4), `floor-quality`, `post-run-validation`, `tuning`, `rolling-start-lens`, `resistance-v2`, `short-side-strategy`, `spy-only-reference` — **11 of the 26 non-MERGED rows**. Every decisive experimental result this week (#2288, #2310, #2332, #2340) was produced LOCAL. This single gap explains most of the stalled bucket. Milestone impact: M6 + M7. recommend: ESCALATE_TO_MAINTAINER — provision the key, or formally re-scope the orchestrator to build/plan-only for the WF-CV tracks.
- **`tuning` M2 qNEHVI blocked on a maintainer enable-commit (#1327)** — **81 days** on a one-line human action, on the M7 critical path. recommend: ESCALATE_TO_MAINTAINER. (Carryover, 6th week.)
- **`sweep-perf` manual ghcr.io flambda rebuild** — the only remaining human step; substantive work stopped **64 days** behind it. recommend: ESCALATE_TO_MAINTAINER. (Carryover, 5th week.)
- **`workflow`-scoped PAT still blocking six `orchestrator-automation` items (#1636)** — per the index row, "six items share the `workflow`-token blocker". One credential action unblocks six, including the automation that would close the silent-slot gap above. recommend: ESCALATE_TO_MAINTAINER. (Carryover.)
- **Follow-up accumulation: 58 open `- [ ]` items across status files — UP from 52.** Deep-scan threshold is 10. `harness` holds **30**, `orchestrator-automation` 6, `cleanup` 6, `tuning-methods` 4, `trade-audit` 3, `all-eligible` 3. The count rose despite the strongest cleanup week of the program, because the retirements closed *mechanisms*, not *checklist items*. recommend: KEEP_AS_INFO.
- **`_index.md` outgrew its own linter and reddened main — NEW, self-resolved.** `#2331` was a `[main-fix]`: the index reached 21,972 bytes against `index_size_linter.sh`'s 20,480 cap because ten orchestrator run summaries had been inlined into the header, each already ending with a pointer to its own `dev/daily/` file. Fixed same day by moving them out. Worth noting only because the growth was invisible until CI failed — the same "accumulate silently, fire all at once" shape `code-health-discipline.md` documents. recommend: KEEP_AS_INFO.

## Recommendations
1. **Stop `ops(budget)` PRs from carrying non-ops content — third occurrence, first repeat non-action.** `#2309` auto-merged 447 lines of *linter* shell past both gates; `#2224` and `#2235` did the same in the preceding week. Add a path allowlist to the budget-PR auto-merge (ops PRs may touch `dev/budget/` and nothing else) or drop the auto-merge entirely. This was recommendation #1 last week and the situation is strictly worse.
2. **Run the weekly picks cycle, and decide who owns the cadence.** Two consecutive Fridays missed (08-07, 08-14); newest record is 16 days old; three misses in five weeks. Either dispatch the run or explicitly de-scope M6.6's weekly cadence — the current state is neither.
3. **Fix the silent orchestrator slot for real.** 5 of 13 slots spent $113.50 with no `dev/daily/` output, 08-15 AM recorded a `null` cost, and the 08-15 PM slot recorded nothing. Re-scope `A-NOOP-BUDGET-ORPHAN` (which still describes the fixed $0.00 shape) to cover spend-without-summary *and* null-measurement, and stop hand-recovering summaries as in `#2337`.
4. **Re-run the missed 2026-08-10 deep health scan** and check why the weekly cadence dropped a cycle. The deep scan is the upstream source of the follow-up-count and linter-expiry warnings; a 13-day-old scan degrades every downstream audit.
5. **Give the entry-ticket / fill-model program an index row.** ~12 merges this week on top of ~22 last week, split across three rows, with its graded defect queue (`#2342`) and its most important finding (`#2341`: TTL cannot capture slow breakouts; the record arm is 84% one trade) named on none of them. 2nd ask.
6. **Decide the bundle-vs-alternatives honest-margin grid** (~7–8h). A default-on promotion (#2047) rests on evidence measured on a basis since shown inflated by −322pp / +6.8pp. Spend the grid or record the caveat as knowingly accepted in `DEEP_RESULTS.md`. 3rd ask.
7. **Decide the EODHD-in-GHA question.** 11 of 26 non-MERGED rows are data-gated and every decisive result this week was produced LOCAL — this one gap generates most of the stalled bucket. Provision the key, or formally mark the WF-CV tracks build/plan-only so their stall stops being reported as a pace problem. 6th ask.
8. **Unblock the three one-action human gates**: `tuning` M2 enable-commit (#1327, 81d, M7 critical path); the `workflow`-scoped PAT (#1636, unblocks six orchestrator items including the silent-slot automation); the manual ghcr.io flambda rebuild for `sweep-perf` (64d).
9. **Finish the three outstanding status reconciles**: `screener` (refreshed 08-10 but the refresh *added* a stale "PR OPEN" claim — seven now, all merged; 3rd ask), `simulation` (`## Next Steps` still the May "Future slices" list; 3rd ask), `stage-accuracy` (71 days, first Next Step self-marked DONE; 6th ask). Also give `backtest-perf` a `## Next Steps` section or fold it into `backtest-infra` — it has neither a section nor a live owner boundary.
10. **Close the finished tracks** — `decline-character` (self-declared exhausted #1739, 7th ask) and `rename-twin-dedup` (index says "next: none"); decide whether `resistance-v2` drops to axis-maintenance (4th ask).
11. **Consider whether the check/linter suite is the unit of work, not its bugs.** `tracked_artifact_linter` shipped 08-09 and took two corrective PRs by 08-13; the same comment-stripping defect was fixed in two scanners two days apart (#2303, #2327); two passes at one gh-fallback path landed the same day (#2334, #2335). Identical shape to last week's `write_audit.sh` finding, on a second component. 15 of 94 merges went here.

## Stats
- **94 PRs merged in last 7d** (10 `ops:` + 7 `ops(budget)` = 17 ops, 25 `docs:` + 10 scoped-docs = 35 docs, ~42 substantive feat/fix/test/cleanup/harness/experiment) — up from 67
- **326 PRs merged in last 30d**
- 9 tracks active / 7 slowing / 10 stalled-IN_PROGRESS (+1 PENDING parked) out of 26 non-MERGED rows
- 0 `[info]` items carried ≥3 reconciles (**8th consecutive week**; the index carries no `[info]` list to age)
- 13 of 14 expected orchestrator cron slots wrote budget records, totalling **$504.33**; **8** daily summaries written → **5 slots spent $113.50 with no output**, 1 record has `total_cost_usd: null`, 1 slot wrote no record
- **3rd** `ops(budget)` PR auto-merging production code past both QC gates (#2224, #2235, **#2309** — 447 lines of linter shell)
- 2 consecutive Friday live-picks runs missed (08-07, 08-14); newest `dev/weekly-picks/` record is **16 days** old
- Weekly deep health scan skipped 2026-08-10; newest is 2026-08-03 (13 days)
- **58** open `- [ ]` follow-up items across status files (up from 52; `harness` holds 30)
- **4 dead mechanisms retired under Rule 4** (#2299 scale-in, #2283 `harvest_rotate`, #2286 `cash_reserve_pct`, #2284 `early_admission_ma_period`), goldens bit-identical; 2 correctly ruled ineligible (#2307, #2312)
- 11 capability-gap bottlenecks flagged: 1 new (skipped deep health scan), 1 new-shape (null-cost budget record), 3 worsened recurrences (ops-PR QC bypass 3rd time, 2nd consecutive missed Friday, follow-up count up), 6 carried (uncertified bundle margin 3rd week, EODHD-in-GHA 6th week, tuning M2 #1327 6th week, sweep-perf ghcr.io 5th week, workflow-PAT #1636, no index row for the entry-ticket program)
- 4 status-file reconciles outstanding (`screener` 3rd ask and regressing, `simulation` 3rd ask, `stage-accuracy` 6th ask, `backtest-perf` no Next Steps section); `_index.md` header 7 PRs behind and lists a merged PR as open
- **1 of last week's 10 recommendations resolved** (`trade-audit` status reconcile), 1 partial (#2337 hand-recovered one stranded summary) — down from 6 of 9. Every unresolved item requires a maintainer decision, not an agent dispatch.
