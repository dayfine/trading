# Entry-timing screen (2026-11-12)

**Status: screen, not a backtest.** Every closed trade of the record run is replayed under three entry rules, plus
one narrow variant, using only information available on the day each rule acts.

**Verdicts.** H1, H2 and H3 are no-build decisions at the tested surfaces. H2′ (cap a stale E) is promising and
escalates to a real paired backtest.

| | |
|---|---|
| Run under test | `record-kseed-2026-10-27`: record config, tie-order seeds k0–k4, top-3000 PIT v12, 2000-01 → 2026-06, run tree fc78391dd |
| Trades | 2,789 closed trades over the five seeds; 2,756 have store bars (`results/validation.txt`) |
| Charts | Every k0 trade drawn book-style, with the code's levels and the alternatives: https://claude.ai/artifact/2hqayoBnVnFkpskr5pqqQQ |
| Reproduce | `sh dev/experiments/entry-timing-screen-2026-11-12/run.sh .sweep-output/record-kseed WORK` (host only; ~14 min including the follow-ups) |

## Why this screen

The record's first trade, DIS-wein-85, was walked chart by chart on 11-12. The screen fired on 14 Jan 2000, with
the close 21 % above the 30-week MA. E was 37.12, the 20 Jan 1999 high that the 8–51-week breakout scan picked up.
The order filled at 37.23 on 25 Jan, 30 % above the MA, and was stopped at 31.91 on 25 Feb for −14.3 %. A book
reading of the same chart buys the Aug–Dec 1999 base breakout at 30⅜, with a stop at 26⅞. That position survives
the February pullback to 31.00, which the book calls a second-chance buy. The question here is whether that lesson
holds across all trades: buy better, or skip trades like DIS.

## Findings in plain English

**How the test worked.** I took every trade the strategy actually made in the 26-year record run: five versions
of the run that differ only in how ties between equally ranked stocks are broken. For each trade I went back to
the price history and replayed it day by day under the new rule. Each result is the trade's gain or loss as a
percent of the portfolio at the time, added up ("NAV-%"). One run's real trades add up to +256 to +322. As a
sanity check, replaying the strategy's own rule reproduces its actual buy day 93 % of the time, and my 30-week
moving average matches the strategy's on every trade.

### H1: don't buy stocks that have already run too far

- **Idea.** DIS was 21 % above its 30-week average when it was picked. Skip trades like that.
- **Test.** Delete every trade above a cutoff (10 %, 15 %, 20 % … 50 % above the average, measured at the pick and
  at the fill) and add up what disappears.
- **Result: worse at every cutoff measured at the pick, in all five runs.** At 20 % it removes about 100 trades per
  run. Together they made +48 to +60, and they include 3–4 of the 8–10 trades per run that doubled.
- **At the fill** it is worse from 10 % to 40 % in all five runs, and +0.6 to +1.7 at 50 %, where it skips only
  14–15 trades per run (`summary.txt` H1′). That one corner sits next to −28 to −38 at 40 %.
- **What went right.** The instinct about losers is correct. The further a stock had run, the more often the trade
  lost: win rate falls from 46 % to 12.5 %, and the median trade from −1.6 % to −11.4 %.
- **What went wrong.** The few extended trades that win, win enormously. APPS made +526 % and BBWI +138 %; they
  were 51.1 % and 50.8 % above the average when picked. The trades more than 50 % above the average earn the most
  per trade of any group. A rule that skips DIS skips them too.
- **One trap.** Skipping only the 30–50 % range gains in every run (+7 to +20). But that's only because APPS and
  BBWI sit just above the 50 % line. Move the line to 60 % and it loses 29–42 in every run. It's a coincidence,
  not a rule.

### H2: buy where the book says, just above the recent trading range

- **Idea.** The strategy priced DIS's buy order at a high from a year earlier, not at the top of the recent range.
- **Test.** Same pick date, but E = the highest price of the last 2, 4, 8 or 13 weeks, plus 0.5 %. Same stop, same
  exit. This is what the existing `entry_anchor_local_range_weeks` setting does: it replaces E.
