# Status Index

Single-source view of all tracked work. Detail belongs in the per-track
status files linked in column 1. Keep every "Next task" cell to one line
(<=160 chars); the `index_size_linter.sh` CI check enforces this.

Last updated: 2026-08-09 run2 (orchestrator run 31313381717 -- main green `a09b4ad3` -> `0d8b7c9f`). Queue was again **EMPTY** (0 open orchestrator PRs), so Step 0.5's non-empty-queue precondition forced a full pass. Shipped **2 merges through all three gates, 1 rework each**: **#2251** (support-floor-stops F3 -- adjusted price basis for the trade-audit R6 ratings; qc-behavioral caught that the PR's *other* call-site change was a **regression**, because `Html_report._utilization` multiplies the mark by a **raw** share count against a **raw** NAV, measured KO -27.5% / JNJ -24.0% / AAPL -77.9%; PR narrowed to the correct half, benchmark half deferred to G4) and **#2252** (harness `tracked_artifact_linter`, the class fix for #2248, keyed on `git ls-files -i -c --exclude-standard` under default-deny). **#2252 exposed a standing trap: any devtools check that shells out to `git` passes locally for the wrong reason** -- the orchestrator's own Step 1 `git config --global --add safe.directory` write is inherited by every agent in this shared container, so author + both QC agents saw green while CI failed on `fatal: detected dubious ownership`. Also filed 2 audit-recorder defects found by using the tool (`consecutive_rework_count` blind to reworks; `--harness-gap` dropped on APPROVED). See dev/daily/2026-08-09-run2.md.

