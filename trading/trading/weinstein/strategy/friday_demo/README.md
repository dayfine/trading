# Friday pipeline demo

What the Weinstein strategy does on one Friday, stage by stage, on a small
made-up market. Every stage prints what it does, what it takes in, what it
puts out, and its result for each stock, so the trace reads top to bottom
without the code.

## Run it

From `trading/`:

```sh
dune exec trading/weinstein/strategy/friday_demo/bin/friday_demo_main.exe
```

The same text is checked in as `test/friday_demo_trace.expected`.
`dune runtest trading/weinstein/strategy/friday_demo` prints a fresh trace and
diffs it against that file, so any change to how the strategy treats this
Friday fails CI. Read the diff; if the change is intended, accept it with
`dune promote`.

## The market

All symbols are `DEMO_*` and every price is generated in
`lib/friday_demo_fixture.ml`: about two years of weekday bars for nine stocks,
an index and three sector ETFs. No vendor data is involved. The screen date is
Friday 2024-06-28; before it, the real strategy runs on the 30 prior Fridays so
that it carries last week's stage for every stock, as it would in a backtest.

The demo config is the strategy default with three changes, each marked
"demo setting" where the trace quotes it: a top-N of 4 (`max_buy_candidates`)
so the cut shows, a fixed seed for the tiebreak among equal scores, and
`require_structural_stop` (the investor preset) so a stock with no pullback to
put a stop under is visibly refused. Every rule value in a stage's "Does:" text
is read from that config (`lib/friday_trace_rules.ml`), not typed into the
prose.

| ticker | built as | where it stops |
|---|---|---|
| `DEMO_BASE` | flat base, Stage 1 | pre-screen: not Stage 2 or 4 |
| `DEMO_FALL` | steady decline, Stage 4 | long rules: stage setup; shorts are closed by the macro gate |
| `DEMO_QUIET` | breakout on ordinary volume | breakout-volume gate |
| `DEMO_GOOD` | pullback, base, breakout on 3x volume | placed; stop under the pullback low |
| `DEMO_WIDE` | deep pullback, then the same breakout | walk: stop more than 15 % below the trigger |
| `DEMO_NOSTOP` | tight base, breakout to a new high | walk: no pullback low, only the fallback stop |
| `DEMO_WEAK` | `DEMO_GOOD`'s shape, in a Weak sector | pre-screen: sector |
| `DEMO_TIE_A`, `DEMO_TIE_B` | `DEMO_GOOD`'s shape, in a Neutral sector | equal scores; the seeded tiebreak puts one above the top-4 cut and one below |

## Reading the stages

1. **Inputs**: the last four weekly closes, and this week's volume over the
   prior four weeks' average.
2. **Stage classification**: the 30-week moving average, its slope, how many of
   the last six closes sit above it, last Friday's stage and this Friday's.
   `<- Stage 1 to 2` marks a breakout.
3. **Macro gate**: the index's stage and the weighted indicators; the trend
   decides whether new longs and new shorts are allowed.
4. **Sectors and pre-screen**: each sector ETF's rating, then which stocks go on
   to full analysis (Stage 2 or 4, sector not blocking).
5. **Breakout cascade**: the buy rules in order; each stock shows the first one
   it failed.
6. **Scoring**: points per signal, total, grade.
7. **Ranking**: score first, then the tiebreak key; the line marks the top-N
   cut.
8. **Entry walk**: per name above the cut, the trigger, the initial stop and
   its distance, the size from the 1 % risk budget, cash before and after, or
   the reason it was skipped.
9. **Orders**: the stop-limit entry tickets the day produces.

## How it stays honest

`lib/friday_pipeline.ml` decides nothing. The macro gate and the screen through
the entry walk are the two calls `on_market_close` makes on a Friday, and their
outcomes are read back through the strategy's own audit recorder. The other
columns (stages, sector ratings, ranking order, stop distances) are recomputed
through the same exported functions the screen uses, on copies of the
strategy's state.

`test/test_friday_demo.ml` holds it to that. On the same fixture and the same
warmed-up state it runs the real `on_market_close` and requires the same
orders (symbol, side, shares, trigger, initial stop) and nothing else; then it
checks the display columns against the strategy's own records: per side, the
rows printed above the ranking cut are the walk's names in its order, and no
admitted name is printed below it; the stop shown for each placed name is the
one the walk installed; each analysed stock's stage columns are the ones the
screen's analysis carried; the cash left after the walk is the starting cash
less the orders' cost. It also pins that the demo config differs from the
default only in the three settings the trace marks.

## Next

A local-only CLI that builds the same trace from real bars for a chosen date,
reusing `Friday_pipeline.run` and `Friday_trace_printer.render`. Not part of
this directory yet.