- **Result: worse in every run (−57 to −121) at every N.**
- **What went wrong.** DIS turned out to be the exception. In 81 % of trades the stock had already moved past the
  old high, so the strategy's E sat *below* the recent high and the order filled on a dip or right away.
  Requiring a fresh new high meant paying more, and about a third of those orders never filled at all, which
  lost good trades.
- **Already tested for real.** The flag was backtested on 10-03
  (`dev/experiments/entry-anchor-recovery-2026-10-02/results-2026-10-03.md`): on the investor preset, every value
  (4, 13 and 26 weeks) diluted in 3/3 salts in both 5-year windows. This screen reaches the same answer from the
  per-trade side.

### H2′: only fix the stale price

- **Idea.** Lower E only when it is stuck *above* the recent range, as with DIS (about 1 trade in 5): E′ = min(E,
  4-week high × 1.005). Otherwise leave it alone.
- **Result: better in all five runs (+6.8 to +12.0, 2–5 % of realised P&L).** 78–90 trades per run better, 4–9
  worse, mostly by buying the same stock a little cheaper or a little earlier, and in a larger size.
- **Two channels: the price paid and the position size.** The replay sizes each ticket at 1 % NAV risk off its own
  trigger, as the code does. A lower E with the same stop shortens the risk per share, so the capped ticket buys
  more shares (median +10 %, p90 +28 %). Stopped losers still lose about 1 % of NAV; winners are larger. Of the
  gain, the price paid is +2.7 to +6.5 per run and the larger position +3.0 to +7.7, so the size channel is
  37–66 % of it (`sizing.txt`).
- **What went right.** It changes the price paid and the position size, not which stocks get bought, so the big
  winners are untouched. The price channel alone is positive in all five runs.
- **What's uncertain.**
  - The replay can't see knock-on effects. Cash spent earlier might block another purchase, and a cheaper fill can
    change later rotation decisions.
  - The size channel needs cash. The replay funds the larger positions freely; the real book is bound by the 70 %
    exposure cap, the 30 % cash floor and rotation, so part of that half may not survive.
  - Orders that never filled at the old high would now fill: 17–24 per run. I estimated them separately with a
    proxy hold, and they came out about break-even (−0.9 to +5.7).
- **DIS itself is not saved.** Its 4-week top was 36.75, so E′ is 36.93 instead of 37.12: the same fill day and
  the same stop-out.

### H3: if it has already run, wait for the pullback

- **Idea.** DIS dropped back to about 31 a month after the buy, the book's "second chance".
- **Test.** When the pick was more than 20 % above the average, don't buy. Instead rest a limit at the average plus
  3 % or plus 8 % for up to 8 weeks, with a book-style stop under the recent lows.
- **Result: worse than what actually happened, in every run (−12 to −26 at plus 8 %).**
- **What went right.** When the pullback came, it was a better entry: those trades beat holding the actual entry
  under the same stop (+40 pooled). DIS bought at 31.31 on 25 Feb would have made money.
- **What went wrong.** About 80 % of the flagged stocks never pulled back within 8 weeks, and they were the strong
  ones, big winners included. Waiting filters out the best stocks.

### The big picture

The strategy's profit comes from a handful of huge winners, and they often look "too extended" when bought. Any
rule that avoids extended stocks, or waits for a dip, also avoids those winners. The only fix that survived changes
the price paid and the position size, not which stocks get bought.

This is the 07-12 entry-shape finding seen from a new angle (`memory/project_entry_shape_gates_no_build`: the big
losers and the monsters are the same kind of ticket). It is also the trigger half of
`memory/project_entry_E_stale_high_bug` ("entry trigger should be current-range top, not stale 52w top"). This
screen narrows that to: only when the stale E is above the current range.

## The numbers, per seed (NAV-% change vs the run)

