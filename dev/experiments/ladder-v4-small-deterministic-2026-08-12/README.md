# Ladder-v4 at 500/5y on the determinism-fixed build — 2026-08-12

All 24 ladder-v4 cells re-run on the PR #2279 build (deterministic intraday
paths) at a scale that is cheap enough to repeat: the ~500-symbol `sp500`
universe over 2019-2023, against CI's committed bar data
(`TRADING_DATA_DIR=trading/test_data`), ~4 min a cell.

Purpose: an independent, *reproducible* read on the ladder-v4 rankings, whose
26y source run was produced on the pre-fix nondeterministic build with a
measured ~278pp noise floor (`dev/notes/ladder-v4-read-2026-08-12.md`).

- `specs/` — the 24 cells, retargeted from the committed 26y specs by changing
  only the period, universe path, universe size, and name.
- `results.txt` — the table.

Headline: cell 09 `nearfloor` and cell 01 `anchor-w8` **reverse sign** against
the 26y ranking; cell 10 `volconf` stays catastrophic with the same mechanism
signature. Cells 07 and 08 come out byte-identical, as they must — they are one
configuration spelled two ways, which is what made them a free null probe at
26y.

Scale caveat: a different universe and regime. This does not prove nearfloor
fails at 26y; it is a second independent reason not to trust the 26y ranking.
