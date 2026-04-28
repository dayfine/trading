# Short-side Ch.11 spot-check on real data (2026-04-27)

`dev/status/short-side-strategy.md` Follow-up #3. Confirms that the
short-side cascade — assembled across PRs #420 (MVP), #617 (bear-window
contract), #623 (live-cascade plumbing fix), #630 (full short cascade
rules) — produces the right Ch.11 patterns on real 2022 bear data.

The unit-level pieces (never short Stage 2; per-stock RS gate; per-stock
volume confirmation; Stage 4 detection) are individually pinned in
`test_screener.ml` and `test_short_side_bear_window.ml`. This note maps
the integration-level book contract to the new tests in
`test_screener_e2e.ml`.

## Method

Ran the screener over the existing 7-stock e2e universe (AAPL, MSFT,
JPM, JNJ, CVX, KO, HD) at four 2022 bear cuts, with `macro_trend =
Bearish` (which `Macro.analyze_with_callbacks` correctly returns on real
2022 GSPC bars per `test_macro_2022_bear_panel_path` in
`test_macro_panel_callbacks_real_data.ml`).

Probe results (synthesised; see git history for the throwaway probe):

| Cut | shorts | who |
|---|---:|---|
| 2022-05-20 | 0 | — |
| 2022-06-17 | 0 | — |
| **2022-07-15** | **2** | **MSFT (Stage 4 + RS bearish crossover); JPM (Stage 4 + breakdown vol + RS neg & declining)** |
| 2022-09-30 | 0 | — |
| 2022-10-14 | 0 | — |
| **2022-12-30** | **2** | **AAPL (Stage 4 + breakdown vol + RS neg & declining); MSFT (Stage 4 + Strong breakdown vol + RS negative)** |

The early-2022 cuts (May / June) sit before the cascade's "Early Stage4"
detector triggers — the 30-week MA hasn't rolled over yet. The
late-September / mid-October cuts produced no shorts because the
trailing rally lifted RS and the MSFT/AAPL/JPM RS lines temporarily
pulled positive vs the (also-falling) S&P benchmark.  The mid-July and
year-end windows are the two clean Ch.11 short setups in this fixture.

Pinned the **2022-07-15** window in
`test_ch11_spotcheck_2022_bear` because both shorts there exercise
distinct Ch.11 rationale paths (RS bearish crossover for MSFT vs
classic breakdown-volume + RS-negative-declining for JPM).

## Ch.11 §6.1 short-entry checklist → test mapping

| §6.1 item | Book rule | Where pinned |
|---|---|---|
| 1 | Market trend bearish (DJI in Stage 4) | `test_macro_2022_bear_panel_path` (real 2022 GSPC → Bearish), `test_macro_2022_bear_with_composer_ad_bars` (composer-loaded AD plumbing); `test_ch11_no_shorts_under_bullish_macro_2022` pins the negation (no shorts under Bullish) |
| 2 | Group is negative (sector below 30-week MA, RS lower) | `test_screener.ml` per-stock unit tests (`test_strong_sector_blocks_short`); empty sector map in e2e tests defaults to Neutral, so the gate is exercised at the unit level |
| 3 | Stock had prior advance, now Stage 3 with flat/declining MA | Captured implicitly: prior_stage threading lands the test analyses in "Early Stage4"; the rationale "Early Stage4" appears in both MSFT and JPM (2022-07-15) and AAPL + MSFT (2022-12-30) outputs |
| 4 | Stock breaks below support and 30-week MA → Stage 4 entry | `test_ch11_spotcheck_2022_bear` rationale ⊇ "Early Stage4" |
| 5 | RS is negative and deteriorating (NEVER short with strong RS) | `test_positive_rs_blocks_short` (per-stock unit), `test_ch11_spotcheck_2022_bear` rationale ⊇ "RS bearish crossover" or "RS negative & declining" |
| 6 | Minimal nearby support below breakdown | `test_short_candidate_populated` (2020 COVID — pinned via `Support` Moderate / Heavy contributions to scores 72 / 55 / 52); the 2022-07-15 rationale does not flag a Support contribution at score 45, consistent with mid-2022 markets having more nearby technical support than the COVID free-fall |

