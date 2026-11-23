# NAV-scale participation, K=5, 26 years: the read

Pre-registration: `README.md` as merged in #3699 (44f1ba28e). The rule is applied as written; nothing in it was adapted.
Cells: record spec rk-k0..k4, 2000-01-01 → 2026-06-26, PIT top-3000 schedule (`pit-v12/composition/top-3000-*`). No sp500 cell.
Paths: `pub:kK/` = `results/kK/` here; `prv:kK/` = trading-results
`dev/experiments/nav-scale-participation-2026-11-23/results/kK/`. Draft by results-analyst; qc-results reviews it.

## Verdicts

- **P-100k: INCONCLUSIVE.** Median Δ +0.002 (3 of 5 positive), median ΔDD +0.04 pp. Per the rule, live-size stays opt-in, and no further cells run without a new mechanism argument.
- **P-1M: INCONCLUSIVE.** Median Δ −0.024 (2 of 5 positive), median ΔDD −0.20 pp. Per the rule, #3681's verify item closes as "no effect at backtest NAV".
- P-10M (descriptive): Δ −0.62 to −0.98 on all 5 seeds (median −0.74), with a third fewer round trips. At a $10M start, a 10 % participation rule removes the record's late tail.
- F across cash (descriptive): whole-share rounding alone moves the record by up to 0.124 log between adjacent cash levels, and 0.184 from $100k to $10M (both on k1).

## Review-pack look

Packs built with `review_pack.sh --no-container` from the private per-arm files (k0: F-1M, P-1M, F-10M, P-10M; k1 and k3: F-1M, P-1M) and rendered with `review_pack_render.sh`; looked at by the dispatcher. The packs carry prices, so they stay local and are not committed.

- **KPI strips match summary.sexp.** k0 F-1M +1,175 %, DD 39.6 %, 559 trades; k1 +1,156 %, DD 35.2 %, 536; k3 +692 %, DD 31.9 %, 557. k0's arm line reads +1,175 / +935 / +1,166 / +503 % for F-1M / P-1M / F-10M / P-10M, i.e. ln 2.546 / 2.337 / 2.538 / 1.796 as in §1.2.
- **One-trade years land where §3.2 says.** k0's eras show the 2010–15 build (ODSY/FOSL era); k1 shows "built 2020 (2.08 → 2.57×)", the APPS draw; every pack shows the 2024 build (ADMA, MMYT).
- **Eras vs SPY agree with §1.2.** Every pack erodes against SPY from 2016 or 2021 to the end. k3 ends at 0.98× SPY (ln 2.070 vs 2.087), the one seed below SPY, as §3.4 says.
- **Not in this read, flagged by the k0 pack:** at the 2021-02-09 NAV peak, F-1M k0 held MSTR with an open gain of 37.8 % of peak NAV before the 39.6 % drawdown to 2023-10-27. It is shared by F and P at $1M, so it does not enter Δ; it is the concentration the record already carries.
- **RV3, the remaining pack signals:** each pack's "What stands out" list printed (eras, reopen episodes, worst three-year stretch, concentration, fill and stop-exit counts) and nothing in it contradicts this read; the fallback-stop, E-below-close and trail-never-raised rows print n/a because they need the trade audit, which `--no-container` skips. Entry geometry and conformance rows are likewise not built; no claim here rests on them.

## 1. The rules, in order

### 1.1 Tripwire and validity

| check | result |
|---|---|
| Tripwire: F-1M k0 `trades.csv` md5 = `TRIP_MD5` 3ee10dca319e54a85f5e0a7842d8c537 | match in all 5 sessions |
| F-1M is the record | `trades.csv` md5 equals the record's vsb-1 cell on every seed (k0 3ee10dca…, k1 e0f36ca0…, k2 55e610d2…, k3 76fcc961…, k4 a098c72e…). ln 2.546 / 2.531 / 2.332 / 2.070 / 2.481 is the ledger band |
| One build, one input | all 30 cells at 44f1ba28e, image sha256:886851cbc0f1, warehouse of 9,236 symbols and 11,880 dividend files |
| V6, each P arm vs F at the same cash and seed | 15 of 15 pairs `V6 \| 0 \| 0 \| agree`, exit 0. No seed dropped; 5 valid seeds per cash level |
| Validator | V6 PASS in 30 of 30; one V16 fallback exit per cell; audit join 100 % |

Liveness: `trades.csv` must differ from F at the same cash on at least 3 of 5 seeds, and `Adv_participation_cap` must appear in the audit.

| arm | seeds whose trades differ from F | cap skips, k0..k4 | |
|---|---|---|---|
| P-100k | 5/5 | 2, 4, 2, 2, 4 | live |
| P-1M | 5/5 | 31, 38, 39, 26, 53 | live |
| P-10M | 5/5 | 252, 258, 245, 232, 261 | live |

P-100k is live by the rule's letter, but its cap barely acts. Its 14 skips are four events:

- MTBLY 2015-05-29 and AMST 2024-12-27, on every seed;
- CVM 2021-01-29 and VHC 2021-02-12, on k1 and k4.

F-100k never traded MTBLY, AMST or VHC, because their ADV sat under its $1M floor. Its CVM ticket of 2021-01-29 never filled. So at $100k the cap removed no F trade on any seed. P-100k's divergence comes from the $100k entry floor (§3.3).

### 1.2 What is measured (per arm, median over seeds)

**Measure 1: ln(final / initial).**

| arm | k0 | k1 | k2 | k3 | k4 | median |
|---|---|---|---|---|---|---|
| F-100k | 2.585 | 2.406 | 2.330 | 2.070 | 2.454 | 2.406 |
| P-100k | 2.574 | 2.519 | 2.332 | 2.074 | 2.401 | 2.401 |
| F-1M | 2.546 | 2.531 | 2.332 | 2.070 | 2.481 | 2.481 |
| P-1M | 2.337 | 2.305 | 2.383 | 2.258 | 2.457 | 2.337 |
| F-10M | 2.538 | 2.591 | 2.272 | 2.070 | 2.457 | 2.457 |
| P-10M | 1.796 | 1.612 | 1.615 | 1.451 | 1.685 | 1.615 |

SPY (adjusted close, 2000-01-03 → 2026-06-25): 2.087. The gap between arm medians (P-1M − F-1M = −0.144) is not the rule's statistic; the rule pairs by seed (§1.3).

