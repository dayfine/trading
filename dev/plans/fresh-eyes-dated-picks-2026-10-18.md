# Fresh-eyes, dated picks: sample X dates, let a book reader pick and manage, compare with our system (2026-10-18)

User direction, 2026-10-18: *"not a full simulation, but taking X dates in that 26y time period, ask it to pick
trades on those dates and follow those trades through in Max(2y, when position close), and compare it to what our
system pick / how our system handle the trades."*

This replaces the monthly-checkpoint design (`fresh-eyes-staged-2026-10-18.md`) as the next fresh-eyes step. It reuses
that plan's charts, stepper, rule card and reader, and its staged market → groups → screen → close-look funnel. What
changes is the unit: one **decision date** instead of 318 monthly cuts.

## 1. The question

On a given Friday, a reader who knows only the book's rules and sees only the charts up to that day picks a few
trades. It then manages them to an exit.

- **Selection:** does it pick the names our screener ranks high, and do its picks do better or worse than ours?
- **Management:** for the trades it holds, does it exit earlier or later than our stop machine, and at what cost?

This is a screen (`mechanism-validation-rigor.md`), not a verdict. It can point at a gap worth a real test. It cannot
promote or reject a mechanism.

## 2. Dates

- **X = 24 decision Fridays, 2000-01..2024-06.** The window ends there so that every trade has 2 years of data after
  entry; the warehouse ends at 2026-06.
- **Stratified:** 24 blocks of about 12.5 months, with one Friday drawn at random inside each block (fixed seed).
  This covers 2000-02, 2008 and 2020 by construction.
- **The same 24 dates are read on our side.**

## 3. The reader's day (one decision date)

| step | input | model | output |
|---|---|---|---|
| A. Market and groups | the market pack (SPY + 30-week MA, A-D line, sector strength), one image | Opus | market phase; longs, shorts or neither; up to 3 favoured groups |
| B. Pool | mechanical, no model (see below) | — | ≤ 120 names |
| C. Screen | contact sheets, 20 five-year thumbnails each (≤ 6 sheets) | Sonnet | ≤ 10 names worth a close look |
| D. Close look | the 2×2 composite per shortlisted name | Opus | ≤ 5 orders (trigger, stop) or none |

- **Pool (step B).** The PIT top-3000 members alive on the date, in the favoured groups, that pass one neutral
  filter: close within 25 % of the 52-week high, and dollar volume above the universe floor.
- **Our screener's top 20 for that week are always added to the pool**, unlabelled. Both readers can then pick the
  same name, and an overlap of zero means a difference in choice, not in what was on offer.
- **Blinding.** Tickers are hidden behind pseudonyms on every image. Prices keep their real levels, as the
  blind-judge skill requires. The full-history frame still shows the calendar axis, so a reader could recognise a
  famous chart. Two calls on the pilot test this: the same chart with and without the date axis should get the same
  answer.

## 4. Following each trade: to the exit, capped at 2 years

- **How it runs.** The stepper fills the buy-stop-limit order and runs the reader's stop mechanically, day by day.
- **When the reader looks again.** At the fill, whenever the stop is hit, and every 8 weeks while the trade is held.
  At each look it may raise the stop or sell.
  - It never sees bars after the day of that look.
  - Unfilled orders expire after 8 weeks.
- **End of a trade:** at the exit, or at 104 weeks after entry, whichever comes first. A trade still open at
  104 weeks is marked to market and flagged.
- **Price path after the end (free, no model calls).** Record the price path to 104 weeks after entry for every
  trade, even after an earlier exit. This shows what each exit left behind or avoided.

Interpretation of "Max(2y, when position close)": the trade is followed until it closes, at most 2 years, and the
price path is kept for the full 2 years either way. If the intent was a 2-year minimum hold, the stepper takes a flag
for that.

## 5. Our side (no model calls)

Read from the record run (rb1 + full NYSE A-D, 26y, salts 0–2, `project_investor_preset_broad`):

- **Our picks on each date:** the screener's top 20 for that week, and the entries we actually made in the 4 weeks
  after the date, with each one's skip reason.
- **Our handling:** for our entries, the trade as the record ran it, including its exit reason and holding period.
- **Cross cells**, so that selection and management can be separated:

  | | reader manages | our stops manage |
  |---|---|---|
  | **reader picks** | step D + §4 | the reader's entries run under our stop rules |
  | **our picks** | the reader's §4 loop on our entries | the record |

  Both off-diagonal cells are mechanical apart from the reader's looks in the bottom-left cell. That cell is
  optional; run it if the top-right cell shows a management gap.

## 6. Pre-registered reads

1. **Pick overlap:** the reader's picks ∩ our top 20, and ∩ our actual entries, per date. Report the distribution
   across dates, not only the total.
2. **Per-trade return vs SPY over the same holding period:** reader vs ours. Report n, mean, median and p10/p25/p75/p90,
   with annualised figures.
3. **Paired per-date read:** equal-weight return of the reader's trades minus our trades from the same date. Report the
   sign rate and its distribution.
4. **Management on shared names:** exit week and return, reader vs our stops, and what each exit left behind (from the
   §4 price path).
5. **Self-consistency:** steps A–D repeated three times on 4 of the dates, with a fresh context each time. Agreement
   on picks and on stops is reported first. It sets how much weight reads 1–4 can bear (blind-judge §Protocol).

## 7. Cost projection

Unit costs come from the forward pass ($0.08 per Opus call with a full composite; Sonnet sheets $0.02–0.04).

| item | calls per date | $ per date |
|---|---|---|
| A, market and groups | 1 | 0.08–0.10 |
| C, contact sheets | ≤ 6 | 0.15–0.25 |
| D, shortlist close looks | ≤ 10 | 0.50–0.80 |
| §4 looks (≤ 5 trades × ~6 looks: fill, stops, every 8 weeks) | ~25 | 1.25–2.00 |
| **per date** | **~40** | **$2.0–3.2** |

| run | dates | $ | share of a week's quota (1 week ≈ $430–700) |
|---|---|---|---|
| **pilot** | 3 (one in 2002, 2008, 2017) | $6–10 | ~1–2 % |
| self-consistency (×3 on 4 dates) | +8 date-runs | $16–26 | ~3–5 % |
| full | 24 | $50–80 | ~8–15 % |
| optional bottom-left cell | 24 | +$25–40 | +4–7 % |
| **full program** | | **$75–115** | **~12–20 %**, inside one day's LARGE allowance |

The pilot measures the real conversion between dollars and quota (`quota_status.sh` before and after) and the
average number of §4 looks. The full run is sized from those two numbers.

## 8. Guards (`batch-model-run` skill)

- Before each date: `sh dev/scripts/quota_status.sh --guard 0.85`. Exit 3 ends the run.
- A usage-limit reply stops the run; it never waits in a retry loop.
- The run is restartable per date. Each date writes its own directory.
- At most 2 dates in flight at once.

## 9. Build

All of this is host-only (awk, sh, headless Chrome, `claude -p`), with no container. Reused as is: `render.sh`,
`market.sh`, `reader.sh`, the stepper and the rule card. New:

- `dates.sh`: the stratified draw;
- `pool.sh`: the step-B filter plus our top 20, read from `trade_audit`;
- `sheets.sh`: contact sheets with pseudonyms;
- `day.sh`: steps A–D for one date;
- `follow.sh`: §4;
- `ours.sh`: §5, our picks and handling from the record artifacts;
- `compare_dates.sh`: the §6 reads.

Then the pilot. A `results-analyst` reads the result; `qc-results` reviews it.
