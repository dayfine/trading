# Velocity since 2026-03-24

**Window:** 2026-03-24 to 2026-05-06 (44 days inclusive).
**Source:** `gh pr list --repo dayfine/trading --state merged --search "merged:>=2026-03-24 merged:<=2026-05-06"` (run 2026-05-06 21:20Z).

## Headline

- Total PRs merged: 734
- Total LOC raw (add+del): 2353637
- Total LOC net (add−del): 2256905
- Average PRs/day: 16.6 (calendar)

**Note on LOC outlier:** PR #873 ("harness: CI golden runs postsubmit") contributed +2043707/−14870 LOC as generated CSV test-fixture data (997 files of ~4,360 lines each). Excluding it: raw 295060, net 228068 — these numbers are more representative of active development churn.

## By category

Categories are parsed from the Conventional-Commits prefix in the PR title (the word before `:`). PRs with no conventional prefix are classified `other`.

| Category | PRs | % PRs | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| feat | 173 | 23.6% | 105028 | 15763 | 120791 | 89265 |
| docs | 107 | 14.6% | 20192 | 750 | 20942 | 19442 |
| harness | 79 | 10.8% | 2058336 | 18053 | 2076389 | 2040283 |
| ops | 75 | 10.2% | 20526 | 1178 | 21704 | 19348 |
| other | 70 | 9.5% | 17262 | 1768 | 19030 | 15494 |
| fix | 59 | 8% | 21233 | 1686 | 22919 | 19547 |
| ci | 28 | 3.8% | 20161 | 512 | 20673 | 19649 |
| refactor | 19 | 2.6% | 4125 | 2510 | 6635 | 1615 |
| chore | 16 | 2.2% | 626 | 593 | 1219 | 33 |
| status | 9 | 1.2% | 11175 | 200 | 11375 | 10975 |
| test | 9 | 1.2% | 3410 | 29 | 3439 | 3381 |
| cleanup | 8 | 1.1% | 284 | 1524 | 1808 | -1240 |
| simulation | 8 | 1.1% | 2131 | 179 | 2310 | 1952 |
| plan | 6 | 0.8% | 1438 | 13 | 1451 | 1425 |
| Harness | 5 | 0.7% | 396 | 128 | 524 | 268 |
| nesting | 5 | 0.7% | 1014 | 938 | 1952 | 76 |
| perf | 5 | 0.7% | 884 | 267 | 1151 | 617 |
| data | 4 | 0.5% | 981 | 138 | 1119 | 843 |
| design | 4 | 0.5% | 1291 | 191 | 1482 | 1100 |
| experiment | 4 | 0.5% | 4556 | 14 | 4570 | 4542 |
| fixture | 4 | 0.5% | 533 | 33 | 566 | 500 |
| orchestrator | 4 | 0.5% | 374 | 94 | 468 | 280 |
| agents | 3 | 0.4% | 284 | 6 | 290 | 278 |
| data-management | 3 | 0.4% | 825 | 22 | 847 | 803 |
| strategy | 3 | 0.4% | 965 | 75 | 1040 | 890 |
| tests | 3 | 0.4% | 904 | 0 | 904 | 904 |
| T3-F | 2 | 0.3% | 374 | 2 | 376 | 372 |
| agent-setup | 2 | 0.3% | 390 | 753 | 1143 | -363 |
| investigate | 2 | 0.3% | 1211 | 1 | 1212 | 1210 |
| session | 2 | 0.3% | 698 | 35 | 733 | 663 |
| DRAFT | 1 | 0.1% | 388 | 2 | 390 | 386 |
| G6 | 1 | 0.1% | 550 | 3 | 553 | 547 |
| Refactor | 1 | 0.1% | 173 | 158 | 331 | 15 |
| data-layer | 1 | 0.1% | 24 | 0 | 24 | 24 |
| data-panels | 1 | 0.1% | 114 | 361 | 475 | -247 |
| decisions | 1 | 0.1% | 112 | 52 | 164 | 60 |
| dev | 1 | 0.1% | 18 | 0 | 18 | 18 |
| diag | 1 | 0.1% | 862 | 13 | 875 | 849 |
| diagnostic | 1 | 0.1% | 340 | 0 | 340 | 340 |
| macro | 1 | 0.1% | 428 | 12 | 440 | 416 |
| order_gen | 1 | 0.1% | 550 | 17 | 567 | 533 |
| portfolio_risk | 1 | 0.1% | 105 | 10 | 115 | 95 |
| revert | 1 | 0.1% | 0 | 283 | 283 | -283 |
| **TOTAL** | **734** | **100%** | **2305271** | **48366** | **2353637** | **2256905** |

