Reviewed SHA: fc9dc23aa20d36555e25b28d3d61f673a3606f09

# Structural QC — PR #2595 (harness/2589-expiry-o2-o3)

## Scope (per `gh pr view 2595 --json files` / GitHub API — not git ancestry)

```
dev/status/harness.md
trading/devtools/checks/deep_scan_linter_expiry_check.sh
```

No `.ml`/`.mli`/`dune` files touched. Pure POSIX-shell test-harness change +
its status-file record.

## Gates (run inside this agent's own worktree, `/__w/trading/wt-qc-2595` @
fc9dc23a, via `./dev/lib/run-in-env.sh`, unpiped exit codes)

| Gate | Command | Exit |
|---|---|---|
| H1 | `dune build @fmt` | 0 |
| H2 | `dune build` | 0 |
| H3 | `dune runtest` (full suite) | 0, zero `^FAIL:` lines |

`deep_scan_linter_expiry_check.sh` runs inside `dune runtest` (confirmed wired
via `trading/devtools/checks/dune:325`, `(run sh %{dep:deep_scan_linter_expiry_check.sh})`)
and produced all **16** `OK:` lines with no `FAIL:`, matching the PR body's claim
verbatim. Also ran the script standalone (`sh
trading/devtools/checks/deep_scan_linter_expiry_check.sh`) — identical 16
`OK:` lines, exit 0. `posix_sh_check.sh` — `OK: posix-sh linter -- 85 scripts
clean.`

## Independent mutation reproduction (O2)

Per the dispatch brief, independently reproduced the O2 evasion in a scratch
tree (`/tmp/qc2595-mutation-repro`, outside any worktree under review, cleaned
up afterward — did not touch `/__w/trading/wt-qc-2595`):

1. Copied the **unmutated** production `check_11_linter_expiry.sh` +
   `_lib.sh`/`_check_lib.sh` and built the same three-conf-file fixture Part 5
   uses (`fixture_stale_le_entry` in `linter_exceptions.conf`,
   `fixture_expired_field` in `adapter_effectiveness_exceptions.conf`, plus the
   two O3 universe-deps fixtures). Baseline run: exit 0, roll-up `W:` line for
   `fixture_stale_le_entry` present, as expected.
2. Independently constructed the O2 evasion shape (own `awk` invocation, not
   copy-pasted from the PR's test script) — inserted
   `case "${label}" in Adapter*) : ;; *) continue ;; esac` immediately before
   the date-branch `add_warning` call. Confirmed via `diff` that exactly one
   line was inserted at the intended location.
3. Ran the mutated script: **exit 0**, AE roll-up line (`Adapter-effectiveness
   exception expiry: fixture_expired_field ...`) present, LE roll-up line
   (`Linter exception expiry: fixture_stale_le_entry ...`) **silently gone** —
   reproduces the exact green-while-broken evasion the PR describes.
4. Ran the PR's actual 5a assertion logic (`[ "$AE_CODE3" -eq 0 ] && grep -q
   '^W: Linter exception expiry: fixture_stale_le_entry review date .* has
   passed'`) against both runs: **PASS on baseline, RED (correctly fails
   closed) on the mutated script.** Non-vacuous, as claimed.
5. Separately verified the PR's stated vacuity trap: a bare
   `grep -q '^W: Linter exception expiry:'` (no fixture-name anchor) **does
   wrongly PASS** under the mutation — it matches the unrelated
   "Design doc ... not found" milestone-parse-warning line, which carries the
   same label prefix and survives the mutation untouched. This is exactly the
   failure mode the PR's docstring calls out and the shipped assertion (anchored
   on label + fixture name + "has passed") avoids it.
6. Cleaned up the scratch tree (`rm -rf /tmp/qc2595-mutation-repro`); the
   review worktree (`/__w/trading/wt-qc-2595`) was never touched —
   `git status --porcelain` clean throughout.

Also spot-checked, by reading the production script, that each of the four
`sed` deletion patterns used in Part 6's mutation-proofs (`:113`, `:161`,
`:166`, `:184`) matches **exactly one line** in `check_11_linter_expiry.sh` —
no risk of a pattern collaterally deleting an unrelated line and manufacturing
a false RED/GREEN split. Confirmed via `grep -n` for each pattern.

