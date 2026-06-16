# README top-line results — plan (2026-06-16)

## Goal

A reusable OCaml module + bin that computes four top-line numbers over one
pinned full-history testing period and writes them into a comment-delimited
block in the repo-root `README.md`, idempotently regenerable.

## The four numbers (one common pinned period)

1. **Pinned testing period** — `[latest-first-bar across instruments,
   earliest-last-bar across instruments]`, derived from actual CSV coverage.
2. **SPY (and BRK-B) buy-and-hold total return** over the period
   (dividend-adjusted close — the CSV has an `adjusted_close` column).
3. **SPY-only Weinstein return** — `Spy_only_weinstein` strategy on SPY alone.
4. **Sector-ETF-only Weinstein return** — `Sector_rotation_weinstein` (k=3,
   30-week investor MA) on the SPDR sector-ETF universe.

## Data coverage (audited 2026-06-16, `data/` CSV store)

| symbol | first | last |
|---|---|---|
| SPY | 1993-01-29 | 2026-06-12 |
| BRK-B | 1996-05-09 | 2026-06-12 |
| XLK/XLF/XLE/XLV/XLI/XLY/XLP/XLU/XLB | 1998-12-22 | 2026-06-12 |
| XLRE | 2015-10-08 | 2026-06-12 |
| XLC | 2018-06-19 | 2026-06-12 |

The 9 original SPDR sector ETFs all start **1998-12-22**, which is the binding
first-bar. XLRE (2015) and XLC (2018) start far later — including them in the
period-intersection would collapse the window to 2018. They are **excluded
from the period-defining instrument set**, but still passed to the sector
runner's universe (the runner skips a symbol on dates before its first bar via
`Daily_price.active_through`, so the late ETFs simply join mid-run — faithful
to how the production runner treats staggered inception).

So the **period-defining instruments** are: SPY, BRK-B, and the 9 original
sector ETFs → pinned period `[1998-12-22, 2026-06-12]` (clipped to actual
trading days by the readers). No fetch needed; full coverage exists.

## Architecture — reuse, don't reinvent

Surface: new `trading/trading/backtest/readme_toplines/{lib,bin}/`.

- **`Coverage`** (pure): `period_intersection`, `total_return_pct`,
  `bah_total_return_pct` (from a `(date, adj_close)` series). Unit-tested.
- **`Readme_block`** (pure): replace text between
  `<!-- toplines:start -->` / `<!-- toplines:end -->` markers; append the
  block if absent. Unit-tested.
- **`Toplines_runner`**: reads coverage + close series via
  `Csv_storage.get`; runs the two Weinstein backtests via
  `Backtest.Runner.run_backtest` (CSV mode, no snapshot needed for these tiny
  universes); reads total return from `Summary`
  (`(final - initial)/initial*100`) and CAGR via
  `Walk_forward.Walk_forward_runner.cagr_pct`. BAH CAGR via
  `Rolling_start.Rolling_start_runner.bah_cagr_pct`.
- **bin `readme_toplines`**: CLI (`--readme <path>`, `--check`,
  `--data-dir <dir>` optional), orchestrates, renders the block, writes README.

## Return math conventions

- **Total return %** = `(final - initial) / initial * 100`.
- **CAGR %/yr** = `cagr_pct ~test_days ~total_return_pct` (calendar days
  inclusive, 365.25/yr) — the same convention the walk-forward + rolling-start
  runners use, so all four rows are directly comparable.
- BAH return uses **adjusted_close** (dividend-adjusted) — labelled as such.

## Idempotent README block

Comment-delimited:
```
<!-- toplines:start -->
... generated table ...
<!-- toplines:end -->
```
Regeneration replaces only the inner text; everything else in README untouched.

## Tests (TDD, pure pieces)

- `Coverage`: intersection of staggered ranges; empty/degenerate; total-return
  math; BAH from a known close series.
- `Readme_block`: insert-when-absent; replace-when-present; idempotency
  (render twice = same output); content outside markers preserved.

The two backtest numbers are data-gated (need the CSV store) so they are
exercised by the bin, not the unit tests.

## Run command (documented in README block footer)

```
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune exec trading/backtest/readme_toplines/bin/readme_toplines.exe -- \
     --readme /workspaces/trading-1/README.md'
```

## Out of scope

Per-strategy tuning, sector-cap dials, robustness grid — this is a reporting
artefact, not a strategy change. No `Weinstein_strategy` edits.
