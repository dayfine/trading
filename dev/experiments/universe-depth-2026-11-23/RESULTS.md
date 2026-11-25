# Universe depth and the structural stop at live size: results (K=5)

**Pre-registration.** `PREREG.md` (237b2bb8d228, #3707) and `PREREG-ADDENDUM.md` (376b2f5ab059, #3719, committed at 20:22Z on 11-24, after the S3 cells and the U4 k1/k2 cells had logged RESULT lines but before any result was read; it only makes PASS harder and none of its clauses were reached). Neither changed afterwards. The rule is applied as written.

**Run.**
- Kit ca42b9146445 (#3714); artifacts are `results/k0..k4/` (96b660385960, PR #3721).
- Build SC_SHA ca42b914644506b1a305f158fed4340f36387772, image sha256:886851cbc0f1.
- Universe: pit-v13 top-3000 and top-4000, which are broad lists. No sp500 cell is used.

**What this read could see.** Only committed, mark-free files:
- per cell: `summary.sexp`, `actual.sexp`, `params.sexp`, `macro_trend.sexp`, `entries.tsv`, `depth.tsv`, `nss.tsv`;
- validator logs, V6 diff logs and chain logs;
- the composition and twin-drop files under `trading/test_data/backtest_scenarios/`.

The price-bearing files are in private `dayfine/trading-results` and were not available: `trades.csv`, `equity_curve.csv`, `open_positions.csv`, `force_liquidations.sexp` and the validator reports. Checks that need them are marked *not done* and listed in Appendix A.

## Verdict

| read | pre-registered verdict | reason | descriptive shape (not a verdict) | addendum follow-up |
|---|---|---|---|---|
| U4 vs S3 (depth) | **INVALID** | V6 fails on 5/5 seeds, leaving 0 valid | median Δ +0.045, 3/5 positive, median ΔDD −3.36 pp: INCONCLUSIVE-shaped | none: A1–A3 apply only after a PASS or PAYS-WITH-RISK |
| N3 vs S3 (structural stop) | **INVALID** | V6 fails on 5/5 seeds | median Δ −1.091, 5/5 negative, median ΔDD +16.18 pp: HARM-shaped, as PREREG predicted | none: A4 applies only after a PASS; N3 is never promotable (spine item 5) |
| UN4 vs U4 (secondary) | **INVALID** | V6 fails on 5/5 seeds | median Δ −2.101, 5/5 negative, median ΔDD +21.02 pp: HARM-shaped | none |

The cause is a data defect upstream of the strategy. The v13 composition lists still contain rename twins: one instrument listed under two symbols in the same year. In 12 of the 20 cells the strategy held one instrument as two positions.

What this leaves for decisions:
- **Live picks:** nothing moves. The PREREG's U4 INCONCLUSIVE branch says "picks stay on top-3000", and INVALID leaves the same in place.
- **The fallback stop:** `require_structural_stop false` stays non-promotable whatever the data shows.
- **The v13 lists:** they are not fit for a measured cell, including a record re-baseline, until the twin dedupe is repaired.

## Review-pack look

No review pack was built: it needs the private `trades.csv` and `equity_curve.csv`, so no images were checked. RV1 is open. RV3 does not apply, because there are no pack bullets. No exposure figure is quoted, so RV2 is not triggered.

## 1. The rules, in order, as written

### 1.1 Build tripwire

> "NAV-scale P-100k k0 … is re-run at the run build and must reproduce its `trades.csv` md5."

All five sessions logged `TRIPWIRE MATCH ns-P-100k-k0-s0 trades.csv md5 f7746eb838618c9eac4aed7f969e63af (563 lines)`, with `log_nav_ratio 2.5739` and `max_drawdown_pct 39.55`. All five ran at the same SC_SHA and image. **Pass.**

Process note (D6). Three sessions restarted after their tripwire and rebuilt the binary at the same SHA and image, logging `SKIP tripwire (done)`:
- k0 at 11-25 05:04Z (39 s build) and k3 at 05:05Z (32 s build), both for their U4, N3 and UN4 cells;
- k4 at 01:31Z (15 s build), for UN4 only.

### 1.2 Stage and preflight

| check | result |
|---|---|
| ABSENT | 4 of 9,694 loadable names (S/N arms) and 4 of 12,345 (U arms): DNGFF, HLAN, MDFI, SYNI, which is the quarantine set |
| Corporate-action extras | `td-ca-extra-v12.txt` and `td-ca-extra-v13.txt` are empty in every seed folder |
| Params | `code_version` ca42b914… in all 20 cells; `initial_cash` 100000; `universe_size` 9,679 (S/N) and 12,330 (U), the union of each schedule's lists (the specs set 3000 and 4000, as PREREG says); `require_structural_stop false` is the last override in N3 and UN4 only |
| Macro path | `macro_trend.sexp` is byte-identical across all 20 cells (one md5), so the macro gate opened and closed on the same weeks everywhere |
| Steps | `n_steps` is 6,898 in the S and N arms and 6,899 in the U arms (D5) |

### 1.3 V6 gate

> "V6 on every paired read (U4 vs S3, N3 vs S3, UN4 vs U4) at the same seed. A V6-failing seed is dropped; < 4 valid seeds = INVALID."

Twins held, per cell. Counts come from `ud-<arm>-kK-s0.validator.log`; the legs come from the V6 diff specimens and `depth.tsv`.

| arm | k0 | k1 | k2 | k3 | k4 |
|---|---|---|---|---|---|
| S3 | 1: GLPG/LKFT | 1: GLPG/LKFT | 1: GLPG/LKFT | 1: GLPG/LKFT | 1: GLPG/LKFT |
| U4 | 3: GLPG/LKFT, CMD/CMN, KONA/KONAQ | 2: CMD/CMN, CNR_old2/NCS | 2: CMD/CMN, CNR_old2/NCS | 0 | 0 |
| N3 | 0 | 0 | 0 | 0 | 0 |
| UN4 | 1: CMBT/EURN | 1: CMBT/EURN | 0 | 1: CMBT/EURN | 1: CMBT/EURN |

`validator_diff -check V6` exited 1 (DIFFER) on all 15 pairs: chain `PAIR … V6 exit=1` lines and `*.v6diff-*.log`. The validator's own words: "these arms hold different instrument sets and their delta is not a paired read".

The gate fails on every seed of every read whether it is read through the pair's diff or through each arm's own count. **Valid seeds: 0 for all three reads.**

### 1.4 Liveness

- **U4.** Rule: ≥ 10 round trips in top-4000-not-top-3000 names on ≥ 3 seeds. Observed 136 / 131 / 127 / 133 / 127. **Live on 5/5.**
- **N3.** Rule: ≥ 20 % of placed entries carry a `Buffer_fallback` stop on ≥ 3 seeds. Observed:

  | seed | Buffer_fallback / placed | share |
  |---|---|---|
  | k0 | 1,529 / 1,741 | 87.8 % |
  | k1 | 1,568 / 1,777 | 88.2 % |
  | k2 | 1,500 / 1,722 | 87.1 % |
  | k3 | 1,461 / 1,701 | 85.9 % |
  | k4 | 1,482 / 1,707 | 86.8 % |

  **Live on 5/5.**
- **Band join.** S3 and N3 have 0 round trips in band 3001–4000 on every seed, which checks the join.

### 1.5 Measures

**M1: ln(final / initial).** Source: `summary.sexp` `final_portfolio_value`, which also matches the chain `RESULT` lines. The per-period split is *not done*: it needs `equity_curve.csv`.

| arm | k0 | k1 | k2 | k3 | k4 | median | median CAGR % | median final NAV |
|---|---|---|---|---|---|---|---|---|
| S3 | 2.6185 | 2.2595 | 1.9919 | 1.8888 | 2.1185 | 2.1185 | 8.33 | $831,833 |
| U4 | 2.4381 | 2.3047 | 2.4325 | 2.3311 | 2.0471 | 2.3311 | 9.20 | $1,028,919 |
| N3 | 1.2964 | 0.9055 | 1.0907 | 1.2470 | 1.0278 | 1.0907 | 4.20 | $297,629 |
| UN4 | 0.3376 | 0.2005 | 0.9400 | 0.4013 | −0.2904 | 0.3376 | 1.28 | $140,158 |

**M2: max drawdown % and Ulcer index.** Source: `actual.sexp`. The per-period split is *not done* (needs `equity_curve.csv`).

| arm | max DD k0 / k1 / k2 / k3 / k4 | median DD | Ulcer k0 / k1 / k2 / k3 / k4 | median Ulcer |
|---|---|---|---|---|
| S3 | 43.51 / 38.15 / 32.31 / 32.79 / 26.23 | 32.79 | 14.38 / 13.53 / 11.60 / 12.51 / 10.74 | 12.51 |
| U4 | 36.27 / 34.57 / 28.96 / 36.06 / 38.43 | 36.06 | 12.49 / 12.50 / 10.35 / 12.44 / 13.60 | 12.49 |
| N3 | 55.58 / 48.80 / 51.58 / 48.97 / 51.37 | 51.37 | 21.07 / 21.96 / 24.14 / 23.22 / 22.86 | 22.86 |
| UN4 | 52.63 / 55.59 / 57.64 / 52.77 / 60.89 | 55.59 | 27.16 / 28.57 / 26.47 / 26.08 / 34.35 | 27.16 |

**M3: entries at or below $14 raw, and doublers.** *Not done*; it needs `trades.csv`.

**M4: round trips by band.** Source: `depth.tsv`, where `date_source` is `audit` on every row. Summed NAV % by band is *not done* (needs `trades.csv`).

| arm | band 1–3000 | band 3001–4000 | total | deep-band share |
|---|---|---|---|---|
| S3 | 575 / 552 / 574 / 585 / 581 | 0 | 575 / 552 / 574 / 585 / 581 | 0 |
| U4 | 417 / 412 / 412 / 432 / 431 | 136 / 131 / 127 / 133 / 127 | 553 / 543 / 539 / 565 / 558 | 22.8–24.6 % |
| N3 | 784 / 773 / 768 / 756 / 763 | 0 | 784 / 773 / 768 / 756 / 763 | 0 |
| UN4 | 595 / 590 / 580 / 596 / 634 | 216 / 199 / 191 / 203 / 209 | 811 / 789 / 771 / 799 / 843 | 24.8–26.6 % |

Deep-band round trips by decision period (2000–08 / 2009–16 / 2017–26), ranges over seeds:
- U4: 37–43 / 44–48 / 42–49;
- UN4: 59–74 / 56–59 / 75–90.

**M5: entries by initial-stop kind.** Placed counts come from `entries.tsv`, round trips from `depth.tsv`. Win rate, median return and doublers by kind are *not done* (need `trades.csv`); arm-level pooled statistics are in §3.

| arm | placed SF | placed BF | BF share of placed | round trips SF | round trips BF | BF share of round trips |
|---|---|---|---|---|---|---|
| S3 | 672 / 662 / 682 / 698 / 686 | 0 | 0 | 575 / 552 / 574 / 585 / 581 | 0 | 0 |
| U4 | 655 / 655 / 647 / 681 / 661 | 0 | 0 | 553 / 543 / 539 / 565 / 558 | 0 | 0 |
| N3 | 212 / 209 / 222 / 240 / 225 | 1,529 / 1,568 / 1,500 / 1,461 / 1,482 | 85.9–88.2 % (median 87.1) | 153 / 164 / 170 / 182 / 171 | 631 / 609 / 598 / 574 / 592 | 75.9–80.5 % (median 77.9) |
| UN4 | 200 / 195 / 212 / 233 / 232 | 1,594 / 1,646 / 1,580 / 1,580 / 1,641 | 87.1–89.4 % (median 88.2) | 153 / 146 / 152 / 171 / 174 | 658 / 643 / 619 / 628 / 669 | 78.6–81.5 % (median 80.3) |

SF is `Support_floor` and BF is `Buffer_fallback`.

- N3's BF share of placed entries by period: 89.7–93.6 % (2000–08), 85.5–89.6 % (2009–16), 82.3–84.4 % (2017–26).
- Round trips per placed ticket, a lower bound on the fill rate because positions still open at the end are not counted:

  | arm | Support_floor | Buffer_fallback |
  |---|---|---|
  | S3 | 83.4–85.6 % | — |
  | U4 | 82.9–84.4 % | — |
  | N3 | 72.2–78.5 % | 38.8–41.3 % |
  | UN4 | 71.7–76.5 % | 39.1–41.3 % |

**M6: `No_structural_stop` skips per year (S3, U4).** Source: `nss.tsv`; 1,335 screening Fridays in total. Each cell shows the median over seeds, with the range in brackets.

| year | Fridays | S3 | U4 |
|---|---|---|---|
| 2000 | 51 | 370 (369–373) | 370 (367–371) |
| 2001 | 50 | 235 (234–236) | 224 (223–224) |
| 2002 | 51 | 273 (272–274) | 270 (269–273) |
| 2003 | 50 | 710 (708–713) | 694 (690–697) |
| 2004 | 50 | 942 (942–943) | 916 (911–919) |
| 2005 | 51 | 964 (963–967) | 962 (957–966) |
| 2006 | 51 | 960 (958–965) | 947 (945–949) |
| 2007 | 51 | 880 (875–884) | 866 (862–868) |
| 2008 | 50 | 157 (155–159) | 158 (157–158) |
| 2009 | 49 | 675 (675–676) | 659 (659–661) |
| 2010 | 50 | 925 (919–931) | 920 (912–927) |
| 2011 | 51 | 815 (812–820) | 808 (804–811) |
| 2012 | 51 | 976 (973–977) | 958 (957–960) |
| 2013 | 51 | 952 (950–957) | 943 (941–946) |
| 2014 | 50 | 941 (936–947) | 935 (932–942) |
| 2015 | 49 | 719 (712–720) | 723 (719–726) |
| 2016 | 51 | 855 (852–857) | 859 (858–862) |
| 2017 | 51 | 942 (940–944) | 927 (926–931) |
| 2018 | 51 | 822 (820–825) | 833 (831–837) |
| 2019 | 51 | 880 (874–883) | 879 (877–882) |
| 2020 | 49 | 890 (886–892) | 890 (888–895) |
| 2021 | 50 | 907 (906–908) | 897 (894–898) |
| 2022 | 51 | 580 (579–580) | 580 (578–580) |
| 2023 | 51 | 983 (978–984) | 977 (975–980) |
| 2024 | 51 | 899 (894–902) | 902 (898–905) |
| 2025 | 50 | 931 (927–932) | 936 (933–937) |
| 2026 | 23 | 411 (407–412) | 413 (410–413) |

- Totals: S3 20,583–20,600 and U4 20,429–20,457, a difference of under 1 %.
- By period (2000–08 / 2009–16 / 2017–26): S3 5,489–5,501 / 6,851–6,861 / 8,231–8,250; U4 5,396–5,414 / 6,799–6,812 / 8,232–8,237.

**M7: S3 against NAV-scale P-100k (descriptive, no decision).** Sources: `../nav-scale-participation-2026-11-23/results/kK/ns-P-100k-kK-s0-*` and this run's S3 files.

| seed | P-100k ln (v12) | S3 ln (v13) | Δ | P-100k DD | S3 DD | ΔDD pp | S3 placed also placed by P-100k | S3 placed in names absent from the v12 list in force |
|---|---|---|---|---|---|---|---|---|
| k0 | 2.5739 | 2.6185 | +0.0446 | 39.55 | 43.51 | +3.95 | 526 / 672 (78.3 %) | 27 |
| k1 | 2.5188 | 2.2595 | −0.2593 | 35.23 | 38.15 | +2.91 | 514 / 662 (77.6 %) | 23 |
| k2 | 2.3318 | 1.9919 | −0.3398 | 28.48 | 32.31 | +3.83 | 547 / 682 (80.2 %) | 28 |
| k3 | 2.0741 | 1.8888 | −0.1852 | 31.90 | 32.79 | +0.89 | 545 / 698 (78.1 %) | 26 |
| k4 | 2.4010 | 2.1185 | −0.2826 | 26.56 | 26.23 | −0.33 | 538 / 686 (78.4 %) | 26 |

Median Δ is −0.2593, negative on 4/5 seeds, with median ΔDD +2.91 pp. P-100k passes V6 on all five seeds, while S3 fails it on all five.

### 1.6 Decision rule

> Paired Δ = ln(arm_final / control_final) at the same seed. PASS needs median Δ ≥ +0.20, ≥ 4/5 positive and median ΔDD ≤ +3 pp. HARM needs median Δ ≤ −0.20 and ≥ 4/5 negative. Fewer than 4 valid seeds is INVALID.

| read | Δ k0 / k1 / k2 / k3 / k4 | median Δ | signs | ΔDD pp k0 / k1 / k2 / k3 / k4 | median ΔDD | V6 | valid seeds | verdict |
|---|---|---|---|---|---|---|---|---|
| U4 vs S3 | −0.1804 / +0.0452 / +0.4406 / +0.4422 / −0.0714 | +0.0452 | 3 + / 2 − | −7.24 / −3.58 / −3.36 / +3.28 / +12.20 | −3.36 | fails on 5 | 0 | **INVALID** |
| N3 vs S3 | −1.3222 / −1.3541 / −0.9012 / −0.6418 / −1.0906 | −1.0906 | 5 − | +12.07 / +10.66 / +19.27 / +16.18 / +25.14 | +16.18 | fails on 5 | 0 | **INVALID** |
| UN4 vs U4 | −2.1005 / −2.1042 / −1.4925 / −1.9298 / −2.3375 | −2.1005 | 5 − | +16.36 / +21.02 / +28.69 / +16.71 / +22.46 | +21.02 | fails on 5 | 0 | **INVALID** |

The rule does not allow setting the gate aside. For the record only, the thresholds without it would read INCONCLUSIVE, HARM and HARM.

The PREREG's floor clause: "a Δ inside the 0.45-log single-cell floor that is not traced to the lever's own trades is reported as no effect." Every U4 seed sits inside the floor (largest |Δ| is 0.4422), and none can be traced without `trades.csv`. Every N3 and UN4 seed sits outside it.

### 1.7 Addendum A1–A4

**A1 (deep-band trace): not reached.** U4 is INVALID, and its shape misses the PASS threshold anyway (median +0.045 < +0.20; 3/5 < 4/5). The trace could not be computed in any case, because summed NAV % per deep-band round trip needs `trades.csv` joined to `depth.tsv`.

Knock-on effects (reported, as A1 asks):
- U4 takes 127–136 deep-band round trips per seed, while its band-1–3000 round trips fall to 412–432 from S3's 552–585.
- 219–240 of S3's round trips per seed are missing from U4.
- On k3, 43 % of the dollar gap is unrealised gain on positions still open at 2026-06-26 (+$156,662 of +$367,746). The round-trip test does not count these.

**A2 (top-5 walk): not done as specified.** Ranking the five largest deep-band contributors needs `trades.csv`. What the committed files do show about the deep band:
- Twin legs: CMN (U4 k0–k2) and KONA/KONAQ (U4 k0) are deep-band round trips that duplicate an instrument already held. This is the defect class A2 names.
- Foreign OTC names: 13–14 of the 127–136 deep-band round trips per seed have five-letter F- or Y-suffixed symbols. Examples are OGZPY 2004-09-17 and TKOMY 2018-10-26 (four seeds each), RYCEY 2018-04-06 and CKHUY 2025-03-28 (all five), and DANOY 2005-07-29 (four).
- Partial walk: six recurring deep-band names (SCCO 2003-07-18, RML 2010-07-23, ANIK 2013-06-21, CPRX 2022-03-04, SA 2007-03-02, VHI 2007-03-23) were checked against the local bar store. They were picked by a forward-move proxy, not by P&L. None shows a splice signature: within a year of entry the largest one-day moves are +33 % (ANIK) and −29 % (CPRX). The local store is uncommitted and its vintage is not verified, so this does not satisfy A2.
- BBT 2006-06-09 (all five U4 seeds) was checked and cleared; see the end of §6.

Because U4 did not PASS, A2's cap and rerun clause do not bind. Any future U4 PASS on these lists would meet A2 at once.

**A3 (confirmation): not triggered** (no PASS or PAYS-WITH-RISK).

**A4 (N3 follow-up): not triggered.** "If N3 is HARM or INCONCLUSIVE, nothing follows", and an INVALID read licenses nothing either.

## 2. Verdict, calibrated

**What the run can claim.** As built, it cannot read either question under its own rule. INVALID is a statement about the input lists, not about depth or the stop. The PREREG gives no follow-up for INVALID; the closest analogue is A2's "quarantine, then rerun the affected pair with the same specs and thresholds".

**U4 is noise-sized even read descriptively.**
- Every seed's |Δ| is inside the 0.45 single-cell floor.
- Mean Δ +0.135, SD 0.291, SE 0.130.
- Leave-one-seed-out medians range from −0.013 to +0.243, so a single seed moves the median across the +0.20 bar.
- The per-pair SD (0.29) is about S3's own seed SD (0.284). Pairing removes little variance: the correlation of S3 and U4 across seeds is 0.24, because the two arms share only 59–62 % of their round trips (§3.2).

**Power of a clean K=5 rerun.** Under a normal model with per-pair SD 0.29 (20,000 draws per effect size), the chance of "median ≥ +0.20 and ≥ 4/5 positive" is:

| true effect (log) | P(PASS shape) |
|---|---|
| 0 | 0.06 |
| +0.20 | 0.43 |
| +0.30 | 0.68 |
| +0.40 | 0.87 |

So K=5 resolves only effects around +0.4 log (about +1.5 log-pp a year) or larger. The observed shape is where a rerun most likely comes back INCONCLUSIVE.

**U4's lower seed spread proves nothing.** Its seed SD is 0.159 against S3's 0.284. The variance ratio of 3.2 is below the 5 % critical value of 6.4 for F(4,4). Do not read it as "depth reduces path risk".

**N3 and UN4.** Their HARM shapes are 1.4–5 times the floor on every seed (N3 −0.64 to −1.35; UN4 vs U4 −1.49 to −2.34). The twins that break the gate amount to one to three positions per cell, and one twin on record moved a 26-year path by 0.204 log (#3266). A clean rerun is unlikely to flip these signs; that is an expectation, not a verdict. Neither read is needed for a decision: spine item 5 settles N3, and A4 licenses nothing on a HARM.

**What the run cannot claim.** Neither "depth does not pay" nor "the structural stop is proven". It is one market history; PREREG calls ≥ 4/5 "a consistency check, not a significance test".

**Economic scale.** Medians over seeds, 26.48 years, $100k start:
- CAGR: S3 8.33 %, U4 9.20 %, N3 4.20 %, UN4 1.28 %.
- Median paired Δ per year: U4 − S3 +0.17 log-pp, N3 − S3 −4.12, UN4 − U4 −7.93.
- At the median, N3 ends with e^−1.09 ≈ 34 % of S3's NAV at the same seed, and UN4 with about 12 % of U4's.

## 3. Why

### 3.1 The gate failed because the v13 lists contain rename twins

**Trace 1: GLPG/LKFT (S3, every seed).**
- Lists: both are in v13 `top-3000-2018`, LKFT at rank 1906 ($12,560,158 ADV) and GLPG at rank 1908 ($12,550,920). In the v12 2018 list GLPG is at rank 1865 with the same ADV, and LKFT is absent.
- LKFT is in no v12 list and not in the committed 05-21 `data/symbol_types.sexp`. It was added by the 11-23 fetch.
- Both were placed on 2018-09-28 and filled on 2019-04-03 (the V6 date).
- V6 flags the pair in all five S3 cells.
- U4 holds both legs only on k0. On k1–k4 it holds GLPG alone, so U4 vs S3 differs on k3 and k4 for this pair alone.

**Trace 2: CMD/CMN (U4 k0–k2), a twin split across the band boundary.**
- CMD is in `top-3000-2009` at rank 2185 ($2,944,720). CMN is only in `top-4000-2009`, at rank 2945 ($873,840), so `depth.tsv` labels it band 3001–4000.
- Both were placed on 2009-10-30 and entered on 2009-11-09. S3 can hold only CMD.
- v12's drop file removed CMN from five top-3000 lists (2005, 2009 and 2013–15). v13's drop file has no row for the pair.
- Precedent: in #3266 this pair, entered the same week, moved a 26-year path by 0.204 log. The twin leg made +$28.7k, and the cash it took pre-empted a CRM ticket worth +$425k (`project_26y_path_noise_floor`).
- So in U4 k0–k2, one "deep-band contribution" is a second copy of a band-1–3000 holding, of a kind known to re-draw the path.

**Trace 3: KONA/KONAQ (U4 k0).**
- Both are in `top-4000-2012` at ranks 3400 and 3401, with identical ADV of $667,736.
- Placed 2013-05-03, entered 2013-05-06.
- KONA is absent from the 05-21 symbol_types and from every v12 list.

**Trace 4: EURN/CMBT (UN4 k0, k1, k3, k4).**
- Both are in `top-4000-2018` at ranks 3041 and 3042 ($2,702,748 and $2,701,892).
- Both were placed on 2018-10-12 with `Buffer_fallback` stops and filled on 2019-05-16.
- v12 dropped EURN in favour of CMBT in nine top-3000 lists (2015–17 and 2019–24). v13 has no row.
- The same pattern holds for NCS/CNR_old2 (U4 k1–k2): `top-3000-2017` ranks 2414 and 2452, placed 2017-12-15, entered 2017-12-22. NCS is a new name.

**List census.**
- Of the 512 unique v12 top-3000 twin-drop rows, 439 (91 distinct pairs) have both legs in the same year's v13 top-3000 list.
- 240 of those rows (58 pairs) have the two legs' v13 ADV within 1 %. An example is NCR/VYX in 1999, at ranks 517 and 518 ($27,743,337 and $27,742,945).
- v13's own drop file has 6,728 top-3000 rows and 8,864 top-4000 rows, so its scan did run.

**What the scan missed.** Two classes:
- pairs v12 had already dropped and v13 let back in (CMN/CMD, EURN/CMBT, and the 439-row census);
- new aliases brought in by the 11-23 fetch (LKFT, KONA, NCS).

`pit_twin_cooccur_check.sh` checks each list only against its own drops file, so neither class can fail it.

**Perturbation.** Twin counts do not line up with U4's sign pattern:
- k0: U4 has two more twins than S3, and Δ is −0.18;
- k1 and k2: U4 has 2, S3 has 1, and Δ is +0.05 and +0.44;
- k3 and k4: S3 has 1, U4 has 0, and Δ is +0.44 and −0.07.

The twins do not explain the signs. Their size is unknown without `trades.csv`, but one can be about 0.2 log, the size of the PASS bar. That is why the gate exists.

### 3.2 U4 vs S3: depth substitutes for top-3000 names, and the path is re-drawn

**The gate binds the same way.** `No_structural_stop` skips differ by under 1 % overall (§1.5 M6). Both arms see about 20 shortlisted candidates per buying Friday (S3 k0: 9,505 evaluated rows over 479 buying Fridays). Deep-band names enter the shortlist only by displacing top-3000 names.

**The book is capacity-bound.**
- U4 makes 539–565 round trips against S3's 552–585.
- 127–136 of U4's are deep band, so its band-1–3000 round trips fall to 412–432.
- Insufficient_cash is counted along the path (read rule d): skips on 84–94 of U4's 460–488 buying Fridays, against 78–96 of S3's 479–504.

**The path is re-drawn.**
- Only 58.7–61.9 % of S3's round trips appear in U4 at the same seed (Jaccard 0.43–0.46).
- For comparison, S3 k0 against its other seeds shares 75.1–76.9 % (Jaccard 0.61–0.63).
- Per seed, 219–240 of S3's round trips are gone in U4. U4 has 195–217 that S3 lacks: 127–136 deep band, and 68–90 top-3000 round trips that only U4's path reaches.
- The arms behave more like two draws than a paired perturbation, which is why pairing barely helps.

**Trace 5: MSTR 2004-10-29 (`entries.tsv`).**
- S3 places MSTR that Friday on all five seeds. U4 places it on k2–k4 and skips it for Insufficient_cash on k0 and k1.
- In the 15 weeks before, U4 bought deep-band names that S3's lists do not contain:
  - k0: MGEE 2004-07-16, MCS 2004-07-23, MDCC 2004-08-20 and OGZPY 2004-09-17;
  - k1: MGEE, MCS and MDCC (2004-08-13).
- On the same Friday, both U4 seeds still placed KFRC.
- S3 k0 and k1 also place MSTR on 2020-09-18. U4 never does: its 2020 MSTR candidacies (2020-08-21 on every seed, and 2020-10-09 on k1–k4) were all skipped for no structural stop.
- k0 is U4's worst seed (−0.18). Yet k1 misses the same 2004 ticket and ends +0.05. No single substitution decides a seed's sign.

**APPS 2020-06-12 goes the other way.** U4 places it on 5/5 seeds; S3 places it only on k0 and k3. S3 k1 skipped it for cash. S3 k2 and k4 have no `entries.tsv` rows that Friday because they placed nothing (D7). k2 is one of U4's best seeds (+0.44). No ticket's size is known without `trades.csv`.

**Per-trade economics** (pooled; `summary.sexp`). Expectancy per trade is derived as win rate × average win % + (1 − win rate) × average loss %.

| metric | U4 | S3 |
|---|---|---|
| win rate | 39.1–41.0 % | 39.3–40.7 % |
| average win | 22.9–24.1 % | 22.3–25.8 % |
| average loss | −8.26 to −8.43 % | −8.38 to −8.80 % |
| expectancy per trade | 3.82–4.75 % (median 4.56) | 3.70–5.53 % (median 3.83) |
| profit factor | 1.36–1.52 | 1.39–1.66 |

By expectancy, U4 is above S3 on k1–k3, below on k0 and level on k4: the same sign pattern as Δ. With about 40 % of the round trips differing between the arms, this reflects the path, not the band. The band's own per-trade numbers need `trades.csv`.

**Where the dollars came from.** Realised is `summary.sexp` `totalpnl`; unrealised is `actual.sexp` `unrealized_pnl`.

| seed | final NAV gap (U4 − S3) | realised | unrealised | interest | dividends |
|---|---|---|---|---|---|
| k2 | +$405,799 | +$300,926 | +$43,860 | +$46,421 | +$25,861 |
| k3 | +$367,746 | +$153,520 | +$156,662 | +$33,991 | +$35,773 |
| k0 | −$226,433 | −$371,687 | +$131,863 | — | — |

**Drawdown.** There is no consistent change. ΔDD runs from −7.24 to +12.20 pp (median −3.36), and the median ΔUlcer is −1.04; both change sign across seeds.

### 3.3 N3 vs S3: the fallback door

This is a gate-distance lever, so read rule (a) applies: admissions, crowd-out and positions, not only the endpoint.

**What the gate was doing.**
- On S3's buying Fridays, about 90 % of evaluated candidates fail the structural-stop requirement (k0: 8,571 of 9,505 rows).
- Across all 1,335 screening Fridays, S3 logs 20,583–20,600 such skips, about 15 per Friday.
- N3 enters every one of them on the fallback stop, about 4 % under entry: either the support-floor scan found no qualifying low, or the structural stop was more than 15 % away and was re-anchored (`floor_stop.ml`, `entry_audit_helpers.ml`).

**Admissions.** N3 places 1,701–1,777 entries against S3's 662–698.

| period | N3 placed | S3 placed |
|---|---|---|
| 2000–08 | 495–549 | 152–166 |
| 2009–16 | 556–606 | 206–230 |
| 2017–26 | 604–673 | 291–307 |

**Sizing puts every fallback position at full size.** Risk sizing is 1 % of NAV divided by the stop distance. A 4 % stop asks for 25 % of NAV and is cut to the 14 % cap (`portfolio_risk.ml`, `_compute_position_size_finite`). With the 70 % exposure cap and 30 % cash floor, about five such positions fill the book.

**Cash binds on essentially every buying Friday.**
- N3 has Insufficient_cash skips on 728–780 of its 729–782 buying Fridays; S3 has them on 78–96 of 479–504.
- That is 12,481–13,480 such skips per seed, against 150–180.

**Crowd-out (read rule a).** N3 places only 209–240 Support_floor entries, against S3's 662–698. Only 18.1–22.9 % of S3's round trips appear in N3 (Jaccard 0.08–0.11). From `entries.tsv`:
- **ODSY 2009-10-30:** S3 places it on 5/5 seeds; N3 skips it for Insufficient_cash on 5/5.
- **MMYT 2023-10-06:** S3 places it on 5/5 seeds, after skipping it for no structural stop on 2023-08-04 and 2023-09-08. N3 skips it for cash on 2023-10-06 on 5/5 seeds. Every earlier N3 appearance, from 2018 on, was skipped too: for cash, apart from three Sized_to_zero skips on 2023-09-29 (k0, k2, k4).
- **APPS 2020-06-12:** S3 places it on k0 and k3; N3 skips it for cash on 5/5. N3 k0 later buys APPS on 2021-10-08 as a fallback entry, on a date S3 skipped for no structural stop.
- **BGO 2003-07-11:** S3 places it on 5/5 seeds; N3 places it on 2/5 and skips it for cash on 3/5.

**What the fallback trades do.** Pooled from `summary.sexp`; 76–81 % of N3's round trips are fallback.

| metric | N3 | S3 |
|---|---|---|
| win rate | 26.5–30.4 % | 39.3–40.7 % |
| average loss | −5.85 to −6.27 % | −8.38 to −8.80 % |
| loser hold | 27–30 days | 37–40 days |
| average win | 17.8–19.9 % | 22.3–25.8 % |
| winner hold | 138–145 days | 153–162 days |
| expectancy per trade | 0.49–1.28 % (median 0.97) | 3.70–5.53 % (median 3.83) |
| profit factor | 1.01–1.11 | 1.39–1.66 |
| max consecutive losses | 31–51 | 16–33 |
| largest single win | $26,397–$89,199 | $141,149–$278,539 |

**Fills.** About 40 % of fallback tickets become round trips (38.8–41.3 %). N3's own Support_floor tickets fill 5–13 pp less often than S3's, so part of the gap is cash taken at fill time by earlier fills. The committed files do not record why a ticket did not fill.

**The trading book barely makes money.**
- Realised P&L over 26.5 years is $8,594–$97,043 on a $100k start; S3's is $427,924–$1,043,248.
- N3's $147k–$266k NAV gain rests more on interest ($25.5k–$35.9k), dividends ($40.4k–$78.9k) and positions still open at the end ($49.8k–$110.6k) than on closed trades.

**Quality flags rise with the door** (validator logs, within this run):
- V7 (a virgin-territory label without enough history): 131–160 per N3 cell, against 22–31 for S3;
- V18 (an implausible stored series): 18–28, against 8–13;
- V16 (fallback exits): 2–5, against 1.

Examples are PLZL (D3) and the stale-held OMM and BUDFF (D4).

**In one line:** the fallback door turns "buy only when support is near" into "buy the shortlist at a 4 % stop and full size". The book fills with extended names that are stopped out within a month, and their cash is missing when the record's tail entries trigger (`project_edge_is_the_fat_tail`). This is spine item 5's warning against automatic percentage stops, visible in the numbers.

### 3.4 UN4: the two levers compound

**Decomposition** (log, per seed).
- UN4 − S3: −2.281 / −2.059 / −1.052 / −1.488 / −2.409 (median −2.059).
- Main effects: U4 − S3 median +0.045; N3 − S3 median −1.091.
- Interaction, (UN4 − N3) − (U4 − S3): −0.778 / −0.750 / −0.591 / −1.288 / −1.247. Negative on 5/5 seeds, median −0.778.
- So depth is about neutral with structural stops, and is about 0.85 log worse once the fallback door is open (UN4 − N3 median −0.846, 5/5 negative; a shape from V6-failing pairs, not an effect estimate).

**Which door the deep band uses.**
- In U4, every deep-band round trip is Support_floor (127–136).
- In UN4 the deep band has 191–216 round trips, of which 157–177 (77–84 %) are fallback.
- Only 24–34 of UN4's deep-band round trips match a U4 deep-band round trip on symbol and decision date.

**What it displaces.** Both N arms are cash-bound on every buying Friday, so UN4's deep band replaces top-3000 round trips: UN4 has 580–634 of them against N3's 756–784.

**The replacements are worse.** Pooled evidence; per-band returns need `trades.csv`.
- UN4's win rate is below N3's on 5/5 paired seeds (25.4–26.9 % against 26.5–30.4 %).
- Its average loss is larger on 5/5 (−6.13 to −6.35 % against −5.85 to −6.27 %), and losers are held for less time on 4/5 seeds (25–28 days against 27–30).
- Thin names gap through a 4 % stop more often.
- ADV-participation skips rise to 62–163, against 38–57 in N3.

**Result.**
- Realised P&L is negative on 4/5 seeds: −$19,057 / −$31,934 / +$25,887 / −$20,610 / −$66,947.
- k4 ends at $74,798 (ln −0.2904).
- Dividends ($26.5k–$41.6k) exceed realised P&L on every seed, and interest ($19.6k–$27.0k) does on four; the gains on k0–k3 rest on them and on open positions.
- DD is 52.6–60.9 %, and the account spends 94.3–95.6 % of the time in drawdown.

**The deep band brings its own defects into this arm:** the EURN/CMBT twin (four seeds), and MRS, a deep-band fallback entry on 2000-06-23 on all five seeds that the summary flags as stale-held (D4).

### 3.5 Measure 7: the list rebuild moved the baseline more than depth did

- S3 is −0.26 log against P-100k at the median, negative on 4/5 seeds.
- 77.6–80.2 % of S3's placed entries are also placed by P-100k on the same date. Only 23–28 per seed are names missing from the v12 list in force. Most of the gap is the cascade re-drawing the path, not new names trading.
- The comparison bundles more than PREREG's two named changes (survivorship fill and true-dollar ranking). It also changes:
  - the bar store (data-20261102 to data-20261123);
  - corporate actions (corpact-2026-10-27 to corpact-2026-11-23);
  - the warehouse (v12wk-9236 to v13pit-12710);
  - the twin regression: S3 fails V6 on every seed, P-100k on none.
- −0.26 is about one seed SD (S3 0.284, P-100k 0.196), so the parts cannot be separated here.

## 4. How it fits what we know

- **`project_pit_chunked_twin_miss` (confirmed, and refined).** The same class came back: a list rebuild re-opened rename twins. The refinement is that v13's build already had cross-chunk scans ("twinfix" in its drop-file header) and still re-admitted 439 v12-confirmed rows, plus new aliases from the fetch. The rule needs one more line: *a list rebuild must re-apply the previous vintage's drops and scan new names against the whole store*.
- **`project_26y_path_noise_floor` (#3266) (confirmed).** The same CMD/CMN pair, in the same week, is where the 0.2-log path-noise figure came from. It recurs here in U4 k0–k2.
- **`project_universe_depth_audit` (confirmed).** Its structural-stop prior (4 % fallback stops: 26y +133 % with DD 55 %, against +624 % with DD 31 %) is reproduced in shape: N3's median total return is +197.6 % with DD 51.4 %, against S3's +731.8 % with DD 32.8 %. Its 2.4 % hard-defect rate for ranks 3001–4000 shows up as twin legs and stale-held MRS in the deep band.
- **`project_nav_scale_participation` and `project_trait_y_low_price` (consistent).** NAV-scale found that at $100k the universe and the `No_structural_stop` gate are what keep cheap names out. Here, widening adds nothing measurable at this power, and removing the gate is HARM-shaped.
- **`project_edge_is_the_fat_tail` (confirmed from a new angle).** The N arms crowd out tail entries (ODSY, MMYT, APPS, BGO), and both average win and largest win collapse.
- **`project_record_kseed_band` (applied).** S3's seed SD here is 0.284, against 0.225 on the v12 record band; the 0.45 floor is applied.
- **`project_cell_e_2020_stall_regime` ("broad universe is the lever") (not contradicted).** That lever was sp500 to top-3000. This run asks whether 3000 to 4000 adds more, and finds nothing measurable at K=5. Saturation by top-3000 at $100k is plausible but unproven.
- **`project_pit_survivorship_inflation` (consistent in direction).** Measure 7's direction (−0.26 with fallen names filled in) is what removing survivorship should do, but measure 7 is confounded (§3.5).
- **Ledger.** No prior entry covers either lever on v13. This run's entry is `dev/experiments/_ledger/2026-11-25-universe-depth.sexp`. The ledger's verdict type has no Invalid, so the entry carries Inconclusive, with INVALID for all three reads, the V6 reason and the non-verdict shapes in its notes.

## 5. What it implies next (options; the choice is the user's)

1. **Repair the v13 lists first.** Every option that runs v13 again needs this:
   - re-apply v12's twin drops;
   - scan the 11-23 additions against the whole store;
   - alias the dropped legs out of both list families;
   - make the co-occurrence check compare a new vintage against the previous vintage's drops (extends #3713).

   The warehouse may not need a rebuild if the lists alone exclude the legs; confirm with the data agent. Record the repaired lists in a short addendum before any rerun, as A2's rerun clause does.
2. **Then rerun S3 and U4 only (10 cells).** This is the only read with an open question. Expect INCONCLUSIVE unless the true effect is about +0.3 log or more (power 0.68; 0.87 at +0.4). A finer answer needs more seeds under a new pre-registration.
3. **Or rerun all 20 cells.** This completes the record, but no N3 or UN4 result can change a decision.
4. **Or stop here.** Record INVALID with the shapes. The practical outcome matches the INCONCLUSIVE branch: picks stay on top-3000. Still do option 1 before v13 is used for a record re-baseline or for the weekly picks.
5. **Cheap hardening, independent of the above.** An entry-time guard that treats rename twins like share classes (`Share_class_held` already fires 0–18 times per cell) would stop a missed list twin from being bought twice. It would be a flag-gated simulator change, not a substitute for repairing the lists.
6. **The fallback door.** Nothing follows (A4).

## 6. Defects found

**D1. The v13 lists keep rename twins (blocking).**

| pair | list | ranks | cells affected |
|---|---|---|---|
| GLPG/LKFT | `top-3000-2018` | 1908 / 1906 | S3, all seeds |
| CMD/CMN | `top-3000-2009` and `top-4000-2009` | 2185 / 2945 | U4 k0–k2 |
| KONA/KONAQ | `top-4000-2012` | 3400 / 3401 | U4 k0 |
| NCS/CNR_old2 | `top-3000-2017` | 2414 / 2452 | U4 k1–k2 |
| EURN/CMBT | `top-4000-2018` | 3041 / 3042 | UN4 k0, k1, k3, k4 |

`pit-v13/twin-drops.txt` has no row for any of these pairs. Census: 439 of 512 v12 top-3000 drop rows have both legs in the same year's v13 top-3000 list, 240 of them with ADV within 1 %.

**D2. The twin check cannot see D1.** `trading/devtools/checks/pit_twin_cooccur_check.sh` checks each list only against its own drops file. #3713 (open) adds a v13 rule but no cross-vintage check.

**D3. A foreign listing with an absurd ADV gets in through the fallback door.**
- PLZL is at rank 155 in `top-3000-2010` with $312,317,542 ADV, and at rank 1798 in `top-3000-2017` ($13,492,113). It is in the v12 lists too.
- Only N3 trades it, always as `Buffer_fallback`: 2010-06-25 on k0–k3, and 2017-09-08 on k2 and k4.
- It is stale-held in N3 k0–k3 (`stale_held_symbols`). The local store shows 233–243 bars a year, a non-US calendar.
- It belongs to the same class as PREREG's known residue (HSBA, SBER, VPI, LDG), but it does not hit every arm alike.

**D4. Stale-held names appear only in the N arms** (`summary.sexp` `stale_held_symbols`):

| name | cells |
|---|---|
| OMM | N3 k0, k1, k2, k4; UN4 k0, k2, k4 |
| MRS | UN4, all five seeds |
| PGL | UN4 k4 |
| BUDFF | N3 k1, k2; UN4 k2 |
| PLZL | see D3 |

S3, U4 and P-100k carry only NLC, plus SWAY in U4 k3. In the local store, OMM's series has a gap from 2007 to 2018, MRS's from 2001 to 2007 and PGL's from 2007 to 2009, which looks like ticker reuse. Whether each position was exited at the gap or marked across it needs `trades.csv` and `force_liquidations.sexp`.

**D5. The U arms have one extra simulation step** (`n_steps` 6,899 against 6,898). Some name in the top-4000 lists alone supplies a bar on a date that no S-arm name has. Locate it with `equity_curve.csv`. It is harmless if that date is a real session, and a stale-fill risk if it is a holiday row (`project_saturday_stale_fill_defect`).

**D6. Resumed cells skipped the tripwire after a rebuild:** k0 and k3 (U4, N3, UN4) and k4 (UN4). The SHA and image are the same, so the risk is low. The kit should re-run the tripwire whenever BUILD actually rebuilds.

**D7. `entries.tsv` has rows only for Fridays with a placement** (S3 k2 and k4 have none on 2020-06-12). A Friday that evaluated candidates but placed nothing cannot be told apart from one that evaluated nothing. This is a kit limitation for future reads.

**D8. V7 (an invariant check) fails in every cell:** 22–36 violations in the S and U arms, 131–180 in the N arms, and 26 in the v12 tripwire cell. It is outside the PREREG gate and predates this run, but it rises 4–6 times with the fallback door. Worth checking that its INV status matches how it is used.

**Checked and cleared: BBT 2006-06-09** (U4 deep band, all five seeds). In the local store, the BBT series matches BHLB's on all 6,334 common days (closes within 0.5 %). It is Berkshire Hills' history under its later ticker, and `pit-v13/twin-drops.txt` drops BHLB in favour of BBT. Not a defect.

## Appendix A. Not done from committed files, and what each needs

| check | needs (in `dayfine/trading-results`, same path) |
|---|---|
| M1 and M2 by period; positions held along the path (read rule a) | `equity_curve.csv` per cell |
| M3 entries at or below $14 raw, doublers | `trades.csv` |
| M4 summed NAV % by band; A1 trace | `trades.csv` joined to `depth.tsv` on `position_id`; NAV at entry from `equity_curve.csv` |
| M5 win rate, median return and doublers by stop kind | `trades.csv` joined to `depth.tsv` |
| A2 top-5 walk | M4 ranking, then the data-20261123 bars for each name |
| Size of each twin's double position | `trades.csv` |
| Stale-held exit path (D4) | `trades.csv`, `force_liquidations.sexp` |
| Specimens for V7, V16 and V18 | validator reports |
| Review pack (RV1) | `trades.csv`, `equity_curve.csv` |
| Why placed tickets did not fill | trade audit (not kept) |

## Appendix B. Sources for every quoted number

All paths are relative to `dev/experiments/universe-depth-2026-11-23/` unless noted; K is 0–4.

| figures | file |
|---|---|
| ln(final/initial), final NAV, median final NAV | `results/kK/ud-<arm>-kK-s0-summary.sexp` (`final_portfolio_value`, `initial_cash`); the same values appear in the `chain-kK.log` `RESULT` lines |
| max DD, Ulcer, unrealised P&L | `ud-<arm>-kK-s0-actual.sexp` (`max_drawdown_pct`, `ulcer_index`, `unrealized_pnl`) |
| CAGR, win rate, average win and loss %, PF, largest win, hold days, max consecutive losses, time in drawdown, realised P&L, interest, dividends, `n_steps`, `stale_held_symbols` | `ud-<arm>-kK-s0-summary.sexp` (`cagr`, `winrate`, `avgwinpct`, `avglosspct`, `profitfactor`, `largestwindollar`, `avgholdingdays*`, `maxconsecutivelosses`, `timeindrawdownpct`, `totalpnl`, `cashinteresttotal`, `dividendincometotal`) |
| Derived expectancy % | `summary.sexp` `winrate`, `avgwinpct`, `avglosspct`, using the formula in §3.2 |
| Tripwire md5, 563 lines, ln 2.5739, DD 39.55, SC_SHA, image, ABSENT counts, ABORT and restart times, build durations, PAIR exits, LIVE counts | `results/kK/chain-kK.log` |
| V6, V7, V16 and V18 counts | `ud-<arm>-kK-s0.validator.log`; for P-100k, `../nav-scale-participation-2026-11-23/results/kK/ns-P-100k-kK-s0.validator.log` |
| V6 DIFFER verdicts and specimen dates | `ud-<arm>-kK-s0.v6diff-<control>.log` |
| Round trips by band, kind and period; deep-band events (197 distinct, 82 on all seeds; UN4 469 and 46); trade overlaps and Jaccard; named decision dates (GLPG, CMD, CMN, KONA, KONAQ, NCS, CNR_old2, EURN, CMBT, MRS, PLZL, BBT, OGZPY, TKOMY, RYCEY, DANOY, CKHUY, MGEE, MCS, MDCC, KFRC, ODSY, MMYT, APPS, BGO, MSTR); F/Y symbol counts | `ud-<arm>-kK-s0-depth.tsv` |
| Placed and skipped counts, skip reasons, BF placed share and its split by period, buying Fridays, rows per Friday, MSTR, MMYT, ODSY, APPS and BGO skip reasons | `ud-<arm>-kK-s0-entries.tsv` |
| `No_structural_stop` skips per year and period; 1,335 Fridays | `ud-<arm>-kK-s0-nss.tsv` |
| `code_version`, `universe_size`, `initial_cash`, `require_structural_stop`; 14 % position cap, 70 % exposure cap, 30 % cash floor | `ud-<arm>-kK-s0-params.sexp` (`max_position_pct_long`, `max_long_exposure_pct`, `min_cash_pct`) |
| Macro path identical in all cells | `ud-<arm>-kK-s0-macro_trend.sexp` (one md5) |
| Empty corporate-action extras | `results/kK/td-ca-extra-v1{2,3}.txt` |
| P-100k ln, DD, Ulcer; M7 placed overlap | `../nav-scale-participation-2026-11-23/results/kK/ns-P-100k-kK-s0-{summary.sexp,actual.sexp,entries.tsv}` |
| List ranks and ADVs (GLPG, LKFT, CMD, CMN, KONA, KONAQ, NCS, CNR_old2, EURN, CMBT, NCR, VYX, PLZL, BBT) | `trading/test_data/backtest_scenarios/pit-v13/composition/top-{3000,4000}-YYYY.sexp`; GLPG in v12 from `pit-v12/composition/top-3000-2018.sexp` |
| 512, 439 (91 pairs), 240 (58 pairs), 6,728, 8,864; v12 rows for CMN/CMD (five lists) and EURN/CMBT (nine lists); v13 row BHLB to BBT | `pit-v12/twin-drops.txt`, `pit-v13/twin-drops.txt`, plus the v13 composition lists |
| 23–28 S3 entries in names missing from the v12 list in force | `ud-S3-kK-s0-entries.tsv` against `pit-v12/composition/top-3000-YYYY.sexp` (list in force = latest 05-31 rebalance on or before the decision date) |
| LKFT, KONA and NCS are new names | `data/symbol_types.sexp` (committed, 05-21 vintage) and the v12 composition lists |
| 1 % risk per trade | `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml` (default `risk_per_trade_pct`, not overridden in `params.sexp`) |
| 4 % fallback stop and the 15 % re-anchor | `trading/trading/weinstein/stops/lib/floor_stop.ml` (`compute_initial_stop`: half of `min_correction_pct` 0.08 below a reference of entry × `initial_stop_buffer` 1.0); `stops/lib/stop_types.ml` (`max_stop_distance_pct` 0.15); `trading/trading/weinstein/strategy/lib/entry_audit_helpers.ml` (`_maybe_reanchor_to_entry_base`, armed by `stop_anchor_at_entry_base true` in `params.sexp`) |
| 0.204 log, +$28.7k, +$425k (#3266) | memory `project_26y_path_noise_floor`; `dev/experiments/verify-3266-rerun-2026-10-22/` |
| +133 % / DD 55 % against +624 % / 31 % prior | memory `project_universe_depth_audit` |
| Power table, leave-one-out medians, correlation 0.24, variance ratio 3.2, seed SDs, interaction, per-year scaling | computed in this read from the ln values above (normal model, 20,000 draws, per-pair SD 0.29; 26.48 years) |
| BBT/BHLB match; OMM, MRS and PGL gaps; PLZL calendar; six-name partial walk | local store `/Users/difan/Projects/trading-1/data/` (uncommitted, vintage unverified); used only to clear or flag, never for a verdict |
