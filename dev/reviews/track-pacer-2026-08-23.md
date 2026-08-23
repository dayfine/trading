# Track Pacer Report — 2026-08-23

## Summary
- Tracks audited: 50 index rows (27 IN_PROGRESS + 1 PENDING = 28 non-MERGED; 22 MERGED). Cadence run on the 27 IN_PROGRESS.
- Active (≥1 PR last 7d): 9
- Slowing (7–30d since last PR): 7
- Stalled (>30d): 11 IN_PROGRESS + 1 PENDING parked
- `[info]` items needing decision: 0
- Capability gaps flagged: 8 (1 new, 2 improved-but-open, 5 carried)

Headline: **the best governance week of the program — four of last week's ten
recommendations resolved, including all three that had been recurring —
against a record 114 merges. What remains is almost entirely the human-decision
queue, which is now the *only* thing left.**

Three carried findings closed outright:

1. **The `ops(budget)` QC-bypass did not recur.** All five `ops(budget)` PRs
   this week (#2360, #2375, #2400, #2471, #2472) are single-file diffs touching
   only `dev/budget/*.json`. Every `ops:` daily-summary PR touched only
   `dev/{budget,daily,health,status,reviews,audit}`. After three consecutive
   weeks of production code auto-merging past both gates (#2224, #2235, #2309),
   zero this week. This was recommendation **#1** for two weeks running.
2. **`lead-orchestrator.md` now honours holds.** #2480 added the
   `do-not-merge` label check *and* the draft-as-hold rule to Step 5 Stage 3 —
   closing the "tooling is ahead of the spec" gap the index header has carried
   since #2397 reverted the −40.91pp clock-26 promotion. #2456 additionally
   made `pr_gate_status.sh` hold on conflicting verdicts at one SHA, closing the
   concurrent-QC-pipeline finding (#2432) at the gate reader.
3. **The weekly deep health scan is back on cadence** (2026-08-17, 6 days old);
   last week's skipped 08-10 cycle did not repeat.

And **both `do-not-merge` holds resolved correctly, by a human, on the merits** —
#2433 merged 08-22 only after its headline was retracted (the sp500 "reversal"
was a universe artifact, #2448) and #2456 after the `unclear` verdict call was
made. This is the first week the hold mechanism can be observed working end to
end rather than being bypassed.

The bad news is narrower but unchanged in kind:

- **The live picks cadence is still not weekly.** 2026-08-07 was never produced,
  2026-08-14 landed four days late (#2377, 08-18), and **2026-08-21 has not
  landed** as of today. Newest record is 9 days old. M6.6 critical path, 3rd week.
- **Silent orchestrator slots persist, 3rd week, with the shape now inverted
  too.** 5 of 13 slots spent **$53.05** with no `dev/daily/` summary — and one
  slot (08-20 AM, run `32344313210`) wrote a summary with **no budget record**,
  the mirror-image failure.
- **The human-gated queue is unmoved for the third consecutive week.** `tuning`
  M2 (#1327, 88 days), `sweep-perf` ghcr.io flambda rebuild (71 days), the
  `workflow`-scoped PAT (#1636), the uncertified bundle margin (4th week).

## Active tracks (≥1 PR last 7d)
- **harness** — ~22 PRs (#2482 `goldens-affected` PR check, #2481 15y-golden CI cap, #2456 `pr_gate_status.sh` conflicting-verdict hold, #2449 `prune_candidates.sh`, #2437 `prior_cell_check`, #2430 sexp-default drift linter + #2462/#2464 its two corrections, #2419/#2420/#2421/#2425 gate-reader verdict-heading parsing, #2424 scenario-42 residuals, #2390 `_glob_count` guard, #2372/#2373, #2362, #2359, #2339, #2338, #2363, #2369, #2446); theme: **the gate reader and the check suite auditing themselves**. Top-volume track for the 5th straight week. See P6.
- **arc-readiness** (NEW track, created 2026-08-20 via #2451) — ~15 PRs (#2447 plan, #2451/#2454/#2474 tracker, #2452 book-faithful entry bundle + live-picks A/B, #2459 corrected 26y record, #2463 G2a `entry_fill_reject_retries`, #2468 G2b `entry_fill_size_to_available`, #2469 G3 first arming, #2473 the three-way funding grid, #2475 effect-vs-null report tool, #2476 A3-2 doc prune, #2477 A3-3 config-`.mli` compression 1,911→1,362, #2455 6-month trade-inspection harness, #2453 picks-chart plan); theme: **Axis 1 declared feature-complete and the funding program closed**. This track absorbs the entry-ticket / fill-model program — see P4.
- **simulation** — ~12 PRs (#2349 TTL knob split into re-screen + clock, #2355 TTL cancel precedence + 40 spec migration, #2353/#2368/#2376 the TTL re-test and its REJECT, #2384 clock-26 promotion and #2397 its revert, #2392 the −38.42pp golden A/B, #2414/#2416 status corrections, #2378 G3 `reserve_cash_for_resting_tickets`, #2352 `Demote_over_max`, #2423/#2431 cap-refused StopLimit tally + `Fill_rules` extraction); theme: **the entry-ticket clock, promoted, reverted, and re-framed**.
- **trade-audit** — 5 PRs (#2348 portfolio-rejected entry tickets now resolve in `trade_audit.sexp`, #2357/#2364 stale walk-order docstrings, #2365 cancel-reason closed list by reachable set, #2371 cohort measurement); theme: ticket-lifecycle observability feeding the funding program.
- **screener** — 4 PRs (#2391 book §4.4 rule 2 long-side RS admission gate, #2379 AXTI entry-construction pin, #2399 docstring nits, #2387 withdrawal of the fill re-anchor "defect"); theme: book-faithfulness gates and one retracted measurement.
- **weekly-snapshot** — 2 PRs (#2377 the 2026-08-14 picks record, four days late; #2453 chart plan). The track's *code* is quiet; its *output cadence* is the P7 gap.
- **orchestrator-automation** — 1 PR (#2480 merge gate honours holds; Stage 3 never flips a held draft; GHA subagents get their own worktree). Small volume, high value — this is the fix for the #2384 class.
- **cleanup** — 1 PR (#2461 backtest subdir appendix reconciled, 4 missing rows, recurrence filed). Volume fell from 13 as #2312 predicted: the seeded Rule-4 RETIRE list is exhausted. **Not** a regression.
- **support-floor-stops** — 1 PR (#2455 6-month trade-inspection harness + fallback-stop canonical pin, shared with arc-readiness Axis 2).

_(Cross-cutting and not cleanly attributable to one row: the **measurement/retraction cluster** — #2436 the 5y drawdown null, #2438 the contention knob, #2441/#2442 its residuals, #2444 the sp500-universe rule, #2445 the ledger audit against it, #2448 the reversal-was-the-universe retraction, #2450 the late_stage2 KEEP-AXIS ruling, #2417/#2411/#2413 the entry-cap axis at 3-year folds. Nine of these belong to `arc-readiness` Axis 2 in substance; counted there loosely above.)_

## Slowing tracks (7–30d since last PR)
- **backtest-infra** — last PR #2319 was 9 days ago (2026-08-14, candidate-universe payoff measurement); index says "next: none queued". recommendation: KEEP_AS_INFO.
- **rename-twin-dedup** — last PR #2302 was 10 days ago (2026-08-13, prefilter-precondition pin); index says "next: none (optional V6 report-consult tweak)". recommendation: KEEP_AS_INFO — this track is finished in all but name (see Recommendations #7).
- **post-run-validation** — last PR #2242 was 15 days ago (2026-08-08, fill-basis `stop_fill_distance_pct` column); remaining golden-run V3/V4/V7 integration test is data-gated. recommendation: KEEP_AS_INFO.
- **margin-realism** — last PR #2196 was 19 days ago (2026-08-04); nothing new queued. recommendation: KEEP_AS_INFO.
- **data-foundations** — last PR #2192 was 20 days ago (2026-08-03); next is `ATB.curated` arming + `General::Type` enrichment. Status file last updated 2026-07-12 (42 days). recommendation: KEEP_AS_INFO.
- **resistance-v2** — last PR #2170 was 25 days ago (2026-07-29); the promotion shipped (#2047), the record was re-pinned, what remains is a data-gated WF-CV plus a lever-b axis. recommendation: KEEP_AS_INFO (5th ask on dropping to axis-maintenance — see P6).
- **short-side-strategy** — last PR #2081 was 28 days ago (2026-07-26); next is a short-leg regime-P&L decomposition marked LOCAL. **Tips stalled next week.** recommendation: KEEP_AS_INFO.

## Stalled tracks (>30d since last PR)
- **backtest-perf** — last own PR #2024 at 2026-07-20 (34 days) — **newly stalled, exactly as predicted last week**; reason: its subject matter now ships under `backtest-infra` and `arc-readiness`; status file last updated 2026-06-16 (68 days). recommendation: ESCALATE_TO_MAINTAINER (the ownership boundary has drifted six weeks — see P2).
- **extension-stop** — last PR #1960 at 2026-07-13 (41 days); reason: only a default flip remains, human-gated on a further insurance-basis ACCEPT (R3). recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 at 2026-07-10 (44 days); reason: P1b step 3 (lens screen vs TR-SPY) is deep-warehouse maintainer-LOCAL. recommendation: KEEP_AS_INFO.
- **stage-accuracy** — last PR #1864 at 2026-07-06 (48 days); reason: a rejection streak, not churn; broad-universe WF-CV re-run is data-gated. Status file untouched since 2026-06-06 (78 days). recommendation: ESCALATE_TO_MAINTAINER (status refresh, 7th ask).
- **decline-character** — last PR #1740 at 2026-06-24 (60 days); reason: the track **self-declares "WORKSTREAM EXHAUSTED (2026-06-25, #1739)"**. recommendation: ESCALATE_TO_MAINTAINER (mark closed — 8th consecutive ask).
- **rolling-start-lens** — last own PR #1648 at 2026-06-18 (66 days); reason: next steps self-tagged deep-warehouse maintainer-LOCAL. recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (70 days); reason: NS1 shipped and flipped ON, NS2 impl human-gated, NS4 DD-validation data-gated. recommendation: KEEP_AS_INFO.
- **sweep-perf** — last substantive PR #1574 at 2026-06-13 (71 days); reason: the only remaining step is the **manual ghcr.io flambda rebuild**, a human action, without which `-O3` is a silent no-op in CI. recommendation: ESCALATE_TO_MAINTAINER (6th ask).
- **spy-only-reference** — last PR #1438 at 2026-06-03 (81 days); reason: next is explicitly a human session. recommendation: KEEP_AS_INFO.
- **experiment-platform** — last own PR #1374 at 2026-05-29 (86 days); reason: the platform is in continuous use — every default-off flag this week (#2463, #2468, #2378) is an R2 axis routed through it — but the code track's single-dial surface is exhausted. recommendation: KEEP_AS_INFO (steady-state infra, not a real stall).
- **tuning** — last PR #1333 at 2026-05-27 (88 days); reason: M1 complete 5/5; **M2 qNEHVI still awaiting a maintainer enable-commit per #1327**. On the M7 critical path. recommendation: ESCALATE_TO_MAINTAINER (7th ask).
- **tuning-methods** (PENDING) — parked since 2026-05-24 (91 days); Step 0 done, steps 1–3 demoted, component-decomposition objective queued but never dispatched. recommendation: KEEP_AS_INFO.

## Next Steps staleness (P2)
- **arc-readiness** — **NEW, and the freshest file in the repo is the stalest claim.** `## Last updated: 2026-08-22`, but `## Next task` item 1 still names **A3-2 and A3-3** as remaining open work; both merged the same day (#2476 A3-2, #2477 A3-3). `## Follow-ups` opens with "**#2433 framing** ⚠ USER DECISION — held under `do-not-merge`"; #2433 merged 2026-08-22 (`d7087e0a`). The file was written by #2474, which merged *before* all three — a same-day ordering artifact, not neglect, but the file now misdescribes the track's own state. recommend: refresh on next touch. KEEP_AS_INFO.
- **screener** — carried, **4th ask**, no longer worsening. `## Last updated: 2026-08-10`. Four literal `PR OPEN` markers remain, every one for merged work: #2267 (F5 `volume_confirm_at_fill`, merged 08-10), #2079 (ranked-candidate arming, merged 07-24), the #1941 `resistance_min_history_bars` threading PR (merged 07-13), and #1782 Phase 1 (merged 06-28). The narrative convention — recording each entry as it is written, never re-reading it after merge — is what produces this. ESCALATE_TO_MAINTAINER.
- **simulation** — carried, **4th ask**. Header is current (2026-08-19) with the clock-26 revert correctly recorded, but `## Next Steps` is still the May "### Future slices" list whose second bullet is struck through as DONE via `walk-forward-cv`. The entry-ticket ladder that ~12 of this week's merges advanced appears nowhere in it. ESCALATE_TO_MAINTAINER.
- **stage-accuracy** — carried, **7th ask**. `## Last updated: 2026-06-06` (**78 days**). First `## Next Steps` item is self-marked "**DONE 2026-06-06: REJECTED**". Flagged 07-12, 07-19, 07-26, 08-02, 08-09, 08-16. ESCALATE_TO_MAINTAINER.
- **backtest-perf** — carried, **6th week**, with a correction to last week's finding: the file *does* have a `## Next steps` section (line 1013, lowercase `s`, which is why the P2 heuristic missed it). It is worse than absent — items 1–3 are all marked `(DONE)` and date from **April 2026**. File last updated 2026-06-16 (68 days). ESCALATE_TO_MAINTAINER — give it a live Next-steps list or fold the track into `backtest-infra`.
- **rolling-start-lens** — file last updated 2026-06-15 (69 days). Carried six weeks. KEEP_AS_INFO.
- **backtest-infra** — `## Next Steps` item 1 still defers Step 3 to `backtest-scale.md` and names "the Tiered loader flip" as a prerequisite; `backtest-scale` has been MERGED for months. Carried from 08-02, 08-09, 08-16. KEEP_AS_INFO.
- **`_index.md` header** — `Last updated: 2026-08-21 (orchestrator run 2)`, **30 merges behind**. Its `Open PR(s)` column lists **#2463** (arc-readiness) and **#2456** (harness) as open; both merged on 2026-08-21/08-22. The header's own framing — "both open PRs (#2456, #2433) sit under `do-not-merge` Rule-0 holds awaiting human decisions" — is now resolved in both cases. Minor drift, no escalation.
- **Pattern note (carried):** on 7+ tracks the first `## Next Steps` entry is a struck-through or DONE-marked completed item. This is a formatting convention, not a defect — the P2 "first item" heuristic still cannot be read mechanically on this repo.

## `[info]` items needing decision (P3)
- **None.** `dev/status/_index.md` carries **0** `[info]`-tagged items (`grep -c '\[info\]'` → 0). Since #2331 moved the inlined run history to `dev/daily/`, the header block is a single-run reconcile pointer with no carried-forward `[info]` list, so there is nothing to age. **Ninth consecutive week** with the same structural answer — the check has no surface to read on this repo. Re-pointing it (e.g. at the `USER DECISIONS carried` block in `arc-readiness.md`, which *is* a real aged-decision list) would be a human call.

## Tracks without owner (P4)
- **No IN_PROGRESS or PENDING row is missing an owner.** Every `—` in the Owner column belongs to a MERGED row (exempt).
- **One new track in the last 14 days: `arc-readiness`** (created 2026-08-20, #2451), owner `dayfine (LOCAL) + feat-weinstein`. Correctly owned on creation. No flag.
- **RESOLVED — the entry-ticket / fill-model program now has an index row.** Last week's 2nd-ask recommendation is closed: `arc-readiness` explicitly carries the entry-ticket half (`sim_entry_trigger_at_suggested`, `enable_sim_entry_stoplimit`, `entry_extension_max_pct`, `stop_anchor_at_entry_base`), the screening half (`entry_anchor_local_range_weeks`, `entry_freshness_basis`, `volume_confirm_at_fill`), the ladder-v4 cells, and the four-step funding plan — with a per-step state table. The program's state is no longer split across three rows describing only their own slice.

## Recurring discussion topics (P5)
- **None from the P5 scan surface.** `dev/decisions.md` has **no entries in the last 30 days** — the newest is 2026-05-16 (the Norgate→EODHD/IWV vendor pivot), **99 days** old. Standing observation, carried for the **8th week**: `dev/decisions.md` has been retired in practice as the human→agent decision channel in favour of `dev/notes/next-session-priorities-*.md` handoffs, the experiment ledger (`dev/experiments/_ledger/`), the `.claude/rules/*.md` corpus (two new rules landed this week: #2444 universe discipline, #2383 QC-outranks-backtests), and the daily orchestrator summaries — none of which P5 scans. Re-pointing the check is a human decision. KEEP_AS_INFO.

## Diminishing returns (P6)
- **No track trips the strict heuristic** (≥3 of the last 5 PRs matching `chore` / `fix(linter)` / `golden` / `repin` / `fmt` / `ocamlformat`). Only **6 of 114** subjects match any maintenance keyword, and all six are substantive: #2482 (a new blocking check), #2481 (a CI cap fix), #2435, #2397 (the −40.91pp revert), #2401, #2392 (a golden A/B *measurement*). Two softer signals:
  - **harness — soft flag, 5th consecutive week, and the defect-to-fix cycle has tightened from 4 days to 1.** #2430 added the `sexp.default` drift linter on 08-20; #2462 fixed it "passing vacuously" on 08-21; #2464 fixed the CP4 residual in *that* fix the same day — and the index header records that #2462's own behavioral review found **the same disease surviving inside its own fix** (`| exception _ -> ()` still dropping 300 of 820 files silently at exit 0), with #2462 merged **44 seconds** after the NEEDS_REWORK. Separately, the QC gate reader took **six** PRs in four days (#2419, #2420, #2421, #2424, #2425, #2456 — the last one alone rewriting 500 of `pr_gate_status.sh`'s lines). Same shape flagged for `tracked_artifact_linter` last week and `write_audit.sh` the week before, now on a third component. 22 of 114 merges went here. The track also holds **25 of the repo's 64** open `- [ ]` items. recommend: KEEP_AS_INFO — but this is the third component in three weeks where the *suite*, not the individual bug, is the real unit of work.
  - **resistance-v2** — the promotion it existed to produce shipped (#2047) and its record was honestly re-pinned (#2170). What remains is one open evidence caveat (P7) plus a default-off lever-b softener. 5th ask on whether it drops to axis-maintenance.
- **Explicitly NOT a diminishing-returns flag: `cleanup`.** Volume fell 13 → 1 this week exactly as #2312 predicted when it recorded that every remaining row on the seeded RETIRE list fails Rule 4 eligibility. Its single PR (#2461) reconciled a doc-inventory drift *and filed the recurrence* as a linter proposal rather than re-pinning by hand a third time. That is the correct response to an exhausted seam.

## Capability gaps (P7)
- **The weekly live-picks run is still not on a weekly cadence — 3rd week, partially improved.** `dev/weekly-picks/` newest record is `f88c277d5/` = **2026-08-14**, committed 08-18 (#2377) — four days late. **2026-08-07 was never produced at all**, and **2026-08-21 has not landed** as of today (08-23). That is two misses and one late delivery in the last three Fridays; the newest record is 9 days old. Improvement over last week (08-14 did eventually run, and #2452 regenerated picks against the arc bundle at that as-of date), but the *cadence* — which is the M6.6 capability — still is not running. A verification harness that does not run weekly is not a verification harness. recommend: ESCALATE_TO_MAINTAINER.
- **Silent orchestrator slots persist, 3rd week, now in both directions.** Across 2026-08-16…08-22: **13 budget records** (14 expected at 2 slots/day) totalling **$471.65**, against **9** `dev/daily/` summaries. Mapping run ids to summaries:
  - **5 slots spent $53.05 and wrote no summary** — `31947128499` (08-16 PM, $8.86), `32136982845` (08-18 PM, $7.18), `32252817153` (08-19 PM, $8.75), `32559670185` (08-22 AM, $16.68), `32573037249` (08-22 PM, $11.58). Every one self-describes in its own JSON as covering "entire orchestrator run including all internally-spawned subagents", so these are orchestrator runs, not another workflow.
  - **1 slot wrote a summary but NO budget record** — `32344313210` (08-20 AM, `dev/daily/2026-08-20.md`). This is the **mirror image** of the tracked failure and is not covered by `A-NOOP-BUDGET-ORPHAN`'s framing at all.
  - Note the shape: the missing-summary slots are all **cheap** ($7–17) while every slot that wrote a summary cost **$40–62**. That correlation is a diagnostic lead, not noise — it suggests the cheap slots are terminating early rather than working silently. recommend: ESCALATE_TO_MAINTAINER — re-scope `A-NOOP-BUDGET-ORPHAN` to cover both directions, and chase the cost correlation.
- **The promoted bundle's relative margin has still not been re-certified on the honest basis — carried, 4th week.** `dev/backtest/DEEP_RESULTS.md:45` still reads verbatim: the re-pin "records the honest level of the promoted config, not a re-certification of the promotion decision". The file has not been touched since 2026-07-29 (#2170). The bundle is **default-on since #2047** and the basis it was promoted on was shown to flatter results by −322pp return / +6.8pp MaxDD (#2156). Under `promotion-confirmation.md` this is a live default whose justifying evidence is uncertified. Scoped at ~7–8h of grid time. recommend: ESCALATE_TO_MAINTAINER — spend the grid or record the caveat as knowingly accepted.
- **EODHD data access absent in the GHA orchestrator environment — carried, 7th week; still the dominant systemic blocker.** **22 of 28** non-MERGED index rows carry a next-task marked data-gated, LOCAL, human-gated or maintainer-gated. Every decisive experimental result this week (#2433, #2436, #2438, #2448, #2459, #2473) was produced LOCAL. This single gap explains most of the stalled bucket. Milestone impact: M6 + M7. recommend: ESCALATE_TO_MAINTAINER — provision the key, or formally re-scope the orchestrator to build/plan-only for the WF-CV tracks so their stall stops being reported as a pace problem.
- **`tuning` M2 qNEHVI blocked on a maintainer enable-commit (#1327)** — **88 days** on a one-line human action, on the M7 critical path. recommend: ESCALATE_TO_MAINTAINER. (Carryover, 7th week.)
- **`sweep-perf` manual ghcr.io flambda rebuild** — the only remaining human step; until it happens, `-O3` is a **silent no-op in CI** (`sweep-perf.md:41-42`). Substantive work stopped **71 days** behind it. recommend: ESCALATE_TO_MAINTAINER. (Carryover, 6th week.)
- **`workflow`-scoped PAT still blocking six `orchestrator-automation` items (#1636)** — per `orchestrator-automation.md:1051-1053`, "six filed defects now share that one blocker", including `A-GIT-SAFE-DIRECTORY` and `H-BLAS`. One credential action unblocks six. recommend: ESCALATE_TO_MAINTAINER. (Carryover.)
- **Follow-up accumulation: 64 open `- [ ]` items across status files — UP from 58.** Deep-scan threshold is 10. `harness` holds **25** (down from 30 — real progress), `trade-audit` **9** (up from 3), `cleanup` 7, `orchestrator-automation` 6, `tuning-methods` 4, `arc-readiness` 4 (new), `all-eligible` 3. The net rise is driven by two tracks opening new checklists faster than harness closed its own. recommend: KEEP_AS_INFO.
- **`cleanup`'s top open item is a human policy decision, not agent work — carried.** `linter_coverage`: `linter_file_length.sh` scopes to `*/lib/*.{ml,mli}`, so **test files are entirely exempt**. Measured 2026-08-13: of **401** `*/test/*.ml` files, **154 exceed 300 lines and 70 exceed 500**; largest is `test_screener.ml` at **2,687 lines**. The item has been correctly left un-dispatched pending a policy call (what limit, if any, applies to test files). It cannot clear itself. recommend: ESCALATE_TO_MAINTAINER — decide the policy or close the item as WONTFIX.

## Recommendations
1. **Run the 2026-08-21 weekly picks, and decide who owns the cadence.** 08-07 never ran, 08-14 ran four days late, 08-21 has not run; newest record is 9 days old. Either wire the cadence to something that fires without a human, or explicitly de-scope M6.6's weekly cadence. 3rd ask — and it is now the only *recurring operational* failure left after the ops-PR and orchestrator-hold fixes landed.
2. **Fix the silent orchestrator slot, and note it now fails in both directions.** 5 of 13 slots spent $53.05 with no `dev/daily/` output; one slot (08-20 AM, `32344313210`) wrote a summary with no budget record. Re-scope `A-NOOP-BUDGET-ORPHAN` to cover spend-without-summary **and** summary-without-spend. The $7–17 vs $40–62 cost split between silent and reporting slots is the diagnostic lead to start from. 3rd ask.
3. **Unblock the three one-action human gates**: `tuning` M2 enable-commit (#1327, **88d**, M7 critical path); the `workflow`-scoped PAT (#1636, unblocks six orchestrator items including the silent-slot automation); the manual ghcr.io flambda rebuild for `sweep-perf` (**71d**, without which `-O3` is a silent no-op in CI). None of these is agent-dispatchable.
4. **Decide the EODHD-in-GHA question.** 22 of 28 non-MERGED rows are data/LOCAL/human-gated and every decisive result this week was produced LOCAL. Provision the key, or formally mark the WF-CV tracks build/plan-only so their stall stops being reported as a pace problem. 7th ask.
5. **Decide the bundle-vs-alternatives honest-margin grid** (~7–8h). A default-on promotion (#2047) rests on evidence measured on a basis since shown inflated by −322pp / +6.8pp, and `DEEP_RESULTS.md` says so in its own text. Spend the grid or record the caveat as knowingly accepted. 4th ask.
6. **Finish the four outstanding status reconciles**: `screener` (4 `PR OPEN` markers, all merged; 4th ask), `simulation` (`## Next Steps` still the May "Future slices" list; 4th ask), `stage-accuracy` (78 days, first Next Step self-marked DONE; 7th ask), `backtest-perf` (its `## Next steps` exists but items 1–3 are April-2026 `(DONE)` entries). Also refresh `arc-readiness` on next touch — A3-2/A3-3/#2433 all closed after it was written.
7. **Close the finished tracks** — `decline-character` (self-declared exhausted #1739, **8th ask**), `rename-twin-dedup` (index says "next: none"), and decide whether `resistance-v2` drops to axis-maintenance (5th ask). Also fold `backtest-perf` into `backtest-infra` or give it a live owner boundary — six weeks of drift.
8. **Decide the `linter_coverage` test-file policy.** 154 of 401 test files exceed the lib soft limit, 70 exceed the hard limit, the largest is 2,687 lines. `cleanup` has correctly refused to dispatch against it for weeks because it is a policy question. Set a limit, declare the exemption intentional in the script header, or close it WONTFIX.
9. **Consider whether the check/linter suite is the unit of work, not its bugs — 3rd component in 3 weeks.** The `sexp.default` drift linter needed two corrective PRs within 24 hours of shipping (#2430 → #2462 → #2464), and #2462's own behavioral review found the identical silent-swallow defect inside the fix. The QC gate reader took six PRs in four days. 22 of 114 merges went to `harness`, which also holds 25 of 64 open follow-ups.
10. **Note what worked, so it is repeated.** #2480 (orchestrator honours holds) + #2456 (gate reader holds on conflicting verdicts) + the clean `ops(budget)` week are three fixes to *the process that merges code*, and all three closed recurring findings. Both `do-not-merge` holds this week resolved by human decision on the merits (#2433 after its headline was retracted; #2456 after the `unclear` call). The governance layer is now working; the remaining queue is decisions, not mechanisms.

## Stats
- **114 PRs merged in last 7d** (18 `ops:`/`ops(budget)`, 39 `docs:`, 20 harness, 12 `feat(`, 12 `fix(`, 9 `experiments(`, 4 `test(`, 2 `rules:`, 1 `cleanup`) — **up from 94; a program record**
- **376 PRs merged in last 30d** — up from 326
- 9 tracks active / 7 slowing / 11 stalled-IN_PROGRESS (+1 PENDING parked) out of 28 non-MERGED rows
- 0 `[info]` items carried ≥3 reconciles (**9th consecutive week**; the index carries no `[info]` list to age)
- 13 of 14 expected orchestrator cron slots wrote budget records, totalling **$471.65**; **9** daily summaries written → **5 slots spent $53.05 with no output**, and **1 slot (08-20 AM) wrote a summary with no budget record**
- **0** `ops(budget)` PRs auto-merged production code past the QC gates (was 3 consecutive weeks: #2224, #2235, #2309) — **all five this week are single-file `dev/budget/*.json` diffs**
- 1 of the last 3 Friday picks runs delivered on time; 08-07 missed entirely, 08-14 four days late, **08-21 not yet landed**; newest `dev/weekly-picks/` record is **9 days** old
- Weekly deep health scan ran on cadence (2026-08-17, 6 days old) — last week's skipped cycle did not recur
- **64** open `- [ ]` follow-up items across status files (up from 58; `harness` 25 — down from 30, `trade-audit` 9 — up from 3)
- 2 `do-not-merge` holds resolved this week, both by human decision on the merits (#2433 after retraction, #2456 after the `unclear` call) — first observed end-to-end success of the hold mechanism
- 1 new track created (`arc-readiness`, 2026-08-20, owned on creation), absorbing the entry-ticket / fill-model program that had no index row for 3 weeks
- 8 capability-gap bottlenecks flagged: 1 new (orchestrator summary-without-budget-record, the inverse failure), 2 improved-but-open (picks cadence, follow-up count), 5 carried (uncertified bundle margin 4th week, EODHD-in-GHA 7th week, tuning M2 #1327 7th week, sweep-perf ghcr.io 6th week, workflow-PAT #1636)
- 5 status-file reconciles outstanding (`screener` 4th ask, `simulation` 4th ask, `stage-accuracy` 7th ask, `backtest-perf` 6th week, `arc-readiness` new); `_index.md` header 30 PRs behind and lists 2 merged PRs as open
- **4 of last week's 10 recommendations resolved** (#1 ops-PR QC bypass, #4 deep health scan cadence, #5 entry-ticket program index row, plus the carried orchestrator draft/label-hold spec gap), 1 partial (#2 picks cadence) — up from 1 of 10. Every remaining item requires a maintainer decision, not an agent dispatch.
