# Fresh-eyes Weinstein study: a reader with no access to our code trades 100 charts (2026-10-13)

User direction, 2026-10-13: *"forget about our system (code written) -- use a fresh agent that does not read this
codebase ... read the book ... pick ~100 stocks and produce charts (26y, with price and 30w MA etc) ... along with
macro and ADL data / sector strength -- deterministic ... then determine long and short trades from these 100 stocks
throughout time ... and see how different it is than our system, and try to summarize / analyze why."* Sizes set by
the user: 100 stocks for the hindsight read, 100 for the forward trading pass. Hindsight: *"show only part of the
same image, e.g. by covering up the future part."*

This is a **screen that produces leads**, not a verdict on any mechanism (`mechanism-validation-rigor.md`). Its
output is a list of places where a book-only reader and our system disagree, each classified and traced.

## 1. What is deterministic and what is not

| part | who | deterministic? |
|---|---|---|
| sample of 100 symbols | script, fixed seed | yes |
| weekly bars, 30-week MA, Mansfield RS, volume, market and sector series | script | yes |
| chart images (SVG -> PNG via headless Chrome) | script | yes, byte-stable for the same inputs |
| order fills, stops, P&L in the forward pass | script (the stepper) | yes |
| stage labels, setups, order tickets | the fresh agent | no; repeated on a subset to measure self-consistency |
| comparison with our system | a separate step, never the fresh agent | yes for the joins, analyst for the why |

## 2. Sample

- Pool: every symbol in the yearly PIT top-3000 lists (`dev/experiments/short-setup-map-2026-10-12/results/membership.txt`)
  with at least 156 weeks of daily data inside 2000-01-01..2026-06-30.
- Stratify by first list year into 2000-04 / 2005-09 / 2010-14 / 2015-19 / 2020-25 and draw 20 from each with a
  fixed seed (`awk` with `srand(20261013)` over the sorted pool). Delisted names stay in, so the sample is not
  survivor-only. The draw and the pool are committed.
- The same 100 symbols feed both layers.

## 3. Charts (the "page" the reader sees)

One PNG per (symbol, cut date, frame). A cut date `t` is a Friday; nothing after `t` is drawn or used.

- **Frames.**
  - *Full*: a fixed x-axis 2000-01..2026-06 for every symbol and every cut, so the axis leaks neither the delisting
    date nor the cut's position relative to the data end. Weeks after `t` are a flat grey block labelled "future".
  - *5-year*: the trailing 260 weeks ending at `t`, plus the same grey block for 26 weeks to the right so the latest
    bar never sits on the edge.
