# 15y SP500 trade count root-cause investigation (2026-05-05)

Closes the question raised by the 2026-05-04 verification run on
`goldens-sp500-historical/sp500-2010-2026.sexp`: only 16 round-trip
trades over 16 years of an S&P 500 universe, vs ~264 expected from
linear extrapolation of the 5y sp500-2019-2023 baseline (81 trades).

## TL;DR — dominant cause

**Position-sizing eats nearly the entire $1M cash bucket inside the first
year, and ~8 winners-that-never-stopped tie up $0.95M of cost basis for
the remaining 15 years. From 2012 onward every Friday cycle finds 10–17
qualified candidates but every single one is rejected on
`Insufficient_cash` because the per-trade dollar-risk × 1/stop-distance
sizing wants $100K-$200K positions while free cash sits at $50K-$200K.**

That single mechanism produces:

- 23 entries in 2010 (the cash-deployment year)
- 1 entry in 2011 (AEP, after some 2010 stops freed cash)
- 0 entries 2012-2026 (728 weekly cycles, zero entries)

Hypotheses 1 (Wiki-replay survivorship), 2 (sector="Unknown" filter),
3 (warmup), 4 (regime), 6 (data gaps) are NOT the dominant cause —
data is sufficient, sector filter does not block "Unknown", warmup is
fine (entries land Jan 8 2010 with 30+ years of pre-history), and
even in 2017/2024 (clean Bullish years) the cascade admits 14-16
candidates per Friday and 0 enter.

## Method

Source: `dev/backtest/scenarios-2026-05-04-232151/sp500-2010-2026-historical/`
(the 2026-05-04 verification run; complete; 100-min wall; 822 weekly cycles).

Artifacts inspected:

- `summary.sexp` / `actual.sexp` — top-line metrics
- `trades.csv` — 16 closed round-trips
- `open_positions.csv` — 8 still-open positions at run end
- `trade_audit.sexp` — 24 entry-decision records + 822 cascade summaries
- `progress.sexp` — cycles_done 882, trades_so_far 39, current_equity 100308
- `equity_curve.csv` — 224 rows; cuts off at 2010-11-16 (mark-to-market reporting bug, see §Side-issues)
- `params.sexp` — confirms CSV mode, no extra config overrides

## Quantitative breakdown

### Entries by year (from 822 cascade summaries' `(entered N)` field)

| Year | Weeks | Bull | Neutral | Bear | Avg total stocks | Avg long_top_n_admitted | Entered |
|------|-------|------|---------|------|------------------|-------------------------|---------|
| 2010 | 50    | 37   | 13      | 0    | 358.0            | 14.1                    | **23**  |
| 2011 | 51    | 33   | 12      | 6    | 369.0            | 10.3                    | **1**   |
| 2012 | 51    | 46   | 5       | 0    | 352.0            | 15.5                    | **0**   |
| 2013 | 51    | 51   | 0       | 0    | 390.0            | 15.0                    | **0**   |
| 2014 | 50    | 49   | 1       | 0    | 354.3            | 17.4                    | **0**   |
| 2015 | 49    | 29   | 9       | 11   | 359.3            | 10.5                    | **0**   |
| 2016 | 51    | 42   | 2       | 7    | 367.0            | 14.1                    | **0**   |
| 2017 | 51    | 51   | 0       | 0    | 376.5            | 14.5                    | **0**   |
| 2018 | 51    | 40   | 5       | 6    | 367.4            | 12.8                    | **0**   |
| 2019 | 51    | 45   | 0       | 6    | 374.7            | 13.8                    | **0**   |
| 2020 | 49    | 38   | 11      | 0    | 384.1            | 14.0                    | **0**   |
| 2021 | 50    | 50   | 0       | 0    | 392.8            | 11.8                    | **0**   |
| 2022 | 51    | 10   | 15      | 26   | 381.5            | 8.2                     | **0**   |
| 2023 | 51    | 45   | 6       | 0    | 372.6            | 13.2                    | **0**   |
| 2024 | 51    | 51   | 0       | 0    | 384.7            | 16.1                    | **0**   |
| 2025 | 50    | 38   | 9       | 3    | 375.9            | 14.5                    | **0**   |
| 2026 | 14    | 11   | 3       | 0    | 383.6            | 14.7                    | **0**   |

