# Track Pacer Report — 2026-08-09

## Summary
- Tracks audited: 49 index rows (26 IN_PROGRESS + 1 PENDING = 27 non-MERGED; 22 MERGED). Cadence run on the 26 IN_PROGRESS rows.
- Active (≥1 PR last 7d): 13
- Slowing (7–30d since last PR): 5
- Stalled (>30d): 8 IN_PROGRESS + 1 PENDING parked
- `[info]` items needing decision: 0
- Capability gaps flagged: 9 (2 new/severe, 1 new-form recurrence, 6 carried)

Headline: **the loop recovered — and immediately produced the highest-throughput
week of the program.** Last week's #1 finding (four orchestrator runs at
`$0.0000` with zero output) is fully closed: all **14** cron slots between
2026-08-02 and 2026-08-08 produced budget records with real spend (~$412.41
total), `#2180` landed the `A-FASTEXIT-VACUOUS` fix and `#2195` closed the
no-op budget-orphan path. The two branches idle since 07-29 — `#2169`
(`harness/audit-atomic-write`) and `#2166` (`cleanup/adjusted-basis-sync-pin`)
— both merged on 08-03. **67 PRs merged this week** against zero the week
before.

The week's dominant work was the **entry fill-model / E-anchored entry arc**
(`#2158`): ~22 PRs across `simulation`, `screener`, `trade-audit` and the
experiment ledger, including the `#2216` honest-ladder finding that the
designed rule earns +965%, the `#2208` correction reframing the trigger, and
the `#2237` confound resolution (the stop-distance metric artifact was
E-basis, not a gate defect). It has **no index row** (see P4).

Two severe findings, both governance rather than pace:

1. **The `ops(budget)` auto-merge sweep-in recurred.** `#2235`
   (`ops(budget): record 2026-08-07-31178553959`) carried **300 lines of
   production OCaml** — `trade_audit_report.{ml,mli}` + 206 lines of tests,
   the support-floor-stops F6 report row — into `main` on an auto-merged ops
   PR that bypassed **both** QC gates. This is the second occurrence
   (`#2224` on 08-06 swept in `segmentation_test.ml` + a dune change). The
   index header confirms the recurrence; nothing is dispatched against it.
2. **The Friday 2026-08-07 live picks run did not happen.** It was the
   explicit P0 of `dev/notes/next-session-priorities-2026-08-04.md`. The
   newest record in `dev/weekly-picks/` is 2026-07-31 (`3e10a92c7/`, `#2192`).
   Second missed Friday in three weeks, on the M6.6 critical path.