Did not independently re-run all four Part 6 mutations by hand (O2 was the
one the brief called out as highest-value and the one with the documented
prior evasion history); Part 6's assertions were verified via the full
`dune runtest` pass instead, which exercises the identical code path with no
observed discrepancy from the PR's transcript.

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | exit 0 |
| H2 | dune build | PASS | exit 0 |
| H3 | dune runtest | PASS | full suite, exit 0, zero `^FAIL:` lines; `deep_scan_linter_expiry_check.sh` produced all 16 `OK:` lines |
| P1 | Functions ≤ 50 lines (linter) | PASS | `fn_length_linter` ran clean as part of H3 (`OK: no functions exceed 50 lines.`); also N/A in spirit — this diff is POSIX shell, not OCaml, so the OCaml fn-length linter doesn't scan it, but nothing regressed |
| P2 | No magic numbers (linter) | NA | Shell-script diff; the OCaml magic-numbers linter doesn't apply. Fixture literals (`2019-01-01`, `M2`, `M3`) are test data, not production constants |
| P3 | Configurable thresholds in config record | NA | No new tunable value introduced; this is test scaffolding for an existing check |
| P4 | Public-symbol export hygiene (`.mli` coverage) | NA | No `.mli`/`.ml` files in this diff |
| P5 | Internal helpers prefixed per convention | NA | OCaml `_helper` convention doesn't apply to POSIX shell; shell test file follows the sibling scripts' existing local-variable naming (`AE_*`, `MS_*`, `NF_*` fixture-root prefixes), consistent with house style in this file |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (OCaml + Matchers) | NA | This diff is POSIX shell test tooling (`deep_scan_linter_expiry_check.sh`), not OUnit/Alcotest — the Matchers-library rules do not apply. Checked the shell equivalent instead: `posix_sh_check.sh` passes (`OK: posix-sh linter -- 85 scripts clean.`), and the new Part 5/6 blocks follow the same fixture-root / positive-assertion / mutation-proof structure as the pre-existing Part 1-4 (and the sibling `adapter_effectiveness_check_test.sh` style referenced in the file's own header) |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | Neither changed file is a core module; both are harness/status files |
| A2 | `analysis/` → `trading/trading/` dependency-direction rules | NA | No dune files, no library dependencies touched |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | `$PR_FILES` (from the GitHub API) = exactly `dev/status/harness.md` and `trading/devtools/checks/deep_scan_linter_expiry_check.sh` — both directly in scope for closing O2/O3. No drift into unrelated files |

## Independent verification of the PR's factual claims

- **5 `add_warning()` sites in `_scan_exceptions_conf`**: read
  `trading/devtools/checks/deep_scan/check_11_linter_expiry.sh` directly (not
  taken on faith from the PR body) — confirmed exactly 5 call sites inside the
  function at lines 113, 161, 166, 176, 184, matching the PR's claim exactly.
- **6th branch (missing-`review_at`) never calls `add_warning`**: confirmed by
  reading lines 130-137 — that branch only appends to `_SCAN_MISSING` /
  `_SCAN_MISSING_COUNT` and has no `add_warning` call anywhere in its path.
  The correction to the prior status-file accounting (previously miscounted
  as one of "the five") is accurate, and the newly filed residual
  (`H-EXPIRY-MISSING-REVIEWAT-UNPINNED`) correctly describes it as a distinct,
  still-untested branch.
- **"16 `OK:` lines, exit 0" claim**: reproduced exactly, both standalone and
  inside `dune runtest`.
- **Vacuity-trap claim (bare label-only grep would wrongly pass)**:
  independently reproduced — see step 5 above.

No overclaiming found. The declared residual (`H-EXPIRY-MISSING-REVIEWAT-UNPINNED`)
is filed honestly as still-open rather than folded into this PR's "done" claim.

## Quality Score

5 — All gates pass, the diff is minimal and precisely scoped (2 files, no
drift), the mutation-proof pattern is consistent with the sibling Parts 1-4,
every `sed`/`awk` mutation pattern was verified to match exactly one line
(no collateral-deletion risk), and the PR's most load-bearing and previously-
contested claim (the O2 roll-up wiring is per-conf-file, not AE-specific, and
the fix is non-vacuous) was independently reproduced from scratch and holds.

## Verdict

APPROVED

## NEEDS_REWORK Items

(none — verdict is APPROVED)
