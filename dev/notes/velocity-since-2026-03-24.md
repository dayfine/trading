# Velocity since 2026-03-24

**Window:** 2026-03-24 to 2026-05-06 (44 days inclusive).
**Source:** `gh pr list --repo dayfine/trading --state merged --search "merged:>=2026-03-24"` (run 2026-05-06 21:10Z).

## Headline

- Total PRs merged: 730
- Total LOC raw (add+del): 2,351,224
- Total LOC net (add−del): 2,254,512
- Average PRs/day: 16.6 (calendar) / 23.5 (approx. working days)

**Note on LOC outlier:** PR #873 ("harness: CI golden runs postsubmit") contributed +2,043,707/−14,870 LOC as generated CSV test-fixture data (997 files of ~4,360 lines each). Excluding it: raw 292,647, net 225,675 — these numbers are more representative of active development churn.

## By category

Categories are parsed from the Conventional-Commits prefix in the PR title (the word before `:`). PRs with no conventional prefix (all 51 March PRs + 38 April/May PRs) are classified `other`.

| Category | PRs | % PRs | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| feat | 171 | 23.4% | 102,739 | 15,753 | 118,492 | 86,986 |
| docs | 105 | 14.4% | 20,078 | 750 | 20,828 | 19,328 |
| other | 89 | 12.2% | 21,151 | 3,224 | 24,375 | 17,927 |
| harness | 79 | 10.8% | 2,058,336 | 18,053 | 2,076,389 | 2,040,283 |
| ops | 75 | 10.3% | 20,526 | 1,178 | 21,704 | 19,348 |
| fix | 59 | 8.1% | 21,233 | 1,686 | 22,919 | 19,547 |
| ci | 28 | 3.8% | 20,161 | 512 | 20,673 | 19,649 |
| refactor | 19 | 2.6% | 4,125 | 2,510 | 6,635 | 1,615 |
| chore | 16 | 2.2% | 626 | 593 | 1,219 | 33 |
| status | 9 | 1.2% | 11,175 | 200 | 11,375 | 10,975 |
| test | 9 | 1.2% | 3,410 | 29 | 3,439 | 3,381 |
| cleanup | 8 | 1.1% | 284 | 1,524 | 1,808 | -1,240 |
| simulation | 8 | 1.1% | 2,131 | 179 | 2,310 | 1,952 |
| plan | 6 | 0.8% | 1,438 | 13 | 1,451 | 1,425 |
| nesting | 5 | 0.7% | 1,014 | 938 | 1,952 | 76 |
| perf | 5 | 0.7% | 884 | 267 | 1,151 | 617 |
| experiment | 4 | 0.5% | 4,556 | 14 | 4,570 | 4,542 |
| fixture | 4 | 0.5% | 533 | 33 | 566 | 500 |
| orchestrator | 4 | 0.5% | 374 | 94 | 468 | 280 |
| data | 4 | 0.5% | 981 | 138 | 1,119 | 843 |
| design | 4 | 0.5% | 1,291 | 191 | 1,482 | 1,100 |
| agents | 3 | 0.4% | 284 | 6 | 290 | 278 |
| strategy | 3 | 0.4% | 965 | 75 | 1,040 | 890 |
| tests | 3 | 0.4% | 904 | 0 | 904 | 904 |
| investigate | 2 | 0.3% | 1,211 | 1 | 1,212 | 1,210 |
| session | 2 | 0.3% | 698 | 35 | 733 | 663 |
| decisions | 1 | 0.1% | 112 | 52 | 164 | 60 |
| dev | 1 | 0.1% | 18 | 0 | 18 | 18 |
| diag | 1 | 0.1% | 862 | 13 | 875 | 849 |
| diagnostic | 1 | 0.1% | 340 | 0 | 340 | 340 |
| macro | 1 | 0.1% | 428 | 12 | 440 | 416 |
| revert | 1 | 0.1% | 0 | 283 | 283 | -283 |
| **TOTAL** | **730** | **100%** | **2,302,868** | **48,356** | **2,351,224** | **2,254,512** |

## Observations

