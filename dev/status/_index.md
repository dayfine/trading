# Status Index

Single-source view of all tracked work. Detail belongs in the per-track
status files linked in column 1. Keep every "Next task" cell to one line
(<=160 chars); the `index_size_linter.sh` CI check enforces this.

Last updated: 2026-09-01 (orchestrator run 33482398132; main **`c0f40ecb`
-> `6da52064`**, one PR merged. Green at run start and at run end:
build 0, runtest 0, 0 `^FAIL:`, `status_file_integrity` 0, `index_size_linter`
0 — every exit code read **unpiped**).

**Merged this run:** **#2623** (the four #2618 workflow-cap residuals). Its
qc-behavioral NEEDS_REWORK finding — the added comment claiming a job-level
cancel *"SKIPS this `if: always()` branch entirely"*, refuted across all nine
measured timeout cancellations in both workflows — was fixed by the
maintainer's parallel local session (two reworks) because the fix lives in
`.github/workflows/**`, which this token cannot push.

**The theme was the merge gate reading itself wrong.** Four QC passes on
`pr_gate_status.sh` produced **four** distinct defects in the file that decides
whether a PR may merge: #2620's interior-heading leak (fixed, #2622), two
surviving mutations of that fix (**(d)** dropping `strip_fences` is a live
false-MERGE/false-BLOCK pair; **(j)** the `^` anchor lost its pin) now closed by
**#2625**, three further **live** unpinned mutations recorded there
(**(k)**, **(f)**, **(g)**), and a new one filed as **#2626** — a review with no
`Reviewed SHA:` line in its body is *current-at-every-tip-forever*, observed
live on #2625 itself. The API's `commit_id` already carries the answer the
parser tries to recover from prose.

**Two PRs open and reworked, awaiting re-QC:** **#2624** (pins the
missing-`review_at` branch of `check_11`) and **#2625**. Both were recovered
dispatcher-side after their authoring agents stalled on backgrounded `dune`
calls, so both carry **no author self-attestation** — the commit messages and
PR bodies say so explicitly.

Capabilities re-measured live, not copied. `.github/workflows/**` **pushes**
are rejected (`refusing to allow a Personal Access Token to create or update
workflow ... without \`workflow\` scope`) — but a **server-side PR merge of a
workflow-touching PR succeeds** (#2623 merged fine), which is a sharper
statement than "workflows are 403". Comment writes are **PR-scoped, not
issue-scoped**: `POST /issues/<n>/comments` returned **201** for a PR number
and **403** for an issue number, same endpoint, same token. `POST /issues`
works (**201**, #2626); `PATCH /pulls/<n>` works (**200**).
`.claude/agents/**` writes remain gated by the harness.

Per-run history lives in `dev/daily/YYYY-MM-DD*.md`, one file per
orchestrator run — not here. This header carries the current run only.
Ten prior run summaries were inlined above it until 2026-08-14, growing
the file to 21,972 bytes against the linter's 20,480 cap and turning a
lookup table into a changelog; each already ended with a pointer to its
own daily file, so nothing was lost in moving them out. Recent runs:
`2026-08-14.md`, `2026-08-13.md`, `2026-08-12.md`, `2026-08-09.md`,
`2026-08-08.md`, `2026-08-07.md`, `2026-08-05.md`, `2026-08-04.md`.

## Active + complete tracks

Each row: one line; deeper task detail in the linked status file.
"Next task" = top-of-queue concrete item from that file's Next Steps.

| Track | Status | Owner | Open PR(s) | Next task |
|---|---|---|---|---|
| [arc-readiness](arc-readiness.md) | IN_PROGRESS | dayfine (LOCAL) + feat-weinstein | — | Funding program CLOSED (A1-1..A1-4); G3 terminal REJECT as default, G2a/G2b default-off axes; Axis 1+3 complete; next: A2-4 |
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
| [trade-audit](trade-audit.md) | IN_PROGRESS | feat-backtest | — | #2371 `6c3485c4` + #2368 `a994b7bc` MERGED (cohort measured; mis-join claim withdrawn); next: retire `project_rest_time_pnl_is_cell_specific` (obligation now due) |
| [decision-audit](decision-audit.md) | MERGED | feat-backtest | — | #1799/#1806/#1811 MERGED (report+counterfactual+weekly-picks adapter); selection FAITHFUL; live-picks pipeline ready (#1812); next: matured weekly counterfactual |
| [optimal-strategy](optimal-strategy.md) | MERGED | — | — | — |
| [all-eligible](all-eligible.md) | MERGED | — | — | — |
| [support-floor-stops](support-floor-stops.md) | IN_PROGRESS | feat-weinstein | — | #2505 stops differential pin MERGED (A2 rule fix #2508 landed, unblocking it); next: `_ratchet_tightened` ratchet-freeze defect (#2486 H1) |
| [short-side-strategy](short-side-strategy.md) | IN_PROGRESS | feat-weinstein | — | #2081 robust dollar-ADV (#2060) MERGED `9670e49a`; next: short-leg regime-P&L decomposition (LOCAL) |
| [extension-stop](extension-stop.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | arming + insurance-ACCEPT MERGED (#1960, ext_stop 2.0/0.25, default-off); next: default-flip only on further insurance-ACCEPT (R3, human-gated) |
| [decline-character](decline-character.md) | MERGED | — | — | WORKSTREAM EXHAUSTED (#1739); closed in #2493 after 8 pacer asks; one EODHD-gated item to re-home |
| [spy-only-reference](spy-only-reference.md) | IN_PROGRESS | feat-weinstein | — | WF-CV on sector-rotation testbed; top-1000 bankability gate; long-short verification (human session) |
| [stage-accuracy](stage-accuracy.md) | IN_PROGRESS | feat-weinstein | — | force_exit_off grid REJECTED (#1503); cascade-selection inversion documented (#1509 merged); broad-universe WF-CV re-run data-gated |
| [harvest-rotate](harvest-rotate.md) | MERGED | — | — | WF-CV REJECT (#1532) — dispersion-amplifying noise, not Sharpe edge; mechanism stays default-off, axis not promoted |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — |
| [sector-data](sector-data.md) | MERGED | — | — | — |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | #2624, #2625 | Both reworked, awaiting re-QC; gate-parser has 3 live unpinned mutations + #2626; next: re-QC then R-4 expiry table |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-maintainer | — | A-MERGEABLE-STATE-NOT-A-CLOSE-TELL filed (run-1 guidance corrected); open: #2427 #2428 #2429 #2432 — need `workflow` scope or a human |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | odoc dangling-ref check MERGED `d5247fd5` (#2596) + its 11 findings fixed to 0 `e4945655` (#2597); top item `linter_coverage` still a HUMAN POLICY DECISION (15 runs) |
| [cost-tracking](cost-tracking.md) | MERGED | — | — | — |
| [data-layer](data-layer.md) | MERGED | — | — | — |
| [portfolio-stops](portfolio-stops.md) | MERGED | — | — | — |
| [screener](screener.md) | IN_PROGRESS | dayfine (LOCAL) + feat-weinstein | — | RS trend live (`lookback_bars` 52->56) landed via **#2561** (#2555 closed unmerged, superseded); #2380 closed; next: none queued |
| [simulation](simulation.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | Clock 0→52 MERGED #2587; D-null adverse at top-1000, USER kept 52 (ledger amended #2611); next: optional A-null (salts 1,2) |
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