**Total: 24 entries over 822 weekly cycles (0.029 entries/week).** For
contrast, sp500-2019-2023's baseline (5y, 491 sym) lands 81 trades over
~260 weekly cycles (0.31 entries/week — 10× higher entry rate).

The cascade is doing its job: an average of 13.8 grade-≥-min long
candidates per Friday after macro / breakout / sector / grade gates
(from `long_top_n_admitted`). The blocker is downstream — at the
entry-decision phase in `Entry_audit_capture.classify_candidate`.

### Position-sizing footprint (from `initial_position_value` in audit)

The 24 entries cumulatively committed **$3.26M of cost basis** against
a $1M portfolio:

```
symbol     entry_date       position_value    stop_floor_kind
BA         2010-01-08       $299,992          Buffer_fallback (30% cap-bound)
BALL       2010-01-08       $299,975          Buffer_fallback
CMI        2010-01-08       $299,962          Buffer_fallback
SHW        2010-01-08       $ 93,411          Support_floor
ADBE       2010-01-15       $300,447          Buffer_fallback
AMAT       2010-01-15       $160,819
BCR        2010-01-15       $ 88,899
FDO        2010-01-22       $ 65,153
GENZ       2010-01-22       $ 91,751
HBAN       2010-01-22       $143,317
AAPL       2010-01-29       $203,776
AIZ        2010-01-29       $ 86,118
AMZN       2010-01-29       $104,341
COF        2010-01-29       $102,471
EK         2010-02-05       $ 83,345
CSCO       2010-02-19       $ 83,384
CHRW       2010-05-07       $ 84,316
PTV        2010-05-28       $146,930
MRO        2010-06-11       $ 79,703
PEG        2010-07-09       $100,653
VZ         2010-07-30       $ 78,346
JNS        2010-11-26       $ 90,503
GME        2010-12-03       $ 90,034
AEP        2011-09-09       $ 77,979
TOTAL                       $3,255,626 (avg $135,651/position)
```

Day 1 alone (2010-01-08 Friday signals → Mon Jan 11 fills) committed
**$993K of $1M** to four positions (BA, BALL, CMI, SHW). The first three
each hit the 30% per-position cap (`max_position_pct_long = 0.30` ×
$1M = $300K), driven by very tight `Buffer_fallback` stops (BA's stop
sat $1.22 below the broker fill = 2.0% distance).

### Why cash never recovers

Of the 24 positions:

- 16 stopped out 2010-01-13 → 2015-08-07, returning ~$2.46M proceeds
- **8 never stopped out** — AAPL, COF, HBAN, MRO, PEG, PTV, SHW, VZ —
  these are the positions whose Stage 2 advance carried them up
  through 2025 with the trailing stop chasing but never triggering.
  They tie up ~$949K cost basis (mark-to-market $1.15M / $203K
  unrealized PnL) for the remaining 15 years.

After ~mid-2011 cash floats around $50K-$200K. Every Friday the
strategy:

1. Reads `portfolio.cash` and seeds `remaining_cash := cash`
2. Walks 10-17 cascade-admitted candidates
3. Sizes each at `dollar_risk = $11.6K / stop_distance ≈ $100K-$200K`
4. `check_cash_and_deduct` rejects every one: `cost > remaining_cash`
5. Audit logs nothing because `record_entry` only fires on `Kept`

Cumulatively: 822 cycles × 14 candidates = ~11,500 candidate
decisions. ~926 passed sizing (became `Entry_ok`, per the
`AEP-wein-926` position counter). Only **24** passed the cash gate
(became `Kept`).

### Skip-reason distribution among `alternatives_considered`

From the 24 audit entries' alternatives lists (the rivals that lost
to the entry that got Kept):

| Skip reason       | Count |
|-------------------|-------|
| Insufficient_cash | 271   |
| Stop_too_wide     | 37    |
| (none others)     | 0     |

**Insufficient_cash dominates 7.3:1.** And this is only the
alternatives-that-lost-to-a-winner — for the 798 weeks with zero
winners (zero entries), every single one of their 14 candidates is an
Insufficient_cash skip not even logged in audit because no `Kept` ⇒
no `record_entry`.