- **High harness + ops investment:** harness (10.8% of PRs) and ops (10.3%) together account for 21.1% of all merged work — more than `fix` (8.1%) or `ci` (3.8%) combined. This reflects a deliberate commitment to tooling, agent definitions, and process automation as first-class work.
- **docs/PR ratio is unusually high:** 105 docs PRs (14.4%) for 171 feat PRs means roughly 1 doc PR per 1.6 feature PRs. The project is documenting design decisions, status, and plans at nearly the same cadence as building features.
- **Largest single-PR LOC contribution outside data fixtures:** PR #270 ("ci: add GHCR-prebuilt image workflow + fast PR gate") at +18,955/−250 LOC — a CI infrastructure overhaul. The next non-infrastructure outlier is PR #720 ("fix(stop_log): drop warmup-window stop_infos via entry_date stamp") at +13,290/−6.
- **March was the ramp-up phase:** All 51 March PRs (100%) used freeform titles (no Conventional Commits prefix). The project adopted the `type(scope): message` convention sometime in early April; April and May only have 38 non-conventional PRs combined (7.3% of those months' merged work).
- **Very low revert count:** 1 revert out of 730 PRs (0.14%) indicates stable development discipline — this is consistent with the test-driven-development workflow and QC gate system (qc-structural + qc-behavioral reviews).

## Methodology + caveats

- Categorization is from the PR title's Conventional-Commits prefix; if a PR was mis-prefixed, it's mis-classified here. Spot-checked 3 PRs (#899, #884, #891); all matched GitHub's additions/deletions exactly.
- 89 PRs (12.2%) are classified `other` because they lack a conventional-commits prefix. Of these, 51 are from March 24–31 (the project had not yet adopted the convention). The remaining 38 span April–May and include draft investigations, freeform feature work, and mid-session status commits.
- The `harness` category is a project-local prefix (not part of standard Conventional Commits) used for tooling/linter/agent-definition changes. It is treated as its own category here rather than folding into `chore`.
- Raw LOC double-counts modifications; net LOC under-counts effort on refactors. Both shown.
- Squash-merge style means each PR = one commit on main; LOC reflects the squashed delta (consistent with GitHub's display).
- **LOC outlier:** PR #873 contributes 2,043,707 additions of generated CSV test-fixture data (SP500 golden-run data, 997 files). All tables above include it as-is; the headline note gives adjusted totals excluding it.
- Excludes: PRs not merged (closed-without-merge).
- Time window inclusive on both ends.

## Per-month rollup

| Month | PRs | Raw LOC | Net LOC | Top categories by PR count |
|---|---:|---:|---:|---|
| 2026-03 (24-31) | 51 | 13,694 | 12,586 | other(51) — pre-conventional-commits |
| 2026-04 | 519 | 192,048 | 142,628 | feat(102), docs(82), harness(75) |
| 2026-05 (1-6) | 160 | 2,145,482 | 2,099,298 | feat(69), docs(23), fix(20) |

April was the project's highest-velocity month, averaging 17.3 PRs/calendar day across 30 days. May's outsized raw/net LOC is driven entirely by PR #873 (generated test fixtures); excluding it, May 1–6 shows ~76,000 raw LOC across 159 PRs — roughly in line with April's pace.

## By language

**Source:** per-file `{path, additions, deletions}` from `gh pr list --json number,files` + REST API pagination for PR #873 (which hits the 100-file truncation in the GraphQL `files` field). 733 PRs, 4,925 file-change records.

**Note on LOC outlier:** PR #873 contributed 997 CSV files (generated SP500 golden-run fixtures), adding 2,038,990 lines to the CSV bucket. The table below includes it as-is; the "(ex-#873)" row gives adjusted CSV totals.

| Language | PRs touched | Files touched | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| CSV | 14 | 568 | 2,074,900 | 14,912 | 2,089,812 | 2,059,988 |
| CSV (ex-#873) | 13 | 75 | 35,910 | 44 | 35,954 | 35,866 |
| OCaml source | 337 | 619 | 116,702 | 22,402 | 139,104 | 94,300 |
| Markdown | 476 | 370 | 66,116 | 5,825 | 71,941 | 60,291 |
| Sexp / scenario | 58 | 686 | 24,222 | 631 | 24,853 | 23,591 |
| Shell | 63 | 70 | 11,355 | 2,596 | 13,951 | 8,759 |
| Other | 33 | 19 | 5,329 | 826 | 6,155 | 4,503 |
| Dune | 210 | 137 | 2,426 | 357 | 2,783 | 2,069 |
| YAML / GHA | 46 | 13 | 1,991 | 576 | 2,567 | 1,415 |
| JSON | 49 | 51 | 2,055 | 159 | 2,214 | 1,896 |
| Docker | 7 | 1 | 143 | 82 | 225 | 61 |
| **TOTAL** | **733** | **4,925** | **2,305,239** | **48,366** | **2,353,605** | **2,256,873** |

_"PRs touched" = unique PR count where at least one file in the bucket was modified. "Files touched" = unique file paths. Buckets: OCaml = `*.ml`/`*.mli`; Dune = `dune`, `dune-project`, `*.opam`; Sexp = `*.sexp`; Shell = `*.sh`/`*.bash`; YAML = `*.yml`/`*.yaml`; Docker = `Dockerfile`/`*.dockerignore`; Other = everything else._

Top 5 paths in the Other bucket (by raw LOC): `wiki_sp500/.../changes_table_2026-05-03.html` (3,273), `panel-golden-divergence-trace-linux.txt` (708), `perf_sweep_report.py` (414 — two PRs), `perf_hypothesis_report.py` (336), `linter_exceptions.conf` (282).

### Observations

- **OCaml source is the effort core:** excluding PR #873, OCaml accounts for 47% of raw LOC (139,104 / 295,028) despite representing 46% of PRs. Additions heavily outweigh deletions (116,702 vs. 22,402), reflecting net new capability rather than churn. The deletions share (16% of OCaml raw LOC) is the highest non-Docker ratio, consistent with active refactoring cycles.
- **Markdown volume tracks docs investment closely:** 476 PRs touched a `.md` file (65% of all PRs), contributing 71,941 raw LOC — 24% of the ex-#873 total. The near-parity between docs PRs (105 by category) and the 476 PRs touching Markdown reveals that most feature and harness PRs also update a status or design doc, not just the dedicated `docs:` commits.
- **Sexp / scenario fixtures are a meaningful second-tier signal:** 686 unique `.sexp` files across 58 PRs, producing 24,853 raw LOC. These are all test-scenario inputs for the Weinstein stage/stop/screener subsystems — an unusually high fixture-to-implementation ratio that reflects the golden-scenario test strategy. The CSV outlier (PR #873) aside, generated sexp fixtures represent the largest non-OCaml, non-Markdown LOC category.
- **CSV / generated data:** PR #873 alone contributes 2,038,990 lines (99.5% of the CSV bucket), dwarfing all other categories. Excluding it, CSV drops to 35,954 raw LOC across 13 PRs — primarily backtest output artifacts committed alongside investigation runs.
