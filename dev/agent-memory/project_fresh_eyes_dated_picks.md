---
name: project_fresh_eyes_dated_picks
description: "Dated-picks screen 10-18 (24 dates, book reader vs record): no pick/manage gap detectable; 0 shared trades because the investor floor scan only admits post-high pullbacks (2/3 of NSS skips are fresh highs)"
metadata:
  type: project
---
**Result (#3328, dev/experiments/fresh-eyes-dated-2026-10-18/results/README.md, rework 1):** reader longs n 34 vs record n 51: mean excess +3.3 vs +2.6 %, median −6.1 vs −3.1 %, difference +0.7 pp (date-clustered 95 % CI −11.4 to +14.8); per year of capital +0.3 vs −1.3 %; paired dates 7/14. Each side's picks held 104 weeks: +1.4 vs +0.4 % geometric (difference +1.0 pp, CI −13 to +18). Both managers are about 1 point under simply holding. Reader shorts 1/9. Self-consistency: Jaccard 0.47 on long dates, 0 on the short date. The close look orders our top-20 names at 2× the pool rate (13/40); the contact sheet does not. (A first draft read +3.9 % / −0.6 pp: FLO 2013's split-restated entry price had been read as raw, qc-results R2.)

**Why zero shared trades (transferable):** require_structural_stop + Support_floor Window_extreme (90 bars, ≥ 8 %) anchors on the newest high and needs a low AFTER it. A name at, or within days of, a fresh 90-day high therefore has no floor and is skipped. The record places tickets only on post-high pullbacks (672 s0 tickets: high a median 8 bars earlier, correction 9.9 %); a book reader buys the breakout week.
- 13/13 overlap orders were NSS (12 at the high).
- 26y sample of 1,514 NSS: 29.6 % had the high on the decision day, 38.5 % a pullback under 8 %, 31.9 % a floor more than 15 % away.
- The reader's stops (8.7–14.2 %) sat above the pre-breakout low: the card's trader rule, not its investor rule.

**How to apply:** "0 overlap with a book reader" is not a taste gap; by construction the two buy different phases of the move. Nearest would not change it much: pre-breakout lows sit a median 17.8 % below the close, and only 10–29 % of them come within the 15 % cap (the installed stop sits 4 % under the floor). The record's trades.csv entry_price is restated onto the exit's split basis when a split falls inside the hold (round_trip_pairing.mli); never read it as the raw fill. No selection or management lever is ruled in. For any future reader study: build the date-axis test first, and take the decision week's Placed names as "our picks", and draw a 2020 date. Links: [[project_recovery_reentry_gap]], [[project_fresh_eyes_forward_quota]], [[project_nearfloor_is_risk_not_return]], [[project_edge_is_the_fat_tail]].
