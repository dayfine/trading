# T2-A: Golden Scenario Test Suite — Screener

**Status:** Blocked — see dependency below
**Target file:** `trading/analysis/weinstein/screener/test/regression_test.ml`
**Trigger:** Screener merged to main (done). Stop state machine scenarios deferred until order_gen merges.

**Dependency:** `docs/design/eng-design-data-management.md` must land first (assigned to
`feat-data-layer`). Specifically: `Data_path.default_data_dir` (§1) and
`data/inventory.json` (§2). Once those are on main, this file can be assigned to
`feat-screener` for implementation.

**Assigned to:** `feat-screener` (implement the test file once data-management prework lands)

---

## Purpose

Golden scenarios are data-driven regression tests with fixed historical inputs and
asserted known-correct outputs. They run as part of `dune runtest` and serve as
behavioral unit tests for the domain logic — making the Weinstein rules executable
and verifiable. Any future change to screener, stage, RS, macro, or sector logic
that breaks these tests must be an intentional change, not an accidental regression.

---

## Data source

Real EODHD historical data lives in `data/` (at repo root:
`/Users/difan/Projects/trading-1/data/`). Organized as:

```
data/<first-letter>/<second-letter>/<SYMBOL>/data.csv
data/<first-letter>/<second-letter>/<SYMBOL>/data.metadata.sexp
```

Example: `data/A/L/AAPL/data.csv` — daily OHLCV from 1980-12-12 to 2025-05-16,
11,199 rows. Format: `date,open,high,low,close,adjusted_close,volume`.

Load via `Historical_source` (from `analysis/weinstein/data_source/`):
```ocaml
let source = Historical_source.create ~data_dir:(Fpath.v "<relative-path-to-data>") in
let bars = Historical_source.get_bars source ~symbol:"AAPL"
             ~start_date:(Date.of_string "2022-01-01")
             ~end_date:(Date.of_string "2022-12-31")
```

**Data path:** use `Data_path.default_data_dir ()` from
`analysis/weinstein/data_source/lib/data_path.ml` (see `eng-design-data-management.md`).
Do not hardcode a relative path.

---

## Weekly resampling

All Weinstein analysis modules expect **weekly bars**. Use the existing
`Conversion.daily_to_weekly` from `analysis/technical/indicators/time_period/`:

```ocaml
let weekly = Conversion.daily_to_weekly ~include_partial_week:false daily_bars
```

Add `weinstein.time_period` (or the correct library name from its dune stanza)
to the test's library dependencies. Do not write a custom resampling helper.

---

## Scenarios to implement

### Scenario 1: AAPL Stage 2 — 2023 Bull Run

AAPL had a strong uptrend in 2023 (price rose ~50%). By end of 2023 the 30-week
MA was clearly rising and price was consistently above it.

```
Input:  AAPL daily bars 2021-01-01 to 2023-12-31 → resample to weekly
        (need 2+ years of history for 30-week MA warmup)
Call:   Stage.classify ~config:Stage.default_config ~bars:weekly_bars ~prior_stage:None
Assert at 2023-12-29 (last Friday of 2023):
  - stage matches Stage2 { ... }
  - result.ma_direction = Rising
```

### Scenario 2: AAPL Stage 4 — 2022 Bear Market

AAPL fell ~30% peak-to-trough in 2022. The 30-week MA turned declining by mid-2022.

```
Input:  AAPL daily bars 2020-01-01 to 2022-12-31 → resample to weekly
Call:   Stage.classify at 2022-10-14 (near the trough)
Assert:
  - stage matches Stage4 { ... }
  - result.ma_direction = Declining
```

Note: `Stage.classify` takes all bars up to the reference date. Load bars up to
that date and pass them all; the classifier uses the full series for the MA.

### Scenario 3: Macro gate blocks all buy candidates

When macro is Bearish, `Screener.screen` must return zero buy candidates regardless
of individual stock quality. Construct `Macro.result` directly (it is a pure record)
rather than loading real macro data — this is simpler and more deterministic:

```ocaml
let bearish_macro : Macro.result = {
  index_stage = { stage = Weinstein_types.Stage4 { weeks_declining = 5 }; ... };
  trend = Bearish;
  confidence = 0.2;
  ...
}
```

Then run the screener with this macro result and any stock candidates.
Assert: `result.buy_candidates = []`.

### Scenario 4: Stage 2 stock is a buy candidate

Load AAPL weekly bars for Jan–Jun 2023 (clear Stage 2). Run `Stock_analysis.analyze`
with default config. Assert:
- `breakout_candidate = true` OR grade is A/B
- `stage_result.stage` matches Stage2

### Scenario 5: RS trend — stock weaker than benchmark

