# Status Index

Single-source view of all tracked work. Detail belongs in the per-track
status files linked in column 1. Keep every "Next task" cell to one line
(<=160 chars); the `index_size_linter.sh` CI check enforces this.

Last updated: 2026-09-14 run 2 (orchestrator run 34878607445; main **`67485620`**
at start, tip advanced to **`c5b11789`** mid-run). Green at run start from **CI on
the same commit** — `build-and-test`, `perf-tier1-smoke`, `golden-sp500-5y`,
`golden-custom-universe` all `success`; `status_file_integrity` **0**,
`index_size_linter` **0**, `no_python_check` **0**, run standalone without dune,
exit codes read **unpiped**. Step 0.5 did not fire: `QUEUE_NON_EMPTY=2` per the
workflow (1 by the time I read it, #2809), and Condition 1 failed anyway.

**Run 1 today proved the D3 hand-discipline note below is not a control.** Run
`34853606164` dispatched three writing agents, recorded all three `_in flight_`,
and produced **zero branches and zero PRs**; its `## Escalations`, `## Integration
Queue` and dispatch-outcome column still hold the literal placeholder
`_(Completed at the end of the run.)_`, and it never performed this reconcile —
which is why this header sat two runs stale. Step 8 (the whole turn) ran **886 s**:
a serial pre-dispatch baseline gate consumed it, agents were dispatched at the end,
and the container was torn down mid-flight with nothing snapshotted to a branch.
Filed as **#2810** with the reordering ask — dispatch *before* verifying, since
nothing in the deterministic set gates dispatch and CI already publishes the build
answer for the same commit. Run 2 dispatched ~9 min in and ran every check
standalone (no dune, no mutex contention); all three lost tasks were re-dispatched.

**Fifth instance of one class this month** (#2741, #2747, #2771, #2803, #2810):
a green run is still indistinguishable from a productive one, because nothing
checks a run's claimed dispatches against the branches that actually exist.
**#2812 closes the summary half of it and is MERGED (`d04c75e2`)** — dispatched,
double-QC'd (structural 5 / behavioral 5, 10/10 mutations killed, 0 survivors) and
auto-merged inside this run. From the next run on, a FULL-mode run that loses its
summary **fails the job** instead of going green. The **dispatch** half is still
open — nothing checks claimed dispatches against branches that exist, which is
exactly what run 1 needed (#2810).

Run 2 shipped three mutation-verified PRs, all re-dispatches of run 1's lost work:
**#2812** (`verify` asserts a FULL-mode summary was published, #2803), **#2813**
(R7 + `force_liquidation`, #2800 follow-up), **#2814** (warn-level QC score
digit/adjective lexicon, H-QC-SCORE-ADJECTIVE-LEXICON). **#2812 went the whole way —
dispatched, both QC gates APPROVED at its tip, merged.** #2813 (CI green) and #2814
await QC next run: each QC agent needs its own cold **16 GB** `_build` and the
one-dune mutex serializes them; disk peaked at **90%** during the feature dispatch
and returned to **58%** once the finished worktrees were reclaimed, which is what
bought room for #2812's pass. #2813's real
result is a **corrected premise**: R7 already returned `Fail` for breaker exits as
of #2800 (`stage_at_exit` was never the blocker for this exit kind), but the flip
was unpinned and fired in only one shape — the plausible tidy-up that reverts it
would have passed green.

**The orchestrator was DEAD for three days and the cause was not in this repo.**
Six consecutive scheduled runs failed 2026-09-10 -> 09-12 (`34475636575`,
`34501930703`, `34597781805`, `34622262330`, `34691534671`, `34702540272`), each
`$0.0000` with `num_turns: 1`, `duration_ms ~506` and `modelUsage: {}` — the SDK
died **before issuing a single model request**. Zero summaries, zero health scans,
zero audits. The 09-13 track-pacer report leads with PR #2757 as the suspect; that
hypothesis is **false** — `git diff 68cd3b8c origin/main -- .claude/agents/
.github/workflows/` is **empty**, i.e. the agent definition and every workflow are
byte-identical between the first dead run's head and today's successful one. The
same content failed six times and then succeeded. What varied in lockstep is the
**unpinned Claude Code build**: 2.1.266 green -> 267/268/269 red -> 2.1.270 green.
Filed as **#2770** (ask: pin the version; alert on orchestrator failure).

**D2 (#2741) is CLOSED.** PR #2757 repointed Step 8 at
`dev/scripts/publish_daily_summary.sh` (plain git + curl REST), so the five-runs
-lost-the-summary defect can no longer recur by that path. Note the irony worth
keeping: #2757 was then wrongly blamed for the three-day outage above, purely
because it merged inside the gap. **#2729 is answered and CLOSED** by #2749
(`cce6d073`) — the two QC passes ran disjoint mutation sets, and #2727 had
already killed the mutant. **D3 (#2747) remains open**: nothing yet *mechanically*
stops the orchestrator ending its turn mid-dispatch; this run held the discipline
by hand, which is not a control.

**The watchers were all down during the outage, and one is blind by
construction.** The scheduled-workflow health detector (#2634/#2663) needs only
API **read** access — the blocked `workflow` scope gates *wiring it as a cron*,
not *calling it*, and nothing had ever called it. **The orchestrator now runs it
directly.** But run on 09-13 it reported `Daily orchestrator` = **OK** mid-outage:
it inspected only the newest scheduled run, which was the orchestrator's own
`in_progress` execution, classified as OK — so the orchestrator masks its own
health unconditionally. Fixed in **#2772** (streak-aware, in-progress-unmasked).
Separately, the **weekly deep scan ran on 09-07, reported every step successful,
and produced no file** — the agent returned `is_error: false` after 31 turns and
$0.39 in 98s, and the publish step's honest `No changes in dev/health/` guard
exited 0. Filed as **#2771**. Three defects this month share one shape: **a green
run is indistinguishable from a productive one, because nothing checks the
artifact against the exit code.**

Two RED weekly workflows remain (`Prune candidates weekly`, `Weekly start sweep
(BAH SPY)`), both last fired **2026-09-07** — before their fix (#2725) merged.
They cannot produce a new datapoint before their next weekly cron; not re-derived
this run.

Capabilities (carried; measured 2026-09-04 unless noted): `.claude/agents/**`
writes **refused** (13th run — re-probed 2026-09-13 with a one-line Edit, refused;
note #2757 landed a change to that file via a *human-merged PR*, which is a
different route); `workflow` scope unavailable by push **and**
contents API (403 on a workflow path vs **201** on a `dev/notes/` control,
same token, seconds apart — the control is what makes it a measurement);
`POST /actions/workflows/<f>/dispatches` **403**; `POST /issues` create-only
(issue comments **403**, re-tested 2026-09-08 and again 2026-09-14; **`PATCH
/issues/<n>` is also 403** — new 2026-09-14, so a filed issue can be neither
commented on nor edited, and a mistake in an issue body is uncorrectable from this
runtime); `PATCH /pulls/<n>`, `POST /pulls/<n>/reviews`, `POST /pulls` (create),
`PUT /pulls/<n>/merge`, `PUT .../update-branch` all work.

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
| [backtest-infra](backtest-infra.md) | IN_PROGRESS | dayfine + feat-backtest | — | PIT universe migration LOCAL, do not dispatch: steps 1–3a MERGED (#2808/#2809/#2816); 3b `_v11pit` chunked build + step-4 null band in flight |
| [rename-twin-dedup](rename-twin-dedup.md) | IN_PROGRESS | feat-backtest | — | v1(#1940)+v2(#1946) MERGED; dedup warehouse rebuilt + 28y record re-run landed (#1949, 83 groups/91 legs dropped); next: none (optional V6 report-consult tweak) |
| [post-run-validation](post-run-validation.md) | IN_PROGRESS | feat-backtest | — | V18 #2750 + `Series_level` build-time sibling #2773 MERGED `9b65f7cb` (report-only, default-off, unwired); next: wire to Build_runner; #2732 asks 1+3 LOCAL |
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
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | #2772 MERGED `ccf075be` — streak-aware scheduled-workflow health, unmasked from in-progress runs (#2770); next: Step 6.2 doubled-path fix via PR route |
| [orchestrator-automation](orchestrator-automation.md) | IN_PROGRESS | harness-maintainer | — | `workflow` scope proven blocked on EVERY route (403 path vs 201 control, 09-04); blocks #2653 #2662 + #2634 wiring, #2427-#2432 |
| [cleanup](cleanup.md) | IN_PROGRESS | code-health | — | §Backlog has NO actionable work (09-09 run 2 audit): 1 policy decision + 2 explicit archive entries + 1 fenced template. Prior "disk decline" framing withdrawn |
| [cost-tracking](cost-tracking.md) | MERGED | — | — | — |
| [data-layer](data-layer.md) | MERGED | — | — | — |
| [portfolio-stops](portfolio-stops.md) | MERGED | — | — | — |
| [screener](screener.md) | IN_PROGRESS | dayfine (LOCAL) + feat-weinstein | — | `deteriorating_blocks_longs` default-off long gate MERGED #2759 + pre-registered 3-salt read #2768; next: run that pre-registered read |
| [simulation](simulation.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | Clock 0→52 MERGED #2587; A-null LANDED #2631 (`deb45a7e`) — return effect sign-inconsistent, maxDD the robust property; next: none queued |
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
