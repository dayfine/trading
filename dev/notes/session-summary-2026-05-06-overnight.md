# Session Summary — 2026-05-06 Evening → 2026-05-07 Morning

Session window: ~19:00 → ~03:40 CEST (UTC+2). 20 PRs merged (#891 through #911).
Reference commit at session open: `3df165e4` (docs: §4.6 continuation buys + §5.6 laggard rotation).

---

## 1. Headline Numbers

**Capital-recycling Cell E (Stage3 K=1 + Laggard h=2) on 5y SP500: 120% return / Sharpe 0.93 / MaxDD 23.1%.**
Baseline is 58.34% / Sharpe 0.54 / MaxDD 33.6%. This is +61.7pp return, -10.5pp MaxDD. First configuration in any capital-recycling experiment to break Sharpe 0.9. Source: PR #910.

Full 5-cell table from #910:

| Cell | Stage3 | Laggard | Return | Trades | WR     | MaxDD  | Sharpe | AvgHold |
|------|--------|---------|-------:|-------:|-------:|-------:|-------:|--------:|
| A    | OFF    | OFF     | 58.3%  | 81     | 19.8%  | 33.6%  | 0.54   | 84.1d   |
| B    | K=1    | OFF     | 66.6%  | 128    | 30.5%  | 27.0%  | 0.63   | 84.8d   |
| C    | OFF    | h=4     | 79.5%  | 154    | 26.6%  | 29.8%  | 0.69   | 66.3d   |
| D    | K=1    | h=4     | 37.1%  | 164    | 27.4%  | 30.4%  | 0.42   | 60.9d   |
| E    | K=1    | h=2     | 120.0% | 196    | 33.7%  | 23.1%  | 0.93   | 44.9d   |

**Framing-note lever ordering is inverted.** Laggard alone (+21.2pp, Cell C vs A) is a bigger lever than Stage-3 alone (+8.3pp, Cell B vs A) on 5y. PR #896's framing note implicitly treated Stage-3 (A) as the primary mechanism. Data says laggard (B) is. Future tuning effort should bias toward laggard hysteresis / RS-window sweeps.

**Cell D regression (-21.2pp)** exposes a composition anti-pattern: at h=4, both mechanisms target slow MA-flatteners and produce churn. Cell E's h=2 splits the populations cleanly — laggard fires on RS weakness before Stage-3's MA test triggers.

**All-eligible opportunity-cost analysis (#908):** at min_grade=C (the live cascade's actual quality bar), the diagnostic admits 5,300 trades with mean return -10%. The live strategy's 81 trades / +58.34% comes almost entirely from portfolio-gate mechanics (cash gate + top-N=20 + sector caps). Signal alpha without portfolio selection is negative. The 65× trade-count gap is ~98.5% portfolio mechanics, ~1.5% cascade quality.

**15y Cell E measurement: NOT COMPLETED.** A parallel agent was running the 15y run when it was reaped mid-execution by `cleanup_merged_worktrees.sh`. The crash fix that enables 15y runs is in main (#911, merged 03:37 CEST). The run needs to be re-fired.

---

## 2. PRs Merged Tonight (Chronological)

| # | Merged (CEST) | Summary |
|---|--------------|---------|
| #891 | pre-session | docs(weinstein): add §4.6 continuation buys + §5.6 laggard rotation |
| #894 | 15:41 | ops: daily orchestrator summary 2026-05-06 |
| #892 | 19:01 | feat(screener): expose `min_score_override`; quick-look threshold sweep |
| #893 | 19:36 | feat(tuner): wire `grid_search.exe` CLI binary |
| #895 | 19:58 | harness: enforce CI gate on PR merge via GitHub branch protection |
| #896 | 20:10 | docs(notes): capital-recycling framing note synthesizing #872 + #887 |
| #897 | 20:22 | feat(perf): add tier4-broad-1y mechanic-validation SCALE cell |
| #898 | 20:33 | docs(status): refresh post #892/#893 |
| #899 | 20:46 | feat(backtest): all-eligible trade-grading lib (issue #870 PR-1) |
| #900 | 21:24 | docs(notes): velocity analysis 2026-03-24 to 2026-05-06 (730 PRs) |
| #901 | 21:52 | feat(backtest): all-eligible runner CLI (issue #870 PR-2) |
| #902 | 22:27 | feat(strategy): Stage-3 force-exit detector for capital recycling (#872) |
| #903 | 22:56 | docs(velocity): add LOC-by-language breakdown section |
| #904 | 00:38 | fix(all-eligible): dedup consecutive Friday breakout re-firings |
| #905 | 23:35 | harness: `velocity_report.sh` + OCaml test/source split |
| #906 | 23:46 | experiment(stage3-force-exit): impact on 5y + 15y baselines |
| #907 | 00:22 | refactor(position): generic `StrategySignal` exit_reason variant |
| #908 | 01:15 | feat(all-eligible): min_grade quality gate + grade sweep |
| #909 | 02:08 | feat(strategy): laggard rotation — lighten up before stop-out (#887) |
| #910 | 02:58 | experiment(capital-recycling-combined): 5y Stage3+Laggard 5-cell sweep |
| #911 | 03:37 | fix(backtest): write degenerate actual.sexp on crash + dedup adjust+exit collisions |

---

## 3. Key Code That Landed

**Stage-3 force-exit detector + runner (#902, refactored by #907).**
New pure module `analysis/weinstein/stage3_force_exit/` with `observe` / `observe_position` primitives and `hysteresis_weeks` config. Integrated into `weinstein_strategy.ml` as a fourth exit channel (after stops, force-liq, and before entries). Opt-in: `enable_stage3_force_exit = false` by default — baselines unchanged. PR #907 immediately followed with a core-module cleanup: replaced the Weinstein-specific `Stage3ForceExit` variant in `Position.exit_reason` with the generic `StrategySignal { label : string; detail : string option }` shape (qc-behavioral A1 finding), making the core `Position` module strategy-agnostic again.

**Crash fix for adjust-vs-exit collision (#911).**
Root cause: `weinstein_strategy.ml` concatenates `exit_transitions @ ... @ adjust_transitions @ entries`. When `Stops_runner` emits `UpdateRiskParams` (stop-raise) for position P on the same tick that any exit channel emits `TriggerExit` for P, the simulator transitions P to Exiting and then applies the adjust — `Position.apply_transition (Exiting, UpdateRiskParams)` is an invalid transition. This raises, the child crashes silently (no `actual.sexp`), the parent reports "did not write actual.sexp". The fix: filter `adjust_transitions` against the union of all exit-channel position ids before concatenation. Second fix: crash handler now writes a sentinel `actual.sexp` with `crashed = true` + exception string so failures are visible in the run table. This explains why #906's 5y K=1 worked (stochastic non-collision over 260 weeks) while every 15y cell crashed (882 weekly cycles with 60+ held positions guaranteed the collision).

**Laggard rotation detector + runner (#909).**
New module `analysis/weinstein/laggard_rotation/` implementing Weinstein Ch.4 §5.6. Measure: rolling 13-week return of the position vs the benchmark's rolling 13-week return. A laggard is a position whose RS_13w has been negative for ≥ K consecutive Fridays (default K=4). Fires after stops and Stage-3 exits, before entries. Uses the same generic `StrategySignal` exit_reason (`label = "laggard_rotation"`). Opt-in: `enable_laggard_rotation = false` by default. 19 unit tests covering hysteresis edges, whipsaw resets, and the bear-market both-negative comparison case.

**All-eligible diagnostic tool (#899, #901, #904, #908).**
New `Backtest_all_eligible` library + `all_eligible.exe` CLI. Scans all Stage-2 first-admissions in a universe, grades each against the cascade, and reports trade statistics at each quality floor. Dedup fix (#904) collapsed consecutive Friday re-firings of the same breakout into 1 trade (was inflating counts ~8%). Grade sweep (#908) added `--grade-sweep` mode and the opportunity-cost framing: min_grade=C admits 5,300 trades at -10% mean return vs live strategy's 81 trades at +58.34%.

**screener `min_score_override` knob + `grid_search.exe` CLI (#892, #893).**
`Screener.config` gains `min_score_override : int option` field (default `None`), enabling numeric cascade-score floor sweeps from the grid-search harness. `grid_search.exe` is now a wired binary under `trading/weinstein/backtest/scripts/`.

**GitHub branch protection (#895).**
`main` now requires `build-and-test` + `perf-tier1-smoke` (strict mode, `enforce_admins: true`, force-push disabled). Before this: `gh pr merge --squash` had no CI gate. PR #883 was merged while CI was FAILED (required the fix-forward #884). This is now a hard block at the GitHub layer.

**Tier4-broad-1y mechanic-validation cell (#897).**
New SCALE cell that runs the full ~10,472-symbol universe × 1y to validate snapshot-corpus auto-build and cache-bounded RSS budget before the multi-hour 10y run. Marked `perf-tier: 4-scale`, auto-discovered by `run_tier4_release_gate.sh`. User-supervised local run still pending.

**Velocity report script (#900, #903, #905).**
`dev/scripts/velocity_report.sh`: reproducible POSIX + jq script that regenerates the PR velocity report for any `--since/--until` window. Added OCaml test/source split to the by-language table. Velocity snapshot: 730 PRs from 2026-03-24 to 2026-05-06, ~260 LOC/PR median, OCaml ~82% of committed lines.

---

## 4. Strategic Implications

**Capital-recycling lever ordering should flip: B (laggard) > A (Stage-3).** The framing note written at session start (PR #896) set up a grid with Stage-3 as the "bigger mechanism to test first." The 5y sweep (#910) refuted that ordering. Laggard at h=4 alone produces +21.1pp; Stage-3 at K=1 alone produces +8.2pp. If further tuning effort goes into one mechanism, it should go into laggard: RS-window alternatives (13w vs 26w vs 4w), hysteresis values (h=1, h=2, h=3), and comparison-universe alternatives (benchmark=SPY vs benchmark=sector ETF).

**The interaction effect at h=2 is the session's main empirical finding.** Cell E is not just "both mechanisms on"; it's "mechanisms partitioned by speed": laggard h=2 fires fast on RS weakness, Stage-3 K=1 fires on MA flattening, and they rarely compete for the same position on the same tick. Cell D (h=4 on both) is the cautionary counterexample — same population, same tick, cancellation. Future parameter sweeps should track "stage3-fires / laggard-fires / both-on-same-position" as diagnostic columns.

**Neutral recycling does not help; selection does.** PR #906 (Stage-3 alone at K=1) produces +8pp and #908 (all-eligible diagnostic) confirms the raw signal population has negative mean return (-10%). The portfolio mechanics (top-N cap, sector concentration limits, cash gate) are not just a filter — they are the alpha source. This has implications for 15y tuning: if Cell E shows weaker alpha on 15y, the first hypothesis should be "portfolio mechanics behave differently over longer regimes" rather than "the exit mechanisms are wrong."

**15y validation is the remaining gate before flipping defaults.** PR #910's recommendation: do not change production defaults (`enable_stage3_force_exit = false`, `enable_laggard_rotation = false`) until 15y Cell E passes. The crash fix is in main (#911). The 15y run needs ~100min wall time. If 15y shows comparable alpha, the flip is straightforward: set both mechanisms on with K=1 / h=2 and repin the goldens.

---

## 5. Known Harness Issues

**Agent worktrees reaped mid-run by `cleanup_merged_worktrees.sh`.** Three agents were killed during this session: two lost work (15y run, a QC review), one recovered after an additional crash-fix cycle (#911). The cleanup script uses `--stale-hours 0` as its effective default: if a branch name has never appeared on origin (i.e., the agent hasn't pushed yet), the script treats it as "deleted from origin → safe to remove." For in-flight agents that haven't pushed their first commit, this is a false positive. The worktree directory is removed while the agent is mid-execution.

Recommended fix: change the cleanup logic to treat "branch never existed on origin" separately from "branch was deleted from origin." Only branches that *previously existed on origin* and are now absent (implying the PR was merged and the remote branch deleted) are safe to reap. Branches that *never existed* on origin should be left alone (minimum stale-hours of 1 or more). Alternatively: enforce that agent worktrees push an empty initial commit within the first minute of execution so origin has a record of the branch.

**QC review persistence failure.** At least two QC agents wrote review files to `dev/reviews/pr-NNN.md` but the worktree-reap deleted the files before the commit could be pushed. The merge-gate decisions (qc-structural PASS, qc-behavioral PASS) were reported as text output in the agent thread and recorded in the PR body, so the merges were defensible — but the review files are absent from `main`. Trust the agent text output for merge-gate records when the review file is missing.

**ocamlformat skew container vs CI.** Container has 0.28.1 (pinned-to-0.29.0 behavior), CI has released 0.29.0. Two known constructs differ: `{[ ]}` docstring block indentation and `(** ... *)` paragraph word-wrap. Two fmt-fix commits landed tonight (#902's inline fix, #907's fmt pass). The `memory/project_ocamlformat_version_skew.md` entry is current. Apply `dune fmt` in the container before pushing; if CI rejects the fmt, apply the CI diff manually (do not auto-promote `--unsafe-allow-all-attributes`).

---

## 6. Tomorrow's First Tasks (Priority Order)

1. **Re-fire the 15y Cell E run.** The crash fix is in `main` (#911, SHA `d24d4bfa`). Run parameters: scenario_runner on the 15y SP500 sexp (likely `data/goldens/sp500-historical/sp500-2010-2024.sexp` or equivalent) with config overrides:
   ```
   --config-overrides "((enable_stage3_force_exit true) (enable_laggard_rotation true) (stage3_force_exit_config ((hysteresis_weeks 1))) (laggard_rotation_config ((hysteresis_weeks 2))))"
   ```
   Expected wall time: ~100 minutes on a quiet box. Use shell directly OR an agent with an explicit guard to NOT isolate to a worktree that the cleanup script will reap. Consider running under `tmux` or `screen` so a session disconnect doesn't kill it.

2. **Interpret 15y Cell E result and decide on default flip.**
   - If 15y shows comparable Sharpe / alpha: flip production defaults (`enable_stage3_force_exit = true`, `enable_laggard_rotation = true`, K=1, h=2) and repin the goldens. Write a decision note to `dev/notes/capital-recycling-defaults-decision-2026-05-07.md`.
   - If 15y shows regression: do NOT flip defaults. Investigate why (longer-duration positions? regime sensitivity? different hit-rate on MA-flatten in bull vs bear years?). The equity-degeneration pattern seen in the crashed run ($30K–$660K range) may be a clue — was the crash exposing a real pathology or purely the adjust-vs-exit collision?

3. **Local tier4-broad-1y mechanic-validation run** (user-supervised). Script: `dev/scripts/run_tier4_release_gate.sh`. This is independent of strategy work and validates ~10k-symbol mechanics. Should run in minutes; clears the prerequisite for the multi-hour 10y SCALE run.

4. **Patch `cleanup_merged_worktrees.sh`** to stop reaping in-flight worktrees. See §5 above for the specific logic change needed. This is a harness item, low code volume, high operational value.

5. **Laggard tuning follow-up (post-15y, if Cell E passes).** Priority sweep candidates:
   - RS window: 13w (current) vs 26w vs 4w
   - Hysteresis: h=1, h=2, h=3 (h=2 already shown best; h=1 may be too noisy)
   - Comparison universe: SPY (current) vs sector ETF (Weinstein's preferred)
   These are medium-complexity experiments; each is a branch + experiment dir + notes file, no production code changes needed.

---

## Appendix: Session Timeline

All timestamps CEST (UTC+2).

```
19:01  #892  screener min_score_override
19:36  #893  grid_search.exe CLI
19:58  #895  GitHub branch protection (T1-S harness item)
20:10  #896  capital-recycling framing note
20:22  #897  tier4-broad-1y SCALE cell
20:33  #898  status refresh
20:46  #899  all-eligible trade-grading lib (PR-1)
21:24  #900  velocity analysis note
21:52  #901  all-eligible runner CLI (PR-2)
22:27  #902  Stage-3 force-exit detector (feat)
22:56  #903  velocity LOC-by-language breakdown
23:35  #905  velocity_report.sh script
23:46  #906  Stage-3 impact experiment (5y OK, 15y CRASH)
00:22  #907  StrategySignal generic refactor (A1 fix)
00:38  #904  all-eligible dedup fix
01:15  #908  all-eligible min_grade + grade sweep
02:08  #909  laggard rotation (feat)
02:58  #910  combined 5-cell sweep — Cell E headline
03:37  #911  crash fix (adjust+exit dedup + crash sentinel)
```
