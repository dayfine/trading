# Velocity since 2026-04-30

**Window:** 2026-04-30 to 2026-05-23 (24 days inclusive).
**Source:** `gh pr list --repo dayfine/trading --state merged --search "merged:>=2026-04-30 merged:<=2026-05-23"` (run 2026-05-23 08:36Z).

## Headline

- Total PRs merged: 534
- Total LOC raw (add+del): 4538875
- Total LOC net (add−del): 3616893
- Average PRs/day: 22.2 (calendar)

**Note on LOC outlier:** PR #873 ("harness: CI golden runs postsubmit") contributed +2043707/−14870 LOC as generated CSV test-fixture data (997 files of ~4,360 lines each). Excluding it: raw 2480298, net 1588056 — these numbers are more representative of active development churn.

## By category

Categories are parsed from the Conventional-Commits prefix in the PR title (the word before `:`). PRs with no conventional prefix are classified `other`.

| Category | PRs | % PRs | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| feat | 167 | 31.3% | 1304991 | 86809 | 1391800 | 1218182 |
| docs | 95 | 17.8% | 28664 | 1070 | 29734 | 27594 |
| fix | 71 | 13.3% | 36053 | 3309 | 39362 | 32744 |
| ops | 57 | 10.7% | 15359 | 403 | 15762 | 14956 |
| cleanup | 47 | 8.8% | 4743 | 3823 | 8566 | 920 |
| harness | 17 | 3.2% | 2046103 | 14985 | 2061088 | 2031118 |
| experiments | 12 | 2.2% | 3894 | 6 | 3900 | 3888 |
| chore | 11 | 2.1% | 567 | 580 | 1147 | -13 |
| experiment | 11 | 2.1% | 12048 | 0 | 12048 | 12048 |
| refactor | 10 | 1.9% | 2202 | 1411 | 3613 | 791 |
| perf | 7 | 1.3% | 852 | 269 | 1121 | 583 |
| fixture | 5 | 0.9% | 552 | 51 | 603 | 501 |
| test | 5 | 0.9% | 588 | 6 | 594 | 582 |
| investigate | 2 | 0.4% | 1211 | 1 | 1212 | 1210 |
| investigation | 2 | 0.4% | 712 | 0 | 712 | 712 |
| plan | 2 | 0.4% | 1073 | 0 | 1073 | 1073 |
| rules | 2 | 0.4% | 421 | 0 | 421 | 421 |
| tuning | 2 | 0.4% | 434 | 0 | 434 | 434 |
| G6 | 1 | 0.2% | 550 | 3 | 553 | 547 |
| analysis | 1 | 0.2% | 295 | 0 | 295 | 295 |
| audit | 1 | 0.2% | 432 | 0 | 432 | 432 |
| ci | 1 | 0.2% | 499658 | 0 | 499658 | 499658 |
| data | 1 | 0.2% | 114537 | 348252 | 462789 | -233715 |
| diag | 1 | 0.2% | 862 | 13 | 875 | 849 |
| diagnostic | 1 | 0.2% | 340 | 0 | 340 | 340 |
| infra | 1 | 0.2% | 343 | 0 | 343 | 343 |
| plans | 1 | 0.2% | 400 | 0 | 400 | 400 |
| **TOTAL** | **534** | **100%** | **4077884** | **460991** | **4538875** | **3616893** |

## By language

**Source:** per-file `{path, additions, deletions}` from `gh pr list --json number,files` + REST API pagination for any PR with exactly 100 files (100-file truncation in the GitHub GraphQL `files` field).

**Note on LOC outlier:** PR #873 contributed 2038990 CSV additions (500 files of generated SP500 golden-run fixtures). The CSV (ex-#873) row gives adjusted totals.

| Language | PRs touched | Files touched | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| CSV | 23 | 704 | 2578415 | 14868 | 2593283 | 2563547 |
| CSV (ex-#873) | 22 | 204 | 539425 | 0 | 539425 | 539425 |
| OCaml source (total) | 282 | 669 | 97950 | 15529 | 113479 | 82421 |
| — OCaml source (lib) | 267 | 469 | 54605 | 11711 | 66316 | 42894 |
| — OCaml source (test) | 197 | 200 | 43345 | 3818 | 47163 | 39527 |
| Markdown | 348 | 359 | 53722 | 1810 | 55532 | 51912 |
| Sexp / scenario | 103 | 1291 | 1129600 | 428414 | 1558014 | 701186 |
| Shell | 33 | 29 | 4327 | 125 | 4452 | 4202 |
| Other | 26 | 39 | 5365 | 8 | 5373 | 5357 |
| Dune | 116 | 118 | 1888 | 152 | 2040 | 1736 |
| YAML / GHA | 15 | 13 | 955 | 60 | 1015 | 895 |
| JSON | 46 | 58 | 1397 | 22 | 1419 | 1375 |
| Docker | 2 | 1 | 23 | 3 | 26 | 20 |
| **TOTAL** | **532** | **3281** | **3873642** | **460991** | **4334633** | **3412651** |

_"PRs touched" = unique PR count where at least one file in the bucket was modified. "Files touched" = unique file paths. Buckets: OCaml = `*.ml`/`*.mli`; OCaml (lib) = OCaml files NOT under any `/test/` directory; OCaml (test) = OCaml files under `/test/`; Dune = `dune`, `dune-project`, `*.opam`; Sexp = `*.sexp`; Shell = `*.sh`/`*.bash`; YAML = `*.yml`/`*.yaml`; Docker = `Dockerfile`/`*.dockerignore`; Other = everything else._

_Bin and scripts (`*/bin/*.ml`, `*/scripts/*.ml`) count as source (lib), not test. Only paths containing `/test/` qualify as test._

## Per-month rollup

| Month | PRs | Raw LOC | Net LOC | Top categories by PR count |
|---|---:|---:|---:|---|
| 2026-04 | 22 | 5416 | 4914 | fix(6), docs(5), feat(5) |
| 2026-05 | 512 | 4533459 | 3611979 | feat(162), docs(90), fix(65) |

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
- Script: `dev/scripts/velocity_report.sh --since 2026-04-30 --until 2026-05-23`
