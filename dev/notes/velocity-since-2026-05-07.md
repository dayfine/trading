# Velocity since 2026-05-07

**Window:** 2026-05-07 to 2026-05-23 (17 days inclusive).
**Source:** `gh pr list --repo dayfine/trading --state merged --search "merged:>=2026-05-07 merged:<=2026-05-23"` (run 2026-05-23 08:27Z).

## Headline

- Total PRs merged: 343
- Total LOC raw (add+del): 2354606
- Total LOC net (add−del): 1479670
- Average PRs/day: 20.1 (calendar)

**Note on LOC outlier:** PR #873 ("harness: CI golden runs postsubmit") contributed +/− LOC as generated CSV test-fixture data (997 files of ~4,360 lines each). Excluding it: raw 2354606, net 1479670 — these numbers are more representative of active development churn.

## By category

Categories are parsed from the Conventional-Commits prefix in the PR title (the word before `:`). PRs with no conventional prefix are classified `other`.

| Category | PRs | % PRs | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| feat | 90 | 26.2% | 1236364 | 81204 | 1317568 | 1155160 |
| docs | 65 | 19% | 21955 | 929 | 22884 | 21026 |
| cleanup | 47 | 13.7% | 4743 | 3823 | 8566 | 920 |
| fix | 44 | 12.8% | 12078 | 2478 | 14556 | 9600 |
| ops | 40 | 11.7% | 9642 | 256 | 9898 | 9386 |
| experiments | 12 | 3.5% | 3894 | 6 | 3900 | 3888 |
| harness | 10 | 2.9% | 1180 | 50 | 1230 | 1130 |
| experiment | 7 | 2% | 8012 | 0 | 8012 | 8012 |
| chore | 4 | 1.2% | 302 | 306 | 608 | -4 |
| perf | 4 | 1.2% | 162 | 40 | 202 | 122 |
| test | 3 | 0.9% | 335 | 6 | 341 | 329 |
| investigation | 2 | 0.6% | 712 | 0 | 712 | 712 |
| plan | 2 | 0.6% | 1073 | 0 | 1073 | 1073 |
| refactor | 2 | 0.6% | 147 | 100 | 247 | 47 |
| rules | 2 | 0.6% | 421 | 0 | 421 | 421 |
| tuning | 2 | 0.6% | 434 | 0 | 434 | 434 |
| analysis | 1 | 0.3% | 295 | 0 | 295 | 295 |
| audit | 1 | 0.3% | 432 | 0 | 432 | 432 |
| ci | 1 | 0.3% | 499658 | 0 | 499658 | 499658 |
| data | 1 | 0.3% | 114537 | 348252 | 462789 | -233715 |
| fixture | 1 | 0.3% | 19 | 18 | 37 | 1 |
| infra | 1 | 0.3% | 343 | 0 | 343 | 343 |
| plans | 1 | 0.3% | 400 | 0 | 400 | 400 |
| **TOTAL** | **343** | **100%** | **1917138** | **437468** | **2354606** | **1479670** |

## By language

**Source:** per-file `{path, additions, deletions}` from `gh pr list --json number,files` + REST API pagination for any PR with exactly 100 files (100-file truncation in the GitHub GraphQL `files` field).

**Note on LOC outlier:** PR #873 contributed 0 CSV additions (500 files of generated SP500 golden-run fixtures). The CSV (ex-#873) row gives adjusted totals.

