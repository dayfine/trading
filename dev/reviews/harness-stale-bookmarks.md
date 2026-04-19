Reviewed SHA: 45095f30e7d7cf0505def34793c1a31f332516f6

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No OCaml files changed; shell/dune/md files have no dune fmt rules |
| H2 | dune build | PASS | Exit 0 |
| H3 | dune runtest | PASS | Exit 0 on clean build. Pre-existing linter FAIL text (nesting_linter, fn_length_linter, status_file_integrity) is also present on main@origin and is not caused by this branch. New smoke test (deep_scan_stale_bookmarks_check.sh) passes: "OK: deep scan Stale Local Bookmarks section (harness gap sub-item 4) structural check passed." |
| P1 | Functions ≤ 50 lines (fn_length_linter) | NA | No OCaml source files changed |
| P2 | No magic numbers (linter_magic_numbers.sh) | NA | No OCaml source files changed |
| P3 | All configurable thresholds/periods/weights in config record | NA | Shell-only change; no configurable numeric parameters introduced |
| P4 | .mli files cover all public symbols (linter_mli_coverage.sh) | NA | No OCaml source files changed |
| P5 | Internal helpers prefixed with _ | NA | Shell functions: `_is_protected_bookmark` follows the convention |
| P6 | Tests use the matchers library | NA | No OCaml test files changed |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No OCaml files touched at all |
| A2 | No imports from analysis/ into trading/trading/ | NA | No OCaml files changed |
| A3 | No unnecessary modifications to existing (non-feature) modules | FAIL | `deep_scan.sh` header comment says "Performs ten read-only analyses:" and lists checks 1–10, but Check 11 (stale bookmarks) was added to the implementation without updating the header count or numbered list. The file is in scope (modified by this PR), so the stale documentation is a required fix. |

## FLAG: Check 11 numbering collision

`harness/deep-scan-stale-bookmarks` and `harness/deep-scan-linter-expiry` (#435, open) both claim "Check 11" in `deep_scan.sh`. The marker comments, header labels, and report section labels will collide when either PR is merged followed by the other. This is a review-meta FLAG, not a FAIL — the human resolves it at merge time by renumbering whichever PR merges second. The collision does not block APPROVED on its own, but A3 already yields NEEDS_REWORK.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### A3: Stale "ten" count and missing item 11 in deep_scan.sh header

- Finding: `deep_scan.sh` lines 4–14 state "Performs ten read-only analyses:" and enumerate only checks 1–10. This PR adds Check 11 (stale local jj bookmarks) to the implementation but leaves the header count and numbered list unchanged. Every reader of the file header gets a false picture of the script's scope.
- Location: `/__w/trading/trading/trading/devtools/checks/deep_scan.sh` lines 4 and 14 (header block)
- Required fix: Change "ten" to "eleven" and append `#  11. Stale local jj bookmarks — local-only and behind-origin bookmark detection` to the numbered list in the header comment. (If the linter-expiry PR merges first and claims 11, renumber this check to 12 and update accordingly.)
- harness_gap: LINTER_CANDIDATE — a simple grep for the count word in the header vs the number of `# Check N:` markers in the file could detect this mechanically. Not currently encoded as a dune test.