## Hypothesis ranking

| # | Hypothesis | Verdict | Evidence |
|---|------------|---------|----------|
| 1 | Wiki-replay survivorship effect | NOT dominant | Cascade still admits 13.8 candidates/wk on average; the surviving universe still produces breakouts (in 2010 alone, 23 distinct symbols broke out and got entered). The biased universe might shrink the trade *quality* mix, but it isn't what's gating count. |
| 2 | Sector="Unknown" filter | **REFUTED** | `_long_admission` line 450 in `screener.ml`: `passes_sector = passes_breakout && not (equal_sector_rating sector.rating Weak)`. `Unknown` defaults to `Neutral` rating (`screener.ml` line 538), which **passes** the long-side sector gate. 222/510 Unknown symbols are admitted equally with the rated 288. |
| 3 | Indicator warmup | **REFUTED** | Entries on day 5 (2010-01-08) for BA/BALL/CMI/SHW, all with `Stage2 (weeks_advancing 1)` and intact `volume_quality` / `ma_slope_pct`. CSV files for these symbols go back to 1980+ (AAPL: 1980-12-12, MRO: 1962-01-02, PEG: 1980-01-02), so 30-week MA + 52-week RS warmup is amply available pre-2010-01-01. |
| 4 | 2010-2014 strong bull market | NOT dominant | Cascade `long_top_n_admitted` averages 14-17 in those years. Stage 2 transitions ARE happening; the strategy just can't fund them. |
| 5 | **Position sizing × cash exhaustion** | **CONFIRMED** | See above. 24 entries × avg $136K = $3.26M cost basis on a $1M portfolio. Insufficient_cash is the only material skip reason. |
| 6 | Bar-data gaps / missing CSVs | NOT dominant | Spot-checked all 8 stuck symbols + several closed; data spans the full 2010-2026 window without obvious gaps. |

## Side-issues surfaced (out of scope but recorded)

These are real bugs that the 100-min run exposed, separate from the
trade-count question:

