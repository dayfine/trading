Reviewed SHA: 7ce511e512c1ed308fc04871c929c3889932f3c6

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | NA | No OCaml files — shell-only PR |
| H2 | dune build | NA | No OCaml files — shell-only PR |
| H3 | dune runtest | NA | No OCaml files — shell-only PR |
| P1 | Functions ≤ 50 lines (linter) | NA | Shell scripts; no dune linter applies |
| P2 | No magic numbers (linter) | NA | Shell scripts; thresholds in env-var defaults (LAUNCH_SWEEP_DISK_FREE_GB_MIN=50, etc.) are intentionally configurable parameters, not magic literals |
| P3 | Config completeness | PASS | All tunable thresholds are env-var overridable with sensible defaults. launch_sweep.sh (6 thresholds: disk_free_min, docker_raw_max, worktree_stale_hrs, etc.). sweep_disk_watcher.sh (4 thresholds: host_free_min, raw_warn, raw_kill, tmp_warn). All exposed as LAUNCH_SWEEP_* and DISK_WATCHER_* env vars in the header. |
| P4 | Public-symbol export hygiene (linter) | NA | Shell scripts; no module system |
| P5 | Internal helpers prefixed per convention | PASS | Helpers consistently prefixed with underscore: _kill() in sweep_disk_watcher.sh. Helper functions (check_disk_free, check_docker_raw, check_container_running, check_bind_mount, check_no_existing_runner, check_no_stale_worktrees) prefixed with check_ per script convention. Log helpers (log, err) unprefixed but are top-level utilities, consistent with shell script idiom. |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | No OCaml tests — shell tests are fixture-driven bash fixtures with standard bash assert idioms (grep, exit-code checking). Not under the OCaml test-pattern rules. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | Shell-only infra; no core modules touched |
| A2 | No new analysis/ imports into trading/trading/ | NA | Shell-only infra; no dune dependencies |
| A3 | No unnecessary existing module modifications | NA | Only new files; no existing modules modified |

## Test Results

Both test suites pass cleanly:
- **sweep_disk_watcher_test.sh**: 9/9 scenarios PASS (all clear, host-disk-low, docker-raw warn/kill, container-tmp warn, dead PID, usage errors, name validation, log-file write)
- **launch_sweep_test.sh**: 10/10 scenarios PASS (all preconditions, dry-run, each of 6 failures, usage/name validation, multi-failure reporting)

## Shell Linter

POSIX-sh linter (`trading/devtools/checks/posix_sh_check.sh`) passes: 55 scripts clean (no new violations).

## Code Quality

