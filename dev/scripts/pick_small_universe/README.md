# pick_small_universe

One-shot selection of the committed small-universe fixture used by most
backtest scenarios. See
`dev/plans/backtest-scale-optimization-2026-04-17.md` §Step 1.

## Where the code lives

The OCaml source + dune target live inside the workspace at
`trading/backtest/scenarios/pick_small_universe/`. They sit there
rather than under `analysis/scripts/` so they can link against the
workspace-local `scenario_lib` without needing a public opam name on
the library. This directory holds only documentation so the plan's
pointer (`dev/scripts/pick_small_universe/`) stays findable.

## What the script does

1. Reads the full inventory (`data/inventory.sexp`) and sector map
   (`data/sectors.csv`) from `$TRADING_DATA_DIR` (or the canonical
   `/workspaces/trading-1/data`).
2. Applies two filters:
   - **Inventory coverage** — symbol has price bars covering at least
     the 2018-01-01 → 2023-12-31 window (configurable).
   - **Sector assigned** — skip symbols missing from `sectors.csv`.
3. Stratifies by sector: keeps up to `K` symbols per GICS sector (default
   28 — 28 × 11 ≈ 308 total) in alphabetical order.
4. Unions the stratified sample with a hand-curated list of known
   historical Weinstein cases (NVDA 2019, MSFT 2020, PYPL 2021, etc.)
   so the backtest retains breakout coverage.
5. Writes `trading/test_data/backtest_scenarios/universes/small.sexp` as
   `(Pinned ((symbol <sym>) (sector <sector>)) ...)`.

No liquidity filter in the current cut — the stratified sort is
alphabetical, not by market-cap, because inventory metadata doesn't
carry cap. A follow-up run with a cap-aware sort is tracked in
`dev/status/backtest-infra.md` §Follow-up.

## When to re-run

- Sector-map composition changes meaningfully (see follow-up #3 in
  `dev/status/backtest-infra.md`).
- Data coverage window shifts (e.g., goldens move past 2023).
- A systematic bias is discovered (e.g., all 11 sectors representable
  but stage-2 breakouts clustered in one).

The committed output is the source of truth for CI and experiments. This
script is **not** run from CI or `dune runtest` — it is invoked manually
when the human decides the fixture needs refreshing.

## How to run

```bash
dune exec trading/backtest/scenarios/pick_small_universe/pick.exe
```

Override via env vars:
- `TRADING_DATA_DIR` — where to read `inventory.sexp` + `sectors.csv` from.
- `SMALL_UNIVERSE_PER_SECTOR` — symbols kept per sector (default 28).
- `SMALL_UNIVERSE_START_DATE` / `SMALL_UNIVERSE_END_DATE` — coverage
  window filter, ISO-8601 (default `2018-01-01` → `2023-12-31`).

## Known historical cases (always included)

This set is hand-maintained. Editing the source list in `pick.ml`
requires a separate commit with justification.

- Information Technology: NVDA, MSFT, AAPL, AMD, AVGO, CRM, ORCL, ADBE
- Consumer Discretionary: AMZN, TSLA, HD, MCD, NKE
- Communication Services: META, GOOGL, NFLX, DIS, T
- Financials: JPM, V, MA, BAC, WFC, GS
- Health Care: UNH, JNJ, LLY, PFE, ABBV, TMO
- Industrials: CAT, BA, DE, UNP, UPS, HON
- Consumer Staples: WMT, PG, KO, PEP, COST
- Energy: XOM, CVX, COP, OXY
- Utilities: NEE, DUK, SO, AEP
- Real Estate: AMT, PLD, EQIX, SPG
- Materials: LIN, APD, SHW, FCX
