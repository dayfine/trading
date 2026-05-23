# Velocity since 2026-03-23

**Window:** 2026-03-23 to 2026-04-29 (38 days inclusive).
**Source:** `gh pr list --repo dayfine/trading --state merged --search "merged:>=2026-03-23 merged:<=2026-04-29"` (run 2026-05-23 08:36Z).

## Headline

- Total PRs merged: 548
- Total LOC raw (add+del): 200326
- Total LOC net (add−del): 150300
- Average PRs/day: 14.4 (calendar)

**Note on LOC outlier:** PR #873 ("harness: CI golden runs postsubmit") contributed +/− LOC as generated CSV test-fixture data (997 files of ~4,360 lines each). Excluding it: raw 200326, net 150300 — these numbers are more representative of active development churn.

## By category

Categories are parsed from the Conventional-Commits prefix in the PR title (the word before `:`). PRs with no conventional prefix are classified `other`.

| Category | PRs | % PRs | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| feat | 97 | 17.7% | 59152 | 10231 | 69383 | 48921 |
| docs | 77 | 14.1% | 13483 | 609 | 14092 | 12874 |
| harness | 73 | 13.3% | 14128 | 3171 | 17299 | 10957 |
| other | 70 | 12.8% | 17262 | 1768 | 19030 | 15494 |
| ops | 58 | 10.6% | 14809 | 1031 | 15840 | 13778 |
| fix | 33 | 6% | 3694 | 859 | 4553 | 2835 |
| ci | 28 | 5.1% | 20161 | 512 | 20673 | 19649 |
| refactor | 12 | 2.2% | 2139 | 1239 | 3378 | 900 |
| chore | 9 | 1.6% | 361 | 319 | 680 | 42 |
| status | 9 | 1.6% | 11175 | 200 | 11375 | 10975 |
| cleanup | 8 | 1.5% | 284 | 1524 | 1808 | -1240 |
| simulation | 8 | 1.5% | 2131 | 179 | 2310 | 1952 |
| test | 7 | 1.3% | 3157 | 29 | 3186 | 3128 |
| plan | 6 | 1.1% | 1438 | 13 | 1451 | 1425 |
| Harness | 5 | 0.9% | 396 | 128 | 524 | 268 |
| nesting | 5 | 0.9% | 1014 | 938 | 1952 | 76 |
| data | 4 | 0.7% | 981 | 138 | 1119 | 843 |
| design | 4 | 0.7% | 1291 | 191 | 1482 | 1100 |
| orchestrator | 4 | 0.7% | 374 | 94 | 468 | 280 |
| agents | 3 | 0.5% | 284 | 6 | 290 | 278 |
| data-management | 3 | 0.5% | 825 | 22 | 847 | 803 |
| strategy | 3 | 0.5% | 965 | 75 | 1040 | 890 |
| tests | 3 | 0.5% | 904 | 0 | 904 | 904 |
| T3-F | 2 | 0.4% | 374 | 2 | 376 | 372 |
| agent-setup | 2 | 0.4% | 390 | 753 | 1143 | -363 |
| perf | 2 | 0.4% | 194 | 38 | 232 | 156 |
| session | 2 | 0.4% | 698 | 35 | 733 | 663 |
| DRAFT | 1 | 0.2% | 388 | 2 | 390 | 386 |
| Refactor | 1 | 0.2% | 173 | 158 | 331 | 15 |
| data-layer | 1 | 0.2% | 24 | 0 | 24 | 24 |
| data-panels | 1 | 0.2% | 114 | 361 | 475 | -247 |
| decisions | 1 | 0.2% | 112 | 52 | 164 | 60 |
| dev | 1 | 0.2% | 18 | 0 | 18 | 18 |
| experiment | 1 | 0.2% | 1337 | 14 | 1351 | 1323 |
| macro | 1 | 0.2% | 428 | 12 | 440 | 416 |
| order_gen | 1 | 0.2% | 550 | 17 | 567 | 533 |
| portfolio_risk | 1 | 0.2% | 105 | 10 | 115 | 95 |
| revert | 1 | 0.2% | 0 | 283 | 283 | -283 |
| **TOTAL** | **548** | **100%** | **175313** | **25013** | **200326** | **150300** |

## By language

**Source:** per-file `{path, additions, deletions}` from `gh pr list --json number,files` + REST API pagination for any PR with exactly 100 files (100-file truncation in the GitHub GraphQL `files` field).

**Note on LOC outlier:** PR #873 contributed 0 CSV additions (500 files of generated SP500 golden-run fixtures). The CSV (ex-#873) row gives adjusted totals.

| Language | PRs touched | Files touched | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| CSV | 6 | 40 | 34221 | 44 | 34265 | 34177 |
| CSV (ex-#873) | 5 | 40 | 34221 | 44 | 34265 | 34177 |
| OCaml source (total) | 230 | 426 | 73996 | 14885 | 88881 | 59111 |
| — OCaml source (lib) | 202 | 292 | 35915 | 9205 | 45120 | 26710 |
| — OCaml source (test) | 177 | 134 | 38081 | 5680 | 43761 | 32401 |
| Markdown | 368 | 264 | 48162 | 5389 | 53551 | 42773 |
| Sexp / scenario | 22 | 78 | 3327 | 215 | 3542 | 3112 |
| Shell | 52 | 58 | 9270 | 2560 | 11830 | 6710 |
| Other | 28 | 14 | 1093 | 826 | 1919 | 267 |
| Dune | 163 | 105 | 1762 | 288 | 2050 | 1474 |
| YAML / GHA | 42 | 11 | 1745 | 565 | 2310 | 1180 |
| JSON | 35 | 31 | 1594 | 159 | 1753 | 1435 |
| Docker | 7 | 1 | 143 | 82 | 225 | 61 |
| **TOTAL** | **548** | **1028** | **175313** | **25013** | **200326** | **150300** |

_"PRs touched" = unique PR count where at least one file in the bucket was modified. "Files touched" = unique file paths. Buckets: OCaml = `*.ml`/`*.mli`; OCaml (lib) = OCaml files NOT under any `/test/` directory; OCaml (test) = OCaml files under `/test/`; Dune = `dune`, `dune-project`, `*.opam`; Sexp = `*.sexp`; Shell = `*.sh`/`*.bash`; YAML = `*.yml`/`*.yaml`; Docker = `Dockerfile`/`*.dockerignore`; Other = everything else._

_Bin and scripts (`*/bin/*.ml`, `*/scripts/*.ml`) count as source (lib), not test. Only paths containing `/test/` qualify as test._

## Per-month rollup

| Month | PRs | Raw LOC | Net LOC | Top categories by PR count |
|---|---:|---:|---:|---|
| 2026-03 | 51 | 13694 | 12586 | other(51) |
| 2026-04 | 497 | 186632 | 137714 | feat(97), docs(77), harness(73) |

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
- Script: `dev/scripts/velocity_report.sh --since 2026-03-23 --until 2026-04-29`
