Reviewed SHA: 26202ddcfd817b762d46f0b2c21933f611cbf612

## Structural QC — PR #2596

**harness: dangling odoc-reference check, WARN-only (#2542 B1)**

Checked out at `26202ddc` via a dedicated plain-git worktree
(`/__w/trading/wt-qc-2596`), detached, never touching the shared
`/__w/trading/trading` checkout (a sibling QC agent was concurrently
reviewing PR #2595 in its own worktree). All `dune` invocations ran via
this worktree's own `./dev/lib/run-in-env.sh`.

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | exit 0 |
| H2 | dune build | PASS | exit 0 |
| H3 | dune runtest | PASS | exit 0, 0 `^FAIL:` lines. Confirms `odoc_dangling_ref_check_test.sh` (7/7 assertions) and the check itself (WARN, 150 scanned / 16 dangling, non-gating exit 0) both ran inside the sandbox. |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | NA | Shell, not OCaml; `fn_length_linter` only scans `.ml`. Manually inspected: largest shell function (`_ident_exists`) is ~20 lines. |
| P2 | No magic numbers — covered by language-specific linter | NA | Shell, not OCaml; `magic_numbers_linter` only scans `.ml`. Not applicable to a POSIX-sh detector script. |
| P3 | All configurable thresholds/periods/weights in config record | NA | No tunable strategy parameters in this PR; the one toggle (`ODOC_DANGLING_REF_CHECK_STRICT`) is an env-var switch, matching the CC-linter's own promotion-toggle precedent, not a strategy config value. |
| P4 | Public-symbol export hygiene (.mli coverage) | NA | Shell scripts, no `.mli` concept. |
| P5 | Internal helpers prefixed per project convention | PASS | `_ident_exists` (and test helpers `ok`/`bad`/`make_fixture_trading_dir`/`run_check`) follow the same underscore-private-helper convention used throughout sibling scripts in this directory (verified against `arch_layer_test.sh`, `budget_rollup_check.sh`, `goldens_affected_check.sh`, etc.). |
| P6-shell | POSIX-sh conformance (`posix_sh_check.sh` / `dash -n`) | PASS | Both new scripts have `#!/bin/sh` shebangs, are scanned by `posix_sh_check.sh` (in scope: `trading/devtools/checks/*.sh`), and independently verified with `dash -n` — clean parse, no bash-isms. |
| P6-shell-conv | Follows house shell-check conventions (header rationale block, fixture-driven self-test, `_check_lib.sh` sourcing, `trading_dir()`/`repo_root()` usage, dune cache-invalidation deps) | PASS | Compared against `linter_file_length.sh`/`linter_file_length_test.sh`, `tracked_artifact_linter.sh`/`_test.sh`, and `backtest_appendix_drift_check.sh`/`_test.sh`. The new pair matches the established shape: extensive rationale header, private `mktemp -d` fixture trees so the test never depends on the real tree's current state, explicit `(glob_files_rec ...)` deps on the dune rule (matches the "Cache-invalidation deps" convention documented at the top of `trading/devtools/checks/dune`). |
| no-python | No `*.py` added; check itself is POSIX sh, not Python | PASS | Confirmed via PR file list — only `.sh` + `dune` + `.md` files changed. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | Pure harness/tooling PR; touches only `trading/devtools/checks/` and `dev/status/cleanup.md`. |
| A2 | `analysis/` → `trading/trading/` dependency-direction rules | NA | No dune library dependency changes; `trading/devtools/checks/dune` only adds two new `(rule (alias runtest) ...)` stanzas with `(deps ...)`/`(action (run sh ...))`, no `(libraries ...)` changes. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | `$PR_FILES` (via GitHub API, not ancestry) = exactly 4 files: `dev/status/cleanup.md`, `trading/devtools/checks/dune`, `trading/devtools/checks/odoc_dangling_ref_check.sh`, `trading/devtools/checks/odoc_dangling_ref_check_test.sh`. The `dune` file diff is a pure append (+35/-0) of two new rule stanzas; no existing rule was altered. `cleanup.md` diff is the expected status-tracking update (closes the `linter_candidate` item, files the new `odoc_dangling_ref_debt` item). No drift into unrelated files. |
| WARN-only design | Weighed on its merits per `.claude/rules/code-health-discipline.md` (measured decision vs. reflexive linter-dodge) | PASS | Not a reflex "bump the limit" — the PR measured the real-tree corpus (36,695 `[...]` spans / 4,926 `{!...}` refs), narrowed to a 0-false-positive pattern, and found **11 distinct pre-existing violations**, past the code-health-discipline "single-digit exceptions" bar for a `linter_exceptions.conf` carve-out. The **CC-linter precedent is real**, not invented: `trading/devtools/checks/dune` line 302 reads verbatim "Cyclomatic complexity: CC > 10 = warning (not failure); exits 0 always." The 11 findings were **not** dropped — they were filed as a new `[ ] odoc_dangling_ref_debt` item in `dev/status/cleanup.md` with every identifier + citing file enumerated, explicitly scoped to `code-health`, with the promotion trigger (`ODOC_DANGLING_REF_CHECK_STRICT=1`) named as the follow-up once the backlog clears. This is the "concrete refactor plan + tracking issue with real owner" shape the discipline doc requires for a limit/gate deferral, applied to a brand-new check rather than a bumped limit — same intent. |
| Silent-breakage risk (WARN-only checks can silently stop working) | Assessed: does the test suite pin behavior strongly enough? | PASS | `odoc_dangling_ref_check_test.sh` is wired as its **own separate, normally-gating** `dune runtest` rule (not itself WARN-only) with 7 fixtures, including a dedicated **fails-closed backstop** (fixture D): a mutant copy with `CANDIDATE_RE` rewritten to match nothing must emit the **distinct** `"0 candidate ... scanned"` message rather than the clean-tree `"...scanned; 0 dangling"` message. If the shipped detector's regex ever regressed to matching nothing, fixture B (regression-shape RED) and fixture D1 (baseline confirms 1 dangling) would both go from PASS to FAIL, and the test script's own `exit 1` on any `$FAIL -gt 0` would red the build via the normal `^FAIL:` gate — independent of the checked script's own permanent `exit 0`. This structurally closes the "always-green means nobody notices it broke" risk for a non-gating check. |

## Independent re-derivation of the PR's quantitative claims

Ran directly against the real tree at this SHA (not from the PR body):

- `sh trading/devtools/checks/odoc_dangling_ref_check.sh` → **150 candidate doc-identifier reference(s) scanned; 16 dangling reference(s) found**, listing all 16 occurrences. Extracted the identifiers from the output and deduplicated: **11 distinct**. This matches the PR body's claimed "150 raw / 96 distinct selected... 16 raw / 11 distinct genuinely dangling" on the load-bearing halves (the 16/11 dangling figures, which are the numbers that matter for the WARN-only decision) exactly, digit for digit.
- `sh trading/devtools/checks/odoc_dangling_ref_check_test.sh` (run standalone, outside dune) → all **7/7 assertions pass** (fixtures A/B/C/D1/D2/E×2), matching the PR's "Mutation transcript (7/7 assertions)" claim.
- `{!...}` odoc-reference total count: independently grepped **4,926** — exact match to the PR's claimed corpus figure.
- `[...]` code-span total count: independently grepped with a simple non-nested-bracket approximation and got **39,071** vs. the PR's claimed **36,695** — a ~6% discrepancy. This number is **documentation/rationale only** (motivates why a broad, unnarrowed check would be unusable); it is not consumed by `CANDIDATE_RE` or any code path that gates behavior, and the actually-operative narrowed-pattern numbers (150/96/16/11) reproduce exactly. Not a structural defect — noting for the record in case a future reader wants to tighten the header's own counting methodology.
- Full `dune runtest` output line 3603 independently confirms the same `150 candidate ... 16 dangling` result from inside the dune sandbox, matching the standalone run.

## Quality Score

5 — Exemplary: builds/tests/fmt all green, a real measured trade-off (not a linter-dodge) backed by a legitimate precedent, an explicit fails-closed self-test closing the WARN-only check's own blind spot, residual debt filed rather than dropped, and every quantitative claim independently reproduced digit-for-digit on the operative numbers.

## Verdict

APPROVED