| rule | k0 | k1 | k2 | k3 | k4 | source |
|---|---:|---:|---:|---:|---:|---|
| realised total | 259.6 | 321.8 | 283.2 | 255.8 | 288.7 | `summary.txt` totals |
| H1 skip, screen > 20 % over MA | −53.3 | −50.5 | −53.7 | −60.4 | −47.9 | `summary.txt` H1 |
| H1 skip, screen > 30 % | −26.5 | −16.1 | −18.6 | −17.8 | −22.6 | `summary.txt` H1 |
| H1 band 30–50 % | +7.3 | +19.9 | +14.9 | +18.2 | +11.1 | `extra.txt` band |
| H1 band 30–60 % | −41.6 | −29.0 | −34.0 | −30.7 | −37.9 | `extra.txt` band |
| H2 anchor N=4 vs null | −74.0 | −114.0 | −112.7 | −73.4 | −98.9 | `summary.txt` H2 (k0 90 % CI [−137.5, −19.0]) |
| H2′ cap stale E vs null | +11.6 | +7.3 | +6.8 | +12.0 | +9.7 | `extra.txt` H2′ (k0 90 % CI [+2.2, +22.1]) |
| of which the price paid | +3.9 | +4.4 | +2.7 | +6.5 | +6.1 | `sizing.txt` |
| of which the larger position | +7.7 | +3.0 | +4.1 | +5.5 | +3.6 | `sizing.txt` |
| H2′ never-filled tickets (proxy) | −0.9 | −0.8 | +5.7 | +0.2 | +5.1 | `unfilled.txt` |
| H3 X=20 % m=8 %: real → pullback | 53.3 → 31.6 | 50.1 → 30.3 | 53.7 → 41.6 | 60.4 → 34.3 | 47.9 → 36.0 | `summary.txt` H3 |

The H3 row covers flagged trades only: the real P&L, then the pullback rule's (zero where the limit never filled).

## Method

**Inputs.**
- Audit entries are parsed by `decision-walk-rk-2026-11-06/lib/entries.awk` and joined to `trades.csv` by
  `position_id`, with NAV at the screen from the equity curve (`lib/specs.awk`).
