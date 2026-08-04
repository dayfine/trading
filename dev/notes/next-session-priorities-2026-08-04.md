# Next-session priorities — 2026-08-04

**Supersedes** `next-session-priorities-2026-07-30.md`. Its P0 (Friday 07-31
live run) executed 08-02 (record `dev/weekly-picks/c028ee864/2026-07-31.*`,
merged #2179 — validation 0 errors / 1 FBRX split warn; first live #2171 cap
tickets, all math hand-verified). The 08-02/08-03 sessions then ran an
issue-burn-down arc.

## Shipped since 07-30 (all through full gates)

- **#2179** 07-31 weekly record (Bullish 1.00, 20 longs led by WTW A+ 90,
  0 shorts; picks artifact: https://claude.ai/code/artifact/c36e6664-e4da-4a1e-85e9-d38d8ffe0a23).
- **#2180** A-FASTEXIT-VACUOUS fix — orchestrator Step 0.5 now requires a
  non-empty queue (was: 4 slots on 07-31/08-01 produced only orphaned budget
  branches). Watch next few `dev/daily/` summaries confirm real passes.
- **#2181** `split_safe_floors` default-off flag + stop_recompute
  anchor-mode fix (closes #2167 QC finding). Panel/callback path still
  unconverted (daily_view lacks raw close) — documented gap.
- **#2182** #2122 slices b/c/d (cross-artifact instruction identity,
  committed-record round-trip + F4/F5 pins, eligible-beyond-cap).
- **#2188** Fold_health emission wired into the backtest binary (#1557
  item 1; items 2/3 were ALREADY merged — #1575, #1567/#1582).
- **#2189** report improvements (user-requested 08-02): sector column,
  score breakdown (bit-identical scorer refactor, QC-verified), weakness
  line, HTML hover explainers, beyond-cap generator test.

**Issues closed:** #2084, #1782, #2133, #2122, #1557 (13 → 8 open).

## In flight at handoff

- **`feat/live-rename-detect`** (#2083 fix 2) — feat-agent dispatched
  2026-08-04: returns-basis twin matcher (reuse #1946 scoring, 1e-3 basis)
  surfacing probable renames as weekly-report warnings; detection-only, no
  universe auto-rewrite. [blocking: check PR by next session start;
  reclaim-if-untouched — salvage from branch if agent died, per the #2182
  precedent.] Closes #2083 when merged; the universe re-pin itself stays a
  human/ops action the warning will prompt.

## P0 — Friday 2026-08-07 weekly run

Same recipe as 07-31 (memory `project_split_safe_resistance_basis` + the
07-30 doc P0), now with: report improvements live (#2189), rename warnings
if #2083 lands, and the option to arm `split_safe_floors true` in
`live-config-overrides.sexp` to kill the FBRX-class floor caveat (live
stop_recompute path IS converted — arming decision is the user's; note it
changes displayed stops for split-in-window names only).

## P1

- Land/QC/merge `feat/live-rename-detect` if not done.
- Bundle-vs-alternatives honest margin grid (~7-8h) — still the one open
  caveat on the re-pinned record (#2170); user call.
- `Extended`-branch unit case in test_report_shared.ml (qc-behavioral
  non-blocking nit on #2189).

## Remaining open issues (6) — the full backlog queue, with blockers (2026-08-04 late addendum)

Late-session updates: #2083 CLOSED (detector was already built in #2100; the
real remainder — arming dry-run + live arming — done, #2191: 0 false
positives over the full universe, candidates bit-identical). #1563 CLOSED
(margin work covers it — Portfolio_margin strict-broker collateral lock,
M4-verified; convention recorded: short-arm scenarios run margin-on). Also
shipped: **07-31 v2 record** (`3e10a92c7/`, #2192) — picks bit-identical,
artifact enriched with the #2189 columns + armed rename detection.

All six remaining issues, blocker-triaged (session task list mirrored here
since that list dies with the session):

1. **#1672 window migration 1998-2026** — effectively UNBLOCKED; one pinned
   spec (`exit-timing-surface-deep-2000-2026.sexp`) → 1998 start + rename +
   as-of-1998 universe + fresh-run band re-pin (snapshot mode; use the
   current split-safe warehouse basis). One local re-pin session. Cheapest
   first bite.
2. **#1572 budget orphans** — LOCALLY unblocked (the workflow-token label
   only blocks GHA-side agents; #2172 proved local workflow pushes work).
   Fix = orchestrator no-op path lands the budget record (tiny auto-merge PR
   or fold into next summary). FIRST verify the orphan path still exists
   post-#2180 (the non-empty-queue precondition may have shrunk it to
   genuinely-empty-queue runs). Spec detail: A-NOOP-BUDGET-ORPHAN in
   dev/status/orchestrator-automation.md.
3. **#2006 after-tax lens Phase 1** — no hard blocker; pure post-run exe
   (mtm_flat 0.35 must reproduce $18.8M/$21.8M on the Run D dir).
   PRE-FLIGHT: confirm `dev/backtest/scenarios-2026-07-13-194522/…ALLARMED`
   still on disk; else re-derive acceptance from a fresh record run.
   Comparator = after-tax SPY-TR.
4. **#2076 margin exit audit** — DESIGN first: Margin_runner fires outside
   the strategy/audit path; options = thread an observer hook through
   Simulator.dependencies (mirror #2074) vs unenriched margin-exit records.
   Only matters for margin-armed runs.
5. **#2158 Phase 2 simulator StopLimit fill** — user-set P1 (2026-08-04):
   gated experiment, default-off, own WF-CV surface, NEVER bundle; fill-model
   basis change shifts every golden. Needs explicit user go on compute.
6. **#1729 complete-data broad goldens** — HEAVIEST. Memory-crash blocker
   RESOLVED (snapshot-format-v2; issue comment updated 08-04). Remaining:
   CI-provision the 3,017-sym warehouse (GHA cache/artifact) + wire
   --snapshot-dir into perf-tier3/4 broad cells + re-pin all broad/custom
   cells ON THE SPLIT-SAFE BASIS (post-#2145/#2153) or they move again.
   Plan: dev/plans/broad-golden-complete-data-2026-06-24.md.

## Ops lessons this arc (recurring — internalize)

- **Lint gauntlet**: 4 of 5 code PRs went CI-red on nesting/fn-length/
  file-length at least once. Feat-agent briefs now demand pre-push
  `dune runtest devtools/checks` + `linter_file_length.sh`; keep doing it.
  Also: shared-type field additions need a FULL `dune build` (the #2189
  round-1 red was a test constructor in decision_audit, outside the scoped
  build).
- **Wait-stall + kick**: agents ended turns "awaiting monitor events" 5+
  times; the SendMessage kick template (foreground bounded poll + finish
  protocol) recovers them every time.
- **Salvage works**: two agents died/lost worktrees mid-task (#2182 API
  death, #2189 worktree swept); pushed-branch WIP + dispatcher finish
  recovered both with zero loss. Keep the push-WIP-in-30-min brief line.
- **Stale dispatch**: the #1557 brief asked for two items already merged in
  June — pre-flight verify-against-main applies to ISSUE bodies too, not
  just status files.
