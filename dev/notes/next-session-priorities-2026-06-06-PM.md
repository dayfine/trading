# Next-session priorities — 2026-06-06 (PM)

**Supersedes:** `next-session-priorities-2026-06-06.md` (its P0 — the late-Stage2
dial confirmation grid — is DONE/REJECTED; see below). This doc sets P0 = build +
grid the **macro-bearish held-exposure trim**, the lever the crash autopsy surfaced.

## What shipped since the morning doc

- **Late-Stage2 stop-tighten dial (#1446) — confirmation grid DONE → REJECT (#1458).**
  DD-unchanged to the bp in both windows, buffer-insensitive, bull no-op, deep +321pp
  from ~1 trade. Root cause: fast-crash drawdowns reset `late` before the top, so the
  dial never engages on the DD-defining episodes. Ledger:
  `dev/experiments/_ledger/2026-06-06-late-stage2-stop-tighten-grid.sexp`.
- **Crash autopsy → the real DD lever, SCOPED (#1461).** Two settled facts:
  (1) reaction speed is NOT the problem — production stops are `Daily` (level + intraday-low
  trigger every day); the Friday cadence touches only entries/macro/stage, never stops.
  (2) Slow tops are callable (macro gate Bearish from Jan-2008 ~10mo pre-waterfall; around
  the 2000 top), 2020 is not (vertical shock, gate never Bearish pre-crash). The gate only
  blocks *entries*, never trims *held* exposure → that gap is the lever. Plan:
  `dev/plans/macro-bearish-exposure-trim-2026-06-06.md`. Memory:
  `project_macro_bearish_trim_lever`.
- Infra (earlier today): #1454 snapshot wrapper, #1455 tier4 PIT migration, N=3000 local
  proof (152.75% / ~3 GB bounded RSS / breadth = 4× Calmar).

## P0 · Build + grid the macro-bearish held-exposure trim

**Step 1 — build the mechanism (strategy-core → TDD + 3-gate QC; dispatch `feat-weinstein`).**
Full spec in `dev/plans/macro-bearish-exposure-trim-2026-06-06.md`. Summary:
- New module `Macro_bearish_trim_runner` (`weinstein/strategy/lib/`), modeled on
  `force_liquidation` + `laggard_rotation_runner` (RS ranking, weakest-first).
- Wire into `weinstein_strategy.ml` `_process_market_day` as a pass after
  `_run_special_exits`, gated on `config.enable_macro_bearish_exposure_trim`
  && `macro_result.trend = Bearish` && screening day. Trim held long exposure to
  `macro_bearish_max_long_exposure_pct`, selling weakest-RS first. Never force-buys.
- Two config fields, default-off no-op:
  `enable_macro_bearish_exposure_trim : bool [@sexp.default false]`,
  `macro_bearish_max_long_exposure_pct : float [@sexp.default 0.70]`.
- Tests: trims to cap on Bearish; no-op when flag off / not Bearish / already under cap;
  weakest-RS ordering; never force-buys; collision with stop/stage3/laggard (single-exit).
- Register as a `Variant_matrix` axis. **No default flip without a grid ACCEPT.**

**Dispatch brief blocks** (per `.claude/rules/feat-agent-dispatch.md`, paste before the task):
- *Current test failures in `weinstein/strategy/lib/test/`*: run `dune runtest` first; expect "All passing".
- *Last QC review findings*: No prior review (first dispatch on this mechanism).
- *Open follow-up items*: None.
- *Do not modify `dev/status/_index.md` from the PR; update only `dev/status/stage-accuracy.md`.*

**Step 2 — run the deep+bull confirmation grid (dispatcher, NOT an agent).**
Same harness as the late-dial grid (which worked cleanly). Reuse
`dev/backtest/p0-barbell-prod/production-deep.sexp` (2000-2026, dot-com+GFC) +
`p0-barbell-bull-prod/production-bull.sexp` (2010-2026). Generate baseline + treatment
cells (axis `macro_bearish_max_long_exposure_pct ∈ {0.0, 0.175, 0.35, 0.525}` with the
flag on), run `scenario_runner --dir <cell-dir> --parallel 1 --fixtures-root
test_data/backtest_scenarios --no-emit-all-eligible` (CSV mode; `--no-emit-all-eligible`
is essential — the all_eligible diagnostic adds hours). **Output to repo tree is fine
ONLY when no jj agent is running** (per `feedback_no_parent_backtest_during_jj_agent`) —
so run the grid AFTER the build PR merges, not concurrently with the feat-weinstein agent.
Each cell → Pareto + Deflated-Sharpe → ledger entry → confirmation-grid decision
(`.claude/rules/promotion-confirmation.md`).

**Decision rule + honest prior:** PROMOTE a value only if it **cuts deep MaxDD (37%)
materially without killing the 918% return AND is not badly dominated on bull**, robust
across the grid — never the single-window winner. **This WILL move DD (unlike the
late-dial)** but at a return cost (bear-rally whipsaws + missed rebound), so a REJECT is a
real possible outcome. The grid prices the DD-vs-return trade.

## P1 (carried) · Snapshot-loader Phase-F perf fix
N=3000 local works on RSS (~3 GB) but is ~16× too slow per cycle for sweeps. Durable fix:
windowed/mmap decode in `Daily_panels` (per-cycle cost O(positions) not O(universe)). Also
fix the ~1218 `/tmp/snapshot_*.tmp.*`-per-run leak. (`project-snapshot-streaming-status`.)

## P2 (carried) · Breadth as a first-class lever
Breadth keeps winning (4× Calmar at top-3000 vs top-1000, same window). Pin a top-3000
broad golden once the Phase-F perf fix makes re-runs cheap.

## State at handoff (clean start verified)
- main GREEN (CI success on c7627916a); 0 open PRs; 0 ci-red watchdog issues.
- Repo + container clean (no worktrees, bookmarks→main only, no `/tmp` leftovers, no live procs).
- All artifacts on main: plan #1461, ledger REJECT #1458, memories #1459/#1462.

## Ramp-up reminders
- Strategy-core changes need TDD + the confirmation grid; don't rush. Don't flip the
  default without a grid ACCEPT.
- A rework agent stuck in a lock-wait may hide an un-compiled fix — verify its `dune build`.
- Grid runs: `--no-emit-all-eligible`, output to `/tmp/sweeps/` or repo-tree-only-when-no-agent.
- Fixture/docs PRs → admin-merge on CI green; strategy code → full 3-gate.