- Bars come from the CSV store (`data/`). The trade audit is not committed (the chain's `collect` drops it), so
  `run.sh` reads `.sweep-output/record-kseed/`.

**Replay (`lib/replay.awk`, one symbol at a time).**
- Basis: adjusted, with bar prices scaled by `adjusted_close / close` and the run's raw prices by that day's factor.
- Weeks are Monday-based calendar weeks. The MA is the code's 30-week WMA (`Stage.default_config`).
- Entries are a stop-limit (trigger E, limit E × 1.02) live from the day after the screen. A fill is
  `min(max(open, E), E × 1.02)` on the first day whose range reaches E within the band.
- **null**: the code's own E. It is the reference for H2/H2′, so fill-model differences cancel.
- **H2(N)**: E = max weekly high over the last N weeks (incl. the screen week) × 1.005. Keeps the installed stop,
  and exits at the actual exit unless that stop is hit first.
- **H2′** = H2(4) on trades where the code's E is above that level; elsewhere it equals the null.
- **H3(m)**: on screens more than X over the MA, a buy-limit at the last completed week's MA × (1 + m), live for 40
  trading days.
  - Book stop: 0.96 × the lowest weekly low of the 8 weeks before the fill week. The entry is skipped when that is
    more than 15 % below it (book §5.1).
  - Exit at the actual exit if that was not a stop-loss. Otherwise hold until the book stop hits, or 13 weeks past
    the later of the actual exit and the fill.
  - **control**: the actual fill under the same stop and exit rule, which isolates H3's entry from its stop.
- Sizing for every modelled P&L follows the code: value = min(1 % NAV / stop distance at the trigger, 14 % NAV).
  The model matches DIS's real P&L (−$10,371 vs −$10,382).

**H2′ split (`lib/sizing.awk`, over `replay-k*.csv` only).** Price channel = `h2n4_pnl` × shares(null) /
shares(E′): the capped fill and exit at the null's share count. Size channel = the rest. The shares come from the row
itself: E = `E_over_fill`, E′ = `rt4_over_fill` × 1.005, and the stop from `value_over_nav` (stop distance =
0.01 / `value_over_nav` below the 14 % cap). The rebuilt stop reproduces `null_pnl` and `h2n4_pnl` from their R
columns on all 500 stale rows (largest relative error 2e-5, CSV rounding).

**Never-filled tickets (`lib/unfilled.awk`).** For tickets the code placed but never filled, with E above the
4-week high: does the capped E′ fill within 52 weeks? If so, they are held with the installed stop for up to 26
weeks. This is a proxy, since the code's result there is 0.

**Validation (`results/validation.txt`).**
- The run fill sits inside the store's raw bar for 97.8 % of trades. The rest are excluded from the counterfactual
  reads as basis mismatches.
- The replay's MA extension is within 1 pp of the audit's on 2,756 / 2,756 trades.
- The null control reproduces the fill day on 92.8 %. The replay fills earlier on 169 trades, which the sim
  presumably held back for cash or exposure reasons it can't see; it fills later on 22 and never on 7.

## Screen-rigor checks (`.claude/skills/screen-rigor`)

1. **Estimand and gap.** The mechanisms change the portfolio's realised return. The screen measures per-trade
   replayed P&L in NAV-%, with exits fixed (H2/H2′) or proxied (H3). It does not model portfolio interactions:
   cash, the 70 % exposure cap, the 30 % cash floor, rotation, or displaced rivals.
   - H1 ignores redeploying freed capital. Replacing each skipped trade with an average one is roughly a wash at
     X = 20 %: the skipped cohort's own mean is about the average trade's, and the lost tail remains.
   - H3 is scored only on flagged trades whose E-ticket eventually filled. That is a stronger subset than all
     extended screens, so the bias favours H3, and H3 still loses.
   - For H2′ the gap includes its size channel (37–66 % of the gain): the replay funds the larger positions freely.
2. **Distributions.** `why.txt` gives n, mean and p10/p25/median/p75/p90 per extension bucket, per-trade H2
   deltas by E position, and the H3 filled-vs-control distribution.
   - H1's buckets differ in the tail, not the middle. The median trade worsens monotonically with extension, while
     the ≥ 50 % bucket's mean (+31 %) is set by 10 trades of 80.
   - The H2′ per-trade delta is narrow and positive: k0 median +0.07, p10 0.00, p90 +0.41 NAV-%.
3. **Magnitude.** NAV-% weighs every trade by its effect on the portfolio at the time; seed totals are 256–322.
   H2′ is 2–5 % of realised P&L. Scaled to the run's 26y log return (about 2.8), that is roughly
   0.05–0.15 log. This is a proportional estimate, not a measured return, and it sits below a single cell's
   noise floor (0.45 log, `memory/project_record_kseed_band`). So the real test must be K = 5 paired.
4. **Selection.** Every rule uses decision-time information:
   - the audit's own screen close and MA;
   - range tops from weekly bars through the screen week;
   - the pullback limit from the last completed week's MA.

   The sample is the trades the code took. Tickets it never filled are covered for H2′ (`unfilled.txt`); names it
   never screened are not covered.
5. **Surface.** H1: X ∈ {10, 15, 20, 25, 30, 40, 50 %} at the screen and at the fill, plus 15 band cells. H2: N ∈
   {2, 4, 8, 13}. H3: X × m ∈ {7 values} × {3 %, 8 %}. Signs are stable across each surface, except two H1
   corners: the band cells (see the trap above), and the fill-based cut at X = 50 %, which is +0.6 to +1.7 in 5/5
   seeds on 14–15 trades, next to −28 to −38 at 40 %. Neither changes the H1 verdict.
6. **Paired, event-level.** H2/H2′ are paired with the null per trade (better/worse counts in `extra.txt`); H3 is
   paired with its control. DIS, APPS and BBWI are traced (`extra.txt` lists every ≥ +100 % trade with its
   extension).
7. **Uncertainty.**
   - Bootstrap 90 % CIs of k0's sums: H2 N=4 [−137.5, −19.0]; H2′ [+2.2, +22.1]; H3 X=20 % m=8 % pullback − control
     [−66.4, −1.6].
   - Sign consistency across the 5 seeds for every headline row.
8. **V6.** Not applicable: no paired backtest arms; each seed's single run is replayed per trade. The H2′ backtest
   must gate on V6.

## Verdicts (calibrated to a screen)

- **H1, H2, H3: no-build decisions at the tested surfaces.** They lean on the standing priors
  `memory/project_edge_is_the_fat_tail` and `memory/project_entry_shape_gates_no_build`. This is not "the mechanism
  cannot work". The mechanism of failure is structural: all three change **which** names fill, and the names they
  drop carry the right tail.
  - H1 and H3 are new rules, and nothing is built for them.
  - H2 is the existing flag `entry_anchor_local_range_weeks` (default off). Classification: REJECT-as-default /
    keep-as-axis, as the flag inventory (`dev/notes/mechanism-flag-inventory-2026-08-09.md`) lists it. A screen
    cannot earn do-not-revive, so this verdict does not make the flag retirement-eligible. The screen re-derives
    the flag's real test of 10-03 (`dev/experiments/entry-anchor-recovery-2026-10-02/results-2026-10-03.md`), where
    every value diluted in 3/3 salts in both windows.
- **H2′: escalate.** Build a default-off flag that caps E at the current range top only when E is above it, then
  run a K = 5 paired 26y comparison on the record config.
  - The paired test must report the split between the price and the size channel: per-arm position value and
    exposure, or a price-only sizing variant that keeps the null's share count.
  - Faithfulness: book §4.7 anchors the buy-stop at the top of the *current* trading range. This is an entry-level
    dial (W2), and the spine is intact.
  - Nothing here promotes it.

## Files

- `run.sh`: regenerates `results/` (host only, about 14 minutes with the follow-ups).
- `lib/specs.awk`: joins audit, trades and NAV. `lib/replay.awk`: the per-trade replay. `lib/gspc_weekly.awk`:
  the RS benchmark (charts only).
- `lib/validate.awk`, `lib/summarize.awk`, `lib/why.awk`, `lib/extra.awk`: the result tables.
- `lib/unfilled_specs.awk`, `lib/unfilled.awk`: never-filled tickets under the cap.
- `lib/sizing.awk` (`run.sh` step 5, over the result CSVs only): H2′ split into its price and size channels, and
  F1's NAV at risk per trade. Output `results/sizing.txt`.
- `results/replay-k{0..4}.csv`: one row per trade per seed, with every counterfactual. `results/unfilled.csv`: never-filled
  tickets. The text files are the tables quoted above.

## Follow-ups (same day): the book's stop, an entry-feature scan, re-entry after a stop

The chart walk continued trade by trade after the main screen:

- DIS-wein-85: https://claude.ai/artifact/1ZhBw8avVU4xx8sfNEpKqM
- TWX1-wein-83: https://claude.ai/artifact/9RzBSdYR6Z6hL1QbiZk68H
- SFAM-wein-87: https://claude.ai/artifact/EWWWigCQZVq2HKam5fzzgj

All three losses share one mechanism. `Support_floor.find_recent_level` (scope `Window_extreme`, 8 %) takes the
90-day high and the lowest low *after* it, but the screen fires after the breakout has started.

- **A clean breakout with no 8 % dip yet is skipped as `No_structural_stop`.** SFAM on 21 Jan 2000 was a top
  candidate; its dip was 7.3 %.
- **The code then buys later and higher**, with a tight stop under a dip inside the run:
  - DIS: the screen-week low;
  - TWX1: the first dip after the AOL merger gap;
  - SFAM: a one-day dip in the second leg.

The book (§5.1) puts the stop under the correction low *before* the breakout. At the code's entry price, that
floor was more than 15 % away in all three trades. The follow-ups test whether fixing this, or working around it,
helps.

### F1: the book's stop (the pre-breakout floor)

**In plain English.** I used the book's stop as written. The breakout is the most recent week whose close cleared
the prior N-week high, while the week before did not. The floor is the lowest low of the M weeks before it, and the
stop goes 4 % under, the code's own buffer. The record's 15 % stop-width gate (`Drop_over_max`) then applies. The
rule was replayed on every closed trade of all five seeds, over N ∈ {8, 13, 26} × M ∈ {2, 4, 8}. It was also run
the other way: k0's `No_structural_stop` skips that the book's stop would turn into tickets.

**Result: it removes the big winners.**

- **The book's floor is more than 15 % below the code's E on most trades.** In k0 at N=13, M=4 that is 443 of 545
  (81 %). The gate drops them, including 6 of the 8 doubling trades in k0's replayed set (k0's ninth, ADSK 2003,
  fails the basis check and is not replayed):

  | trade | result | book stop below E |
  |---|---:|---:|
  | APPS 2020 | +526 % | 47 % |
  | BBWI 2020 | +138 % | 47 % |
  | MMYT 2023 | +155 % | 27 % |
  | AVGO 2013 | +200 % | 24 % |
  | LGND 2012 | +233 % | 29 % |
  | BGO 2003 | +103 % | 36 % |

  Every cell is negative in every seed, from −101 to −261 NAV-%.