## Ch.11 §6.2 key differences → test mapping

| §6.2 item | Book rule | Where pinned |
|---|---|---|
| Volume not required | Breakdown is valid without volume; volume increase is a bonus | `test_ch11_spotcheck_2022_bear` MSFT entry has no volume rationale ("RS bearish crossover" alone), JPM has "Adequate breakdown volume". Both score 45 → both pass the grade-C floor without requiring volume |
| Pullbacks rare | Only ~50% of breakdowns pull back | Out of scope for the screener; this is a strategy/timing concern, not a candidate-emission concern |
| Head-and-shoulders tops most bearish | Pattern recognition for short setups | Not implemented in the current screener (TODO in `eng-design-2-screener-analysis.md`) |

## Ch.11 §6.3 short stop rules → test mapping

| §6.3 item | Book rule | Where pinned |
|---|---|---|
| Initial buy-stop above prior rally peak | Stop above resistance | `_candidate_matcher` in `test_screener_e2e.ml` asserts `suggested_stop > suggested_entry` for every short, plus the entry/stop ranges put each short's stop at ~entry × (1 + short_stop_pct) where `short_stop_pct = 0.08` |
| Trail down as stock declines | Lower stop after each failed rally | Out of scope for the screener; lives in `Weinstein_stops.compute_initial_stop_with_floor` (long-side equivalent rule, mirrored for shorts in the stops state machine) |

## Real-data observations

**What shorted (2022-07-15 cut, real bars):**

- MSFT (Tech, mega-cap): peaked Nov 2021, broke 30-week MA Feb 2022,
  printed bearish RS crossover by mid-July 2022. Score 45, entry $351.42
  (resistance high), stop $379.53 (entry × 1.08).
- JPM (Financials): topped Oct 2021, broke down through support spring
  2022, RS negative & declining vs S&P. Score 45, entry $173.82, stop
  $187.73.

**What did NOT short:**

- AAPL: held up better than peers in mid-2022; RS not yet definitively
  negative at the 2022-07-15 cut. Re-tests at year-end (2022-12-30) and
  AAPL does fire — captured by the year-end probe but not pinned (one
  pin point is enough; year-end is the natural successor and was
  already implicitly covered by the 2020 COVID test).
- JNJ, CVX, KO: defensives + Energy. CVX in particular was Stage 2 in
  2022 (energy boom), not Stage 4 — the cascade correctly did not flag
  it as a short. JNJ + KO outperformed and stayed Stage 1/2.
- HD: Stage 3/4 transitional; did not pass the Early Stage 4 detector at
  this cut.

**Conclusion:** the system correctly identifies Ch.11 short candidates
on real 2022 bear data. The tests pin both the positive case (Stage 4 +
negative RS + Bearish macro → short emitted) and the negative cases
(Bullish macro → no shorts; Stage 2 stocks → no shorts; positive-RS
stocks → no shorts via per-stock rule).

## Test universe limitation

The e2e fixture is 7 large-caps + sectors. Known 2022 archetypal Stage 4
names (CVNA, COIN, PTON, AFRM) are not in the test fixture — the SP500
golden universe (`universes/sp500.sexp`) does have CVNA + COIN, but the
scenario format does not currently expose `total_short_trades` as a
pinable metric and the universe-level expansion would belong to a
separate item (extend `Scenario.expected` with short-side metrics →
follow-up). The 7-stock universe still provides distinct enough Ch.11
patterns (RS crossover vs RS negative-declining; with-volume vs
without-volume) to anchor the contract; broader-universe pins are a
later optimization.

## What's NOT pinned

- Per-stock RS-improving short rationale path (no test stock fires this
  in 2022 within the universe). Per-stock unit tests in
  `test_screener.ml` cover it.
- Sector-RS gate (`Strong sector blocks short`). Per-stock unit
  coverage exists; e2e fixtures use empty sector map.
- Real GSPC → real macro_trend wiring under the live cascade. That seam
  is pinned by `test_macro_2022_bear_with_composer_ad_bars` (PR #623);
  this note relies on its conclusion (Bearish on real 2022 bars) rather
  than re-driving it.