| Language | PRs touched | Files touched | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| CSV | 13 | 162 | 510278 | 0 | 510278 | 510278 |
| CSV (ex-#873) | 12 | 162 | 510278 | 0 | 510278 | 510278 |
| OCaml source (total) | 172 | 504 | 54151 | 7895 | 62046 | 46256 |
| — OCaml source (lib) | 163 | 347 | 31665 | 6784 | 38449 | 24881 |
| — OCaml source (test) | 101 | 157 | 22486 | 1111 | 23597 | 21375 |
| Markdown | 235 | 233 | 34610 | 1321 | 35931 | 33289 |
| Sexp / scenario | 64 | 663 | 1108407 | 427998 | 1536405 | 680409 |
| Shell | 20 | 14 | 1593 | 89 | 1682 | 1504 |
| Other | 20 | 28 | 966 | 8 | 974 | 958 |
| Dune | 68 | 85 | 1223 | 83 | 1306 | 1140 |
| YAML / GHA | 11 | 11 | 709 | 49 | 758 | 660 |
| JSON | 32 | 37 | 936 | 22 | 958 | 914 |
| Docker | 2 | 1 | 23 | 3 | 26 | 20 |
| **TOTAL** | **341** | **1738** | **1712896** | **437468** | **2150364** | **1275428** |

_"PRs touched" = unique PR count where at least one file in the bucket was modified. "Files touched" = unique file paths. Buckets: OCaml = `*.ml`/`*.mli`; OCaml (lib) = OCaml files NOT under any `/test/` directory; OCaml (test) = OCaml files under `/test/`; Dune = `dune`, `dune-project`, `*.opam`; Sexp = `*.sexp`; Shell = `*.sh`/`*.bash`; YAML = `*.yml`/`*.yaml`; Docker = `Dockerfile`/`*.dockerignore`; Other = everything else._

_Bin and scripts (`*/bin/*.ml`, `*/scripts/*.ml`) count as source (lib), not test. Only paths containing `/test/` qualify as test._

## Per-month rollup

| Month | PRs | Raw LOC | Net LOC | Top categories by PR count |
|---|---:|---:|---:|---|
| 2026-05 | 343 | 2354606 | 1479670 | feat(90), docs(65), cleanup(47) |

## Methodology

- Categorization is from the PR title's Conventional-Commits prefix; if a PR was mis-prefixed, it is mis-classified here.
- PRs with no conventional prefix are classified `other`.
- The `harness` category is a project-local prefix (not part of standard Conventional Commits) used for tooling/linter/agent-definition changes.
- Raw LOC double-counts modifications; net LOC under-counts effort on refactors. Both are shown.
- Squash-merge style means each PR = one commit on main; LOC reflects the squashed delta.
- **100-file truncation:** `gh pr list --json files` truncates file lists at 100 entries per PR. For any PR with exactly 100 files, this script falls back to `gh api repos/dayfine/trading/pulls/<N>/files --paginate` to retrieve the complete list. Verified for this window: PR #873 (997 files via pagination).
- **OCaml test vs source split:** after the `*.ml`/`*.mli` extension match, the path is checked for `/test/` as a substring. Paths containing `/test/` are classified as test; all others (including `/lib/`, `/bin/`, `/scripts/`) are classified as lib/source. The total OCaml row equals lib + test (asserted before output).
- **CSV (ex-#873):** subtracts only the CSV-file-specific lines from PR #873 (computed from per-file data), not the full PR additions/deletions.
- Time window inclusive on both ends. Day count uses UTC midnight to avoid DST-boundary off-by-one errors.
- Excludes: PRs not merged (closed-without-merge).
- Script: `dev/scripts/velocity_report.sh --since 2026-05-07 --until 2026-05-23`

## OCaml comment LOC — snapshot of current working tree

This section is a **snapshot** of the codebase at report time, not a delta over the window. The standard PR-delta tables above count added/deleted lines without distinguishing code from comment — to answer "how much of our OCaml is comments?" the question is naturally a state question, not a delta.

**Source:** every tracked `*.ml` / `*.mli` file (`git ls-files`, excluding `test_data/`). Each line is classified `code` / `comment` / `blank` by a small awk state machine that tracks `(* ... *)` nesting depth (including `(** ... *)` doc comments). Strings containing the literal `(*` are not specially handled — rare and accepted as noise. Lines containing **both** code and comment are classified `code` (their primary content).

| Bucket | Files | Code | Comment | Blank | Total | Comment % |
|---|---:|---:|---:|---:|---:|---:|
| lib (`*.ml` + `*.mli`, ex-`/test/`) | 648 | 44,818 | 24,677 | 7,204 | 76,699 | **32.2%** |
| — `*.ml` only (impl) | — | 38,564 | 8,188 | — | 46,752 | 17.5% |
| — `*.mli` only (interface) | — | 6,254 | 16,489 | — | 22,743 | **72.5%** |
| test (`*.ml` + `*.mli` under `/test/`) | 249 | 64,221 | 11,911 | 6,194 | 82,326 | **14.5%** |
| **All OCaml** | **897** | **109,039** | **36,588** | **13,398** | **159,025** | **23.0%** |

### Observations

- **The repo is 23% comments** across all OCaml. That's high by typical OCaml-project norms — `.mli` docstrings carry most of it.
- **`.mli` is 72.5% comments.** Interfaces are nearly three lines of documentation per line of declaration. This is the project's documented design — `.mli` files double as the API spec, and the qc-structural P2 row enforces presence + density via `linter_mli_coverage.sh`.
- **`.ml` is 17.5% comments.** Implementation files carry far less commentary — most reasoning lives in the `.mli`, and `.ml` has terse `_helper_function` names + structural code. This matches the CLAUDE.md guidance ("comments for symbols in `.mli` and complex implementations in `.ml`").
- **Tests are 14.5% comments.** Notably lower than lib — test code uses descriptive matcher composition (`assert_that ... is_ok_and_holds ...`) to express intent inline, so explanatory comments are rarely needed.
- **Effort implication for velocity numbers above:** the OCaml source raw LOC in the by-language table mixes code and comment. If you want a code-only effort proxy, scale that bucket by roughly `1 − (lib comment %)` = `1 − 0.322 = 0.678` for lib changes, or `1 − 0.145 = 0.855` for test changes. Per-PR breakdowns would require parsing each diff hunk — not done here.