- **Without the gate, at the run's risk sizing:** −40 to −138, because wider stops shrink the positions.
- **Without the gate, at the run's position size** (only the stop and a 13-week hold-through change): +58 to +81
  in 5/5 seeds. But more trades get worse (173–184) than better (158–167).
  - The gain rests on STRP 2017 (a Verizon/AT&T bidding war, +24.1 NAV-% in k0) and GME 2020 (the squeeze, +13.0).
  - Deeper stops turned small losses into large ones: FMI 2015 −1.1 → −7.4, PYX 2018 −1.9 → −6.7, SIRI 2023
    −1.7 → −6.0, and CVNA Dec 2025.
  - It also puts about 2.4 % of NAV at risk per trade on average, against the record's 1 %, and 5 % or more on 22
    of k0's 524 trades with a book stop (`sizing.txt`: `value_over_nav` in `replay-k0.csv` × `n13m4_stop_dist` in
    `floor.csv`). The FMI, PYX and SIRI losses are that tail, which the book's 15 % rule exists to prevent.
- **Converted skips (k0):** 1,264 fills on a 26-week proxy hold. The proxy is calibrated on the run's own entries:
  +245 NAV-% against +260 realised.

  | | the run's entries | converted skips |
  |---|---:|---:|
  | mean per trade (NAV-%) | +0.44 | +0.41 |
  | median | −0.70 | +0.36 |
  | losers | 59 % | 40 % |
  | trades ≥ +5 NAV-% | 4.7 per 100 | 0.8 per 100 |