By period: log NAV change, cut at the last 2008 and 2016 rows of the equity curve, median over seeds.

| arm | 2000–08 | 2009–16 | 2017–26 |
|---|---|---|---|
| F-100k | 0.478 | 1.194 | 0.697 |
| P-100k | 0.478 | 1.184 | 0.748 |
| F-1M | 0.507 | 1.169 | 0.748 |
| P-1M | 0.514 | 1.134 | 0.736 |
| F-10M | 0.507 | 1.169 | 0.748 |
| P-10M | 0.524 | 0.821 | 0.261 |
| SPY | −0.325 | 1.073 | 1.339 |

**Measure 2: max drawdown and Ulcer index.** Whole run, from summary.sexp:

| arm | max DD %, k0..k4 | median | Ulcer, k0..k4 | median |
|---|---|---|---|---|
| F-100k | 39.56, 27.69, 28.44, 31.89, 26.23 | 28.44 | 13.06, 10.65, 10.75, 11.81, 10.69 | 10.75 |
| P-100k | 39.55, 35.23, 28.48, 31.90, 26.56 | 31.90 | 13.07, 12.45, 10.81, 11.82, 10.89 | 11.82 |
| F-1M | 39.57, 35.24, 28.46, 31.91, 26.24 | 31.91 | 13.23, 12.40, 10.88, 11.81, 10.47 | 11.81 |
| P-1M | 39.57, 27.60, 27.17, 32.30, 26.04 | 27.60 | 13.56, 10.72, 10.80, 11.78, 10.54 | 10.80 |
| F-10M | 39.57, 35.24, 28.46, 31.91, 26.24 | 31.91 | 13.23, 12.33, 10.95, 11.81, 10.70 | 11.81 |
| P-10M | 36.09, 21.00, 24.82, 18.00, 19.42 | 21.00 | 14.76, 7.91, 9.32, 7.93, 7.98 | 7.98 |

By period (median), computed from the daily `equity_curve.csv` with the peak reset at each period start. This recipe reproduces summary.sexp's max DD but not its Ulcer (§6 D6), so compare P with F only within this table.

| arm | max DD 00–08 | 09–16 | 17–26 | Ulcer 00–08 | 09–16 | 17–26 |
|---|---|---|---|---|---|---|
| F-100k | 13.65 | 26.18 | 28.44 | 6.36 | 9.48 | 14.50 |
| P-100k | 13.66 | 26.19 | 31.90 | 6.29 | 9.66 | 16.68 |
| F-1M | 13.42 | 26.19 | 31.91 | 6.37 | 9.48 | 16.69 |
| P-1M | 13.42 | 25.95 | 27.60 | 5.85 | 9.71 | 14.61 |
| F-10M | 13.42 | 26.19 | 31.91 | 6.37 | 9.48 | 16.69 |
| P-10M | 12.53 | 19.42 | 17.82 | 4.79 | 5.56 | 11.28 |

**Measure 3: share of entries at or below $14 raw, and funded doublers among them.** The raw entry price is `entry_price` with any split during the hold undone from the cell's `splits.csv` (§6 D4).

| arm | share ≤ $14 %, k0..k4 | median | cheap doublers, k0..k4 | all doublers, k0..k4 |
|---|---|---|---|---|
| F-100k | 12.5, 11.4, 12.4, 12.4, 12.1 | 12.4 | 2, 2, 2, 3, 2 | 9, 9, 8, 7, 8 |
| P-100k | 12.6, 11.6, 12.7, 12.7, 12.3 | 12.6 | 2, 3, 2, 3, 2 | 9, 10, 8, 7, 8 |
| F-1M | 12.3, 11.8, 12.6, 12.4, 12.1 | 12.3 | 2, 3, 2, 3, 2 | 9, 9, 8, 7, 8 |
| P-1M | 11.2, 11.0, 11.3, 11.5, 11.4 | 11.3 | 2, 2, 2, 3, 3 | 9, 8, 8, 7, 9 |
| F-10M | 12.4, 11.6, 12.6, 12.4, 12.1 | 12.4 | 2, 3, 2, 3, 2 | 9, 9, 8, 7, 8 |
| P-10M | 7.5, 7.9, 7.8, 7.3, 8.6 | 7.8 | 0 on every seed | 3, 3, 3, 2, 3 |

By period: median share % / median cheap doublers / median all doublers.

| arm | 2000–08 | 2009–16 | 2017–26 |
|---|---|---|---|
| F-100k | 10.69 / 1 / 1 | 13.94 / 0 / 4 | 12.24 / 1 / 3 |
| P-100k | 11.51 / 1 / 1 | 13.86 / 0 / 4 | 12.65 / 1 / 4 |
| F-1M | 10.87 / 1 / 1 | 14.37 / 0 / 4 | 12.24 / 1 / 4 |
| P-1M | 10.95 / 1 / 1 | 12.50 / 0 / 4 | 11.02 / 1 / 3 |
| F-10M | 10.87 / 1 / 1 | 14.37 / 0 / 4 | 12.24 / 1 / 4 |
| P-10M | 5.21 / 0 / 0 | 7.63 / 0 / 2 | 9.52 / 0 / 1 |

The cheap doublers are a few shared events. BGO 2003 and ADMA 2023 appear in every arm except P-10M. APPS 2020 and TIBX 2010 appear only on the seeds where those draws landed.

**Measure 4a: P round trips whose 20-day dollar ADV at the decision Friday was below $1M,** i.e. names the record's floor would have blocked. ADV is the mean of close × volume over the 20 bars to the decision date, the simulator's stored-dollar basis, from local bars.

| arm | k0..k4 | 2000–08 | 2009–16 | 2017–26 |
|---|---|---|---|---|
| P-100k | 6, 6, 6, 7, 5 | 5, 5, 4, 5, 4 | 1, 1, 1, 1, 1 | 0, 0, 1, 1, 0 |
| P-1M | 1, 0, 0, 0, 0 | 1, 0, 0, 0, 0 | 0 | 0 |
| P-10M | 0 on every seed | 0 | 0 | 0 |

By year:

- P-100k: 2003 FCNCA (5 seeds), OME (5), TCT (k0); 2004 GLAD (5); 2006 HAFC (5); 2007 VHI (k1, k3); 2012 TKPPY (5); 2021 VHC (k2, k3).
- P-1M: 2003 TCT (k0).