## Active tracks (≥1 PR last 7d)
- **harness** — 7 PRs (#2169 atomic `write_audit.sh`, #2184 skip unparseable prior records, #2199 restore 0644 mode, #2211 chmod-before-rename ordering, #2221 audit hooks require explicit `=1`, #2231 disable-count decoupling + REPO_ROOT precedence, #2243 REPO_ROOT override in `record_qc_audit.sh`); theme: **the audit-record writer** — 5 of 7 PRs fix `write_audit.sh` / `record_qc_audit.sh`. See P6.
- **support-floor-stops** — 5 PRs (#2181 split-safe floors + `stop_recompute` anchor-mode fix, #2213 split-safe floors on the panel/callback path, #2220 F5 three-way basis tag, #2232 B5/B6 `Empty_window` + inert-fraction naming, #2239 `%`-absence pin on the not-exercised state); theme: **making the split-safe fallback observable** — every PR adds telemetry that distinguishes "measured zero" from "never exercised". Hottest feature track; 4 QC rework iterations absorbed across #2213/#2220.
- **weekly-snapshot** — 5 PRs (#2179 07-31 record, #2182 #2122 slices b/c/d, #2189 sector column + score breakdown + HTML hover explainers, #2192 07-31 v2 enriched record, #2197 Extended-branch chase-weakness pin); theme: report enrichment on bit-identical picks.
- **simulation** — 4 PRs (#2202 StopLimit entry fills default-off, #2209 `sim_entry_trigger_at_suggested`, #2219 stop re-anchors to entry base, #2238 `sim_entry_fill_next_open`); theme: **the entry-execution ladder** — four default-off flags, each an R2 axis.
- **trade-audit** — 4 PRs (#2196 render external exits, #2210 execution-faithfulness capture, #2212 surface it in `trade_audit_report`, #2242 fill-basis `stop_fill_distance_pct` column); theme: designed-order-vs-realised-fill forensics.
- **backtest-infra** — 2 PRs (#2188 `Fold_health` emission from `backtest_runner` (#1557 item 1), #2230 faithfulness/sensibility evaluation harness).
- **screener** — 2 PRs (#2217 local-range entry anchor default-off, #2241 `freeze_entry_at_first_breakout` no-chase entry E).
- **cleanup** (code-health) — 2 PRs (#2166 adjusted-basis rescale sync pin, #2200 retired **both** stale `magic_numbers` linter exceptions rather than re-dating them). Volume down from 8, but composition improved — last week's rec #9 partially actioned.
- **orchestrator-automation** — 2 PRs (#2180 `A-FASTEXIT-VACUOUS` fix — Step 0.5 fast-exit now requires a non-empty queue; #2195 open+auto-merge budget fallback, closing the #1572 no-op orphan path). The two fixes that produced this week's recovery.
- **post-run-validation** — 1 PR (#2236 V12 stop-distance gate-consistency invariant). First activity in 25 days.
- **margin-realism** — 1 PR (#2196, shared with `trade-audit`); closes the #2076 report-layer remainder the index row had carried as open.
- **data-foundations** — 1 PR (#2191 arm live rename detection, #2083 fix-2 remainder, dry-run clean: 0 false positives over the full universe).
- **rename-twin-dedup** — shares #2191 (returns-basis succession from #1946, applied live).

_(MERGED-labelled tracks that shipped work this week, so they do not appear in the cadence buckets: **walk-forward-cv** — #2194 exit-timing deep-spec window migration 2000→1998, #2205 sim-entry-stoplimit surface REJECT.)_

_(Not attributable to any index row: ~10 experiment/docs PRs of the `#2158` fill-model arc — #2205, #2206, #2208, #2216, #2218, #2223, #2225, #2226, #2227, #2237, #2245. See P4.)_

## Slowing tracks (7–30d since last PR)
- **resistance-v2** — last PR #2170 was 11 days ago (2026-07-29, R3 record re-pin); theme: the promotion shipped (#2047) and the record was re-pinned honestly. Remaining: WF-CV vs w30 (data-gated) + a lever-b axis. recommendation: KEEP_AS_INFO (but see P6 — 3rd ask on dropping to axis-maintenance).
- **short-side-strategy** — last PR #2081 was 14 days ago (2026-07-26, robust dollar-ADV); next is a short-leg regime-P&L decomposition marked LOCAL. recommendation: KEEP_AS_INFO.
- **backtest-perf** — last own-track PR #2024 was 20 days ago (2026-07-20); status file last updated 2026-06-16 (54 days) while its subject matter continues shipping under other tracks. recommendation: KEEP_AS_INFO (ownership has migrated; see P2).
- **extension-stop** — last PR #1960 was 27 days ago (2026-07-13); only a default flip remains, human-gated on a further insurance-basis ACCEPT (R3). recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 was **30 days ago** (2026-07-10) — at the top of the band and tipping into stalled next week; P1b step 3 (lens screen vs TR-SPY) is deep-warehouse maintainer-LOCAL. recommendation: KEEP_AS_INFO.

## Stalled tracks (>30d since last PR)
- **stage-accuracy** — last PR #1864 at 2026-07-06 (34 days); reason: a rejection streak, not churn — the file points at breadth as the remaining lever and the broad-universe WF-CV re-run is data-gated. Status file untouched since 2026-06-06 (see P2). recommendation: ESCALATE_TO_MAINTAINER (status refresh, 5th ask).
- **decline-character** — last PR #1740 at 2026-06-24 (46 days); reason: track **self-declares "WORKSTREAM EXHAUSTED (2026-06-25, #1739)"**; all mechanisms parked as default-off axes. recommendation: ESCALATE_TO_MAINTAINER (mark closed — 6th consecutive ask).
- **rolling-start-lens** — last own PR #1645/#1648 at 2026-06-18 (52 days); reason: next steps self-tagged deep-warehouse maintainer-LOCAL / `[blocking: by warehouse build]`. recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (56 days); reason: NS1 shipped and flipped ON, NS2 impl human-gated, NS4 DD-validation data-gated. Adjacent movement only: #2188 landed `#1557` item 1 and confirmed items 2/3 were already merged as #1575/#1567/#1582. recommendation: KEEP_AS_INFO.
- **sweep-perf** — last substantive PR #1574 at 2026-06-13 (57 days); reason: the only remaining step is the **manual ghcr.io flambda rebuild**, a human action. recommendation: ESCALATE_TO_MAINTAINER (4th ask).
- **spy-only-reference** — last PR #1438 at 2026-06-03 (67 days); reason: next is explicitly a human session (sector-rotation testbed, top-1000 bankability gate, long-short verification). recommendation: KEEP_AS_INFO.
- **experiment-platform** — last own PR #1372 at 2026-05-29 (72 days); reason: the platform is in continuous use — every default-off flag shipped this week (#2202/#2209/#2217/#2219/#2238/#2241) is an `experiment-flag-discipline` R2 axis routed through it — but the code track's single-dial surface is exhausted. recommendation: KEEP_AS_INFO (steady-state infra, not a real stall).
- **tuning** — last PR #1333 at 2026-05-27 (74 days); reason: M1 complete 5/5; **M2 qNEHVI still awaiting a maintainer enable-commit per #1327**. On the M7 critical path. recommendation: ESCALATE_TO_MAINTAINER (5th ask).
- **tuning-methods** (PENDING) — parked since 2026-05-24 (77 days); Step 0 done, steps 1–3 demoted, component-decomposition objective queued but never dispatched. recommendation: KEEP_AS_INFO.

## Next Steps staleness (P2)
- **trade-audit** — WORSENED. `## Status` still reads `MERGED` and `## Last updated: 2026-07-27` while the track shipped **four PRs since** (#2196, #2210, #2212, #2242) and `_index.md` lists it IN_PROGRESS with a live next task ("position_id join is date-proximity derived and suspect for forensics"). Flagged 2026-07-26 and 08-02; not actioned. ESCALATE_TO_MAINTAINER (3rd ask).
- **stage-accuracy** — `## Last updated: 2026-06-06` (64 days). First `## Next Steps` item is self-marked "**DONE 2026-06-06: REJECTED**". Flagged 07-12, 07-19, 07-26, 08-02. ESCALATE_TO_MAINTAINER (5th ask).
- **simulation** — header is current (2026-08-07) with detailed entries for #2238/#2219/#2209, but `## Next Steps` (line 489) is still the May "### Future slices" list whose second item is struck through as DONE via the `walk-forward-cv` track. The entry-ladder queue that four of this week's PRs advanced appears nowhere in it. KEEP_AS_INFO → ESCALATE_TO_MAINTAINER (2nd ask, half-done refresh).
- **screener** — PARTIALLY RESOLVED. `## Status` is now `IN_PROGRESS` and the header is 2026-08-06 (last week's ask, actioned). But the narrative body still carries **four** "PR OPEN" claims for PRs merged 07-13…07-26 (#2087, the ranked-mode arming PR, #1952, the #1782 Phase-1 PR). KEEP_AS_INFO.
- **backtest-infra** — `## Next Steps` item 1 still defers Step 3 to `backtest-scale.md` and item 2 names "the Tiered loader flip" as a prerequisite; `backtest-scale` has been **MERGED** for months and the index says "next: none queued". Carried from 08-02. KEEP_AS_INFO.
- **backtest-perf / rolling-start-lens** — files last updated 2026-06-16 / 2026-06-15 (54 / 55 days). Carried for four weeks; the ownership boundary has drifted the whole time. KEEP_AS_INFO.
- **`_index.md` header** — much improved: `Last updated: 2026-08-08 run1`, with only three same-day PRs merged after it (#2242, #2244, #2245). Last week this was 4 days and 9 PRs behind. No escalation.
- **RESOLVED since 2026-08-02:** `support-floor-stops` — the P4/P2 finding is fully closed. `## Status` is now `IN_PROGRESS`, `## Last updated: 2026-08-08`, `## Ownership` names `feat-weinstein`, and the index row carries a live next task ("F11+F12+R3 test-hardening bundle, then F3").
- **Pattern note (carried):** on 7+ tracks the first `## Next Steps` entry is a struck-through or DONE-marked completed item. This is a formatting convention, not a defect — but the P2 "first item" heuristic still cannot be read mechanically on this repo.

## `[info]` items needing decision (P3)
- **None.** `dev/status/_index.md` carries **0** `[info]`-tagged items. The header block is a single-run reconcile narrative with no carried-forward `[info]` list, so there is nothing to age. Seventh consecutive week with the same structural answer.

## Tracks without owner (P4)
- **No IN_PROGRESS or READY_FOR_REVIEW row is missing an owner**, and no new track rows were created in the last 14 days. Last week's sole hit (`support-floor-stops`) is resolved.
- **NEW — the entry fill-model / execution program has no index row.** ~22 of this week's 67 merges belong to the `#2158` arc: the StopLimit/next-open/E-anchored flag ladder (#2202, #2209, #2219, #2238, #2241), the entry anchor (#2217), the execution-faithfulness audit (#2210, #2212, #2230, #2236, #2242), and the experiment/docs spine (#2205, #2206, #2208, #2216, #2218, #2223, #2225, #2226, #2227, #2237, #2245). It is the largest single workstream in the repo and its state is split across three index rows (`screener`, `simulation`, `trade-audit`), each of whose "next task" cell describes only its own slice. The `#2245` plan ("entry-ticket right-basis") is the program's actual next step and appears on no row. recommend: RECOMMEND_NEW_TRACK (or name one of the three rows the program owner) — this is the same shape as the weekly-picks observation carried in July, which resolved once all its PRs wrote to one status file.

## Recurring discussion topics (P5)
- **None from the P5 scan surface.** `dev/decisions.md` has **no entries in the last 30 days** — the newest is 2026-05-16 (the Norgate→EODHD/IWV vendor pivot), 85 days old. Standing observation, now carried for the **6th week**: `dev/decisions.md` has effectively been retired as the human→agent decision channel in favour of `dev/notes/next-session-priorities-*.md` handoffs, the experiment ledger (`dev/experiments/_ledger/`), and the daily orchestrator summaries — none of which P5 scans. Re-pointing the check is a human decision. KEEP_AS_INFO.

## Diminishing returns (P6)
- **No track trips the strict heuristic** (≥3 of the last 5 PRs matching `chore` / `fix(linter)` / `golden` / `repin` / `fmt` / `ocamlformat`). Only 3 of 67 subjects match any maintenance keyword at all. Three softer signals:
  - **harness** — soft flag, 3rd consecutive week, and now narrower. All 7 PRs are meta-work on the check suite, and **5 of 7 touch the same two scripts** (`write_audit.sh`, `record_qc_audit.sh`): atomic write (#2169), unparseable-record tolerance (#2184), 0644 mode (#2199), chmod-before-rename ordering (#2211), REPO_ROOT precedence (#2231 and again #2243). Each fix was real, but a writer that needed six corrective PRs in twelve days is a rewrite candidate, not a patch queue — and 33 open `- [ ]` items remain on the track (half the repo's total). recommend: KEEP_AS_INFO, but worth deciding whether the audit recorder gets a single clean-slate PR.
  - **decline-character** — self-declares exhausted (#1739); 6th consecutive week recommending closure.
  - **resistance-v2** — the promotion it existed to produce shipped (#2047) and its record was honestly re-pinned (#2170). What remains is one open evidence caveat (P7) plus a default-off lever-b softener. 3rd ask on whether it drops to axis-maintenance.
- **Improved:** last week's `cleanup` soft flag (8/8 docs-only PRs) is partially resolved — #2200 retired two stale `magic_numbers` linter exceptions outright rather than re-dating them, which is exactly the `code-health-discipline.md` behaviour the flag asked for.

## Capability gaps (P7)
- **`ops(budget)` PRs auto-merge production code past both QC gates — NEW, severe, and a confirmed recurrence.** `#2235` (2026-08-07) is titled `ops(budget): record 2026-08-07-31178553959 ($21.3693)` and its diff contains `trading/backtest/.../trade_audit_report.ml` (+63), `.mli` (+31) and `test_trade_audit_report.ml` (+206) — the support-floor-stops F6 split-safe report row — plus 110 lines of status file. It merged as an ops PR, i.e. with neither qc-structural nor qc-behavioral run on 300 lines of production OCaml. This is the second instance: `#2224` (2026-08-06) swept in `segmentation_test.ml` + a dune edit, which is how the `cleanup` F2 `default_params` pin reached main un-gated and left `#2228` as a zero-byte no-op. `.claude/rules/pr-merge-gates.md` allows a skip only for docs-only diffs; neither PR qualifies. The index header confirms the recurrence was noticed on 08-08 and nothing is dispatched against it. Milestone impact: all tracks (it is the merge gate itself). recommend: **ESCALATE_TO_MAINTAINER — highest priority this week.**
- **The 2026-08-07 Friday live picks run did not happen — NEW, on the M6.6 critical path.** It was the explicit P0 of `next-session-priorities-2026-08-04.md`, with the recipe pinned and three enhancements ready (report improvements #2189, rename warnings #2191, the option to arm `split_safe_floors`). `dev/weekly-picks/` newest record is 2026-07-31 (`3e10a92c7/`, `#2192`). Second missed Friday in three weeks; the 07-31 miss was recovered two days late on 08-02. recommend: ESCALATE_TO_MAINTAINER.
- **Orchestrator slots that spend money and produce no summary — NEW form of a carried gap.** The `$0.0000` failure mode is fixed (#2180/#2195), but 14 slots ran this week and only **9** `dev/daily/` summaries exist. The index header documents one such slot precisely: the 08-08 07:35Z run "spent $11.97 and wrote no summary", leaving `#2239` unreviewed for the next run to pick up. At 2 slots/day a silent slot is a 12-hour delay. `A-NOOP-BUDGET-ORPHAN` is filed on `orchestrator-automation` but describes the old $0.00 shape. recommend: ESCALATE_TO_MAINTAINER.
- **The promoted bundle's relative margin has still not been re-certified on the honest basis — carried, 2nd week.** `dev/backtest/DEEP_RESULTS.md:44-45` states it verbatim: the re-pin "records the honest level of the promoted config, not a re-certification of the promotion decision". The bundle is **default-on since #2047** and the basis it was promoted on was shown to flatter results by −322pp return / +6.8pp MaxDD (#2156). Under `promotion-confirmation.md` this is a live default whose justifying evidence is uncertified. Scoped at ~7–8h of grid time and listed as P1/"user call" in the 08-04 priorities doc. recommend: ESCALATE_TO_MAINTAINER — spend the grid or record the caveat as knowingly accepted.
- **EODHD data access absent in the GHA orchestrator environment** — carried, **5th week**; still the dominant systemic blocker. Data-gated next-tasks on `backtest-perf`, `stage-accuracy`, `experiment-platform`, `cash-floor-correctness` (NS4), `floor-quality`, `post-run-validation`, `tuning`, `rolling-start-lens`, `resistance-v2` (WF-CV vs w30), `short-side-strategy` (LOCAL), `spy-only-reference`. Every one of this week's decisive experiment results (#2216, #2218, #2223, #2237) was generated LOCAL. Milestone impact: M6 + M7. recommend: ESCALATE_TO_MAINTAINER — provision the key, or formally re-scope the orchestrator to build/plan-only for the WF-CV tracks.
- **`tuning` M2 qNEHVI blocked on a maintainer enable-commit (#1327)** — 74 days on a one-line human action, on the M7 critical path. recommend: ESCALATE_TO_MAINTAINER. (Carryover, 5th week.)
- **`sweep-perf` manual ghcr.io flambda rebuild** — the only remaining human step; substantive work stopped 57 days behind it. recommend: ESCALATE_TO_MAINTAINER. (Carryover, 4th week.)
- **`workflow`-scoped PAT still blocking six `orchestrator-automation` items (#1636)** — per the index row, "six items share the `workflow`-token blocker". One credential action unblocks six. recommend: ESCALATE_TO_MAINTAINER. (Carryover.)
- **Follow-up accumulation: 52 open `- [ ]` items across status files** (deep scan 2026-08-03, warning 2; threshold 10) — **down from 76** last week. `harness` alone holds 33 of them. recommend: KEEP_AS_INFO — improving.
- **Resolved since 2026-08-02:** the orchestrator no-op loop (14/14 slots with real spend; #2180 + #2195 shipped) — last week's #1, closed. The two branches idle since 07-29 (#2169, #2166) — merged 08-03. The missed 07-31 live picks run — executed 08-02 (#2179) and enriched (#2192). `support-floor-stops` ownership + status — restored. `screener` status keyword — fixed. `margin-realism` #2076 — closed via #2196.

## Recommendations
1. **Stop `ops(budget)` PRs from carrying non-ops content.** `#2235` auto-merged 300 lines of production OCaml past both QC gates; `#2224` did the same the day before. Add a path allowlist to the budget-PR auto-merge path (ops PRs may touch `dev/budget/` and nothing else) or drop the auto-merge. This is the merge gate itself failing twice in three days, and it is already noticed-but-undispatched in the 08-08 index header.
2. **Run the 2026-08-07 weekly picks cycle.** It was P0 in the 08-04 priorities doc with the recipe pinned; the newest record is 07-31. Second miss in three weeks on the M6.6 path — the cadence is the capability.
3. **Give the `#2158` entry fill-model program an index row.** ~22 of 67 merges this week, split across three rows, with its actual next step (the `#2245` entry-ticket right-basis plan) named on none of them. Either create the row or designate one of `screener`/`simulation`/`trade-audit` as the program owner.
4. **Fix the silent orchestrator slot.** 14 slots ran, 9 summaries were written; the 08-08 07:35Z run spent $11.97, wrote nothing, and left `#2239` for the next run. Re-scope `A-NOOP-BUDGET-ORPHAN` (which describes the now-fixed $0.00 shape) to cover spend-without-output.
5. **Decide the bundle-vs-alternatives honest-margin grid** (~7–8h). A default-on promotion (#2047) rests on evidence measured on a basis since shown inflated by −322pp / +6.8pp. Spend the grid or record the caveat as accepted in `DEEP_RESULTS.md`; leaving it open is the weakest of the three options. (2nd ask.)
6. **Finish the three outstanding status reconciles**: `trade-audit` (`## Status: MERGED` while four PRs shipped to it this week — 3rd ask), `stage-accuracy` (64 days, first Next Step self-marked DONE — 5th ask), `simulation` (`## Next Steps` still the May "Future slices" list — 2nd ask). Also `screener`'s four stale "PR OPEN" narrative claims.
7. **Decide the EODHD-in-GHA question** — provision the key, or formally mark the WF-CV tracks build/plan-only. Eleven rows are data-gated and every decisive result this week was produced LOCAL. (5th ask.)
8. **Unblock the three one-action human gates**: `tuning` M2 enable-commit (#1327, 74d, M7 critical path); the `workflow`-scoped PAT (#1636, unblocks six orchestrator items at once); the manual ghcr.io flambda rebuild for `sweep-perf` (57d).
9. **Close the finished tracks** — `decline-character` (self-declared exhausted, 6th ask), `rename-twin-dedup` (index says "next: none"), and decide whether `resistance-v2` drops to axis-maintenance (3rd ask).
10. **Consider a clean-slate rewrite of the audit recorder.** `write_audit.sh` / `record_qc_audit.sh` took six corrective PRs in twelve days (#2169, #2184, #2199, #2211, #2231, #2243), each fixing a distinct latent defect in the same two files. The defect rate suggests the script, not the individual bugs, is the unit of work.

## Stats
- **67 PRs merged in last 7d** (9 `ops: daily orchestrator summary`, 18 `ops:` total, 38 substantive feat/fix/test/cleanup/harness/experiment/correction, 11 docs) — recovered from **0** the prior week
- **307 PRs merged in last 30d** (92 ops daily summaries, 129 substantive)
- 13 tracks active / 5 slowing / 8 stalled-IN_PROGRESS (+1 PENDING parked); 1 MERGED-labelled track also shipped work
- 0 `[info]` items carried ≥3 reconciles (7th consecutive week; the index carries no `[info]` list to age)
- 14 of 14 orchestrator cron slots produced budget records with real spend (~$412.41 total); **9** daily summaries written → 5 slots spent money with no output
- 2 `ops(budget)` PRs auto-merged production code past both QC gates in 3 days (#2224, #2235)
- 52 open `- [ ]` follow-up items across status files (down from 76; `harness` holds 33)
- 9 capability-gap bottlenecks flagged: 2 new-severe (ops-PR QC bypass, missed 08-07 live run), 1 new-form (silent orchestrator slot), 6 carried (uncertified bundle margin 2nd week, EODHD-in-GHA 5th week, tuning M2 #1327 5th week, sweep-perf ghcr.io 4th week, workflow-PAT #1636, follow-up accumulation)
- 4 status-file reconciles outstanding (`trade-audit` 3rd ask, `stage-accuracy` 5th ask, `simulation` 2nd ask, `screener` narrative claims); `_index.md` header current to within 3 same-day PRs
- **6 of last week's 9 recommendations fully or partially resolved** (orchestrator loop recovery, the two stranded branches, the missed 07-31 run, `support-floor-stops` ownership, `_index.md` reconcile, `cleanup` feeder composition)