**Why.** A book-literal floor plus the 15 % rule only admits stocks still near their base. The record's money comes
from stocks bought after they have run, where the only stop within 15 % is a dip inside the run. The post-breakout
floor is what lets the code buy extended leaders at all. Fixing it points the same way as H1 (skip extended
entries), which lost, but cuts much deeper: the gate drops 81 % of k0's trades, against about 18 % for H1 at 20 %.

**Verdict: no-build** at the tested surface. The book-floor trades have a better median and fewer losers. That is
worth remembering if the goal ever becomes steadier returns rather than maximum return, but that is a different
objective and a different test.

### Entry-feature scan: can features tell the monsters from the losers?

**In plain English.** I took 903 unique trades (symbol + fill date) across the five seeds and split each of 12
features the code knows at entry into quintiles. That includes the new ones from today: stale E, book-floor
distance, and extension at the fill.

**Result: the features sort trades by risk, not quality.** Extension at the screen, RS, MA slope and book-floor
distance all point the same way for losers and for monsters. AUC(+50 %) / AUC(loser) for each:

| feature | AUC(+50 %) | AUC(loser) |
|---|---:|---:|
| extension at the screen | 0.60 | 0.58 |
| RS | 0.62 | 0.58 |
| MA slope | 0.60 | 0.55 |
| book-floor distance | 0.62 | 0.55 |

