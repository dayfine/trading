Reviewed SHA: ae19e3af9f6cfb0d135f0a214b9d026af831cf66

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; no OCaml files changed |
| H2 | dune build | PASS | Exit 0 |
| H3 | dune runtest | PASS | Exit 1 on both main and feature branch identically — pre-existing failures (fn_length_linter: runner.ml:193; nesting_linter: 49 functions; magic_numbers_linter: weinstein_strategy.ml, trace.ml; arch_layer: screener dune files; file_length: weinstein_strategy.ml). None introduced by this branch. deep_scan_stale_bookmarks_check.sh: OK. |
| P1 | Functions ≤ 50 lines (fn_length_linter) | PASS | H3 linter output unchanged vs main; no new violations introduced by this branch (shell script only) |
| P2 | No magic numbers (linter_magic_numbers.sh) | PASS | H3 linter output unchanged vs main; no new violations introduced |
| P3 | All configurable thresholds/periods/weights in config record | NA | No OCaml files changed |
| P4 | .mli files cover all public symbols (linter_mli_coverage.sh) | PASS | No OCaml files changed; mli linter passes as part of H3 for existing code |
| P5 | Internal helpers prefixed with _ | NA | No OCaml files changed |
| P6 | Tests use the matchers library | NA | No OCaml test files changed |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to any core modules |
| A2 | No imports from analysis/ into trading/trading/ | PASS | No OCaml source files changed |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Rework commit touches only trading/devtools/checks/deep_scan.sh lines 4 and 15: "ten" → "eleven" and adds Check 11 enumeration line. Header count now matches the 11 numbered items and implementation. Prior FAIL resolved. |

## FLAG (carried forward from prior review)

Check 11 collision with open PR #435 (harness/deep-scan-linter-expiry), which also claims "Check 11". Resolved at merge time by human renumbering the second-merging PR. Not a FAIL.

## Verdict

APPROVED

---

# Behavioral QC — harness-stale-bookmarks
Date: 2026-04-19
Reviewer: qc-behavioral

## Scope note

This is a pure harness maintenance PR. It adds `Check 11: Stale local jj bookmarks` to `trading/devtools/checks/deep_scan.sh` plus a structural smoke test. The diff touches only harness shell scripts, dune registration, dev/status, and dev/health report fixtures. No Weinstein analysis, screener, portfolio, stop, or strategy modules are modified. Almost all Weinstein-domain checklist items are therefore NA; behavioral QC focuses on intent / correctness of the harness check itself.

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | No core modules touched; structural QC did not flag A1. Only files under `trading/devtools/checks/` + `dev/` changed. |
| S1 | Stage 1 definition matches book | NA | No stage classification logic in this change. |
| S2 | Stage 2 definition matches book | NA | No stage classification logic. |
| S3 | Stage 3 definition matches book | NA | No stage classification logic. |
| S4 | Stage 4 definition matches book | NA | No stage classification logic. |
| S5 | Buy criteria match book | NA | No signal/buy logic. |
| S6 | No buy signals in Stage 1/3/4 | NA | No signal logic. |
| L1 | Initial stop below base | NA | No stop-loss logic. |
| L2 | Trailing stop never lowered | NA | No stop-loss logic. |
| L3 | Stop triggers on weekly close | NA | No stop-loss logic. |
| L4 | Stop state machine transitions | NA | No stop-loss logic. |
| C1 | Screener cascade order | NA | No screener code. |
| C2 | Bearish macro blocks all buys | NA | No macro/screener code. |
| C3 | Sector RS vs. market | NA | No sector code. |
| T1 | Tests cover all 4 stage transitions | NA | No stage/domain tests. |
| T2 | Bearish macro → zero buy candidates test | NA | No screener tests. |
| T3 | Stop trailing tests over multiple advances | NA | No stop tests. |
| T4 | Tests assert domain outcomes | NA | No Weinstein-domain tests added. |

