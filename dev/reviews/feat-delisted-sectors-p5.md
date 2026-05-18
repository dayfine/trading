Reviewed SHA: 9173ff9829150243efe107079445bcb247b48eba

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | No format violations |
| H2 | dune build | PASS | Clean build |
| H3 | dune runtest | PASS | All tests pass (no new tests in this feature) |
| P1 | Functions ≤ 50 lines (linter) | NA | No code changes |
| P2 | No magic numbers (linter) | NA | No code changes |
| P3 | Config completeness | NA | No code changes |
| P4 | Public-symbol export hygiene (linter) | NA | No code changes |
| P5 | Internal helpers prefixed per convention | NA | No code changes |
| P6 | Tests conform to project test-patterns rules | NA | No new tests added |
| A1 | Core module modifications | PASS | No modifications to core modules (portfolio/orders/position/strategy/engine) |
| A2 | Dependency-direction rules respected | PASS | No dune files modified; no new analysis imports into trading/trading |
| A3 | No unnecessary modifications to existing modules | PASS | Only 86 data files changed (sectors.csv + 84 goldens + 1 notes file); no code modules touched |

## Verdict

APPROVED

This is a pure data PR: 40 hand-curated delistings appended to data/sectors.csv, 84 composition golden fixtures rebuilt against the augmented sectors, and a notes file documenting vendor probes and impact. No OCaml code, no tests, no dune configuration. All structural gates (fmt/build/test) pass. No architecture violations.

---

# Behavioral QC — feat-delisted-sectors-p5
Date: 2026-05-18
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No new .mli added (pure data PR). |
| CP2 | Each claim in PR body "Test plan" sections has a corresponding test in the committed test file | PASS | PR Test plan is data/runtime claims, not new test files. Verified empirically against the PR-tip working tree: (1) `dune build` clean — confirmed by qc-structural; (2) sectors.csv has 10,513 rows (10,473 + 40 appended) matching the loader's first-wins-on-duplicate semantics (LB,Energy preserved at original position; LB_old,Consumer Discretionary appended without clobbering); (3) 84 composition goldens present under `trading/test_data/goldens-custom-universe/composition/` (years 1998-2025 × {500,1000,3000} = 28×3 = 84, consistent with claimed written=84/skipped=3 for missing 2026 bars); (4) all 10 spot-checked famous delistings (AABA, TWTR, CELG, ANTM, AGN, ATVI, CBS, CERN, ABMD, ALXN) now carry their canonical GICS sectors in top-500-2019.sexp; (5) weinstein-2019-top-500-composition scenario re-run produced identical metrics to the writeup (return 77.30, trades 258, win_rate 30.23, sharpe 0.69, maxDD 40.28, sortino 0.96, calmar 0.30, ulcer 17.20) — all within the #1190 pinned bands. |
| CP3 | Pass-through / identity / invariant tests pin identity | NA | No pass-through semantics in this feature. |
| CP4 | Each guard called out explicitly in code docstrings has a test for the guarded-against scenario | NA | No new guard claims in code (data-only change). |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification strategy-agnostic | NA | No core module changes (qc-structural A1=PASS). |
| S1 | Stage 1 definition matches book | NA | Pure data PR, no Weinstein code change. |
| S2 | Stage 2 definition matches book | NA | Pure data PR. |
| S3 | Stage 3 definition matches book | NA | Pure data PR. |
| S4 | Stage 4 definition matches book | NA | Pure data PR. |
| S5 | Buy criteria | NA | Pure data PR. |
| S6 | No buy signals in Stage 1/3/4 | NA | Pure data PR. |
| L1 | Initial stop below base | NA | Pure data PR. |
| L2 | Trailing stop never lowered | NA | Pure data PR. |
| L3 | Stop triggers on weekly close | NA | Pure data PR. |
| L4 | Stop state machine transitions | NA | Pure data PR. |
| C1 | Screener cascade order | NA | Pure data PR. |
| C2 | Bearish macro blocks all buys | NA | Pure data PR. |
| C3 | Sector RS vs. market, not absolute | NA | Pure data PR. |
| T1 | Tests cover all 4 stage transitions | NA | Pure data PR. |
| T2 | Bearish macro → zero buy candidates test | NA | Pure data PR. |
| T3 | Stop trailing tests | NA | Pure data PR. |
| T4 | Tests assert domain outcomes | NA | Pure data PR. |