Prior (2026-08-09 run1 (orchestrator run 31301600156 -- main green `d696f603` -> `2c84d8c4`). Queue was **EMPTY** (0 open orchestrator PRs; the only open PR was the maintainer's own track-pacer #2246), so Step 0.5's non-empty-queue precondition correctly forced a full pass. Shipped **2 merges through all three gates, 0 reworks**: **#2248** (cleanup -- untracked `trading/compile_commands.json`, a dune output tracked in git that dirtied the tree on every build; churn quantified as exactly 40 bytes = `5.3` -> `5.3.0+flambda` in 4 include paths) and **#2249** (support-floor-stops F11+F12+R3 test hardening; F12 and R3 each closed a gap the old suite was measurably blind to, and F11 was reported as an **honest negative** -- the old suite already caught its mutation via a different assertion). **Found and fixed a bookkeeping defect: `tracked_build_artifact` was never a `## Backlog` item -- it was the illustrative TEMPLATE inside the fenced block under `## How findings get here`, which a bare `grep '^- \[ \]'` matches.** The finding was real, but both the orchestrator's Step 2e scan and #2248's author treated a doc example as live queue. Template restored and annotated. See dev/daily/2026-08-09.md.)

Prior (2026-08-08 run1 (orchestrator run 31257309829 -- main green `d22bd136` -> `813a91e5`). Queue held **one** orchestrator PR (#2239) left unreviewed by the 08-08 07:35Z run, which spent $11.97 and wrote no summary. Shipped **2 merges through all three gates**: #2239 (support-floor-stops, 1 rework -- QC caught a status-file follow-up claiming a mutation "passes all 36" that measured 2 failures, and declaring itself "Closed" on a tightening absent from the diff) and #2243 (harness H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING, 0 reworks). **#2239 arrived behind main with a two-dot diff that would have deleted `entry_freeze.*` (-561 lines, the #2241 feature); rebased before QC.** Confirmed the #2224 ops-PR sweep-in RECURRED as #2235. Settled the open `dune runtest` exit-code question: it DOES exit 1 on a failing test. See dev/daily/2026-08-08.md.)

Prior (2026-08-07 run1 (orchestrator run 31159010863 -- main green at `b54f8880`). Shipped **2 merges through all three gates** (#2231 harness audit-test count + REPO_ROOT precedence, 1 rework; #2232 support-floor-stops B5+B6, 0 reworks) and **recovered a stranded branch**: `cleanup/segmentation-default-params-pin` had been pushed 2026-08-06 with no PR ever opened. Opening it as #2228 revealed a **zero-byte net diff** -- the test code had already reached main inside **#2224, an auto-merged `ops(budget)` PR declaring itself "additive observational data only"**, bypassing both QC gates. #2228 closed as superseded; the review posted there is the gate that content never got (mutation-verified, no revert warranted). See dev/daily/2026-08-07.md.

Prior (2026-08-05 run1, run 30987681815 -- main green `04e2c75b` -> `6cf8773d`). Queue was EMPTY (0 open PRs) so Step 0.5 correctly forced a full pass. Shipped **#2211** (H-AUDIT-MODE-ORDER-UNPINNED: iteration 0's runtime hook was structurally blind to a chmod inserted *between* the `mv` and the hook, so rework added a static source-order check) and **#2213** (split-safe floors on the panel/callback path -- the flag was silently inert on the main multi-symbol strategy path, an `experiment-flag-discipline.md` **R2 defect**; also found `daily_view.closes` was raw while its docstring claimed adjusted).

Prior (2026-08-04 run1, run 30890598574 -- main green `206cea4b` -> `f6333f84`). Queue was non-empty (2 open PRs) so Step 0.5 evaluated the four conditions; Condition 1 FAILED (neither open PR had a review at its tip) -> full pass. A large human burn-down session landed 11 PRs (#2188-#2198). Shipped #2199 (H-AUDIT-MODE-0600 -- `write_audit.sh` was writing records 0600 since #2169 because `mktemp` ignores umask by design and `mv` preserves mode), #2200 (retired BOTH stale `magic_numbers` linter exceptions rather than re-dating them), #2187 (weekly deep scan). Closed #2185 as obsolete.

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [resistance-v2](resistance-v2.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | grid 3/3 ACCEPT w=30; BUNDLE PROMOTED default-on #2047 (R3 human-approved 07-23); next: WF-CV vs w30 (data-gated) + lever-b axis |
| [margin-realism](margin-realism.md) | IN_PROGRESS | dayfine (maintainer LOCAL) + feat-backtest | — | M4 MERGED #2063; #2057 exit labels MERGED #2074; trade_audit half MERGED #2085; #2076 CLOSED (report fallback #2196) |
| [leverage-dawn](leverage-dawn.md) | MERGED | feat-weinstein | — | MERGED default-off #2077 after B1 permissive-funding rework; next: WF-CV surface + promotion-confirmation grid before any R3 flip |
| [capital-management-scale-in](capital-management-scale-in.md) | MERGED | — | — | PROGRAM CLOSED: v1 (#1840) + v2 (#1860) both REJECTED; mechanisms merged default-off, searchable; class exhausted (2026-07-06) |
| [cash-reserve](cash-reserve.md) | MERGED | — | — | CLOSED: mechanism MERGED default-off (#1867); WF-CV surface {0,.1,.2,.3} REJECT (ledger 2026-07-06, #1872); envelope program closed both directions (2026-07-06) |
| [backtest-infra](backtest-infra.md) | IN_PROGRESS | dayfine (maintainer) + feat-backtest | — | LAPACKE fix MERGED `757abdf2` (#2113) — un-redded main; CI hold self-resolved once a merge commit triggered a check-suite; next: none queued |
| [rename-twin-dedup](rename-twin-dedup.md) | IN_PROGRESS | feat-backtest | — | v1(#1940)+v2(#1946) MERGED; dedup warehouse rebuilt + 28y record re-run landed (#1949, 83 groups/91 legs dropped); next: none (optional V6 report-consult tweak) |
| [post-run-validation](post-run-validation.md) | IN_PROGRESS | feat-backtest | — | v1 harness (#1937) + C6b audit-join-by-position_id (#1947) MERGED; next: golden-run integration test for V3/V4/V7 (data-gated) |
| [cash-floor-correctness](cash-floor-correctness.md) | IN_PROGRESS | feat-weinstein | — | NS1 impl+flip ON (#1567/#1582 correctness), NS2 design+NS3 MERGED (#1569/#1575); next: NS2 impl (human-gated), NS4 optional DD-validation (data-gated) |
| [backtest-scale](backtest-scale.md) | MERGED | — | — | — |
| [backtest-perf](backtest-perf.md) | IN_PROGRESS | feat-backtest | — | snapshot-format-v2 S4 PROVEN (warehouses v2, top-3000 fits at cache<=1024); S5/v1-cleanup deferred (oversight); next: regime-diverse lenses on v2 (LOCAL) |
| [rolling-start-lens](rolling-start-lens.md) | IN_PROGRESS | feat-backtest | — | t3k factor-lens matrix SHIPPED LOCAL (#1639 2000-26 H1 r=-0.744; #1642 2011-26 confirm); next: regime-gated deploy proxy validation (LOCAL/data-gated) |
| [barbell-overlay](barbell-overlay.md) | MERGED | — | — | Gate-#2 overlay (#1683) + scenario wiring (#1689) + floor_weight searchable axis (#1697, R2 complete) all MERGED default-off; no remaining follow-ups |
| [sweep-perf](sweep-perf.md) | IN_PROGRESS | harness-maintainer | — | Win #4 production wiring MERGED (#1574, opt-in default-off); next: manual ghcr.io flambda rebuild + enable prune opt-in in sweeps |
| [cost-model](cost-model.md) | MERGED | — | — | — |
| [data-panels](data-panels.md) | MERGED | — | — | — |
| [hybrid-tier](hybrid-tier.md) | MERGED | — | — | — |
| [trade-audit](trade-audit.md) | IN_PROGRESS | feat-backtest | — | #2115 fixed the trades.csv duplicate/phantom rows; #2076 CLOSED (report fallback #2196); next: position_id join is date-proximity derived and suspect for forensics |
| [decision-audit](decision-audit.md) | MERGED | feat-backtest | — | #1799/#1806/#1811 MERGED (report+counterfactual+weekly-picks adapter); selection FAITHFUL; live-picks pipeline ready (#1812); next: matured weekly counterfactual |
| [optimal-strategy](optimal-strategy.md) | MERGED | — | — | — |
| [all-eligible](all-eligible.md) | MERGED | — | — | — |
| [support-floor-stops](support-floor-stops.md) | IN_PROGRESS | feat-weinstein | — | F3 R6-half MERGED #2251 `3f0b0d44` (1 rework); next: G4 (`?bar_close` basis split — the deferred benchmark half of F3) |
| [short-side-strategy](short-side-strategy.md) | IN_PROGRESS | feat-weinstein | — | #2081 robust dollar-ADV (#2060) MERGED `9670e49a`; next: short-leg regime-P&L decomposition (LOCAL) |
| [extension-stop](extension-stop.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | arming + insurance-ACCEPT MERGED (#1960, ext_stop 2.0/0.25, default-off); next: default-flip only on further insurance-ACCEPT (R3, human-gated) |
| [decline-character](decline-character.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | All builds + A-D flip merged; arming-speed A-D-live WF-CV REJECTED (#1729 ledger 06-24); decline mechanisms stay default-off axes; exhausted (#1739) |
| [spy-only-reference](spy-only-reference.md) | IN_PROGRESS | feat-weinstein | — | WF-CV on sector-rotation testbed; top-1000 bankability gate; long-short verification (human session) |
| [stage-accuracy](stage-accuracy.md) | IN_PROGRESS | feat-weinstein | — | force_exit_off grid REJECTED (#1503); cascade-selection inversion documented (#1509 merged); broad-universe WF-CV re-run data-gated |
| [harvest-rotate](harvest-rotate.md) | MERGED | — | — | WF-CV REJECT (#1532) — dispersion-amplifying noise, not Sharpe edge; mechanism stays default-off, axis not promoted |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — |
| [sector-data](sector-data.md) | MERGED | — | — | — |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | tracked_artifact_linter MERGED #2252 `0d8b7c9f` (1 rework); next: audit-script rewrite (8 known defects across write_audit/record_qc_audit) |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-maintainer | — | 8 open; A-NOOP-BUDGET-ORPHAN new (5 records recovered); A-FASTEXIT-VACUOUS now has measured cost; six items share the `workflow`-token blocker |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | tracked_artifact_linter CLOSED via #2252 (harness-owned); 10 open, next: adjusted_basis_guard_asymmetry, or flaky_test |
| [cost-tracking](cost-tracking.md) | MERGED | — | — | — |
| [data-layer](data-layer.md) | MERGED | — | — | — |
| [portfolio-stops](portfolio-stops.md) | MERGED | — | — | — |
| [screener](screener.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | local-range entry anchor MERGED #2217 (default-off axis `entry_anchor_local_range_weeks`); next: re-run honest ladder with local-top-E arms, then WF-CV |
| [simulation](simulation.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | stop re-anchor to entry base MERGED #2219 (default-off, E-family gated); next: WF-CV the E-anchored family per the honest-ladder plan |
| [trade-autopsy](trade-autopsy.md) | MERGED | — | — | — |
| [stage3-hysteresis](stage3-hysteresis.md) | MERGED | — | — | — |
| [experiment-platform](experiment-platform.md) | IN_PROGRESS | feat-backtest | — | force-exit-off grid REJECTED for promotion (#1503); single-dial surface exhausted; next: continuation-buy recheck on top-3000 (data-gated) |
| [experiments](experiments.md) | MERGED | — | — | — |
| [tuning-methods](tuning-methods.md) | PENDING | feat-backtest | — | Step 0 done; steps 1-3 demoted (surface is the bind); component-decomposition objective next |
| [tuning](tuning.md) | IN_PROGRESS | feat-backtest | — | M1 complete (5/5 deliverables); M2 qNEHVI next (awaiting maintainer enable-commit per #1327) |
| [weekly-snapshot](weekly-snapshot.md) | IN_PROGRESS | feat-weinstein | — | #2182 MERGED `06487307`; #2185 CLOSED obsolete (fixes superseded by #2189 refactor, main green); next: none queued |
| [walk-forward-cv](walk-forward-cv.md) | MERGED | feat-backtest | — | — |
| [tax-lens](tax-lens.md) | MERGED | feat-backtest | — | Phase 1 #2066 + CP4 loader error-path contract #2073 MERGED; Phase 2 wash-sale / April outflows deferred, user-gated (#2006) |
| [data-foundations](data-foundations.md) | IN_PROGRESS | feat-data | — | asset-type blocklist MERGED (#1939, default-off); next: arm ATB.curated for live universe build + General::Type enrichment feed |
| [floor-quality](floor-quality.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | P1b step2 SPY-sleeve MERGED #1913; next = step 3 lens screen vs TR-SPY (deep-warehouse, maintainer LOCAL / S5) |

## How to use

- **Find what's in flight**: filter rows by Status = IN_PROGRESS.
- **Find what needs an owner**: look for empty Owner cells on non-MERGED rows.
- **Find what's awaiting review**: check the Open PR column.
- **Find the next concrete task** for a track: read its "Next task" cell.
- **Start a session**: open the linked status file to get full context.

## Maintenance

Agent-owned update: any agent that touches `dev/status/<track>.md`
during a session must also update that track's row here if Status,
Owner, Open PR, or Next task changed. Agents only touch their own row,
so parallel write conflicts stay rare.

The `Next task` cell must be **one line** (<=160 chars). History and
rationale belong in the per-track status file, not here.
`trading/devtools/checks/index_size_linter.sh` enforces the cap at CI.

Orchestrator reconciliation: `lead-orchestrator` diffs this index
against the per-track status files at end-of-run and flags drift.

Adding a new track means creating the status file AND adding a row
here in the same commit.
