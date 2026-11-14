---
name: project-floor-after-breakout-pattern
description: "Window_extreme support floor = dip AFTER the 90-day high, so post-breakout screens anchor stops on dips inside the run and clean breakouts skip as No_structural_stop; seen in 3/3 walked 2000 trades (DIS/TWX1/SFAM)"
metadata:
  node_type: memory
  type: project
  originSessionId: 249246cf-fc3d-457f-8536-5d3b905a45a5
  modified: 2026-11-13T06:32:04.435Z
---

Trade-by-trade chart walk of record rk-k0 (11-12, artifacts: DIS 1ZhBw8avVU4xx8sfNEpKqM, TWX1 9RzBSdYR6Z6hL1QbiZk68H,
SFAM EWWWigCQZVq2HKam5fzzgj). `Support_floor.find_recent_level` (scope `Window_extreme`, min 8 %) takes the 90-bar
highest high and the lowest low AFTER it. Book §5.1 wants the correction low BEFORE the breakout. They agree only when
the ticket is placed while price is under its range top; the screen fires after the MA cross, usually mid-breakout.
- DIS: floor = screen-week dip two weeks into the run (33 5/16) -> stop 31.98, shaken out on the pullback.
- TWX1: floor = first dip after the AOL merger gap (77 7/8) -> 7 % stop, 14 % cap bound, shaken out on the base-top retest.
- SFAM: 21 Jan 2000 base breakout reached top-N but skipped No_structural_stop (dip after the 90-day high 7.3 % < 8 %);
  bought 3 weeks later on the second leg at 21 (+53 % over MA) with floor = one-day dip 19 1/8.
At the code's entry price, the book's pre-breakout floor was >15 % away in all three (book: prefer other candidates).

**Why:** explains "skip the clean breakout, buy later/higher with a tight stop". The 10-25 floor screen
([[project_floor_and_refresh_screens]]) saw the skip half (67 % no 8 % dip after the peak); Nearest scope was tested
negative. The book-literal "last correction low before the breakout" floor was screened the same day (below).
**How to apply:** treat the post-breakout floor as the price of buying extended leaders, not as a defect to fix;
see [[project-entry-timing-screen-1112]] for the sibling entry rules.

**Screened 11-12 (`dev/experiments/entry-timing-screen-2026-11-12/` run.sh step 4, jj change usxwqwrz, local as of 11-12): NO-BUILD.** F1 = floor under the
4 weeks before the latest 13-week-range breakout x 0.96, record 15 % gate. (a) Entries, 5 seeds x 9 cells (N 8/13/26,
M 2/4/8): gate on -101..-261 NAV-% (81 % of k0 trades dropped; 6 of k0's 8 doublers: APPS 47 %, BBWI 47 %, MMYT 27 %,
AVGO 24 %, LGND 29 %, BGO 36 % stop distance); gate off risk-sized -40..-138; same size +58..+81 but 173-184 trades
worse vs 158-167 better, carried by STRP 2017 (takeover war) and GME 2020, and puts ~2.4 % of NAV at risk per trade on average vs the record's 1 % (k0: 22 of 524 trades >= 5 %, max 10.6 %;
#3594 `sizing.txt`; the earlier "5-7 %" was unsourced).
Counterexamples to a deeper stop: FMI 2015, PYX 2018, SIRI 2023, CVNA 2025-12. (b) k0 skips converted: 1,264 fills,
proxy mean +0.41 vs actual entries +0.44 (proxy calibrated: +245 vs real +260), median +0.36 vs -0.70, losers 40 % vs
59 %, but >= +5 NAV-% trades 0.8 vs 4.7 per 100. WHY: the post-breakout floor is what lets the code buy extended
leaders at all; a book-literal floor + 15 % gate points the same way as skip-extended (H1) but cuts deeper (81 % vs ~18 % of
trades), so it drops the tail. No-build at the tested surfaces (#3594); re-open only with a new mechanism, not a re-screen.