## Harness-Correctness Checklist (non-Weinstein; local to this feature)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| HA1 | Check 11 implements stated purpose (classify local jj bookmarks into local-only, behind-origin, in-sync, local-ahead; emit INFO for first two) | PASS | `deep_scan.sh` lines 988–1116: enumerates `jj bookmark list --all 'glob:*'`, parses local + `@origin` entries via awk, classifies using `[ -z origin_commit ]` (local-only), `bm_commit = origin_commit` (in-sync, skipped), and `jj log -r local..origin` non-empty (behind-origin). Local-ahead and unrelated histories are silently skipped per comment on line 1105. Matches spec in `dev/status/harness.md` §Follow-up sub-item 4. |
| HA2 | Protected-prefix filter avoids false positives on first-party work | PASS | Line 1064–1069 `_is_protected_bookmark` matches `main|master|HEAD|trunk` exactly. Feature branches (`feat/*`) and harness branches (`harness/*`) are intentionally not protected — they are the legitimate candidates the check is designed to surface. Dispatch note mentioned `release/*` as protected, but the repo has no such branches and the implementation's narrower list is consistent with the code comment on line 996. Not a false-positive risk. |
| HA3 | Graceful degradation when jj is absent or `.jj/` missing | PASS | Lines 1016–1023: `command -v jj` probe + `[ -d .jj ]` probe; sets `JJ_AVAILABLE=false` with a human-readable `JJ_SKIP_REASON`. Detection block is gated on `if $JJ_AVAILABLE`. Report emission (lines 1207–1238) always runs and prints the skip reason when unavailable — the section header is always emitted as claimed. |
| HA4 | No mutations; read-only operation preserved | PASS | Only three jj invocations: `jj bookmark list --all` (line 1036), `jj log -r <commit>` for description (line 1083), `jj log -r <range>` for ancestry (line 1095). No `jj new/edit/describe/rebase/abandon/bookmark set/bookmark delete/bookmark forget/git push/git fetch` anywhere in the file. No network calls. All jj calls guarded with `2>/dev/null || true` (or `|| echo`) so they cannot crash the script under `set -e`. |
| HA5 | Output advisory only (no exit nonzero on findings) | PASS | Findings routed through `add_info` (line 1114); INFO level does not toggle `ACTION=YES` (lines 1124–1130: only `CRITICAL_COUNT > 0` triggers YES). Matches the deep-scan convention used by Checks 1–10. |
| HA6 | `## Stale Local Bookmarks` section wired into the report | PASS | Lines 1207–1238: section always emitted via `printf` appended to `$OUTPUT_FILE`. Metrics line 1169 also exposes `local-only=<n> behind-origin=<n>` counts. Verified `dev/health/2026-04-19-deep.md` contains the section (sample report in this PR). |
| HA7 | Companion smoke test exercises behavior, not just header existence | PASS | `deep_scan_stale_bookmarks_check.sh` checks nine distinct markers (Check 11 marker, header, graceful-degradation string, both accumulator vars, `jj bookmark list` invocation, section header, both sub-section headers), plus verifies the most-recent `dev/health/*-deep.md` contains the section. That's stronger than header-only — it guards against the check being gutted while leaving the section name intact. (Does not execute deep_scan.sh itself, which is appropriate per the spec's "weekly tool, not per-PR gate" principle.) |
| HA8 | Smoke test registered in dune runtest | PASS | `trading/devtools/checks/dune` lines 155–164 register the smoke test under `(alias runtest)` with `_check_lib.sh` as a dep. Structural QC H3 confirmed it runs (`deep_scan_stale_bookmarks_check.sh: OK`). |
| HA9 | Header enumeration matches implementation | PASS | Prior FAIL (A3) resolved in rework commit: header count now reads "eleven read-only analyses" (line 4) and enumerates items 1–11 (lines 5–15). Numbering matches the eleven `Check N:` blocks in the body. |
| HA10 | Weinstein book conformance | PASS | Trivially PASS: no Weinstein domain code touched. No stage, screener, stop, or macro logic modified. |

## Minor observation (not a FAIL)

The range-test heuristic on line 1095 (`jj log -r "${bm_commit}..${origin_commit}"` non-empty → behind) will also classify **unrelated histories** (no common ancestor) as "behind origin", contrary to the code comment on line 1093 which says "unrelated histories are skipped silently". In practice unrelated histories between local bookmark and `@origin` ref for the same name shouldn't arise in a colocated jj repo, and the output is INFO-level advisory only, so any mild false positive is self-correcting with one visual inspection. Not a blocker.

## Quality Score

4 — Clean, defensive implementation: correct classification logic, proper graceful degradation, read-only guarantees, strong smoke test coverage. Minor nit on the unrelated-histories edge case (documented but not handled) is the only reason this isn't a 5. No domain logic risk since no Weinstein code is touched.

## Verdict

APPROVED

