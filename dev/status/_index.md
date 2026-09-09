# Status Index

Single-source view of all tracked work. Detail belongs in the per-track
status files linked in column 1. Keep every "Next task" cell to one line
(<=160 chars); the `index_size_linter.sh` CI check enforces this.

Last updated: 2026-09-09 run 2 (orchestrator run 34378061508; main **`df7922fb`**.
Green at run start: `dune build` **0**, `dune runtest` **0**, 0 `^FAIL:`,
`status_file_integrity` **0**, `index_size_linter` **0** — every exit code read
**unpiped**. Step 0.5 skipped: `QUEUE_NON_EMPTY=0`, and per the precondition an
**empty** queue is the opposite of saturated.

**Summary publication is fixed in practice; the call site is still not.** Five
consecutive runs (`34030886835`, `34042419476`, `34127853646`, `34148849699`,
`34224532158`) completed `success`, spent real money (09-08 alone **$20.18**) and
created **zero** `ops/daily-*` PRs. 09-08, 09-09 run 1 and 09-09 run 2 all landed
by bypassing Step 8. **Root cause corrected 2026-09-09 (issue #2741): `jj` is NOT
broken in this image** — `jj git push` succeeds once `jj config set --user
user.name/user.email` and `jj describe` have run. Step 8 sets *git's* identity
(jj does not read it) and never describes `@`; both are independently fatal.
`dev/scripts/publish_daily_summary.sh` (PR #2721) is the tested replacement and
**was exercised end-to-end in production on 09-09 run 2** (PR #2746). Step 8
still calls `jj`; the repoint is write-gated.

**D3 (2026-09-09 run 2): the orchestrator can end its turn mid-dispatch and
destroy every agent's work.** Run `34350513426`'s `Run lead-orchestrator` step
lasted **20m 57s** while its summary listed three agents as "in flight"; a single
`dune runtest` on this runner exceeds 25 min, so none could have returned. Zero
branches reached origin. Distinct from the artifact-loss defect above and blocked
on no access grant — see `dev/daily/2026-09-09-run2.md`.

**All three red scheduled workflows had stale diagnoses; two are now
corrected.** Every cron fired since 09-05, so this run got a real answer rather
than a stale row. **#2723 (new)**: the track-pacer no longer fails pre-flight —
it runs **28 turns / $3.08** and dies only on the `subtype:"success"` +
`is_error:true` contradiction, so the `allowedTools` hypothesis is **dead** and
the ask is now `show_full_output: true` **alone**. **#2722 (new)**: PR #2651's
own status entry cited `prune_candidates.sh`'s sanity-probe anchor, and
`dev/status` is a citation source — the fix broke the check by documenting it;
PR #2725 makes the probe synthetic and two-sided. The third (#2702) was already
re-diagnosed by the 09-07 run whose summary was lost — which is the argument for
filing to a queue rather than a summary.

**Those three PRs (#2721/#2724/#2725, plus #2727) all merged overnight 09-08.**
The open question they left is #2729: the orchestrator's behavioural pass on
#2721 found a mutant that **pushes an empty branch, prints a PR number, exits 0,
and passes 35/35**, while the interactive pass on the same file found no such
silent path. Both cannot be right; reconciling them is dispatched 09-09 run 2.

Capabilities (carried; measured 2026-09-04 unless noted): `.claude/agents/**`
writes **refused** (12th run — re-probed 2026-09-09 run 2 on the concrete Step 8
repoint edit); `workflow` scope unavailable by push **and**
contents API (403 on a workflow path vs **201** on a `dev/notes/` control,
same token, seconds apart — the control is what makes it a measurement);
`POST /actions/workflows/<f>/dispatches` **403**; `POST /issues` create-only
(issue comments **403**, re-tested 2026-09-08); `PATCH /pulls/<n>`,
`POST /pulls/<n>/reviews`, `POST /pulls` (create), `PUT /pulls/<n>/merge`,
`PUT .../update-branch` all work.

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
| [backtest-infra](backtest-infra.md) | IN_PROGRESS | dayfine + feat-backtest | — | #2724 MERGED (`-incremental` merges the manifest); next: V18 store-sanity check for mis-scaled series (#2732 ask 2, dispatched 09-09 run 2) |
| [rename-twin-dedup](rename-twin-dedup.md) | IN_PROGRESS | feat-backtest | — | v1(#1940)+v2(#1946) MERGED; dedup warehouse rebuilt + 28y record re-run landed (#1949, 83 groups/91 legs dropped); next: none (optional V6 report-consult tweak) |
| [post-run-validation](post-run-validation.md) | IN_PROGRESS | feat-backtest | — | **V18 store-sanity MERGED (#2750)**, `Expectation`; next: #2732 asks 1+3 (quarantine MEL, re-run item-3) + build-time sibling |
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
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | #2749 | #2643 nested-field FP MERGED (#2748, suite 21→23); #2749 open at `6024976c` after 2 reworks — rework cap spent, next run re-QCs |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-maintainer | — | `workflow` scope proven blocked on EVERY route (403 path vs 201 control, 09-04); blocks #2653 #2662 + #2634 wiring, #2427-#2432 |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | §Backlog has NO actionable work (09-09 run 2 audit): 1 policy decision + 2 explicit archive entries + 1 fenced template. Prior "disk decline" framing withdrawn |
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