None of them doubled: the best was VHI at +7.5 %, the worst TKPPY at −15.6 %.

Excluded: CMRE 2012-10-03. It reconstructs below $1M from local bars, but F-1M traded it at the $1M floor, so it is a local-bar defect (§6 D2), not a floor admission.

**Measure 4b: `Adv_participation_cap` skips.** These are a lower bound: the audit lists alternatives only on Fridays with a placed entry. The per-year table is in Appendix A.

| arm | 2000–08, k0..k4 | 2009–16 | 2017–26 | whole run |
|---|---|---|---|---|
| P-100k | 0, 0, 0, 0, 0 | 1, 1, 1, 1, 1 | 1, 3, 1, 1, 3 | 2, 4, 2, 2, 4 |
| P-1M | 3, 3, 2, 3, 4 | 8, 10, 13, 6, 20 | 20, 25, 24, 17, 29 | 31, 38, 39, 26, 53 |
| P-10M | 59, 58, 54, 57, 62 | 74, 76, 70, 65, 77 | 119, 124, 121, 110, 122 | 252, 258, 245, 232, 261 |

**Measure 5: median position as a share of 20-day dollar ADV at entry.** Median over seeds of each seed's median, with p90 in brackets. The per-year table is in Appendix B.

| arm | 2000–08 | 2009–16 | 2017–26 | whole run |
|---|---|---|---|---|
| F-100k | 0.08 % (0.43) | 0.12 % (0.85) | 0.16 % (0.75) | 0.13 % (0.68) |
| P-100k | 0.09 % (0.46) | 0.12 % (0.83) | 0.16 % (0.81) | 0.13 % (0.75) |
| F-1M | 0.77 % (4.32) | 1.20 % (7.98) | 1.75 % (8.14) | 1.36 % (7.34) |
| P-1M | 0.77 % (4.27) | 1.11 % (5.75) | 1.39 % (5.40) | 1.11 % (5.29) |
| F-10M | 7.66 % (43.2) | 11.99 % (79.8) | 17.12 % (84.1) | 13.37 % (72.3) |
| P-10M | 3.50 % (8.86) | 3.02 % (8.79) | 3.78 % (8.76) | 3.44 % (8.77) |

The convergence the prereg predicted shows in the arms without a cap. F-10M's median position goes from 5.6–15 % of ADV in 2000–07 to 18–33 % in 2023–26; F-1M's goes from 0.6–1.5 % to 1.8–3.4 %.

### 1.3 Decision rule

ΔDD and ΔUlcer use actual.sexp's full precision.

**P-100k**

| seed | Δ | ΔDD pp | ΔUlcer | round trips F → P |
|---|---|---|---|---|
| k0 | −0.0115 | −0.01 | +0.01 | 559 → 562 |
| k1 | +0.1125 | +7.54 | +1.80 | 533 → 542 |
| k2 | +0.0020 | +0.04 | +0.06 | 539 → 544 |
| k3 | +0.0042 | +0.01 | +0.02 | 558 → 565 |
| k4 | −0.0528 | +0.33 | +0.19 | 555 → 560 |
| median | **+0.0020** (3 +, 2 −) | **+0.04** | +0.06 | |

PASS and PAYS-WITH-RISK need a median Δ of +0.20 or more with at least 4 positive; this is not close. HARM needs a median Δ of −0.20 or less with at least 4 negative; not met. **INCONCLUSIVE.**

**P-1M**

| seed | Δ | ΔDD pp | ΔUlcer | round trips F → P |
|---|---|---|---|---|
| k0 | −0.2088 | 0.00 | +0.34 | 559 → 556 |
| k1 | −0.2260 | −7.64 | −1.68 | 536 → 527 |
| k2 | +0.0510 | −1.28 | −0.08 | 540 → 531 |
| k3 | +0.1881 | +0.39 | −0.04 | 557 → 547 |
| k4 | −0.0243 | −0.20 | +0.07 | 555 → 542 |
| median | **−0.0243** (2 +, 3 −) | **−0.20** | −0.04 | |

**INCONCLUSIVE.** This closes #3681's verify item as "no effect at backtest NAV".

By period, P − F per seed (k0..k4):

| | 2000–08 | 2009–16 | 2017–26 |
|---|---|---|---|
| P-100k Δ | −0.001, −0.044, +0.020, +0.016, −0.021 | −0.011, −0.010, −0.010, −0.012, −0.019 | 0.000, +0.166, −0.008, 0.000, −0.013 |
| P-1M Δ | +0.013, +0.007, +0.003, +0.003, +0.005 | −0.250, −0.085, +0.016, +0.123, −0.033 | +0.028, −0.148, +0.032, +0.063, +0.004 |
| P-10M Δ | −0.066, +0.017, +0.048, +0.098, +0.055 | −0.401, −0.392, −0.348, −0.231, −0.386 | −0.275, −0.605, −0.357, −0.487, −0.440 |
| P-100k ΔDD | +0.01, −1.51, +0.01, −0.03, +2.26 | 0.00, −0.01, −0.01, 0.00, +0.01 | −0.01, +7.90, +0.04, +0.01, +0.33 |
| P-1M ΔDD | 0.00 on all | +3.48, −1.34, +0.02, 0.00, −0.24 | 0.00, −7.64, −1.29, +0.39, −0.20 |
| P-10M ΔDD | −2.07, +0.14, −1.06, −2.21, −1.75 | −0.20, −6.70, −2.11, −4.56, −10.22 | −3.48, −17.49, −11.20, −14.09, −6.82 |

### 1.4 Descriptive arms

**P-10M**

- Δ: −0.7421, −0.9791, −0.6573, −0.6191, −0.7715 (median −0.742).
- ΔDD: −3.48, −14.25, −3.64, −13.91, −6.82 (median −6.82 pp).
- ΔUlcer: +1.53, −4.42, −1.63, −3.88, −2.72 (median −2.72).
- Round trips: 558/533/541/557/555 in F-10M against 373/366/384/395/362 in P-10M.
- In money, terminal wealth is 38–54 % of F-10M's. On k0, CAGR is 7.02 % against 10.06 %.

**F across cash** (same seed, same rules):