Construct two price series: a stock that underperforms its benchmark over the RS
lookback period. Run `Rs.classify`. Assert `rs_trend` is `Bearish` or
`Weakening_bearish`.

This can be done with synthetic data (hand-craft two float lists) rather than
loading from files — simpler for a controlled assertion.

### Scenario 6: AAPL pre-COVID peak — 2019-11-29

AAPL was in a strong Stage 2 advance into late 2019 (price had doubled from
early 2019 lows). This tests a different bull market regime from 2023.

```
Input:  AAPL daily bars 2017-01-01 to 2019-11-29 → resample to weekly
Assert at 2019-11-29:
  - stage matches Stage2 { ... }
  - result.ma_direction = Rising
```

### Scenario 7: AAPL COVID crash — 2020-03-20

AAPL fell ~35% in five weeks (Feb–Mar 2020). This tests rapid Stage 4 onset.

```
Input:  AAPL daily bars 2018-01-01 to 2020-03-20 → resample to weekly
Assert at 2020-03-20 (near crash trough):
  - stage matches Stage4 { ... } OR Stage3 { ... }
  - result.ma_direction = Declining
```

Note: the exact stage may be Stage3 or Stage4 depending on how many weeks the
MA has been declining at that date — accept either. Use `matching` with an
`any_of` if needed.

### Scenario 8: AAPL AI-era bull — 2024-06-28

AAPL participated in the AI-driven tech rally of 2024. Tests a third distinct
bull period with a different MA history.

```
Input:  AAPL daily bars 2022-01-01 to 2024-06-28 → resample to weekly
Assert at 2024-06-28:
  - stage matches Stage2 { ... }
  - result.ma_direction = Rising
```

---

## Test file structure

```
trading/analysis/weinstein/screener/test/
  dune                 ← add regression_test to libraries + test stanzas
  regression_test.ml   ← new file
```

Add to `dune`:
```dune
(test
 (name regression_test)
 (libraries
   weinstein.stage weinstein.rs weinstein.macro weinstein.screener
   weinstein.data_source weinstein.stock_analysis
   trading_base matchers core))
```

---

## Implementation notes

- Use `assert_that` + `matching` for variant assertions:
  ```ocaml
  assert_that result.stage
    (matching ~msg:"Expected Stage2" (function Stage2 x -> Some x | _ -> None)
      (field (fun s -> s.weeks_advancing) (gt (module Int_ord) 0)))
  ```
- Pin all dates — never use `Date.today`
- Keep the `to_weekly_bars` helper and `load_aapl` convenience function at the
  top of the file so scenarios are concise
- Each scenario: one `let () = ...` block with a descriptive label
- The data path must work from inside Docker
  (`/workspaces/trading-1/trading/` is the dune root)

---

## Macro data requirements

`Macro.analyze` takes three inputs beyond the primary index bars:

- **`index_bars`** — weekly price bars for SPX or DJI. These are EODHD ticker
  symbols (e.g. `GSPC.INDX`). They would live in `data/` if fetched, but are not
  currently cached. For regression tests, **construct `Macro.result` directly**
  (it is a plain record) rather than loading real index data — this avoids a
  data fetch dependency.

- **`ad_bars`** — NYSE advancing/declining issue counts per day. This is breadth
  data, not derivable from price bars of any index or its constituents. EODHD
  provides it as separate tickers (`ADV.NYSE`, `DEC.NYSE`). Not currently cached.
  Pass `ad_bars:[]` in regression tests — the analyzer degrades gracefully.

- **`global_index_bars`** — weekly bars for other major indices (FTSE, DAX, NK225).
  Also EODHD tickers, not currently cached. Pass `global_index_bars:[]`.

**Conclusion for regression tests**: construct `Macro.result` directly for all
macro-gated scenarios (Scenario 3). This is deterministic and avoids any data
pipeline dependency. Real macro computation from live data is an integration
concern, not a unit regression concern.

**Longer-term**: fetching and caching index + A-D data is a data-layer task.
Once cached, a separate macro regression test suite can run `Macro.analyze`
against real historical index bars. Track this as a follow-up once the data
pipeline is extended.

---

## Agent decisions

1. **Weekly resampling**: use `Conversion.daily_to_weekly ~include_partial_week:false`
2. **Data path**: copy pattern from `test_historical_source.ml` (uses explicit `data_dir` string)
3. **Macro scenario**: construct `Macro.result` directly — see macro.mli for the record fields
4. **Stock_analysis scenario**: check if `Stock_analysis.analyze` needs full sector/RS/volume inputs or has optional parameters
5. **Scenarios 7 (COVID)**: accept Stage3 or Stage4 — use `any_of` matcher if needed