## Observations

- **High harness + ops investment:** harness (10.8% of PRs) and ops (10.2%) together account for 21.0% of all merged work — more than `fix` (8.0%) or `ci` (3.8%) combined. This reflects a deliberate commitment to tooling, agent definitions, and process automation as first-class work.
- **docs/PR ratio is unusually high:** 107 docs PRs (14.6%) for 173 feat PRs means roughly 1 doc PR per 1.6 feature PRs. The project is documenting design decisions, status, and plans at nearly the same cadence as building features.
- **Largest single-PR LOC contribution outside data fixtures:** PR #270 ("ci: add GHCR-prebuilt image workflow + fast PR gate") at +18,955/−250 LOC — a CI infrastructure overhaul. The next non-infrastructure outlier is PR #720 ("fix(stop_log): drop warmup-window stop_infos via entry_date stamp") at +13,290/−6.
- **March was the ramp-up phase:** All 51 March PRs (100%) used freeform titles (no Conventional Commits prefix). The project adopted the `type(scope): message` convention sometime in early April; April and May only have non-conventional PRs combined (a small fraction of those months' merged work).
- **Very low revert count:** 1 revert out of 734 PRs (0.14%) indicates stable development discipline — this is consistent with the test-driven-development workflow and QC gate system (qc-structural + qc-behavioral reviews).

## Methodology + caveats

- Categorization is from the PR title's Conventional-Commits prefix; if a PR was mis-prefixed, it's mis-classified here. Spot-checked 3 PRs (#899, #884, #891); all matched GitHub's additions/deletions exactly.
- PRs with no conventional prefix are classified `other`.
- The `harness` category is a project-local prefix (not part of standard Conventional Commits) used for tooling/linter/agent-definition changes. It is treated as its own category here rather than folding into `chore`.
- Raw LOC double-counts modifications; net LOC under-counts effort on refactors. Both shown.
- Squash-merge style means each PR = one commit on main; LOC reflects the squashed delta (consistent with GitHub's display).
- **LOC outlier:** PR #873 contributes 2,043,707 additions of generated CSV test-fixture data (SP500 golden-run data, 997 files). All tables above include it as-is; the headline note gives adjusted totals excluding it.
- Excludes: PRs not merged (closed-without-merge).
- Time window inclusive on both ends.
- **Reproducible:** regenerate this report with `bash dev/scripts/velocity_report.sh --since 2026-03-24 --until 2026-05-06 --out dev/notes/velocity-since-2026-03-24.md`.

## Per-month rollup

| Month | PRs | Raw LOC | Net LOC | Top categories by PR count |
|---|---:|---:|---:|---|
| 2026-03 | 51 | 13694 | 12586 | other(51) |
| 2026-04 | 519 | 192048 | 142628 | feat(102), docs(82), harness(75) |
| 2026-05 | 164 | 2147895 | 2101691 | feat(71), docs(25), fix(20) |

April was the project's highest-velocity month, averaging 17.3 PRs/calendar day across 30 days. May's outsized raw/net LOC is driven entirely by PR #873 (generated test fixtures); excluding it, May 1–6 shows raw LOC across 163 PRs — roughly in line with April's pace.

## By language

**Source:** per-file `{path, additions, deletions}` from `gh pr list --json number,files` + REST API pagination for PR #873 (which hits the 100-file truncation in the GraphQL `files` field). 734 PRs, 2,534 unique file paths.

**Note on LOC outlier:** PR #873 contributed 500 CSV files (generated SP500 golden-run fixtures), adding 2,038,990 lines to the CSV bucket. The table below includes it as-is; the "(ex-#873)" row gives adjusted CSV totals.

| Language | PRs touched | Files touched | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| CSV | 14 | 568 | 2074900 | 14912 | 2089812 | 2059988 |
| CSV (ex-#873) | 13 | 75 | 35910 | 44 | 35954 | 35866 |
| OCaml source (total) | 337 | 619 | 116702 | 22402 | 139104 | 94300 |
| — OCaml source (lib) | 303 | 426 | 58285 | 14036 | 72321 | 44249 |
| — OCaml source (test) | 270 | 193 | 58417 | 8366 | 66783 | 50051 |
| Markdown | 477 | 370 | 66148 | 5825 | 71973 | 60323 |
| Sexp / scenario | 58 | 686 | 24222 | 631 | 24853 | 23591 |
| Shell | 63 | 70 | 11355 | 2596 | 13951 | 8759 |
| Other | 33 | 19 | 5329 | 826 | 6155 | 4503 |
| Dune | 210 | 137 | 2426 | 357 | 2783 | 2069 |
| YAML / GHA | 46 | 13 | 1991 | 576 | 2567 | 1415 |
| JSON | 49 | 51 | 2055 | 159 | 2214 | 1896 |
| Docker | 7 | 1 | 143 | 82 | 225 | 61 |
| **TOTAL** | **734** | **2534** | **2305271** | **48366** | **2353637** | **2256905** |

_"PRs touched" = unique PR count where at least one file in the bucket was modified. "Files touched" = unique file paths. Buckets: OCaml = `*.ml`/`*.mli`; OCaml (lib) = OCaml files NOT under any `/test/` directory; OCaml (test) = OCaml files under `/test/`; Dune = `dune`, `dune-project`, `*.opam`; Sexp = `*.sexp`; Shell = `*.sh`/`*.bash`; YAML = `*.yml`/`*.yaml`; Docker = `Dockerfile`/`*.dockerignore`; Other = everything else._

_Bin and scripts (`*/bin/*.ml`, `*/scripts/*.ml`) count as source (lib), not test. Only paths containing `/test/` qualify as test._

Top 5 paths in the Other bucket (by raw LOC): `wiki_sp500/.../changes_table_2026-05-03.html` (3,273), `panel-golden-divergence-trace-linux.txt` (708), `perf_sweep_report.py` (414 — two PRs), `perf_hypothesis_report.py` (336), `linter_exceptions.conf` (282).

### Observations

- **OCaml source is the effort core:** excluding PR #873, OCaml accounts for 47% of raw LOC (139,104 / 295,028) despite representing 46% of PRs. Additions heavily outweigh deletions (116,702 vs. 22,402), reflecting net new capability rather than churn. The deletions share (16% of OCaml raw LOC) is the highest non-Docker ratio, consistent with active refactoring cycles.
- **OCaml test vs source split:** of the 619 unique OCaml files, 193 (31%) are test files (under `/test/` directories) and 426 (69%) are source files (lib, bin, scripts). By raw LOC, test and source are nearly equal: test 66,783 raw LOC vs source 72,321 — indicating the project writes roughly one line of test code per line of source.
- **Markdown volume tracks docs investment closely:** 477 PRs touched a `.md` file (65% of all PRs), contributing 71,973 raw LOC — 24% of the ex-#873 total. The near-parity between docs PRs (107 by category) and the 477 PRs touching Markdown reveals that most feature and harness PRs also update a status or design doc, not just the dedicated `docs:` commits.
- **Sexp / scenario fixtures are a meaningful second-tier signal:** 686 unique `.sexp` files across 58 PRs, producing 24,853 raw LOC. These are all test-scenario inputs for the Weinstein stage/stop/screener subsystems — an unusually high fixture-to-implementation ratio that reflects the golden-scenario test strategy. The CSV outlier (PR #873) aside, generated sexp fixtures represent the largest non-OCaml, non-Markdown LOC category.
- **CSV / generated data:** PR #873 alone contributes 2,038,990 lines (99.5% of the CSV bucket), dwarfing all other categories. Excluding it, CSV drops to 35,954 raw LOC across 13 PRs — primarily backtest output artifacts committed alongside investigation runs.