- **Panels** (as in the book's charts): weekly OHLC bars on a log price scale with the 30-week MA; volume bars below;
  the Mansfield RS line vs SPY (52-week zero line) at the bottom.
- **Causality.** Every series, and **the y-axis range**, is computed only from bars dated `<= t`. Masking a finished
  image would leak the future through the y-scale (the axis would already span a later high or low), so each cut is
  rendered fresh with the same layout and a grey future block. That is what "cover up the future part" means here.
- **Identity.** The ticker and the sector are shown; real dates are shown. The reader is a book reader, not a blind
  judge; prices are adjusted for splits and dividends (total-return basis), and the chart says so.
- **Market pack**, rendered for the same cut `t`, same rules:
  - SPY weekly with its 30-week MA and volume;
  - the NYSE advance-decline line (cumulative advances minus declines). NYSE data runs to 2020-02-14; after that the
    series is the universe-computed synthetic counts (`trading/test_data/breadth/synthetic_*.csv`), and the chart
    marks the splice;
  - sector strength: for each of the 11 sectors, the median 26-week return of its member stocks minus SPY's, as a
    small multiples panel. `data/sectors.csv` is survivor-only (a known defect): symbols with no sector are left
    out and counted on the panel.

## 4. The fresh agent

- **Inputs only:** the book text at its local path (never copied, committed or uploaded), the rendered PNGs, and a
  small JSON per cut with the last bar's numbers (date, OHLC, volume, MA) so levels can be stated exactly. It runs
  from a working directory outside the repo containing only those files. The brief forbids reading the repository
  and names none of our rules, thresholds or results.
- **Step 0, the rule card.** One agent reads the book and writes its own card: stages, long buy rules, short sell
  rules, stops, the market and sector gates, how it uses volume, RS, the A-D line. Every stock agent gets this card
  and may grep the book. The card is committed (it is the agent's paraphrase with chapter cites, not book text).
- **Layer (i), hindsight read (100 symbols).** The full-frame chart at `t` = the last bar. The agent marks stage
  segments (start week, end week, stage) and every place the book would buy, sell, or sell short, with levels.
  Hindsight is allowed and the output is labelled as such; it answers *does our classifier read the chart the way
  a book reader does*, a faithfulness question.
- **Layer (ii), forward trading (100 symbols).** One agent context per symbol, run as a loop with the stepper:
  1. The stepper renders the stock (both frames) and the market pack at cut `t`, plus the open position and orders.
  2. The agent returns one JSON: stage, action (`none`, `buy_stop`, `short_stop`, `cancel`, `set_stop`, `exit`),
     levels, a one-line reason.
  3. The stepper simulates daily bars until the next checkpoint: buy-stops and sell-stops fill when traded through
     (at the open on a gap), protective stops trigger intraday, all on adjusted prices; no commissions, no borrow fee
     beyond the dividend a short pays (adjusted prices already charge it).
  4. Checkpoints: every 4 weeks, plus the Friday after any fill, stop hit, or order rest of 8 weeks.
  One position per symbol at a time (long or short), one unit of capital per trade. Outcome per trade: return, and
  excess vs SPY (long) or vs an SPY short (short) over the same days.
- **Self-consistency.** 10 symbols of layer (ii) are run twice in fresh contexts; agreement on trades taken and on
  levels is reported before any comparison (the blind-judge rule: code-vs-agent is uninterpretable until
  agent-vs-agent is known).
- **Pilot first.** 5 symbols of layer (ii) run before the rest, to check the stepper and measure tokens per symbol.
  The full run's cost is stated before it starts. Agents are serial-ish (at most 3 at once); they need no container.

## 5. Comparison (after both layers, by a separate step)

- **Stages:** the agent's stage segments vs our classifier's weekly stages
  (`.sweep-output/short-setup-map/stages/<sym>.csv`), as a confusion matrix and agreement by year.
- **Trades:** the agent's forward trades vs our record run's trades on the same 100 symbols, matched by symbol and
  overlap of holding period: both took it / only the agent / only ours, for longs and shorts. P&L per class.
- **Every disagreement gets a class:** our code misreads the chart; the agent misreads it; the book is ambiguous; a
  documented dial (`weinstein-faithful-core.md`); a data defect. A sample of each class is traced end to end.
- **The why goes to results-analyst** (opus, max), with the rendered charts of the traced cases.
- Book questions the study settles are written back to `docs/design/weinstein-book-reference.md`
  (`book-as-authority.md` tier 3).

## 6. What it may conclude

- "Our classifier and a book reader disagree on X % of weeks, mostly in situation Y", with the traced cases.
- "The book reader takes trades of kind Z that our gates exclude (or the reverse)", with their P&L as a lead.
- Not: a promote/reject on any flag, or "our system is (un)faithful" as a verdict. Leads go through the normal
  pre-registered screen or WF-CV pipeline.

## 7. Build order

1. `dev/experiments/fresh-eyes-2026-10-13/scripts/`: sample, weekly series, market and sector series, the SVG chart
   renderer, the PNG render (host only, headless Chrome, as `review_pack_render.sh`). Pin causality with a check:
   rendering cut `t` from data truncated at `t` and from full data gives byte-identical SVG.
2. The stepper (awk/sh): orders, fills, stops, checkpoint schedule, trade log.
3. Rule card; pilot of 5; cost report; layer (i) and layer (ii) runs; self-consistency pairs.
4. Comparison and analyst read; results PR (qc-results).