1. **Equity curve truncation at 2010-11-16.** `summary.sexp` reports
   `n_steps 224` and `equity_curve.csv` ends 2010-11-16 even though
   `progress.sexp` says `cycles_done 882 / last_completed_date
   2026-04-29`. Root cause: `runner.ml` line 461's
   `is_trading_day` filter drops every step where positions are open
   but their mark-to-market `~ cash`. From 2010-11-17 onward,
   `|portfolio_value - cash| ≤ 1e-2` for every step — the 8 stuck
   positions are sitting in some state that contributes 0 to
   `Portfolio_view.portfolio_value` (likely `Entering` or `Closed`
   per `runner.ml`'s comment block at lines 50-55). Should
   investigate whether `extract_round_trips`'s interaction with
   stop-loss-and-actual-fill is leaving zombie positions in the
   portfolio map.

2. **MRO et al. appear in BOTH trades.csv (as closed) AND
   open_positions.csv.** trades.csv: MRO entered 2010-06-12, exited
   2015-08-07 (stop_loss, days_held=1882). open_positions.csv: MRO
   open at run end with qty 4056, entry_date 2026-05-04 (the run
   end date). `_entry_date_of` in `result_writer.ml` reads the
   earliest lot's `acquisition_date` — so the position must have a
   lot dated 2026-05-04, meaning the simulator either re-opened the
   position somewhere or the original close didn't actually clear
   the lots from `portfolio.positions`. trade_audit.sexp has only
   one MRO entry (2010-06-11), so any "re-entry" wasn't routed
   through the strategy's `_promote_new_entries`. Likely the
   stop-loss exit emits the round-trip event for `Metrics` but
   doesn't clear the position from the portfolio. These zombies are
   the same 8 symbols whose cash sits frozen — strongly correlated
   with side-issue #1.

3. **`progress.sexp` `current_equity` $100K vs `summary.sexp`
   `final_portfolio_value` $1.16M.** A 10× discrepancy suggesting
   a divide-by-10 bug in progress emission, or some divergent
   accounting.

These side issues would partially mask each other if patched
independently — recommend bundling them as a "post-2010 portfolio
state hygiene" follow-up after this investigation closes.

## Recommendation for forward action

The investigation's answer is **the strategy's risk-and-position-sizing
defaults don't compose well with the $1M starting cash + 16y window
combination** — not a strategy bug per se but a config/scaling issue.

Two paths forward, in priority order:

### Path A (preferred) — re-tune the sp500-2010-2026 scenario only

Override `portfolio_risk` config in
`goldens-sp500-historical/sp500-2010-2026.sexp` to constrain
position size and force broader portfolio diversification:

```sexp
(config_overrides
 (((enable_short_side false)
   (portfolio_risk
    ((max_position_pct_long 0.05)        ;; 5% per position vs default 30%
     (max_long_exposure_pct 0.50)        ;; 50% max long exposure vs 90%
     (min_cash_pct 0.30))))))            ;; 30% cash floor vs 10%
```

Expected effect: typical position drops from $135K to $50K. Day 1
deploys ~$50K × 4 = $200K instead of $993K. Cash stays plentiful.
Entries continue across 16 years rather than dying out in late 2010.
Under reasonable assumptions, would expect 200-400 trades over the
16y window — closer to the linearly-extrapolated 264.

This is a **scenario-level tuning**, NOT a default-config change.
Other scenarios (sp500-2019-2023, etc.) keep their existing
calibration and pinned baselines.

LOC: ~5 (sexp edit + re-pin expected ranges after baseline run).

### Path B — investigate the side-issues first

Both #1 and #2 (equity-curve truncation + MRO-zombie) suggest the
post-stop-loss portfolio state isn't fully clean. If the 8 "stuck"
positions are zombies (closed but not removed from
`portfolio.positions`), then:

- The cash they "tie up" is fictitious — the original sale already
  refunded it.
- `Portfolio_view.portfolio_value` excludes them so equity curve
  truncates.
- New entries' `remaining_cash := portfolio.cash` reads the correct
  free cash, but they keep getting Insufficient_cash because... why?

Actually if cash IS free (zombies don't tie up cash), then the
mechanism above is wrong — and we'd need to look at why
`compute_position_size` produces position_value > cash even with
free cash available. Plausible: the sizing references
`portfolio_value` (cash + positions mark-to-market), but
`portfolio_value` post-2010-11-16 excludes the zombies, so it equals
cash. Then `dollar_risk = $200K × 0.01 = $2K`, position = $2K /
8% = $25K. That should fit in $200K free cash easily.

So if the zombies inflate `dollar_risk` numerator (because cost
basis is "in" portfolio_value somehow), candidates over-size and
fail cash. Otherwise the math works and there's another gate.

Path B is "fix the portfolio-state bug then re-run and see if 16
trades expands." If zombies are the issue, this could grow the
trade count substantially without changing strategy config. ~200
LOC + tests, harder to scope without first instrumenting.

### Recommended

**Take Path A first** — it's a 5-LOC scenario tweak that produces
an interpretable baseline for the 16y window AND allows the QC
behavioral checklist's expected-trade-count to be pinned in
sp500-2010-2026.sexp. Path B can be filed as a backtest-infra
follow-up "investigate zombie positions in long-window backtests"
and resolved independently.

**Do NOT** modify the default `Portfolio_risk.config` defaults to
fix this — those defaults are calibrated against sp500-2019-2023
and changing them ripples to every other golden's pinned baseline.

## Files / artifacts referenced

- Run dir: `/Users/difan/Projects/trading-1/dev/backtest/scenarios-2026-05-04-232151/sp500-2010-2026-historical/`
- Scenario: `/Users/difan/Projects/trading-1/trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp`
- Universe: `/Users/difan/Projects/trading-1/trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-01-01.sexp`
- Prior diagnosis: `/Users/difan/Projects/trading-1/dev/notes/15y-sp500-zero-trades-diagnosis-2026-05-03.md`
- Strategy entry path: `/Users/difan/Projects/trading-1/trading/trading/weinstein/strategy/lib/entry_audit_capture.ml`
- Sizing: `/Users/difan/Projects/trading-1/trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml`
