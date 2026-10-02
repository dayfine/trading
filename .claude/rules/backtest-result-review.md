# Backtest result review — build the pack, render it, LOOK at it

**Every 26-year run, and every other long run whose numbers will carry a verdict, gets a
review pack that is rendered to images and looked at before any analysis is written.**
This holds whether or not the user opens the pack.

User instruction, 2026-10-02: *"for 26y runs you should generate the report artifact that I was
asking for. Then regardless whether I am gonna look at it or not, you should take a 'look' /
'Read' at it and check for obvious errors. I know you could also just read the data, but I
think this visual step is also very important."*

## Why reading the data is not enough

The first rendered look at the 26y investor pack (2026-10-02) found five defects in the pack
itself and one in the simulator. None had surfaced in three days of reading the same run's
CSVs and sexps:

| seen in the render | cause |
|---|---|
| "�31.1%", "2019��2021" | no `<meta charset>` |
| a 2000–2026 run charted as 2018–2026 | lightweight-charts' default `minBarSpacing` cannot fit 6,600 daily bars |
| "42 sold at an open after the day the stop traded" on a run whose stops fill on the trigger bar | the breach line was `entry × (1 − sid)`, but `sid` is measured from the decision price, so the line sat above the real stop (MELI: 135.82 vs 134.88). After the fix: 1 |
| "203 of 246 stop exits filled more than 0.5 % below the stop" | the code counted the `gap_down` label, which mostly tags fills a few cents under the stop. The real count is 62 |
| "Macro not Bullish at entry: 0" with no audit report | a missing input rendered as a clean 0 |
| the 1 remaining late stop (AAON 2024) | **a simulator defect**: a 48-week-rested ticket kept a 34 %-wide stop from its 2023 decision, and `trades.csv` misreports it (#3075) |

The `gap_down` misreading had also gone into a merged writeup (#3068, corrected in #3070). A
picture that contradicts what the config implies is the cheapest error detector we have.

## The procedure

1. **Build the pack:**
   ```sh
   sh dev/scripts/review_pack.sh --out .sweep-output/review-<exp> --title "<title>" \
     s0=<prefix-s0> s1=<prefix-s1> s2=<prefix-s2>
   ```
   Take prefixes from the sweep output, which holds the full artifact set
   (`macro_trend.sexp`, `trade_audit.sexp`). Committed `results/` dirs often lack them. While a
   backtest holds the container, use `--no-container` (no audit report, no stage replays). Rebuild
   with the container steps when the container is free; the audit-dependent cards then turn from
   n/a into counts.
2. **Render it:** `sh dev/scripts/review_pack_render.sh --site .sweep-output/review-<exp>/site`.
   This is host-only (headless Chrome and jq), so it is safe beside a running backtest. It writes
   `top.png` plus `part-1..6.png`.
3. **Look.** `Read` `top.png` and every `part-N.png`. For each, check:
   - **Window.** The charts span the run's whole window, and the KPI strip matches `actual.sexp`
     (return, CAGR, max DD, trades).
   - **Text.** No mojibake, `NaN`, `undefined`, or empty panels that should have data.
   - **Implied by the config.** Every count the config says should be about zero is about zero.
     With trigger-bar stop fills on, "stop breached before the exit day" is about 0. With the
     macro gate on, "bought in a Bearish macro week" is 0. A missing input reads n/a, never 0.
   - **Consistency.** The salt spread, the year table vs SPY, and exposure all agree with the
     writeup's own numbers.
   - **Odd rows.** Any trade or row that looks wrong in the picture: open it and trace it to the
     artifact before moving on.
4. **Record what the look found** before analysing:
   - a pack defect → fix it in `dev/lib/review_pack/` and pin it in
     `trading/devtools/checks/review_pack_test.sh`;
   - a simulator or data defect → an issue with the specimen.
5. **Publish** the pack as an artifact (`site/index.html` with `site/data/*` as supporting
   files) and give the user the link in the results report.

## What the eye catches becomes a detector

User follow-up, 2026-10-02: *"there are things that stand out when you look at them, so you should
be watching for those, and make such signals surface in the report / analysis."* Looking is the
detector of last resort. When the look, or the user, spots a pattern by eye, encode it in the pack
so the next run surfaces it at the top of "What stands out" without anyone having to look for it.
The pack's signal block (`renderSignals` in `dev/lib/review_pack/index.html`) holds the current
set:

| signal | what it surfaces |
|---|---|
| **Eras vs SPY** | the strategy/SPY ratio, cut into built / held / eroded eras (±15 % legs, 4+ year runs within a 10 % band split out as held), with a chart and an era table |
| **Regime × era** | each era split by SPY regime (UP / MIXED / DOWN, 30-week MA, lagged a week). The largest gap, and a second one when material, names the cause: holdings lagged in UP regimes at ≥ 40 % invested, cash through rebounds, or cash in a rising market |
| **One-trade / salt years** | a year whose excess vs SPY is ≥ 10 pp and at least half carried by one realised trade, or whose salts end ≥ 15 pp apart |

On the 26y investor pack the block reads, unprompted: eroded 2016–23 (cash through rebounds,
also holdings lagging in UP days at 62 % invested); 2024 rests on ADMA; eroded 2025–26 (holdings
lagged at 53 % invested, not an exposure effect). That is the story we first had to dig out by hand.
The writeup starts from these bullets and states which ones it confirms, refines or rejects.

## Exposure is read against market condition

User instruction, 2026-10-02: *"exposure can be a trap — holding more cash is desirable during
market down turn, so that needs to be measured against market condition."* An average-exposure
figure is never quoted as a cost on its own. Split exposure and returns by the SPY regime: weekly
close vs the 30-week MA and its slope, lagged one week, giving UP / MIXED / DOWN, plus per-year
DOWN rows. Report the strategy's return against SPY's inside each regime, **per period as well as
for the whole window**. Use sub-windows of a few years, cumulative rather than annualised returns
for short pieces, and a year-end running ratio of strategy NAV to SPY.

User follow-up, same day: *"we were otherwise doing fine up until 26 — so we should attribute
based on time period when making statement about exposure etc."* On the 26y investor preset the
whole-window split said the SPY gap was all DOWN regimes. Per period, that held only for 2009–17,
where cash was held through V-rebounds. The running ratio was 1.30× SPY at the end of 2024 (s0)
and 0.90× by mid-2026. In 2025–26, UP-regime days returned SPY +23.1 % against the strategy
−19.9 % at 53 % exposure: losing holdings in a rising market, not cash. 2018–23 also eroded
inside UP regimes. A whole-window average can hide the period that decides the verdict.

## What QC can check (qc-results)

- **RV1.** A results PR for a 26y or verdict-bearing chain links the published pack, and the
  writeup has a short "Review-pack look" section listing what was checked and found (or "nothing
  found").
- **RV2.** Any exposure figure in a conclusion comes with the regime split, by period as well as whole-window.
- **RV3.** The writeup addresses each signal bullet the pack printed (confirm, refine or reject, with the reason). A pattern found by eye that the pack did not flag gets a detector, or a note on why it cannot be one.