The hottest quintile has the worst win rate (28–35 %) and the worst median (−5 to −8 %), but 10–13 +50 % trades,
about the most (book-floor distance's Q4 has 14). Its NAV-% per trade beats the calmest quintile's for extension, RS and MA slope, but not
for book-floor distance (+0.27 against +0.48). The calmest quintile wins most often (46–48 %) and has 4–6 +50 %
trades. The other features show nothing consistent.

There are only 13 trades of +100 % in 26 years (40 of +50 %), too few to validate any multivariate model.

**Selection bias.** The sample holds only trades the run made. For a filter on the run's own entries that is the
right population. For the general question, the unbiased check is the 07-08 feature screen: 162,632 tickets
regardless of cash. It found the same trade-off: win rate is predictable (AUC 0.745), magnitude is not
(R² 0.0034).

### R1: re-buy after a stop

**In plain English.** After every stop-loss exit (about 280 per seed), I rested a buy-stop just above the highest
high made while the stock was held (× 1.005, 2 % band), for 8, 13 or 26 weeks. The stop went 4 % under the shakeout
low (the lowest low between the exit and the re-entry), with a 26-week proxy hold. It was run with and without the
15 % gate. The book allows re-buying after a whipsaw ("insurance premium"); the idea was listed as untested in
`memory/project_weekly_close_stop_lever`.

**Result.**

- **With the gate:** 69–146 re-triggers per seed are blocked (the shakeout low is more than 15 % away). The 23–37
  that fill have a median trade near −11 %, and 4 of 5 seeds are negative.
- **Without the gate:** +143 to +194 NAV-% in 5/5 seeds, but it is one trade. GME was stopped on 11 Sep 2020 and
  re-bought on 14 Sep, and the 26-week hold rides the January 2021 squeeze for +2,684 % (+139 NAV-% in k0).
  - Without each seed's top 3 fills: +1 to +17.
  - Without the top 10: negative in all five seeds.
  - 2000–2012 fills: +2 to +14.
  - Shallow shakeouts (stop within 15 %) fail again.

**Verdict: no-build.** Recoveries to a new high are not better than average entries once the one squeeze is
removed, and in a cash-bound book they would displace better tickets.

### What the follow-ups add up to

Each route to "keep the monsters, lose fewer DIS-type trades" fails for one reason: the losers and the monsters are
the same kind of ticket.

| route | what it does |
|---|---|
| H1, F1 | trim the extended entries, and take the tail with them |
| H3 | waits for a pullback the winners never give |
| entry features | measure heat (risk), not quality |
| R1 | finds no edge outside one squeeze |

Only H2′, which changes the price paid and the position size, not which names fill, survives. The DIS/TWX1/SFAM
losses are the premium the strategy pays to own APPS and MMYT.

### Follow-up files

- `run.sh` step 4 regenerates all of it; the whole `run.sh` takes about 14 minutes on this machine.
- Scripts:
  - `lib/floor.awk`, `lib/fsum.awk`, `lib/fsame.awk`: F1 on entries.
  - `lib/conv_events.awk`, `lib/conv.awk`, `lib/csum.awk`: k0 conversions.
  - `lib/features.awk`, `lib/quint.awk`: the feature scan.
  - `lib/reentry.awk`, `lib/rsum.awk`, `lib/rrobust.awk`: R1.
  - `lib/sizing.awk` (step 5): F1's NAV at risk per trade, in `sizing.txt`.
- Results:
  - `floor-cells.txt`, `floor-samesize.txt`, `floor-conversions.txt`, `features.txt`, `reentry.txt`,
    `reentry-nogate.txt`, `reentry-robustness.txt`.
  - Per-trade CSVs: `floor.csv`, `floor-conversions.csv`, `features.csv`, `reentry.csv`, `reentry-nogate.csv`.
- Conversions use k0's top-N decisions, parsed from the audit's cascade summaries by the decision walk's `weeks.awk`.