**launch_sweep.sh** (+21 lines):
- Enforces 6 critical preconditions before launching Bayesian sweep (disk free, Docker.raw size, container running, bind-mount present, no concurrent runner, no stale worktrees).
- Exits with status code 2 on precondition failure (all failures reported, no short-circuit).
- Spawns disk watcher subprocess in background (lines 325–344), conditional on watcher presence + PID availability. Handles backward compatibility (older checkouts without watcher don't fail).
- Comments explain the rationale (PR-A of sweep-and-qc-architecture-2026-05-26.md) and the six checks.

**sweep_disk_watcher.sh** (+20 lines):
- New cross-VM kill helper `_kill()` (lines 153–160) routes `kill -SIG <pid>` through `docker exec <container> kill` when --container is set, otherwise direct. Comment explains macOS Docker Desktop PID-namespace issue.
- Hook points for testing: env-var overrides for df/du/docker/kill binaries (DISK_WATCHER_DF_BIN, etc.) + MAX_ITERATIONS cap for unit tests.
- Threshold evaluation (evaluate_thresholds, lines 169–196) emits ONE KILL decision per iteration (correct: `should_kill` flag prevents spurious retries).
- Watch loop (lines 205–229) checks PID liveness first, then thresholds, then test-mode cap. Proper sequencing.

**sweep_disk_watcher_test.sh** (+20 lines):
- Mock factory (make_mocks, lines 38–96) generates per-scenario df/du/docker/kill stubs with canned output.
- Docker mock correctly handles dual modes: `docker exec <ctr> du -sk /tmp` and `docker exec <ctr> kill -SIG <pid>`, disambiguated by positional args.
- Scenario 6 (dead PID) verifies the watcher exits cleanly on sweep completion.
- Scenario 9 verifies log-file creation and append-only semantics.

## Integration Points

- **launch_sweep.sh lines 326–344**: Spawns watcher with `nohup`, closes stdout/stderr (`>/dev/null 2>&1`), captures WATCHER_PID, logs it. Respects watcher absence (backward compat on older checkouts).
- **Watcher <-> runner communication**: kill -0 for liveness probe (line 209), kill -TERM for graceful abort (line 218). Both routed through _kill() helper to handle macOS Docker Desktop cross-VM issue.
- **Fallback path**: If CONTAINER is unset, _kill() calls KILL_BIN directly (line 158) — single-machine mode still works.

## Architecture Alignment

Per `.claude/rules/sweep-hygiene.md`:
- **PR-A (launch_sweep.sh enforcement)**: Six preconditions prevent the 2026-05-23/24 failures (disk fill, Docker.raw runaway, concurrent runners, stale worktrees).
- **PR-C (watcher)**: Disk polling during sweep to abort before catastrophic fill (the launch-time check alone isn't enough once snapshot churn begins mid-flight).
- **Bind-mount requirement**: Check 4 enforces `/tmp/sweeps` bind-mounted (the root cause of Docker.raw inflation).
- **Output path discipline**: Launch respects `--out-dir /tmp/sweeps/<name>` (lines 276–277).

## Verdict

**APPROVED**

All structural gates pass or are legitimately NA. Both test suites 100% clean. POSIX linter passes. Code is defensive (precondition gates, error messages, backward compat), well-commented, and properly integrated into the sweep launch pipeline. No behavioral checks required (shell infra only).

---

# Behavioral QC — launch-sweep-wire-watcher
Date: 2026-05-25
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No `.mli` files in this PR — shell-only diff (3 files: `launch_sweep.sh`, `sweep_disk_watcher.sh`, `sweep_disk_watcher_test.sh`). Header-comment "contracts" evaluated under CP2/CP4 instead. |
| CP2 | Each claim in PR body "Test plan" / "Test coverage" sections has a corresponding test in the committed test file | PASS_WITH_NOTE | PR body lists two test-coverage claims, both checked: (a) **watcher mock extension** ("mock `docker` was extended to handle `exec <container> kill -0` and `exec <container> kill -TERM`") — VERIFIED in `sweep_disk_watcher_test.sh` lines 60–79 (docker mock now has `exec kill` case with `-0` / `-TERM` branches). (b) **pin via scenarios 2/4 + scenario 6** ("same `pid_alive` / `kill_calls` markers verify both the liveness-check path and the SIGTERM dispatch through the new `_kill` helper") — VERIFIED: scenario 2 (line 151) asserts `TERM sent to pid=99999` in `kill_calls`; scenario 4 (line 184) asserts `kill_calls` exists; scenario 6 (line 211, `pid_alive=0`) asserts the watcher exits with "sweep pid=99999 exited". All three scenarios pass `--container fakectr` (COMMON_ARGS line 124), so they EXCLUSIVELY exercise the docker-exec branch of `_kill`. The fallback `${KILL_BIN}` branch (lines 157–158) is structurally unreached by any scenario — but PR body doesn't claim it is, so no contract violation. The PR body also notes "10/10 PASS (unchanged)" for `launch_sweep_test.sh`; verified clean. **Note (non-FAIL):** PR body explicitly admits the watcher-spawn log-line claim is "Verified via log line emission only; manual smoke covered by the existing 10-scenario launch_sweep test" — the dispatch prompt accepts this trade-off. Recorded here for transparency, not as a CP2 fail (no false claim in the PR body). |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...]), not just size_is | NA | No pass-through / identity semantics in this PR. Tests assert (exit-code, log-line match, kill_calls file existence/content). All assertions pin exact content (`grep -q 'TERM sent to pid=99999'`, `grep -q 'host_free=15GB < 20GB minimum'`), not just count/size. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PARTIAL_FAIL | Three guards present in new code; only one is pinned. (a) **`_kill` docstring** ("Required on macOS Docker Desktop where the container runs in a Linux VM and its PID namespace is NOT visible from the host") — guarded behavior PINNED by scenarios 2/4/6 which all use `--container fakectr` and verify TERM/-0 routes through the docker mock. PASS. (b) **`launch_sweep.sh` line 326 guard** ("Conditional: only if the script is present (older checkouts won't have it)") — `[[ -x "${WATCHER}" && -n "${PID}" ]]` — NO test covers either branch (script absent → no log line; PID empty → no log line). All 10 `launch_sweep_test.sh` scenarios use `--dry-run` and exit at line 303 BEFORE the launch+spawn block runs. (c) **`launch_sweep.sh` line 312–314 comment** ("Give the runner a moment to fork before we resolve the PID; without this pgrep can return empty on a slow container") — `sleep 2` + the empty-PID handling at line 319 — also unreachable in `--dry-run` test scenarios. **However:** the dispatch prompt explicitly authorizes this trade-off ("Verified via log line emission only; manual smoke covered by the existing 10-scenario launch_sweep test"). The integration block runs only on a real container with a real sweep, and the launch_sweep_test harness deliberately doesn't construct that. Recording as PARTIAL_FAIL only to flag it should the watcher-spawn wire-up ever regress: a `--no-dry-run` scenario with a mocked `bash -c` runner-cmd would pin the "spawned disk watcher pid=..." log line and the two guards above. **Verdict treatment:** the PR body is honest about this gap and the dispatch authorizes the trade-off, so this does NOT block APPROVED — but a follow-up is warranted. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Pure infra / harness PR; domain checklist not applicable. No `trading/trading/` or `analysis/weinstein/` files touched. |
| S1–S6 | Weinstein stage definitions and buy criteria | NA | Pure infra / harness PR; domain checklist not applicable. |
| L1–L4 | Stop-loss rules | NA | Pure infra / harness PR; domain checklist not applicable. |
| C1–C3 | Screener cascade order | NA | Pure infra / harness PR; domain checklist not applicable. |
| T1–T4 | Domain-outcome test assertions | NA | Pure infra / harness PR; domain checklist not applicable. |

## Quality Score

4 — Clean, surgical wire-up + correct docker-exec routing for macOS-VM PID isolation. The `_kill` helper is the right abstraction (single point of policy), the test changes correctly extend mock to record both `-0` and `-TERM` through `docker exec`, and scenarios 2/4/6 collectively pin the docker-routed liveness + SIGTERM paths. Loses one point only for the unpinned launch_sweep wire-up (the "spawned disk watcher pid=..." log line and the two guards at lines 326 + 313 have no test scenario — addressable via a `--no-dry-run` mock scenario in `launch_sweep_test.sh` as a follow-up). PR body is honest about this gap.

## Verdict

APPROVED

(Behavioral verdict: APPROVED with one follow-up suggestion. CP2 PASS (with note), CP4 PARTIAL_FAIL but explicitly authorized by the dispatch prompt and PR body — not a contract violation since no false claim was made.)

## Follow-up suggestion (non-blocking)

Add an 11th scenario to `launch_sweep_test.sh` that:
- Mocks `docker exec -d <ctr> bash -c <runner-cmd>` to a no-op exit-0.
- Mocks `docker exec <ctr> pgrep -f 'bayesian_runner\.exe'` to return a fake PID (e.g. "99999") after the `sleep 2`.
- Mocks the watcher script with a `nohup`-survivable stub that exits-0 immediately.
- Asserts the `spawned disk watcher pid=` line appears in stdout AND a watcher-absence variant (script unset / not executable) asserts the line does NOT appear.

This pins CP4 guard (b) — backward-compat with older checkouts — and CP4 guard (c) — empty PID resolution. ~30 minutes; adds full coverage of the wire-up block.