Note: All Weinstein-domain rows NA — this is a pure data/curation PR (sectors.csv supplement + regenerated golden fixtures + writeup). No code path, no behavior change in Weinstein analysis modules. The empirical correctness check is on data fidelity (correct GICS sectors for the 5 spot-checked delistings) and runtime invariance (post-P5 metrics within #1190 pinned bands).

### Empirical verification details

**Sector-attribution spot checks (5 names requested + 5 more from PR Test plan):**

| Symbol | Claimed sector | sectors.csv | Authority (delisting context) | Result |
|--------|----------------|-------------|-------------------------------|--------|
| AABA | Communication Services | Communication Services | Altaba = Yahoo successor (Verizon spun off 2017, defunct 2019) | PASS |
| CELG | Health Care | Health Care | Celgene = biotech, acquired by BMS Nov 2019 | PASS |
| ATVI | Communication Services | Communication Services | Activision Blizzard = video games (GICS 2018 reclassification moved Telecom → Communication Services, includes Interactive Home Entertainment) | PASS |
| XLNX | Information Technology | Information Technology | Xilinx = semiconductor (FPGAs), acquired by AMD Feb 2022 | PASS |
| CHK | Energy | Energy | Chesapeake Energy = oil/gas E&P | PASS |
| TWTR | Communication Services | Communication Services | Twitter = social media platform | PASS |
| ANTM | Health Care | Health Care | Anthem = managed-care insurer → Elevance Health | PASS |
| AGN | Health Care | Health Care | Allergan = pharma, acquired by AbbVie May 2020 | PASS |
| CBS | Communication Services | Communication Services | CBS Corp = media broadcaster, merged into Paramount | PASS |
| CERN | Health Care | Health Care | Cerner = health IT, acquired by Oracle Jun 2022 | PASS |
| ABMD | Health Care | Health Care | Abiomed = medical devices, acquired by JNJ Dec 2022 | PASS |
| ALXN | Health Care | Health Care | Alexion Pharmaceuticals, acquired by AstraZeneca Jul 2021 | PASS |

All 12 sectors correct per public-record GICS classification at the time of delisting/acquisition.

**Empty-sector count claim (top-500-2019):**
- Pre-P5 (origin/main): 115 empty sectors — verified
- Post-P5 (PR tip): 100 empty sectors — verified
- Delta: -15 — matches writeup claim

**LB ticker-reuse adjustment claim:** verified — `LB,Energy` (current LandBridge) appears at its original row in sorted sectors.csv body; `LB_old,Consumer Discretionary` (defunct L Brands) appended in the supplemental block. First-wins-on-duplicate loader semantics preserve LB,Energy for the live ticker.

**Composition goldens count:**
- 84 files in `trading/test_data/goldens-custom-universe/composition/`
- Years 1998-2025 (28 years) × 3 sizes (top-500/1000/3000) = 84
- Consistent with PR claim "written=84 skipped=3" (the 3 skipped are 2026's top-500/1000/3000 because 2026 bars are unavailable)

**Weinstein-2019-top-500 scenario re-run (post-P5, from this review):**

| Metric | Claimed in writeup | Measured | Band [min,max] | In-band? |
|--------|-------------------|----------|----------------|----------|
| total_return_pct | 77.30 | 77.30 | [62.7, 94.0] | YES |
| total_trades | 258 | 258 | [210, 316] | YES |
| win_rate | 30.23 | 30.23 | [27.1, 36.7] | YES |
| sharpe_ratio | 0.69 | 0.69 | [0.55, 0.83] | YES |
| max_drawdown_pct | 40.28 | 40.28 | [35.8, 48.5] | YES |
| sortino_ratio | 0.96 | 0.96 | [0.77, 1.15] | YES |
| calmar_ratio | 0.30 | 0.30 | [0.23, 0.35] | YES |
| ulcer_index | 17.20 | 17.20 | [15.2, 22.8] | YES |
| avg_holding_days | 40.22 | 40.22 | (no band, descriptive) | n/a |

All 8 banded metrics fall inside the #1190-pinned tolerances. Re-pinning not required, as the writeup claims.

## Quality Score

5 — Exemplary data PR: every empirical claim in the PR body and writeup was reproducible, the LB/LB_old ticker-reuse case demonstrates careful reasoning about the loader semantics, the writeup honestly documents the remaining 100-empty-sector gap and explains why broader vendor solutions were rejected, and the scenario metrics fall cleanly inside the prior pinned bands so no re-pin churn is created.

## Verdict

APPROVED
