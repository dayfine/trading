# Split detector: dividends and stale adjusted closes read as splits (#3104)

Date: 2026-10-03. Issue: #3104. Code: `trading/analysis/data/types/lib/split_detector.ml`.

## What the detector does

`split_factor = adj_ratio / raw_ratio` between consecutive bars. The day is a
candidate when `|factor - 1| > 0.05`, and the factor is then snapped to any
`N/M` with `M <= 20` within 1e-3. Rationals near 1 with `M <= 20` are dense
(17/16, 18/17, 19/18, 20/19, 21/20 ...), so any ~5-10 % jump in the
adjusted/raw ratio has a good chance of snapping. A detected split rescales a
held position's quantity and price (`Split_handler`) and its stop
(`Stops_split_runner`).

## Measurement

**Surface.** Every symbol in the 27 PIT top-3000 vintages
(`trading/test_data/backtest_scenarios/pit-v11/composition/top-3000-{1999..2025}.sexp`,
9,900 unique symbols; 548 had no bar file). Bars from the bar store
`data/<first>/<last>/<SYM>/data.csv`. Each consecutive bar pair was run
through the default detector, re-implemented in awk to match
`split_detector.ml` exactly (same band, same `M <= 20` snap at 1e-3,
smallest-denominator match). An event counts only when its date falls in a
year the symbol was a member (vintage `Y` covers `Y-05-31` to
`(Y+1)-05-31`). That gives 4,416 in-membership events (23,995 over all
dates).

**Raw-gap confirmation.** For a snapped factor `f`, the raw-gap share is
`log(1 / raw_ratio) / log f`: the part of the factor's log-size that the raw
close actually moved. A real split moves the raw close by about `1/f`, so
the share is near 1.0, give or take the day's economic move. A
dividend-driven jump in `adjusted_close` leaves the raw close flat or moving
the wrong way, so the share is near 0 or negative. The test is
`share >= 0.5`, meaning the raw gap carries at least half the factor. This
was chosen over the `|raw_ratio * f - 1| < 0.03` form proposed in the issue.
That form is algebraically `|adj_ratio - 1| < 0.03`, a cap on the day's
economic move, so it fails real splits on volatile days: only 62 % of the
`>= 0.25` band passes it. The share is scale-free. The cut is not sensitive
in the `>= 0.25` band: 2,063 / 2,058 / 2,039 of 2,330 survive at
0.25 / 0.5 / 0.75.

| `\|f - 1\|` band | events | symbols | raw gap confirms (share >= 0.5) | share < 0 (raw moved the wrong way) | `adj_ratio` exactly 1.0 (adjusted close frozen) | share p10 / p25 / p50 / p75 / p90 |
|---|---:|---:|---:|---:|---:|---|
| 0.05-0.10 | 1,666 | 373 | 1,355 (81 %) | 86 (5 %) | 910 (55 %) | 0 / 0.80 / 1.00 / 1.01 / 1.18 |
| 0.10-0.25 | 420 | 166 | 332 (79 %) | 31 (7 %) | 195 (46 %) | 0 / 0.77 / 1.00 / 1.00 / 1.08 |
| >= 0.25 | 2,330 | 1,425 | 2,058 (88 %) | 143 (6 %) | 42 (2 %) | 0.06 / 0.95 / 1.00 / 1.02 / 1.05 |

Issue's `[merge]` count: 2,086 in-membership events with `|f - 1| < 0.25`.
1,687 have a raw gap consistent with the factor (share >= 0.5). 399 do not.

## What the bands contain

- **0.05-0.10: almost none are share-count changes.**
  - 55 % (910) have `adjusted_close` exactly unchanged while the raw close
    moved 5-10 %. The adjusted series is frozen and the "factor" is just the
    raw move snapped to a rational (BAS, DRYS, DPM, LJPC, MOSY ...). The
    raw-gap check cannot catch these because the raw close did move.
  - The rest are ADR dividends (FUJIY: 11 events 2012-2023, 7 of them in membership;
    DHLGY: 5, 2 in membership),
    spin-off adjustments (BMY 2001-08-07, Zimmer), and a few genuine 5 %
    stock dividends (ONB 2001-01-05, CHT).
  - The issue's two specimens: **FUJIY 2020-09-28** (share −0.35, raw +2 %)
    fails the raw-gap check. **DHLGY 2025-05-06** (share 0.78, raw −3.7 %
    for a ~4.9 % dividend) passes it. Only the band can reject DHLGY.
- **0.10-0.25:** a similar mixture, with real 11:10 and 6:5 stock dividends
  more common. 46 % are frozen-adjusted days. The unconfirmed cases are
  adjusted-only jumps such as ADXS 2019-12-06 (raw flat, adjusted +21.5 %),
  ESRX 2002-02-12 and QVCGA 2020-08-28.
- **>= 0.25: real splits.** The share median is 1.00 and the p25 is 0.95.
  The 12 % unconfirmed (272) are mostly days where the adjusted series steps
  by the split factor but the raw close does not (AABA/PMCS 2000-02-14,
  KKD 2001-06-15, ERT 2003-05-30): a day misalignment between the raw and
  adjusted series. Rescaling a position there doubles its marked value,
  because the simulator marks on raw closes and the raw close did not halve.
  Rejecting those is correct for a raw-price simulator.

## Rule shipped (default off)

`Split_detector.detect_split ?raw_confirm_min_share` is a new optional
argument. Omitted means no check, and every existing caller is unchanged.
The recommended "rule on" is:

```
detect_split ~dividend_threshold:0.10 ~raw_confirm_min_share:0.5
```

- `raw_confirm_min_share:0.5` rejects adjusted-only jumps: FUJIY, the
  `>= 0.25` misalignments, ADXS-type cases.
- `dividend_threshold:0.10` (an existing argument) rejects the 0.05-0.10
  band: DHLGY-type ADR dividends, spin-offs and frozen-adjusted noise. Cost:
  genuine 5 % stock dividends go undetected, which is a <= 10 % quantity
  undercount in the conservative direction.

Over the 26y PIT surface, the rule keeps 2,390 of 4,416 in-membership events.
It drops all 1,666 in the 0.05-0.10 band, 88 in 0.10-0.25 and 272 in
`>= 0.25`.

No config record carries detector parameters today. The three callers
(`Split_handler`, `Stops_split_runner`, the split-corpus test) call
`detect_split ~prev ~curr ()`, so the rule is a default argument plus this
recommended pair, not a config field.

## Not fixed here

- **Frozen adjusted close in the 0.10-0.25 band** (195 events). These pass
  both checks when the raw move happens to snap. A guard such as "reject when
  `adj_ratio` is exactly 1.0 and the snapped factor's denominator is large"
  would need its own measurement: the stylised fixtures, and some genuine
  split days, have a flat adjusted close.
- **Default flip.** This needs a paired golden run under
  `.claude/rules/config-default-blast-radius.md`. Every golden whose window
  holds a position through any of the affected events changes, so the
  detector default is effectively an AFFECTS-ALL knob.
