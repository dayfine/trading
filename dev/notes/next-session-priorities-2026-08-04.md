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

## Remaining open issues (8)

#2158 (Phase 2 simulator fill model — gated experiment, never bundle),
#2083 (in flight), #2076 (margin exit-reason rendering), #2006 (tax lens),
#1729 (broad golden complete data — data-gated), #1672 (window migration),
#1572 (budget orphan — workflow-token-blocked), #1563 (short proceeds lock).

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
