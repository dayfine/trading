# Status Index

Single-source view of all tracked work. Detail belongs in the per-track
status files linked in column 1. Keep every "Next task" cell to one line
(<=160 chars); the `index_size_linter.sh` CI check enforces this.

Last updated: 2026-09-15 (orchestrator run 2; main **`767ef9aa`**, green on all
CI checks; `status_file_integrity` **0**, `index_size_linter` **0**,
`no_python_check` **0** — run standalone without dune, exit codes read unpiped).

**This header was trimmed this run.** It had reached **18725/20480 bytes (91%)**
of the linter cap by accreting run-by-run incident narrative, and would have
failed CI mid-reconcile within a few runs. Every incident block removed below is
fully recorded in its own `dev/daily/` summary, which is where run history
belongs; this header now carries only **standing facts that change slowly**.
Keep it that way — append to the daily summary, not here.

## Standing constraints

**Capabilities** (re-measured 2026-09-15 run 2 unless noted):
- `.claude/agents/**` direct writes **refused** (17th consecutive run).
- `.claude/rules/**` writes **also refused** — measured 2026-09-15 run 2, when a
  dispatched agent was blocked twice writing `container-capacity-scheduling.md`.
  **This corrects an earlier assumption** that the gate covered only
  `.claude/agents/**`; PR #2828 edited a rules file through a *human-merged PR*,
  a different route.
- `POST /issues` **works** (#2835, #2837 filed this run).
  **`POST /issues/:n/comments` also works** — corrects the carried "403" claim,
  disproved this run when a QC agent posted a verdict through it successfully.
  `PATCH /issues/:n` remains **403**, so a filed issue cannot be corrected here.
- `workflow` scope unavailable by push **and** contents API (403 on a workflow
  path vs **201** on a `dev/notes/` control, same token, seconds apart — the
  control is what makes it a measurement); `POST /actions/workflows/<f>/dispatches`
  **403**. Blocks #2770, #1636, #2113, and makes the #2810 dispatch-before-verify
  reordering a choice each run rather than a mechanism.

**Runner ceilings** (bind before cost does; cap is 2 agents, not 3):
concurrent `dune` in flight **1** (15 GB, memory-bound; OOM measured run
`34757914354`) · disk per agent worktree **~16 GB**
(`H-AGENT-WORKTREE-DISK-16GB-EACH`) · reclaim each worktree **as its agent
finishes**, never batched (batching took run `33962894987` from 69% to ENOSPC).

**The open defect class** — *a green run is indistinguishable from a productive
one, because nothing checks the artifact against the exit code.* Instances
#2741, #2747, #2771, #2803, #2810; summary half closed by **#2812**, dispatch
half by **#2831**. Still open one level up: **#2837** (a QC verdict posted to a
surface the merge gate cannot read is invisible and undetected) and **#2835**
(Step 0.5 Condition 2 derives `PREV_ISO` from mtime, which `actions/checkout`
sets to run start, so the condition cannot fail on GHA — the script it delegates
to already fixed this in #2605; the prose did not).

**Feature tracks are fenced, by design.** Every IN_PROGRESS feature row below is
LOCAL-fenced (maintainer-owned), data-gated, or human-gated on an R3 default-flip.
The current milestone is the **PIT top-3000 universe migration**
(`dev/plans/pit-universe-migration-2026-09-14.md`; steps 1-3a merged
#2808/#2809/#2816, 3b + step-4 null band in flight locally, #2832) — maintainer-led
and LOCAL. Orchestrator dispatch stays off it; harness is where the throughput is.

**Two RED weekly workflows** remain (`Prune candidates weekly`, `Weekly start
sweep (BAH SPY)`), both last fired 2026-09-07, before their fix (#2725) merged.
Neither can produce a new datapoint before its next weekly cron.

**Note for Step 2c:** `git merge-base --is-ancestor` is **not** a merged-ness test
in this repo — squash merges make every correctly-merged branch a non-ancestor of
`main`, so it reports NOT-MERGED for all of them. Check PR state instead.

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
| [trade-audit](trade-audit.md) | IN_PROGRESS | feat-backtest | — | #2813 R7=Fail for `force_liquidation` MERGED `989eceb0` (double-QC, 1 rework); next: retire `project_rest_time_pnl_is_cell_specific` (obligation due) |
| [decision-audit](decision-audit.md) | MERGED | feat-backtest | — | #1799/#1806/#1811 MERGED (report+counterfactual+weekly-picks adapter); selection FAITHFUL; live-picks pipeline ready (#1812); next: matured weekly counterfactual |
| [optimal-strategy](optimal-strategy.md) | MERGED | — | — | — |
| [all-eligible](all-eligible.md) | MERGED | — | — | — |
| [support-floor-stops](support-floor-stops.md) | IN_PROGRESS | feat-weinstein | — | #2486 book-faithful stops basis SHIPPED 08-24 (buffer 1.02->1.0, anchor-reset on); next: UNSET — prior cell cited #2486 H1, already done (09-15) |
| [short-side-strategy](short-side-strategy.md) | IN_PROGRESS | feat-weinstein | — | #2081 robust dollar-ADV (#2060) MERGED `9670e49a`; next: short-leg regime-P&L decomposition (LOCAL) |
| [extension-stop](extension-stop.md) | IN_PROGRESS | dayfine (maintainer LOCAL) | — | arming + insurance-ACCEPT MERGED (#1960, ext_stop 2.0/0.25, default-off); next: default-flip only on further insurance-ACCEPT (R3, human-gated) |
| [decline-character](decline-character.md) | MERGED | — | — | WORKSTREAM EXHAUSTED (#1739); closed in #2493 after 8 pacer asks; one EODHD-gated item to re-home |
| [spy-only-reference](spy-only-reference.md) | IN_PROGRESS | feat-weinstein | — | WF-CV on sector-rotation testbed; top-1000 bankability gate; long-short verification (human session) |
| [stage-accuracy](stage-accuracy.md) | IN_PROGRESS | feat-weinstein | — | force_exit_off grid REJECTED (#1503); cascade-selection inversion documented (#1509 merged); broad-universe WF-CV re-run data-gated |
| [harvest-rotate](harvest-rotate.md) | MERGED | — | — | WF-CV REJECT (#1532) — dispersion-amplifying noise, not Sharpe edge; mechanism stays default-off, axis not promoted |
| [strategy-wiring](strategy-wiring.md) | MERGED | — | — | — |
| [sector-data](sector-data.md) | MERGED | — | — | — |
| [harness](harness.md) | IN_PROGRESS | harness-maintainer | — | run 2 MERGED both: #2834 gate curl-projection pin `767ef9aa` + #2836 pre-dispatch disk guard `2d023810`; next: N3 mutation row + count-split residual |
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