| seed | F-100k − F-1M | F-10M − F-1M | F-100k − F-10M | one-arm trades, F-100k / F-1M | F-10M / F-1M |
|---|---|---|---|---|---|
| k0 | +0.040 | −0.007 | +0.047 | 12 / 12 | 1 / 2 |
| k1 | −0.124 | +0.060 | −0.184 | 30 / 33 | 5 / 8 |
| k2 | −0.002 | −0.060 | +0.058 | 5 / 6 | 5 / 4 |
| k3 | 0.000 | 0.000 | 0.000 | 1 / 0 | 0 / 0 |
| k4 | −0.027 | −0.024 | −0.003 | 6 / 6 | 6 / 6 |

Rounding and the $1 minimum commission re-draw 0–33 trades a seed. k1's −0.124 is APPS: on 2020-06-12 F-100k logged `Insufficient_cash` and F-1M bought it (§3.2).

## 2. Verdict, calibrated

Both decision arms are INCONCLUSIVE by wide margins: |median Δ| of 0.002 and 0.024 against a 0.20 bar, with sign splits of 3/2 and 2/3.

**What this design can claim.** On this market history:

- At backtest NAV (a $1M start on the record's path, ending at $7.9–12.8M), the 10 % participation cap's effect cannot be told apart from path noise.
- At a $100k start, the live-size profile adds about six non-monster names per seed over 26 years.
- At a $10M start, the same cap costs about 0.74 log, and every seed agrees.

**What it cannot claim.**

1. That the cap is harmless in general. Its footprint grows with NAV (measure 5). ADMA, the record's largest late winner, sat at 5.4–8.9 % of ADV in F-1M. On k0, a NAV about 12 % higher at the August 2023 decision would have put it over the cap.
2. Anything about live sizing after 2008. P-100k's positions are live-sized only early: the median position (entry price × quantity, `prv:kK/ns-P-100k-kK-s0-trades.csv`) is $9.3–9.9k in 2000–03 and $11.1–13.2k in 2004–08 on every seed, then $22–34k in 2009–16 and $54–94k in 2017–26 as the account compounds. So P-100k answers #3693 for live-sized positions over 2000–08 only (about 140 round trips a seed): there the live-size profile changes about five trades a seed (the floor admissions cluster in 2003–07, none doubled) and P-100k's 2000–08 Δ is −0.044 to +0.020. It says nothing about live sizing in a 2009+ market.
3. Significance. The five seeds share one price history, and their large one-arm trades are the same events: ODSY on 3 seeds, NJDCY on 3, TKPPY on 5, and the APPS cash draw. A 5/5 sign count is a consistency check, as the prereg says.

**Noise scale.** The rounding-only null moves the record by up to 0.124 log between adjacent cash levels. P-1M's largest |Δ| is 0.226. The single-cell floor is about 0.45 log, at 2 SD of the measured 26y seed band (SD 0.225, `project_26y_path_noise_floor`; the five vsb-1 cells alone give a sample SD of 0.20, i.e. about 0.40). P-10M's −0.62 to −0.98 is outside all of these and traced to named trades (§3.4), but by the prereg it is descriptive.

The wording follows mechanism-validation-rigor. "No effect at backtest NAV" is about this cap value on this history. It does not say participation gating fails.

## 3. Why

### 3.1 At $1M, only the cap acts

P-1M changes three lines, and two of them do almost nothing at this NAV.

- **Hold floor ($50k instead of $500k).** It mattered once in 30 cells: ENLK 2003-09-22. The F arms sell it on `liquidity_exit` on 2003-12-22 at +5.78 %. P-100k and P-1M hold it to a `laggard_rotation` exit on 2004-01-05 at +9.49 % (k0–k3, +0.29 NAV% a seed). No other `liquidity_exit` appears anywhere.
- **Entry floor ($100k instead of $1M).** One trade in five seeds got through this way: TCT 2003-12-11 on k0, +3.3 %, a position at 9.6 % of ADV. A name under $1M of ADV passes the 10 % cap only if the position is under a tenth of that ADV, i.e. under $100k. Once P-1M's NAV is near $1M or above, nearly every position is bigger than that. The cap is then the binding line, and the dust floor never comes into play.
- **The cap.** Joined by symbol and entry date:
  - F-1M has 56, 56, 43, 31, 67 trades that P-1M lacks.
  - P-1M has 53, 47, 34, 21, 54 that F lacks.
  - Shared: 503, 480, 497, 526, 488.

  These are different names, not re-timed entries: only 1–6 a seed have the same symbol in the other arm within 45 days.

**Which F-only trades the cap blocked.** 19, 24, 20, 15 and 32 of them, counting both:

- the 57 recorded skips;
- Fridays with no P audit row, where P's position (F's position scaled by the two arms' NAV at the decision) would exceed 10 % of ADV.

The estimate reproduced 56 of the 57 recorded skips. That makes 110 blocked trades pooled, from 45 distinct events.

**The blocked slice is ordinary, or slightly worse than ordinary.**

| | n | p10 | p25 | median | p75 | p90 | best | win rate | doublers |
|---|---|---|---|---|---|---|---|---|---|
| cap-blocked F-1M trades | 110 | −13.1 % | −8.6 % | −5.9 % | +5.2 % | +18.4 % | +94.85 % (ODSY) | 35.5 % | 0 |
| all F-1M trades | 2,747 | −13.2 % | −9.7 % | −3.3 % | +7.9 % | +25.8 % | | 40.6 % | 41 |

At the population rate, 110 trades would hold about 1.6 doublers (P(0) ≈ 0.19), or about 0.7 counting distinct events. At $1M the cap neither targets the tail nor spares it.

Doublers per seed are 9, 9, 8, 7, 8 for F-1M and 9, 8, 8, 7, 9 for P-1M. The only one-arm doublers are:

- APPS on k1, F only, and not a cap block;
- TIBX on k4, P only, a cascade that the ODSY block paid for.

**Decomposition.** NAV% is a trade's P&L over NAV at entry, summed. It is additive, not a log, so it does not reconcile exactly with Δ (k4 sums to +2.9 against Δ −0.024). Each entry is the contribution to P − F; counts in brackets.

| seed | Δ | cap-blocked F trades | other F-only | P-only, floor | P-only, other | shared (size) | net |
|---|---|---|---|---|---|---|---|
| k0 | −0.209 | −11.5 (19) | −17.6 (37) | +0.2 (1) | +6.3 (52) | +0.6 | −21.9 |
| k1 | −0.226 | −12.5 (24) | −30.3 (32) | 0 | +5.6 (47) | +1.8 | −35.3 |
| k2 | +0.051 | +0.7 (20) | −0.3 (23) | 0 | +2.5 (34) | +0.6 | +3.5 |
| k3 | +0.188 | +6.0 (15) | +3.8 (16) | 0 | +8.0 (21) | +0.8 | +18.5 |
| k4 | −0.024 | −3.9 (32) | +3.4 (35) | 0 | +3.3 (54) | 0.0 | +2.9 |

Perturbation: moving the "would exceed the cap" threshold from 0.10 to 0.08 or 0.12 moves the cap-blocked column to −11.1…−14.1 (k0), −9.4…−12.5 (k1), +0.4…+1.4 (k2), +4.6…+6.0 (k3) and −2.1…−3.9 (k4). No sign changes.

The cap's own trades are worth −12 to +6 NAV% a seed. The large seeds are decided in the "other" columns: trades that exist in one arm only because the books diverged.

### 3.2 The seeds traced

**k0 (Δ −0.209): the cap's biggest bite, refunded, then a cascade.**

1. On 2009-10-30, F-1M takes ODSY (entry 2009-11-02) at 11.4 % of its 20-day ADV, and P-1M logs `Adv_participation_cap`. ODSY exits `delisted` on 2010-08-18 at +94.85 %, worth +13.5 NAV% to F.
   - The block hangs on the seed's NAV. F-1M's position was 11.4 %, 10.2 % and 10.3 % of ADV on k0, k1 and k4, where P blocked it.
   - It was 9.7 % and 9.1 % on k2 and k3, where P took it.
2. On 2010-08-13, P-1M has the ODSY money free and buys FOSL (entry 2010-08-16, +82.8 %, +11.5 NAV%). F-1M placed nothing that Friday; its ODSY money came back on 2010-08-18. The block's direct cost was nearly refunded within ten months.
3. After that the books differ, and the gap widens through 2017:

   | year-end | 2009 | 2010 | 2011 | 2013 | 2014 | 2015 | 2017 | end |
   |---|---|---|---|---|---|---|---|---|
   | ln(P/F) | −0.004 | −0.033 | −0.054 | −0.112 | −0.161 | −0.244 | −0.315 | −0.209 |

   - F-only winners drive the slide: SBUX 2011 (+6.8 NAV%), SKX 2014 (+5.7), AMRI 2014 (+4.1), IPHI 2015 (+6.4).
   - On the other side is P-only JNS 2014 (+5.2).
   - Two cap blocks add to it: NJDCY 2017 (+58.5 %, +4.2 NAV%) and DY 2013 (+23.4 %, +3.4 NAV%).
   - By period: +0.013, −0.250, +0.028.

So k0's gap is mostly cascade. The cap's own trades account for −11.5 of the −21.9 NAV%.

**k1 (Δ −0.226): one cash draw on 2020-06-12.**

1. After 2010 the gap is −0.113: ODSY was blocked, with no FOSL-like replacement. By the end of 2019 it is back to −0.040.
2. On 2020-06-12, F-1M buys APPS (entry 2020-06-15) at 1.7 % of ADV, far below any cap. P-1M places nothing that Friday. Over the prior month its book had drifted away from F's:
   - P-1M placed ASND on 05-15;
   - its LACO filled 05-27, while F-1M's LACO ticket never filled;
   - it entered MCK on 05-28.

   So P-1M carried 10 positions to F's 7 and had no room.
3. APPS returns +525.6 %, worth +37.2 NAV% to F. The year-end gap is −0.293 for 2020 and −0.226 at the end. Without APPS the k1 decomposition nets +1.9 NAV%.
4. The same event flips the sign elsewhere on k1.
   - At $100k, P-100k bought APPS while F-100k logged `Insufficient_cash` (Δ +0.113).
   - In the rounding null, F-100k trails F-1M by 0.124 on k1 for the same reason.
   - APPS was at about 0.2 % of ADV for a $100k book and 1.7 % for $1M, so the cap could not have touched it at either size.
5. The k1 drawdowns are the same draw. Whoever holds APPS sets a 2021 peak and gives back about 35 % by 2023-10-27 (F-1M 35.24 %, P-100k 35.23 %). The arms without it give back 27.6–27.7 % (P-1M, F-100k). Hence ΔDD of −7.64 for P-1M and +7.54 for P-100k.

**k3 (Δ +0.188): many small differences, no single trade.**

1. ODSY was not blocked (9.1 % of ADV).
2. The cap blocked net losers worth +6.0 NAV% to P:
   - GASS 2013-11-20 (−15.3 %, −2.2 NAV%, recorded skip);
   - UEC 2015, CORV 2010, ATEX 2019, WRLD 2025;
   - offset by MTW 2017 (+21.5 %, +3.0 NAV%).
3. P-only trades netted +8.0 NAV%: TLND 2018 (+3.4), ALSN 2013 (+2.4), FLO 2013 (+2.3), OEC 2017 (+2.2). F-only others netted −3.8.
4. Year-end ln(P/F) runs +0.007 through 2012, +0.075 after 2013 (the GASS block; FLO, ALSN), +0.125 by 2015, +0.161 after 2018 and +0.188 at the end.

The largest one-arm item is 3.4 NAV%. This is a drift, and its sign is the luck of which names crossed 10 % of ADV on k3's NAV path.

**k4 (Δ −0.024): the refund mechanism, step by step.**

1. ODSY is blocked on 2009-10-30, a recorded skip.
2. On 2010-07-02, F-1M still holds ODSY. It logs ENH and SATCQ as `Insufficient_cash` and buys PEG and STEC_old1. P-1M buys all four.
3. On 2010-07-09, both audits list 20 names. F's list includes ENH and SATCQ, which it now buys. P already holds them, so its list reaches THG and TIBX, which F's list does not contain.
4. TIBX (entry 2010-07-12) returns +112.4 %, +10.1 NAV%. It is the only P-only doubler at $1M.

**Mechanism.** At $1M the cap blocks a few percent of the record's trades, an ordinary slice. A block frees cash, and the walk spends it on the next candidate. In a fat-tailed book that replacement can be as good (FOSL, TIBX), or the knock-on cash state can cost a monster (APPS). Whether a seed ends near ±0.2 depends on those knock-on effects, not on what the cap selects.

### 3.3 At $100k, the floor acts and the cap does not

- The cap removed no F-100k trade (§1.1).
- The $100k floor admitted 6, 6, 6, 7 and 5 round trips a seed, from nine distinct events.
  - Every one sat at 1–3 % of ADV except VHC 2021, at 8.9–10.0 %. VHC passed on k2 at the cap's edge and was blocked on k1 and k4.
  - Net NAV% −1.9, −1.5, −3.3, −2.7, −2.2, and no doubler.
  - The two large losers, OME 2003 (−11.7 %) and TKPPY 2012 (−15.6 %), are on every seed. TKPPY alone makes P-100k's 2009–16 Δ negative on all five seeds (−0.010 to −0.019).
- In k0's audit, P-100k lists 249 rows for names with ADV between $100k and $1M; F-100k lists 11 (CMRE-type cases at the $1M line). Of the 249:
  - 238 are skipped as `No_structural_stop`;
  - 8 placed;
  - 2 capped;
  - 1 sized to zero.

  The lower floor widens the top of the funnel, and the structural-stop gate, which drops about 90–95 % of rows for every kind of name, takes almost all of it back.
- The admissions cluster in 2003–07, while P-100k's positions were small enough to sit under 10 % of a sub-$1M ADV. As the account grows (about ×11 over the run), the cap overtakes the floor at $100k too; VHC 2021 is the edge case.
- The rest of P-100k's Δ is cascade plus one draw. k1's +0.113 is APPS. k4's −0.053 is a cascade of 10 P-only and 5 F-only trades.

### 3.4 At $10M, capacity

**F-10M is not a tradeable account.**

- It stays level with F-1M (median 2.457 vs 2.481) only because nothing in the record's fill path depends on order size relative to volume.
- Its median position is 13.4 % of a day's dollar volume over the run: 7.7 % in 2000–08, rising to 17.1 % in 2017–26 and 33.5 % in 2023, with a p90 of 72 %.

**What the cap removes.**

- It blocks 232–261 entries a seed. P-10M makes 362–395 round trips against 533–558.
- The F-10M trades it blocked (228–279 a seed) carried +119 to +165 NAV%. Net P − F across all trades is −92 to −125 NAV%.
- What goes is the tail. F-10M has 9, 9, 8, 7, 8 doublers a seed; P-10M has 3, 3, 3, 2, 3.
  - Lost wherever F held them: ADMA 2023 (+300 %, at 54–88 % of ADV in F-10M), MMYT 2023 (27–45 %), LGND 2012 (32–41 %, 4 seeds), BGO 2003 (22–23 %), LAD 2012 (15–23 %), APPS 2020 (11–18 %, 2 seeds) and HURN 2006 (47 %, 1 seed).
  - Kept: DXCM 2019 and SK 2010 (every seed, at 1 % of ADV or less), NFLX 2010 (3 seeds), MSTR 2020 (1 seed).
  - P-10M found no doubler of its own.

**How the gap grows with NAV.**

- 2000–08: median +0.048, 4 of 5 positive, even though BGO 2003 is lost on every seed.
- 2009–16: −0.386, 0 of 5 positive.
- 2017–26: −0.440, 0 of 5 positive.

**Against SPY.** P-10M ends below SPY on all five seeds (1.45–1.80 against 2.087). The F arms are above SPY on four; k3 sits at 2.070. P-10M's smaller drawdown (median −6.8 pp) and Ulcer (−2.7) come with a third fewer round trips. Whether that is idle cash was not measured, so this read makes no exposure claim (RV2).

**The estimate is, if anything, generous.** The cap reads ADV in stored dollars (`true_dollar_volume` off), which inflates years before a later split (#3136).

- MSTR 2020 passed at 2.5–3.8 % of stored ADV. After the 10:1 split in 2024 the true figure is 25–38 %, so a true-dollar cap would have blocked the one P-10M seed that kept it.
- DXCM (×4) and NFLX (×70) pass on either basis.

**Capacity, for the record as configured.** Somewhere between a $1M and a $10M start, the strategy's edge (a handful of mid-cap monsters a decade) stops fitting through a 10 % participation rule. The record's own $1M path ends at $7.9–12.8M, which is about where ADMA would have crossed the cap.

## 4. How it fits what we know

- **Confirms** `project_26y_path_noise_floor` and `project_record_kseed_band`. P-1M's |Δ| ≤ 0.226 is under the 0.45-log single-cell floor. The trace shows the lever's own trades move at most about 12 NAV% a seed, while one cash draw (APPS) moved k1 by about 0.25.
- **Confirms** `project_edge_is_the_fat_tail` and `project_funding_grid_monster_lottery`. Seed outcomes are set by which tail trades get funded (ODSY, FOSL, TIBX, APPS), not by what the gate selects.
- **Confirms and sharpens** `project_trait_y_low_price` (the 11-18 ADV-floor NO-BUILD).
  - It predicted at most about 6 funded doublers, about +0.06 log, from lowering the floor with a 10 % cap.
  - Measured: 0 doublers among floor admissions at $1M (1 trade) and at $100k (31 trades, best +7.5 %).
  - The reason it gave, that cheap monsters are capacity-bound at our size, holds; the mechanism is that the cap blocks rather than resizes, so above about $1M of NAV it is stricter than the $1M floor it was meant to relax.
- **Refines** `project_trade_realism_liquidity` ("liquidity is a non-issue at our position sizes"). That holds for a $1M start: P-1M ≈ F-1M, and F-1M's p90 position is 7.3 % of ADV. It fails for a $10M start: −0.74 log, with ADMA 2023 at 54–88 % of ADV. The memory needs a size qualifier.
- **Answers** the caveat in `_ledger/2026-07-10-realism-defaults-flip.sexp`: "a STATIC $1M gate is calibrated for ~$1–10M capital; at larger NAV, position-vs-ADV scaling is the real capacity model." This run is that follow-up. The record's $1M path stays inside the range; a $10M start does not.
- **Refines** `project_true_dollar_gate_chain_w` (stored-dollar basis, about 1 % of decisions, no rebuild). Under a participation cap at high NAV, the affected decisions include a tail trade (MSTR 2020).
- **Applied:** `feedback_run_the_null_control_first` (F across cash) and `feedback_perturb_before_believing_a_cohort_split` (cap threshold 0.08–0.12, re-timing window).

No contradiction found.

## 5. What it implies next (options; the choice is the user's)

1. **Record and close, as the rule says.** Close #3681's verify item as "no effect at backtest NAV" and keep `max_entry_adv_participation` default-off. Live-size stays opt-in, and #3693's verify item closes from P-100k with the caveat in §2 item 2 (live-sized positions only over 2000–08). No further cells on this axis without a new mechanism argument.
2. **Stop here.** This is what the evidence supports for the backtest programme. At record NAV the cap is path noise, and the dust floor is moot above about $1M.
3. **If capacity above a few $M matters,** the open lever is sizing, not gating. "Resize to the cap instead of block" would be a new mechanism: a sizing dial that needs book support (W2) and its own pre-registration.
   - Rough arithmetic: ADMA at 54–88 % of ADV resized to 10 % keeps 11–19 % of the position, i.e. a fifth to a ninth of its contribution.
   - Fix #3136 (true-dollar ADV) before any capacity cell, or late splitters slip through.
4. **Live picks.** At about $10k positions the 10 % cap equals the $100k dust floor. P-100k sat in that regime only over 2000–08 (§2 item 2); a backtest started later, or at a fixed position size, would be needed to test it on today's market. Whether to use live-size is an operational choice (which names are buyable), not a return lever.
5. **`max_hold_adv_participation` (the #3693 remainder).** This run gives no reason to build it for the backtest: the hold floor fired once a seed at $500k and never at $50k. At $10M a hold participation rule would act on positions that balloon, which is the tail. It needs its own argument.

## 6. Defects found

- **D1. No review pack at draft time.** Built and looked at afterwards; see "Review-pack look".
- **D2. The local bar store disagrees with the run's bars on two names.** CMRE 2012-10-03: the run's entry price in `prv:k0/ns-*-1M-k0-s0-trades.csv` is 5.1× the local raw close that day; BFH 2004-03-10: 4.0×. Both names have a later reverse split in `splits.csv` (CMRE 1:5 on 2026-05-05, BFH 1:4 on 2006-06-06), but that does not explain the gap: of the 47 traded (symbol, entry) pairs with a later reverse split and no split during the hold, 45 enter within 0.77–1.26× the local raw close, so the run reads raw prices and only these two sit at the split factor. The store and the run's warehouse bars therefore differ for CMRE and BFH (#3705). Effect on this read: CMRE reconstructs below $1M of ADV from local bars, yet the run passed it through the $1M floor (F) and P-1M's cap, so it is excluded from measure 4. Scope: 2 of 958 traded (symbol, entry) pairs; measures 4a and 5 otherwise use local raw close × volume, which matches the run for the other 45.
- **D3. Stored-dollar ADV reaches the cap and floor** (#3136, `true_dollar_volume` off). MSTR 2020 is at 2.5–3.8 % of stored ADV against 25–38 % in true dollars, and passed P-10M's cap on one seed only because of the inflation.
- **D4. `trades.csv` restates `entry_price` and `quantity` for splits during the hold;** position dollars are unchanged. 50–56 round trips per cell are restated. For example, TGI 2011-06-24's `entry_price` is half the as-traded price. Any price-tier read needs the cell's `splits.csv` to recover raw prices.
- **D5. The audit is a lower bound,** as the prereg anticipated. Of the 253 F-only trades at $1M, 120 have no P audit row on their Friday, so blocked counts need the estimator (56 of 57 recorded skips reproduced).
- **D6. Ulcer computed from `equity_curve.csv` does not reproduce summary.sexp.** For F-100k k0 it gives 13.31 (all 6,895 rows, or only the 6,659 SPY trading days) against 13.06; max DD reproduces exactly. The cause was not found. This read takes whole-run Ulcer from summary.sexp and uses the CSV for periods, within-recipe only.
- **Checked, not a defect:** NLC 2011-08-11 → 2011-12-06 exits by `stale_force_exit` in all 30 cells, identically, so it cancels.

## Appendix A: `Adv_participation_cap` skips per decision year

Median over seeds, pooled count in brackets. No skips in 2001, 2002 or 2008; there were no entries in 2008.

| year | P-100k | P-1M | P-10M |
|---|---|---|---|
| 2000 | 0 (0) | 1 (3) | 4 (23) |
| 2003 | 0 (0) | 1 (4) | 13 (67) |
| 2004 | 0 (0) | 1 (5) | 6 (32) |
| 2005 | 0 (0) | 0 (0) | 13 (69) |
| 2006 | 0 (0) | 0 (0) | 4 (23) |
| 2007 | 0 (0) | 1 (3) | 14 (76) |
| 2009 | 0 (0) | 1 (3) | 2 (8) |
| 2010 | 0 (0) | 1 (5) | 9 (44) |
| 2011 | 0 (0) | 2 (10) | 19 (86) |
| 2012 | 0 (0) | 0 (1) | 3 (18) |
| 2013 | 0 (0) | 4 (24) | 16 (80) |
| 2014 | 0 (0) | 0 (3) | 9 (44) |
| 2015 | 1 (5) | 2 (10) | 10 (52) |
| 2016 | 0 (0) | 0 (1) | 6 (30) |
| 2017 | 0 (0) | 3 (13) | 10 (52) |
| 2018 | 0 (0) | 2 (9) | 19 (97) |
| 2019 | 0 (0) | 0 (0) | 5 (26) |
| 2020 | 0 (0) | 0 (0) | 8 (43) |
| 2021 | 0 (4) | 5 (24) | 19 (100) |
| 2022 | 0 (0) | 0 (1) | 5 (21) |
| 2023 | 0 (0) | 1 (5) | 6 (31) |
| 2024 | 1 (5) | 8 (44) | 27 (134) |
| 2025 | 0 (0) | 3 (14) | 8 (45) |
| 2026 | 0 (0) | 1 (5) | 10 (47) |

## Appendix B: median position as % of 20-day dollar ADV, by decision year

Median over seeds of each seed's median. There were no decisions in 2008.

| year | F-100k | P-100k | F-1M | P-1M | F-10M | P-10M |
|---|---|---|---|---|---|---|
| 2000 | 0.085 | 0.085 | 0.849 | 0.824 | 8.49 | 2.08 |
| 2001 | 0.152 | 0.152 | 1.521 | 1.523 | 15.21 | 0.86 |
| 2002 | 0.071 | 0.071 | 0.711 | 0.715 | 7.11 | 5.91 |
| 2003 | 0.108 | 0.073 | 1.078 | 1.083 | 10.79 | 1.05 |
| 2004 | 0.113 | 0.126 | 1.130 | 1.139 | 11.30 | 6.70 |
| 2005 | 0.093 | 0.094 | 0.922 | 0.924 | 9.22 | 3.32 |
| 2006 | 0.058 | 0.064 | 0.557 | 0.559 | 5.58 | 3.75 |
| 2007 | 0.063 | 0.062 | 0.632 | 0.635 | 6.32 | 3.91 |
| 2009 | 0.124 | 0.123 | 1.238 | 1.211 | 12.39 | 3.88 |
| 2010 | 0.108 | 0.110 | 1.082 | 0.945 | 10.82 | 2.84 |
| 2011 | 0.127 | 0.127 | 1.222 | 1.121 | 12.46 | 3.74 |
| 2012 | 0.094 | 0.113 | 0.941 | 0.850 | 9.42 | 2.79 |
| 2013 | 0.135 | 0.130 | 1.350 | 1.105 | 13.50 | 3.51 |
| 2014 | 0.116 | 0.110 | 1.154 | 0.944 | 11.54 | 2.64 |
| 2015 | 0.179 | 0.170 | 1.782 | 1.585 | 17.69 | 2.57 |
| 2016 | 0.136 | 0.129 | 1.387 | 1.211 | 13.88 | 3.34 |
| 2017 | 0.272 | 0.258 | 2.488 | 2.131 | 27.70 | 3.73 |
| 2018 | 0.103 | 0.099 | 1.044 | 1.072 | 10.37 | 2.80 |
| 2019 | 0.121 | 0.115 | 1.162 | 1.069 | 12.33 | 4.48 |
| 2020 | 0.139 | 0.138 | 1.395 | 1.192 | 13.16 | 3.51 |
| 2021 | 0.140 | 0.160 | 1.671 | 1.401 | 16.31 | 4.90 |
| 2022 | 0.050 | 0.050 | 0.485 | 0.795 | 4.82 | 2.71 |
| 2023 | 0.304 | 0.316 | 3.392 | 3.023 | 33.45 | 1.66 |
| 2024 | 0.283 | 0.268 | 2.903 | 1.505 | 28.33 | 3.53 |
| 2025 | 0.191 | 0.184 | 1.959 | 1.765 | 19.11 | 4.15 |
| 2026 | 0.170 | 0.182 | 1.839 | 1.331 | 18.20 | 5.17 |

## Sources: every number and its file

| numbers | file(s) |
|---|---|
| ln(final/initial), Δ, medians, sign counts; whole-run max DD, Ulcer, ΔDD, ΔUlcer; round trips; CAGR; F across cash | `pub:kK/ns-<arm>-kK-s0-summary.sexp` (`final_portfolio_value`, `initial_cash`, `maxdrawdown`, `ulcerindex`, `n_round_trips`, `cagr`); `pub:kK/ns-<arm>-kK-s0-actual.sexp` (`max_drawdown_pct`, full precision) |
| tripwire md5; build, image, warehouse counts | `chain.sh` (`TRIP_MD5`); `pub:kK/chain-kK.log`; `pub:kK/ns-F-1M-kK-s0-trades.md5.txt`; `pub:k1..k4/trip/` |
| F-1M equals the record; record band | md5 of trading-results `dev/experiments/observatory/runs/96cacbe20/vsb-1/obs-vsb-1-kK-s0-trades.csv`; `dev/experiments/_ledger/2026-11-17-virgin-supply-one-basis-correctness.sexp` |
| V6, validator results | `pub:kK/ns-P-<cash>-kK-s0.v6diff-F.log`; `pub:kK/ns-<arm>-kK-s0.validator.log` |
| liveness; cap-skip counts by seed, period and year; named skips and placements (ODSY, NJDCY, GASS, DY, MTBLY, AMST, CVM, VHC, APPS 2020-06-12, ASND 05-15, ENH/SATCQ 2010-07-02, THG/TIBX 2010-07-09, FOSL 2010-08-13); k0 audit band counts (249 / 11) | `pub:kK/ns-<arm>-kK-s0-entries.tsv`; `pub:kK/ns-<arm>-kK-s0-trades.md5.txt` |
| per-period ln, max DD, Ulcer; year-end ln(P/F); k1 drawdown peak and trough dates | `prv:kK/ns-<arm>-kK-s0-equity_curve.csv` |
| trade dates, pnl %, exit reasons, doubler counts, join counts, re-timing counts, NAV% contributions, decomposition, blocked-slice and population percentiles, ENLK, NLC, LACO, MCK, k1 position counts on 2020-06-12 | `prv:kK/ns-<arm>-kK-s0-trades.csv` (NAV at entry from the same cell's `equity_curve.csv`) |
| measure 3 raw prices and tiers | `prv:kK/ns-<arm>-kK-s0-trades.csv` + `prv:kK/ns-<arm>-kK-s0-splits.csv` |
| measures 4a and 5; position share of ADV for ODSY, APPS, ADMA, NJDCY, TCT, VHC, TKPPY and the 10M doublers; cap-blocked estimator and its 0.08–0.12 perturbation; floor-admission bands | trades.csv positions × local bars `data/<f>/<l>/<SYM>/data.csv` (20-day mean close × volume to the decision Friday) |
| later split factors (MSTR ×10, DXCM ×4, NFLX ×70) | `data/<f>/<l>/<SYM>/splits.csv` |
| SPY 2.087 and by period | `data/S/Y/SPY/data.csv` `adjusted_close`; cross-check `dev/experiments/spy-benchmark-26y-2026-10-04/README.md` (+706 %) |
| D2 specimens | `prv:k0/ns-*-1M-k0-s0-trades.csv`; `data/C/E/CMRE/data.csv`, `data/C/E/CMRE/splits.csv`; `data/B/H/BFH/data.csv` |
| D4 specimen | `prv:k0/ns-F-1M-k0-s0-trades.csv` + `-splits.csv` |
| D6 | `pub:k0/ns-F-100k-k0-s0-summary.sexp` vs `prv:k0/ns-F-100k-k0-s0-equity_curve.csv` |
| spec facts (universe, window, override order) | `specs/ns-*.sexp` |
| noise floor 0.45 log, seed SD | memory `project_26y_path_noise_floor`, `project_record_kseed_band`; ledger above |
