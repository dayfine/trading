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
