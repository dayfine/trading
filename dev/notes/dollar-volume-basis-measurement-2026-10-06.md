# Dollar volume on one basis: what it would move (#3136, 2026-10-06)

Issue #3136: the bar store's `volume` is restated for later splits while
`close` is raw, so `close * volume` (the PIT top-N ranking and the strategy's
liquidity gates) is off by the cumulative split factor after the bar. Decided
basis (plan `total-return-and-shorts-phase-b-2026-10-05.md`, decision 5):
**true dollars traded = raw close x raw volume**. This note measures what that
basis would change before any rebuild. **No committed list, golden or default
was changed.**

## How to reproduce

```sh
dune build analysis/data/universe/bin/dollar_volume_measurement.exe
./_build/default/analysis/data/universe/bin/dollar_volume_measurement.exe \
  --bars-root /workspaces/trading-1/data \
  --symbol-types /workspaces/trading-1/data/symbol_types.sexp \
  --lists-dir test_data/goldens-custom-universe/composition \
  --out-report <report.md> --out-rejected <rejected.csv>
```

About 8 minutes on the container, read-only on the store and the lists. The
tables under "Generated report" are its output, verbatim. The rejected-bars
list is `dollar-volume-basis-rejected-bars-2026-10-06.csv`.

The new lists themselves come from the existing runner with the new flag,
which refuses to write into the committed composition directory:

```sh
build_composition_universes_runner.exe ... --true-dollar-volume --out-dir <new dir>
```

## The basis, and checking its direction on the store

True dollar volume on day t = `close_t * volume_t / F(t)`, where `F(t)` is the
product of the factors (new/old shares, `splits.csv`) of the splits dated
**after** t. The split day itself already trades on the new share count, so
its own factor is not in `F`:

- AMZN 2022-06-06 (20:1): 2022-06-03 close 2447.00 x 97.6M stored, then
  2022-06-06 close 124.79 x 135.3M stored. The close jumps by the factor and
  the stored volume does not, so the volume is restated and the split day is
  already on the post-split count.
- C 2011-05-09 (1:10): 2011-05-06 close 4.52 x 5.1M, then 2011-05-09 close
  44.16 x 49.2M. Same picture.
- Specimens (first table below): AMZN 2018-06-14 stored/true = **20.000**, C
  2010-06-14 = **0.100**, exactly the issue's 20x and 1/10.

`F` uses only splits the store's own prices confirm:

1. **The raw close must show the split.** Across the bar on or nearest after the
   vendor date (searching up to 2 bars either side, nearest first), the close
   moves by the factor (within 0.2 in log). The applied split is re-dated to
   that bar. 4,939 of 13,427 vendor splits fail. Most are splits before the
   symbol's first bar, which scale nothing. The rest are on series whose
   `close` is already split-adjusted (FHCC, JOY 2005, many delisted shells), or
   are vendor events the price never shows (RTN 2001-05-14 "0.05"). Dividing
   those by `F` would be wrong, because `close * volume` is already true dollars
   there.
2. **The stored volume must be restated for it.** For splits of 3:1 or more
   either way, the median volume of the 10 bars before is compared with the 10
   bars from the split on. If it jumps by at least half the factor in log terms,
   the volume is raw and the split is dropped from `F` (371 splits). Specimen:
   OHGI's 1:1500 reverse split in 2006, where volume falls from 187M to 55k
   shares. Before this rule, OHGI ranked #3 in 2004 at $24B a day. For smaller
   factors the check is noise (ordinary volume moves are as large as a 2:1
   factor; the histogram has no bump near 1), so they are assumed restated.
3. A symbol with **no `splits.csv`** (8 of 11,859) is scored with `F = 1` and
   counted.

**Implausible bars:** any bar whose true dollar volume is not finite, is
negative, or is above **$200B in one day** is rejected. That cap is about twice
the largest real US single-stock day (NVDA, March 2024, about $100B). The
rejected bars drop out of the window average and are listed. 702 bars across 11
symbols were rejected, among them the issue's VEXPQ ($31T a day) and OCHTQ
($3.7T a day). COMP_old has no bars in the current store; its directory is
empty.

## Headline: PIT membership change per vintage

`L` is the list rebuilt from today's store on the stored basis, `T` the list on
the true basis, and `C` the committed list. "basis" = |L\T| / N, which isolates
the fix. "vs committed" = |C\T| / |C|, the basis effect plus store and candidate-set drift (see below). It is what a rebuild would move against what backtests read today only if the inventory is regenerated too.

| vintage | top-3000 basis | top-3000 vs committed | top-1000 basis | top-1000 vs committed |
|---|---:|---:|---:|---:|
| 1999 | 4.1% | 7.3% | 12.1% | 14.1% |
| 2004 | 2.9% | 6.4% | 12.8% | 15.3% |
| 2009 | 3.2% | 5.2% | 7.7% | 9.8% |
| 2014 | 3.4% | 5.0% | 5.6% | 7.9% |
| 2019 | 2.7% | 3.1% | 2.7% | 4.0% |
| 2024 | 1.8% | 1.7% | 1.1% | 0.8% |

Every year, both sizes: see "Membership change per vintage" below. The swap is
symmetric by construction: n in = n out.

**Cross-check against the issue's one-sided numbers** (members of the committed
top-3000 that fall below the true-basis cutoff: 10 % 2004, 7 % 2009, 6 % 2014,
4 % 2019, 2 % 2024). Here: **6.4 / 5.2 / 5.0 / 3.1 / 1.7 %**. The shape matches
and the level is lower. Part of the gap is which splits go into `F`. An earlier
run of the same exe without the volume-restatement check (rule 2) gave
6.7 / 5.5 / 5.1 / 3.5 / 1.8 %. The issue's estimate presumably applied every
vendor split, including the 4,939 the close never shows, which moves more
names. Part of what this column counts is
not the basis at all. "C\L (store drift)" is the committed list against the
same store on the same basis: 127 symbols in 2004, 85 in 2019. The store has
changed since the lists were built in May.

**Why**: the fix moves symbols by their split history *after* the list date,
which is exactly the look-ahead.

- Leaving `T`: forward splitters, mostly ADRs and large caps that later split
  (2004: SBER x1000 in 2007, POT, NVO, TPL; 2019: BHRB x40, FUJIY, DASTY,
  BBSI). These were ranked up by future splits.
- Entering `T`: later reverse splitters, mostly micro-cap biotech and shells
  (2019: PIXY x1/600, MBRX, ACB, NBR, DFFN). These were ranked down.
- Top-1000 moves more than top-3000 in early vintages: the big forward
  splitters are large caps, near the top-1000 cut.
- The effect fades toward the present because fewer future splits remain.

**Store drift is at least as large as the basis effect in most top-3000 vintages.** By the per-vintage table, C\L exceeds L\T in 22 of 28 top-3000 vintages (e.g. 2004: 127 vs 86; 2009: 128 vs 97; 2014: 121 vs 103) and in 1 of 28 top-1000 vintages, so for the top-3000 the "vs committed" column is mostly drift, not basis. C\L combines two things: (a) symbols gone from the store (508 of the 1998 committed members have no `data.csv` today; only 7 of the 2025 members are missing, so 2025 570 is mostly candidate-set expansion), and (b) the candidate set: this measurement takes 11,859 bar-based candidates from every `data.csv`, while a real rebuild via `Build_from_individuals` filters by `inventory.sexp` (5,734 symbols, generated 2026-07-12). The "vs committed" column therefore describes a rebuild only if the inventory is regenerated from the store too; a rebuild on the committed inventory would move a different, probably smaller, set (not measured here).

## Liquidity gates: not built, measured

**What the gate sees at run time:** `Liquidity_metric.dollar_adv` reads
`Types.Daily_price.t` bars from `Bar_reader` (snapshot warehouse panels). Each
carries `close_price` (raw), `adjusted_close` (split *and* dividend adjusted)
and `volume` (the stored, restated column). There are no split factors.
`close / adjusted_close` mixes in dividends, so it cannot isolate `F`.

**Not cheaply computable there.** A fix needs per-symbol split events at run
time: either a split-factor column (or `F(t)`) in the snapshot schema, written
by the snapshot builder from `splits.csv` with the same confirmation rules, or
a split side-table loaded next to the warehouse. Both change the warehouse
format and need a rebuild, so per the brief this PR does not build a
default-off flag for it.

**Which decisions would flip:** the entry gate at its default ($1M, 20-bar
mean), evaluated on every week-end bar of every committed top-3000 member
under the list that governs that week.

| period | flip share of symbol-weeks | direction |
|---|---|---|
| 1998-2003 | 3.9-6.8 % (230-345 symbols a year pass -> fail) | mostly pass -> fail: future forward splitters' ADV overstated |
| 2004-2013 | 0.8-2.6 % | mostly pass -> fail |
| 2014-2026 | 0.1-0.5 % | turns fail -> pass from 2018 on: future reverse splitters' ADV understated |

The full table is below. The hold-exit gate (`min_hold_dollar_adv`) defaults to
0 (off), so it flips nothing by default. At an armed $500k floor the direction
would be the same.

## Caveats

- **Non-basis contamination remains on both bases.** Foreign-currency lines (HSBA
  in pence, SBER in rubles, CELSIA), unit/warrant pairs (LHC-UN/LHC-WS) and
  shells with a split-adjusted close (VEXPQ 2004, $28B a day on bars under the
  cap) still head several true-basis lists, as they head the committed ones
  (HSBA and CTRA_old are in the committed 2010 and 2019 top-3000). The cap
  catches trillion-scale prints, not this. A currency/listing filter is a
  separate fix.
- The volume check acts only on splits of 3:1 or more either way. A raw-volume
  2:1 split would be divided wrongly (a factor-2 error on that symbol's earlier
  history). The histogram gives no sign of a raw-volume population among small
  splits, but it cannot rule one out.
- The container's bind mount intermittently reported present store directories
  as missing (`Sys_error ... No such file or directory`). One run silently lost
  224 symbols before the reads were retried. The exe now retries each read 3
  times, fails loudly on an unreadable directory, and prints `scanned N of M
  candidates`. This run: 11,859 of 11,859.

## Decision for the user (the [after-merge] item)

Whether to rebuild the PIT lists, and with them the warehouse and every
record, on the true basis. The numbers above are the input: 2-4 % of the top-3000 per vintage from the basis alone (3-14 % for the top-1000). For the top-3000 the rebuild decision is mostly a store and inventory refresh decision (drift exceeds the basis effect in 22 of 28 vintages), with the basis a 2-4 % component; the move against the committed lists holds only if the inventory is regenerated too. The liquidity-gate fix needs a
snapshot-schema change and is a separate decision.

---

# Generated report

## Specimen check

| symbol | date | stored close*volume | true | stored / true |
|---|---|---:|---:|---:|
| AMZN | 2018-06-14 | 1.094e+11 | 5.472e+09 | 20.000 |
| C | 2010-06-14 | 1.483e+08 | 1.483e+09 | 0.100 |

## Store split diagnostics

| item | count |
|---|---:|
| symbols scanned | 11859 |
| without `splits.csv` (scored with F = 1) | 8 |
| vendor splits | 13427 |
| ignored: close shows no matching jump | 4939 |
| ignored: close confirms, volume stored raw | 371 |
| applied (divided out of volume) | 8117 |

Volume jump share of the close-confirmed splits of 3:1 or more either way (log volume ratio over log factor; 0 = volume restated, 1 = raw; outer bins are open):

| bin | splits |
|---|---:|
| [-1.00, -0.75) | 375 |
| [-0.75, -0.50) | 297 |
| [-0.50, -0.25) | 573 |
| [-0.25, 0.00) | 615 |
| [0.00, 0.25) | 394 |
| [0.25, 0.50) | 175 |
| [0.50, 0.75) | 147 |
| [0.75, 1.00) | 130 |
| [1.00, 1.25) | 46 |
| [1.25, 1.50) | 23 |
| [1.50, 1.75) | 9 |
| [1.75, 2.00) | 16 |

## Membership change per vintage

L = rebuilt on the stored basis, T = true-dollar basis, C = committed list.

| year | N | in (T\L) | out (L\T) | out share | C\T | C\T share | C\L (store drift) |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1998 | 1000 | 140 | 140 | 14.0% | 188 | 18.8% | 77 |
| 1998 | 3000 | 81 | 81 | 2.7% | 536 | 17.9% | 519 |
| 1999 | 1000 | 121 | 121 | 12.1% | 141 | 14.1% | 31 |
| 1999 | 3000 | 122 | 122 | 4.1% | 219 | 7.3% | 133 |
| 2000 | 1000 | 105 | 105 | 10.5% | 114 | 11.4% | 15 |
| 2000 | 3000 | 135 | 135 | 4.5% | 156 | 5.2% | 40 |
| 2001 | 1000 | 111 | 111 | 11.1% | 125 | 12.5% | 24 |
| 2001 | 3000 | 105 | 105 | 3.5% | 165 | 5.5% | 76 |
| 2002 | 1000 | 115 | 115 | 11.5% | 128 | 12.8% | 20 |
| 2002 | 3000 | 96 | 96 | 3.2% | 173 | 5.8% | 99 |
| 2003 | 1000 | 111 | 111 | 11.1% | 123 | 12.3% | 23 |
| 2003 | 3000 | 89 | 89 | 3.0% | 175 | 5.8% | 114 |
| 2004 | 1000 | 128 | 128 | 12.8% | 153 | 15.3% | 39 |
| 2004 | 3000 | 86 | 86 | 2.9% | 191 | 6.4% | 127 |
| 2005 | 1000 | 128 | 128 | 12.8% | 152 | 15.2% | 43 |
| 2005 | 3000 | 79 | 79 | 2.6% | 195 | 6.5% | 140 |
| 2006 | 1000 | 128 | 128 | 12.8% | 159 | 15.9% | 44 |
| 2006 | 3000 | 91 | 91 | 3.0% | 194 | 6.5% | 144 |
| 2007 | 1000 | 96 | 96 | 9.6% | 119 | 11.9% | 38 |
| 2007 | 3000 | 100 | 100 | 3.3% | 193 | 6.4% | 137 |
| 2008 | 1000 | 89 | 89 | 8.9% | 108 | 10.8% | 33 |
| 2008 | 3000 | 96 | 96 | 3.2% | 179 | 6.0% | 140 |
| 2009 | 1000 | 77 | 77 | 7.7% | 98 | 9.8% | 30 |
| 2009 | 3000 | 97 | 97 | 3.2% | 156 | 5.2% | 128 |
| 2010 | 1000 | 82 | 82 | 8.2% | 109 | 10.9% | 37 |
| 2010 | 3000 | 111 | 111 | 3.7% | 182 | 6.1% | 144 |
| 2011 | 1000 | 75 | 75 | 7.5% | 98 | 9.8% | 34 |
| 2011 | 3000 | 98 | 98 | 3.3% | 170 | 5.7% | 136 |
| 2012 | 1000 | 65 | 65 | 6.5% | 83 | 8.3% | 28 |
| 2012 | 3000 | 91 | 91 | 3.0% | 157 | 5.2% | 124 |
| 2013 | 1000 | 59 | 59 | 5.9% | 83 | 8.3% | 36 |
| 2013 | 3000 | 88 | 88 | 2.9% | 170 | 5.7% | 130 |
| 2014 | 1000 | 56 | 56 | 5.6% | 79 | 7.9% | 30 |
| 2014 | 3000 | 103 | 103 | 3.4% | 149 | 5.0% | 121 |
| 2015 | 1000 | 42 | 42 | 4.2% | 67 | 6.7% | 30 |
| 2015 | 3000 | 102 | 102 | 3.4% | 145 | 4.8% | 126 |
| 2016 | 1000 | 41 | 41 | 4.1% | 71 | 7.1% | 33 |
| 2016 | 3000 | 82 | 82 | 2.7% | 139 | 4.6% | 119 |
| 2017 | 1000 | 35 | 35 | 3.5% | 58 | 5.8% | 29 |
| 2017 | 3000 | 73 | 73 | 2.4% | 125 | 4.2% | 107 |
| 2018 | 1000 | 32 | 32 | 3.2% | 51 | 5.1% | 26 |
| 2018 | 3000 | 80 | 80 | 2.7% | 105 | 3.5% | 91 |
| 2019 | 1000 | 27 | 27 | 2.7% | 40 | 4.0% | 19 |
| 2019 | 3000 | 80 | 80 | 2.7% | 93 | 3.1% | 85 |
| 2020 | 1000 | 23 | 23 | 2.3% | 36 | 3.6% | 18 |
| 2020 | 3000 | 75 | 75 | 2.5% | 88 | 2.9% | 80 |
| 2021 | 1000 | 30 | 30 | 3.0% | 37 | 3.7% | 16 |
| 2021 | 3000 | 117 | 117 | 3.9% | 111 | 3.7% | 96 |
| 2022 | 1000 | 21 | 21 | 2.1% | 24 | 2.4% | 8 |
| 2022 | 3000 | 106 | 106 | 3.5% | 96 | 3.2% | 53 |
| 2023 | 1000 | 13 | 13 | 1.3% | 12 | 1.2% | 3 |
| 2023 | 3000 | 65 | 65 | 2.2% | 55 | 1.8% | 42 |
| 2024 | 1000 | 11 | 11 | 1.1% | 8 | 0.8% | 4 |
| 2024 | 3000 | 55 | 55 | 1.8% | 52 | 1.7% | 30 |
| 2025 | 1000 | 5 | 5 | 0.5% | 82 | 8.2% | 82 |
| 2025 | 3000 | 49 | 49 | 1.6% | 580 | 19.3% | 570 |

## Rejected bars

702 bars across 11 symbols (full list: the rejected-bars CSV). Largest:

| symbol | bars | max true $/day |
|---|---:|---:|
| VEXPQ | 120 | 3.13e+13 |
| ETP_old2 | 381 | 1.13e+13 |
| VPGC | 25 | 9.97e+12 |
| OCHTQ | 99 | 3.72e+12 |
| CELSIA | 11 | 2.82e+12 |
| CMPC | 44 | 1.57e+12 |
| ELP | 18 | 7.46e+11 |
| TNM | 1 | 4.46e+11 |
| HCD | 1 | 2.89e+11 |
| FTGX | 1 | 2.13e+11 |
| MEL | 1 | 2.04e+11 |

## Entry liquidity gate flips ($1000000 floor, week-end bars of committed top-3000 members)

| year | symbol-weeks | pass->fail | fail->pass | flip share | symbols pass->fail | symbols fail->pass |
|---|---:|---:|---:|---:|---:|---:|
| 1998 | 77073 | 4620 | 592 | 6.8% | 344 | 40 |
| 1999 | 139251 | 6871 | 863 | 5.6% | 340 | 52 |
| 2000 | 146454 | 5887 | 823 | 4.6% | 277 | 53 |
| 2001 | 147504 | 5358 | 1136 | 4.4% | 250 | 59 |
| 2002 | 147743 | 5181 | 1065 | 4.2% | 263 | 56 |
| 2003 | 148845 | 4666 | 1137 | 3.9% | 232 | 57 |
| 2004 | 150962 | 3073 | 790 | 2.6% | 174 | 46 |
| 2005 | 146759 | 1969 | 467 | 1.7% | 115 | 35 |
| 2006 | 145980 | 1363 | 347 | 1.2% | 82 | 23 |
| 2007 | 145202 | 876 | 310 | 0.8% | 51 | 18 |
| 2008 | 145454 | 965 | 396 | 0.9% | 65 | 31 |
| 2009 | 150293 | 1619 | 757 | 1.6% | 93 | 43 |
| 2010 | 147225 | 1527 | 530 | 1.4% | 87 | 26 |
| 2011 | 146812 | 1200 | 625 | 1.2% | 63 | 40 |
| 2012 | 147460 | 1605 | 688 | 1.6% | 77 | 36 |
| 2013 | 147451 | 1039 | 378 | 1.0% | 60 | 25 |
| 2014 | 147723 | 530 | 238 | 0.5% | 39 | 15 |
| 2015 | 150212 | 395 | 328 | 0.5% | 27 | 18 |
| 2016 | 146605 | 441 | 197 | 0.4% | 26 | 16 |
| 2017 | 146935 | 327 | 120 | 0.3% | 17 | 7 |
| 2018 | 147584 | 138 | 239 | 0.3% | 16 | 12 |
| 2019 | 147840 | 152 | 281 | 0.3% | 16 | 17 |
| 2020 | 151637 | 198 | 452 | 0.4% | 14 | 24 |
| 2021 | 147939 | 179 | 476 | 0.4% | 9 | 30 |
| 2022 | 147640 | 156 | 610 | 0.5% | 8 | 28 |
| 2023 | 150764 | 131 | 512 | 0.4% | 12 | 23 |
| 2024 | 151444 | 51 | 387 | 0.3% | 6 | 19 |
| 2025 | 152278 | 11 | 340 | 0.2% | 3 | 29 |
| 2026 | 64232 | 0 | 85 | 0.1% | 0 | 9 |

## Top movers, top-3000 lists

### 1998

True-basis head: HSBA 2.35e+10, GTN 4.83e+09, AGR 3.25e+09, SBFG 3.16e+09, CWBC 1.85e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| DOMH | 3493 | 2691 | 2.47e+05 | 2011-05-09 x0.1, 2012-09-24 x0.05, 2016-03-04 x0.05263, 2019-05-10 x0.235, 2019-10-28 x1.113, 2022-06-07 x0.05882 |
| ARMP | 3476 | 1894 | 7e+04 | 2006-05-11 x0.1, 2015-08-07 x0.02, 2017-04-25 x0.1, 2019-05-10 x0.07143 |
| ACHV | 3466 | 1578 | 3.96e+04 | 2008-08-21 x0.05556, 2017-08-03 x0.09091, 2018-05-24 x0.1, 2020-07-31 x0.05 |
| BKYI | 3482 | 2952 | 1.73e+04 | 2016-12-29 x0.08333, 2020-11-20 x0.125, 2023-12-21 x0.05556, 2026-04-30 x0.1 |
| MBOT | 3475 | 2630 | 1.62e+04 | 2011-07-06 x0.1, 2016-05-09 x0.08333, 2016-11-29 x0.1111, 2018-09-05 x0.06667 |
| ERNA | 3473 | 2621 | 1.5e+04 | 2021-03-26 x0.5, 2022-10-17 x0.05, 2025-06-12 x0.06667, 2026-05-04 x0.04 |
| CVM | 3464 | 2452 | 7.5e+03 | 2013-09-25 x0.1, 2017-06-15 x0.04, 2025-05-20 x0.03333 |
| GLAE | 3410 | 1226 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| ASTC | 3456 | 2899 | 1.5e+03 | 2007-11-29 x0.1, 2017-10-16 x0.2, 2022-12-05 x0.03333 |
| HRBR | 3425 | 2141 | 1e+03 | 2011-11-02 x0.001 |
| AIKI | 3301 | 435 | 808 | 2011-05-09 x0.1, 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| MGLN | 3375 | 1585 | 308 | 2004-01-06 x0.003247 |
| XOMA | 3395 | 1936 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| PEGX | 3418 | 2709 | 250 | 2000-05-31 x2, 2003-01-02 x0.1, 2004-08-27 x2, 2007-01-10 x0.01 |
| ERINQ | 3434 | 2942 | 246 | 2007-01-12 x0.01, 2014-02-24 x2.435, 2015-04-23 x0.1667 |
| PARD | 3351 | 1457 | 240 | 2006-09-25 x0.1667, 2011-11-23 x0.025 |
| USAU | 3436 | 2976 | 240 | 1998-12-04 x2, 1999-12-16 x1.5, 2013-03-18 x0.1667, 2016-07-11 x0.3333, 2017-05-08 x0.25, 2020-03-20 x0.1 |
| OTLC | 3367 | 1674 | 240 | 2011-02-23 x0.05, 2012-12-28 x0.08333 |
| QMCO | 3408 | 2676 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| SMSI | 3422 | 2944 | 160 | 2016-08-17 x0.25, 2024-04-11 x0.125, 2026-06-04 x0.2 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| ATLKY | 2509 | 3345 | 0.0417 | 2005-05-26 x3, 2007-05-30 x2, 2022-05-23 x4 |
| ODFL | 1772 | 3110 | 0.0439 | 2003-06-17 x1.5, 2004-05-21 x1.5, 2005-12-01 x1.5, 2010-08-24 x1.5, 2012-09-10 x1.5, 2020-03-25 x1.5, 2024-03-28 x2 |
| BN | 1847 | 3014 | 0.0687 | 2004-06-02 x1.5, 2006-04-28 x1.5, 2007-06-04 x1.5, 2013-04-15 x1.033, 2015-05-13 x1.5, 2020-04-02 x1.5, 2022-12-12 x1.237, 2025-10-10 x1.5 |
| MRTN | 2599 | 3283 | 0.079 | 2003-07-25 x1.5, 2003-12-08 x1.5, 2005-12-27 x1.5, 2013-06-17 x1.5, 2017-07-10 x1.667, 2020-08-14 x1.5 |
| BF-A | 1988 | 3039 | 0.0797 | 2004-01-21 x2, 2008-10-28 x1.25, 2012-08-13 x1.5, 2016-08-19 x2, 2018-02-07 x1.339, 2018-03-01 x1.25 |
| ATVI | 1971 | 3020 | 0.0833 | 2001-11-21 x1.5, 2003-06-09 x1.5, 2004-03-16 x1.5, 2005-03-23 x1.333, 2005-10-25 x1.333, 2008-09-08 x2 |
| CSWC | 2077 | 3038 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| NSSC | 2803 | 3337 | 0.0926 | 2004-04-28 x2, 2004-11-18 x1.2, 2005-12-29 x1.5, 2006-06-08 x1.5, 2022-01-05 x2 |
| AVD | 2890 | 3355 | 0.103 | 2000-03-29 x1.1, 2001-03-28 x1.1, 2002-04-15 x1.333, 2003-04-14 x1.5, 2004-04-19 x1.5, 2005-04-18 x2, 2006-04-18 x1.333 |
| BMI | 2478 | 3168 | 0.125 | 2004-12-13 x2, 2006-06-16 x2, 2016-09-16 x2 |
| DAKT | 2435 | 3143 | 0.125 | 2000-01-10 x2, 2001-06-25 x2, 2006-06-23 x2 |
| ENB | 2571 | 3200 | 0.125 | 1999-05-06 x2, 2005-05-31 x2, 2011-06-01 x2 |
| EV_old2 | 2197 | 3011 | 0.125 | 1998-09-01 x2, 2000-11-14 x2, 2005-01-18 x2 |
| QSII | 2213 | 3019 | 0.125 | 2005-03-28 x2, 2006-03-27 x2, 2011-10-27 x2 |
| STZ-B | 2322 | 3089 | 0.125 | 2001-05-15 x2, 2002-05-14 x2, 2005-05-16 x2 |
| SWN | 2267 | 3052 | 0.125 | 2005-06-06 x2, 2005-11-18 x2, 2008-03-26 x2 |
| SYBT | 2632 | 3181 | 0.159 | 1999-03-01 x2, 2003-09-22 x2, 2006-05-08 x1.05, 2016-05-31 x1.5 |
| HTO | 2663 | 3188 | 0.167 | 2004-03-02 x3, 2006-03-17 x2 |
| BBSI | 2479 | 3094 | 0.167 | 2005-05-20 x1.5, 2024-06-24 x4 |
| BFA | 2394 | 3040 | 0.167 | 2004-01-21 x2, 2012-08-13 x1.5, 2016-08-19 x2 |

### 1999

True-basis head: HSBA 2.94e+10, TWX 3.8e+09, TMAV 3.7e+09, ATAR_old 3.54e+09, AGR 3.53e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| CVM | 4451 | 2969 | 7.5e+03 | 2013-09-25 x0.1, 2017-06-15 x0.04, 2025-05-20 x0.03333 |
| GLAE | 4410 | 1750 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| HRBR | 4414 | 2534 | 1e+03 | 2011-11-02 x0.001 |
| AIKI | 4323 | 1099 | 808 | 2011-05-09 x0.1, 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| MGLN | 4389 | 2667 | 308 | 2004-01-06 x0.003247 |
| XOMA | 4357 | 2131 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| LEU | 4259 | 1363 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| PEGX | 4173 | 1068 | 250 | 2000-05-31 x2, 2003-01-02 x0.1, 2004-08-27 x2, 2007-01-10 x0.01 |
| SPEX | 3511 | 622 | 80.8 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| HRTX | 4341 | 2931 | 80 | 2007-05-25 x0.25, 2014-01-13 x0.05 |
| TDW | 3239 | 810 | 32.3 | 2017-08-01 x0.031 |
| CDZI | 4072 | 2387 | 25 | 2003-12-18 x0.04 |
| CMPD | 4100 | 2504 | 25 | 2022-05-23 x0.04 |
| NBR | 3035 | 763 | 25 | 2006-04-18 x2, 2020-04-23 x0.02 |
| VEON | 3880 | 1839 | 25 | 2023-03-08 x0.04 |
| AVNW | 3245 | 954 | 24 | 2007-01-29 x0.25, 2016-06-14 x0.08333, 2021-04-08 x2 |
| GILT | 3004 | 828 | 20 | 2003-04-16 x0.05 |
| RGS | 3775 | 1767 | 20 | 2023-11-29 x0.05 |
| AAIC | 3106 | 913 | 20 | 2009-10-07 x0.05 |
| BH | 4176 | 2998 | 17.2 | 2009-12-21 x0.05, 2013-08-23 x1.077, 2014-08-15 x1.08 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| AKR | 8 | 3804 | 1.36e-05 | 2010-07-06 x25, 2012-10-10 x2, 2013-05-13 x0.9412, 2013-11-22 x156, 2014-12-09 x10 |
| HLFN | 180 | 3414 | 0.00167 | 2005-09-01 x600 |
| MNST | 458 | 3511 | 0.00521 | 2005-08-09 x2, 2006-07-10 x4, 2012-02-16 x2, 2016-11-10 x3, 2023-03-28 x2, 2026-08-11 x2 |
| TPL | 1386 | 3759 | 0.0222 | 2007-07-13 x5, 2024-03-27 x3, 2025-12-23 x3 |
| GGB | 1937 | 3922 | 0.0339 | 2000-05-09 x2, 2003-05-13 x1.3, 2004-05-07 x2, 2005-04-19 x1.5, 2006-04-21 x1.5, 2008-06-20 x2, 2023-03-22 x1.05, 2024-04-18 x1.2 |
| CRVL | 1143 | 3303 | 0.037 | 1999-06-15 x2, 2001-09-04 x1.5, 2006-12-11 x1.5, 2013-06-27 x2, 2024-12-26 x3 |
| ODFL | 2533 | 4077 | 0.0439 | 2003-06-17 x1.5, 2004-05-21 x1.5, 2005-12-01 x1.5, 2010-08-24 x1.5, 2012-09-10 x1.5, 2020-03-25 x1.5, 2024-03-28 x2 |
| MSTR | 1318 | 3289 | 0.05 | 2000-01-27 x2, 2024-08-08 x10 |
| DECK | 2459 | 3966 | 0.0556 | 2010-07-06 x3, 2024-09-17 x6 |
| AAON | 1856 | 3637 | 0.0585 | 2001-10-01 x1.5, 2002-06-05 x1.5, 2007-08-22 x1.5, 2011-06-14 x1.5, 2013-07-03 x1.5, 2014-07-17 x1.5, 2023-08-17 x1.5 |
| ROL | 1297 | 3181 | 0.0585 | 2003-03-11 x1.5, 2005-03-11 x1.5, 2007-12-11 x1.5, 2010-12-13 x1.5, 2015-03-11 x1.5, 2018-12-11 x1.5, 2020-12-11 x1.5 |
| BRO | 1766 | 3545 | 0.0625 | 2000-08-24 x2, 2001-11-23 x2, 2005-11-29 x2, 2018-03-29 x2 |
| CTSH | 2279 | 3848 | 0.0625 | 2000-03-17 x2, 2004-06-18 x2, 2007-10-17 x2, 2014-03-10 x2 |
| DINO | 1511 | 3353 | 0.0625 | 2001-07-09 x2, 2004-08-31 x2, 2006-06-02 x2, 2011-09-01 x2 |
| OZK | 1847 | 3599 | 0.0625 | 2002-06-18 x2, 2003-12-11 x2, 2011-08-17 x2, 2014-06-24 x2 |
| OZRK | 1846 | 3598 | 0.0625 | 2002-06-18 x2, 2003-12-11 x2, 2011-08-17 x2, 2014-06-24 x2 |
| BN | 2160 | 3737 | 0.0687 | 2004-06-02 x1.5, 2006-04-28 x1.5, 2007-06-04 x1.5, 2013-04-15 x1.033, 2015-05-13 x1.5, 2020-04-02 x1.5, 2022-12-12 x1.237, 2025-10-10 x1.5 |
| BF-A | 2363 | 3789 | 0.0797 | 2004-01-21 x2, 2008-10-28 x1.25, 2012-08-13 x1.5, 2016-08-19 x2, 2018-02-07 x1.339, 2018-03-01 x1.25 |
| FFIN | 2073 | 3630 | 0.08 | 2001-06-04 x1.25, 2003-06-03 x1.25, 2005-06-02 x1.333, 2011-06-02 x1.5, 2014-06-03 x2, 2019-06-04 x2 |
| INOD | 1668 | 3314 | 0.0833 | 1999-09-10 x3, 2000-12-04 x2, 2001-03-26 x2 |

### 2000

True-basis head: GEG_old 4.77e+10, AVNX 2.24e+10, VIGN 2.09e+10, RAZF 1.98e+10, ARBA 1.97e+10

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| CMPC | 4725 | 148 | 1.75e+05 | 2005-09-22 x0.002857, 2010-03-31 x0.002 |
| ARMP | 4786 | 2172 | 7e+04 | 2006-05-11 x0.1, 2015-08-07 x0.02, 2017-04-25 x0.1, 2019-05-10 x0.07143 |
| MBOT | 4778 | 2624 | 1.62e+04 | 2011-07-06 x0.1, 2016-05-09 x0.08333, 2016-11-29 x0.1111, 2018-09-05 x0.06667 |
| ERNA | 4781 | 2893 | 1.5e+04 | 2021-03-26 x0.5, 2022-10-17 x0.05, 2025-06-12 x0.06667, 2026-05-04 x0.04 |
| IMNN | 4780 | 2887 | 1.42e+04 | 2006-02-28 x0.06667, 2013-10-29 x0.222, 2017-05-30 x0.07143, 2022-03-01 x0.06667 |
| GLAE | 4706 | 1823 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| AIKI | 4245 | 398 | 808 | 2011-05-09 x0.1, 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| USAU | 4712 | 2685 | 720 | 2013-03-18 x0.1667, 2016-07-11 x0.3333, 2017-05-08 x0.25, 2020-03-20 x0.1 |
| POCI | 4622 | 1728 | 450 | 2003-01-29 x0.1667, 2008-12-11 x0.04, 2022-11-03 x0.3333 |
| XOMA | 4527 | 1469 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| LEU | 4650 | 2376 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| PEGX | 4151 | 712 | 251 | 2003-01-02 x0.1, 2004-08-27 x2, 2007-01-10 x0.01 |
| PARD | 4506 | 1539 | 240 | 2006-09-25 x0.1667, 2011-11-23 x0.025 |
| QMCO | 4339 | 1311 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| SMSI | 4574 | 2184 | 160 | 2016-08-17 x0.25, 2024-04-11 x0.125, 2026-06-04 x0.2 |
| VCEL | 4571 | 2180 | 160 | 2010-02-18 x0.125, 2013-10-16 x0.05 |
| SLNH | 4475 | 1839 | 132 | 2008-05-16 x0.125, 2023-10-16 x0.04 |
| AGEN | 4508 | 2042 | 120 | 2011-10-03 x0.1667, 2024-04-12 x0.05 |
| AIMI | 4624 | 2915 | 99.9 | 2025-06-12 x0.01, 2026-01-09 x1.001 |
| SPEX | 3264 | 425 | 80.8 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| AKR | 20 | 4187 | 1.36e-05 | 2010-07-06 x25, 2012-10-10 x2, 2013-05-13 x0.9412, 2013-11-22 x156, 2014-12-09 x10 |
| MNST | 757 | 4009 | 0.00521 | 2005-08-09 x2, 2006-07-10 x4, 2012-02-16 x2, 2016-11-10 x3, 2023-03-28 x2, 2026-08-11 x2 |
| TSCO | 843 | 3685 | 0.0125 | 2002-08-20 x2, 2003-08-22 x2, 2010-09-03 x2, 2013-09-27 x2, 2024-12-20 x5 |
| TPL | 1187 | 3742 | 0.0222 | 2007-07-13 x5, 2024-03-27 x3, 2025-12-23 x3 |
| SID | 1327 | 3507 | 0.0417 | 2004-06-10 x4, 2008-02-11 x3, 2010-04-07 x2 |
| GGB | 1803 | 3856 | 0.0441 | 2003-05-13 x1.3, 2004-05-07 x2, 2005-04-19 x1.5, 2006-04-21 x1.5, 2008-06-20 x2, 2023-03-22 x1.05, 2024-04-18 x1.2 |
| SGU | 1312 | 3384 | 0.05 | 2013-12-23 x20 |
| AAON | 1354 | 3333 | 0.0585 | 2001-10-01 x1.5, 2002-06-05 x1.5, 2007-08-22 x1.5, 2011-06-14 x1.5, 2013-07-03 x1.5, 2014-07-17 x1.5, 2023-08-17 x1.5 |
| ROL | 1805 | 3712 | 0.0585 | 2003-03-11 x1.5, 2005-03-11 x1.5, 2007-12-11 x1.5, 2010-12-13 x1.5, 2015-03-11 x1.5, 2018-12-11 x1.5, 2020-12-11 x1.5 |
| BRO | 1338 | 3279 | 0.0625 | 2000-08-24 x2, 2001-11-23 x2, 2005-11-29 x2, 2018-03-29 x2 |
| DINO | 1739 | 3627 | 0.0625 | 2001-07-09 x2, 2004-08-31 x2, 2006-06-02 x2, 2011-09-01 x2 |
| OZK | 2783 | 4242 | 0.0625 | 2002-06-18 x2, 2003-12-11 x2, 2011-08-17 x2, 2014-06-24 x2 |
| OZRK | 2782 | 4241 | 0.0625 | 2002-06-18 x2, 2003-12-11 x2, 2011-08-17 x2, 2014-06-24 x2 |
| BN | 2763 | 4200 | 0.0687 | 2004-06-02 x1.5, 2006-04-28 x1.5, 2007-06-04 x1.5, 2013-04-15 x1.033, 2015-05-13 x1.5, 2020-04-02 x1.5, 2022-12-12 x1.237, 2025-10-10 x1.5 |
| CRVL | 1828 | 3584 | 0.0741 | 2001-09-04 x1.5, 2006-12-11 x1.5, 2013-06-27 x2, 2024-12-26 x3 |
| BF-A | 2410 | 3943 | 0.0797 | 2004-01-21 x2, 2008-10-28 x1.25, 2012-08-13 x1.5, 2016-08-19 x2, 2018-02-07 x1.339, 2018-03-01 x1.25 |
| FFIN | 2621 | 4050 | 0.08 | 2001-06-04 x1.25, 2003-06-03 x1.25, 2005-06-02 x1.333, 2011-06-02 x1.5, 2014-06-03 x2, 2019-06-04 x2 |
| ATVI | 1667 | 3397 | 0.0833 | 2001-11-21 x1.5, 2003-06-09 x1.5, 2004-03-16 x1.5, 2005-03-23 x1.333, 2005-10-25 x1.333, 2008-09-08 x2 |
| NEOG | 2970 | 4191 | 0.0889 | 2004-01-02 x1.25, 2007-09-05 x1.5, 2009-12-16 x1.5, 2013-10-31 x1.5, 2018-01-02 x1.333, 2021-06-07 x2 |
| CSWC | 2478 | 3921 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |

### 2001

True-basis head: GEG_old 4.04e+10, HSBA 1.95e+10, TMTA 1.73e+10, FTGX 1.04e+10, BPURQ 9.95e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| CMPC | 4656 | 171 | 1.75e+05 | 2005-09-22 x0.002857, 2010-03-31 x0.002 |
| ARMP | 4741 | 2829 | 7e+04 | 2006-05-11 x0.1, 2015-08-07 x0.02, 2017-04-25 x0.1, 2019-05-10 x0.07143 |
| GLAE | 4659 | 2172 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| AIKI | 3869 | 301 | 808 | 2011-05-09 x0.1, 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| PEGX | 4272 | 898 | 500 | 2003-01-02 x0.1, 2004-08-27 x2, 2007-01-10 x0.01 |
| MGLN | 4561 | 2179 | 308 | 2004-01-06 x0.003247 |
| PRPO | 4615 | 2807 | 300 | 2019-04-29 x0.06667, 2023-09-22 x0.05 |
| XOMA | 4284 | 1170 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| LEU | 4408 | 1588 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| PARD | 4588 | 2695 | 240 | 2006-09-25 x0.1667, 2011-11-23 x0.025 |
| BVSN | 3546 | 464 | 225 | 2002-07-30 x0.1111, 2008-10-27 x0.04 |
| SLNH | 4489 | 2070 | 200 | 2008-05-16 x0.125, 2023-10-16 x0.04 |
| QMCO | 4147 | 1264 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| VCEL | 4569 | 2704 | 160 | 2010-02-18 x0.125, 2013-10-16 x0.05 |
| AGEN | 4381 | 1987 | 120 | 2011-10-03 x0.1667, 2024-04-12 x0.05 |
| STCN | 3265 | 557 | 93.3 | 2007-11-01 x0.1, 2023-06-22 x0.1071 |
| AWEB | 3950 | 1603 | 50 | 2012-07-05 x0.02 |
| CDMO | 4409 | 2957 | 35 | 2009-10-19 x0.2, 2017-07-10 x0.1429 |
| EQIX | 4329 | 2733 | 32 | 2002-12-31 x0.03125 |
| CDZI | 4257 | 2711 | 25 | 2003-12-18 x0.04 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| AKR | 7 | 3646 | 1.36e-05 | 2010-07-06 x25, 2012-10-10 x2, 2013-05-13 x0.9412, 2013-11-22 x156, 2014-12-09 x10 |
| FBPI | 509 | 3636 | 0.00333 | 2008-05-12 x300 |
| MNST | 1501 | 4301 | 0.00521 | 2005-08-09 x2, 2006-07-10 x4, 2012-02-16 x2, 2016-11-10 x3, 2023-03-28 x2, 2026-08-11 x2 |
| TSCO | 767 | 3298 | 0.0125 | 2002-08-20 x2, 2003-08-22 x2, 2010-09-03 x2, 2013-09-27 x2, 2024-12-20 x5 |
| TPL | 1576 | 3837 | 0.0222 | 2007-07-13 x5, 2024-03-27 x3, 2025-12-23 x3 |
| ODFL | 2628 | 4187 | 0.0439 | 2003-06-17 x1.5, 2004-05-21 x1.5, 2005-12-01 x1.5, 2010-08-24 x1.5, 2012-09-10 x1.5, 2020-03-25 x1.5, 2024-03-28 x2 |
| NTES | 2270 | 3977 | 0.05 | 2006-03-28 x4, 2020-10-02 x5 |
| DECK | 2261 | 3918 | 0.0556 | 2010-07-06 x3, 2024-09-17 x6 |
| ROL | 1771 | 3477 | 0.0585 | 2003-03-11 x1.5, 2005-03-11 x1.5, 2007-12-11 x1.5, 2010-12-13 x1.5, 2015-03-11 x1.5, 2018-12-11 x1.5, 2020-12-11 x1.5 |
| AAON | 1508 | 3258 | 0.0585 | 2001-10-01 x1.5, 2002-06-05 x1.5, 2007-08-22 x1.5, 2011-06-14 x1.5, 2013-07-03 x1.5, 2014-07-17 x1.5, 2023-08-17 x1.5 |
| OZK | 1927 | 3591 | 0.0625 | 2002-06-18 x2, 2003-12-11 x2, 2011-08-17 x2, 2014-06-24 x2 |
| OZRK | 1928 | 3592 | 0.0625 | 2002-06-18 x2, 2003-12-11 x2, 2011-08-17 x2, 2014-06-24 x2 |
| GGB | 1944 | 3554 | 0.0678 | 2003-05-13 x1.3, 2004-05-07 x2, 2005-04-19 x1.5, 2006-04-21 x1.5, 2008-06-20 x2, 2023-03-22 x1.05, 2024-04-18 x1.2 |
| BN | 1371 | 3010 | 0.0687 | 2004-06-02 x1.5, 2006-04-28 x1.5, 2007-06-04 x1.5, 2013-04-15 x1.033, 2015-05-13 x1.5, 2020-04-02 x1.5, 2022-12-12 x1.237, 2025-10-10 x1.5 |
| REX | 1595 | 3217 | 0.0741 | 2001-08-13 x1.5, 2002-02-12 x1.5, 2022-08-08 x3, 2025-09-16 x2 |
| BF-A | 2494 | 3914 | 0.0797 | 2004-01-21 x2, 2008-10-28 x1.25, 2012-08-13 x1.5, 2016-08-19 x2, 2018-02-07 x1.339, 2018-03-01 x1.25 |
| FFIN | 1930 | 3451 | 0.08 | 2001-06-04 x1.25, 2003-06-03 x1.25, 2005-06-02 x1.333, 2011-06-02 x1.5, 2014-06-03 x2, 2019-06-04 x2 |
| NEOG | 1615 | 3125 | 0.0889 | 2004-01-02 x1.25, 2007-09-05 x1.5, 2009-12-16 x1.5, 2013-10-31 x1.5, 2018-01-02 x1.333, 2021-06-07 x2 |
| CSWC | 1683 | 3162 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| SQM | 1760 | 3213 | 0.0974 | 2008-03-31 x10, 2016-04-25 x1.027 |

### 2002

True-basis head: ETP_old2 1.25e+11, HSBA 2.5e+10, OCHTQ 1.57e+10, FTGX 4.31e+09, AGR 3.16e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| CMPC | 4547 | 207 | 1.75e+05 | 2005-09-22 x0.002857, 2010-03-31 x0.002 |
| PRSO | 4575 | 2122 | 8e+03 | 2017-02-16 x0.1, 2019-08-28 x0.05, 2024-01-03 x0.025 |
| GLAE | 4472 | 1551 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| AIKI | 4367 | 1257 | 807 | 2011-05-09 x0.1, 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| PEGX | 4487 | 2577 | 500 | 2003-01-02 x0.1, 2004-08-27 x2, 2007-01-10 x0.01 |
| MGLN | 4435 | 2453 | 308 | 2004-01-06 x0.003247 |
| XOMA | 4169 | 1226 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| LEU | 4174 | 1282 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| BVSN | 4336 | 1966 | 225 | 2002-07-30 x0.1111, 2008-10-27 x0.04 |
| QMCO | 4280 | 1939 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| AGEN | 4223 | 1980 | 120 | 2011-10-03 x0.1667, 2024-04-12 x0.05 |
| STCN | 3961 | 1472 | 93.3 | 2007-11-01 x0.1, 2023-06-22 x0.1071 |
| SPEX | 3802 | 1260 | 80.7 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| GEG | 3135 | 857 | 36 | 2003-10-22 x0.3333, 2016-01-06 x0.08333 |
| CDMO | 4266 | 2899 | 35 | 2009-10-19 x0.2, 2017-07-10 x0.1429 |
| CDZI | 3798 | 2027 | 25 | 2003-12-18 x0.04 |
| FONR | 4186 | 2887 | 25 | 2007-04-17 x0.04 |
| VEON | 3170 | 1084 | 25 | 2023-03-08 x0.04 |
| AVNW | 3898 | 2241 | 24 | 2007-01-29 x0.25, 2016-06-14 x0.08333, 2021-04-08 x2 |
| CAMP_old | 3190 | 1169 | 23 | 2024-02-02 x0.04348 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| AKR | 6 | 3353 | 1.36e-05 | 2010-07-06 x25, 2012-10-10 x2, 2013-05-13 x0.9412, 2013-11-22 x156, 2014-12-09 x10 |
| FBPI | 1021 | 4072 | 0.00333 | 2008-05-12 x300 |
| MNST | 1664 | 4238 | 0.00521 | 2005-08-09 x2, 2006-07-10 x4, 2012-02-16 x2, 2016-11-10 x3, 2023-03-28 x2, 2026-08-11 x2 |
| TPL | 1485 | 3676 | 0.0222 | 2007-07-13 x5, 2024-03-27 x3, 2025-12-23 x3 |
| ODFL | 2480 | 3985 | 0.0439 | 2003-06-17 x1.5, 2004-05-21 x1.5, 2005-12-01 x1.5, 2010-08-24 x1.5, 2012-09-10 x1.5, 2020-03-25 x1.5, 2024-03-28 x2 |
| NTES | 2354 | 3894 | 0.05 | 2006-03-28 x4, 2020-10-02 x5 |
| DECK | 2355 | 3853 | 0.0556 | 2010-07-06 x3, 2024-09-17 x6 |
| ROL | 1428 | 3161 | 0.0585 | 2003-03-11 x1.5, 2005-03-11 x1.5, 2007-12-11 x1.5, 2010-12-13 x1.5, 2015-03-11 x1.5, 2018-12-11 x1.5, 2020-12-11 x1.5 |
| NJDCY | 1629 | 3296 | 0.0625 | 2005-11-29 x2, 2014-04-08 x2, 2020-04-09 x2, 2024-10-09 x2 |
| BF-A | 2126 | 3569 | 0.0797 | 2004-01-21 x2, 2008-10-28 x1.25, 2012-08-13 x1.5, 2016-08-19 x2, 2018-02-07 x1.339, 2018-03-01 x1.25 |
| SHEN | 1763 | 3253 | 0.0833 | 2004-02-23 x2, 2007-08-20 x3, 2016-01-05 x2 |
| NEOG | 2160 | 3534 | 0.0889 | 2004-01-02 x1.25, 2007-09-05 x1.5, 2009-12-16 x1.5, 2013-10-31 x1.5, 2018-01-02 x1.333, 2021-06-07 x2 |
| CSWC | 2154 | 3515 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| SQM | 2070 | 3421 | 0.0974 | 2008-03-31 x10, 2016-04-25 x1.027 |
| COKE | 1694 | 3081 | 0.1 | 2025-05-27 x10 |
| FFIN | 1725 | 3111 | 0.1 | 2003-06-03 x1.25, 2005-06-02 x1.333, 2011-06-02 x1.5, 2014-06-03 x2, 2019-06-04 x2 |
| MSTR | 2870 | 3932 | 0.1 | 2024-08-08 x10 |
| UHAL | 1877 | 3257 | 0.1 | 2022-11-10 x10 |
| GEL | 2790 | 3845 | 0.11 | 2011-04-12 x10, 2013-04-04 x0.9091 |
| ASNA | 2319 | 3491 | 0.125 | 2002-06-03 x2, 2006-04-03 x2, 2012-04-04 x2 |

### 2003

True-basis head: ETP_old2 9.07e+10, FTGX 4.33e+10, HSBA 4.28e+10, CADMQ 7.18e+09, AGR 5.63e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| CMPC | 4391 | 36 | 1.75e+05 | 2005-09-22 x0.002857, 2010-03-31 x0.002 |
| ARMP | 4568 | 2968 | 7e+04 | 2006-05-11 x0.1, 2015-08-07 x0.02, 2017-04-25 x0.1, 2019-05-10 x0.07143 |
| MBOT | 4519 | 1977 | 1.62e+04 | 2011-07-06 x0.1, 2016-05-09 x0.08333, 2016-11-29 x0.1111, 2018-09-05 x0.06667 |
| CTIC | 4505 | 1814 | 1.2e+04 | 2007-04-16 x0.25, 2008-09-02 x0.1, 2011-05-16 x0.1667, 2012-09-04 x0.2, 2017-01-03 x0.1 |
| PRSO | 4497 | 1904 | 8e+03 | 2017-02-16 x0.1, 2019-08-28 x0.05, 2024-01-03 x0.025 |
| GLAE | 4324 | 884 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| HRBR | 4467 | 2745 | 1e+03 | 2011-11-02 x0.001 |
| AIKI | 4145 | 779 | 807 | 2011-05-09 x0.1, 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| XOMA | 4176 | 1402 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| LEU | 4316 | 2018 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| OTLC | 4368 | 2503 | 240 | 2011-02-23 x0.05, 2012-12-28 x0.08333 |
| PARD | 4351 | 2345 | 240 | 2006-09-25 x0.1667, 2011-11-23 x0.025 |
| KZIA | 4397 | 2980 | 200 | 2017-07-14 x0.25, 2024-10-28 x0.1, 2025-04-17 x0.2 |
| QMCO | 4216 | 1930 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| SMSI | 4263 | 2130 | 160 | 2016-08-17 x0.25, 2024-04-11 x0.125, 2026-06-04 x0.2 |
| VCEL | 4326 | 2435 | 160 | 2010-02-18 x0.125, 2013-10-16 x0.05 |
| AGEN | 4054 | 1628 | 120 | 2011-10-03 x0.1667, 2024-04-12 x0.05 |
| STCN | 3799 | 1194 | 93.3 | 2007-11-01 x0.1, 2023-06-22 x0.1071 |
| SPEX | 3465 | 833 | 80.8 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| PEGX | 3886 | 1800 | 50 | 2004-08-27 x2, 2007-01-10 x0.01 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| NPSNY | 420 | 3583 | 0.00274 | 2005-07-15 x10, 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| FBPI | 939 | 3992 | 0.00333 | 2008-05-12 x300 |
| MNST | 1403 | 4096 | 0.00521 | 2005-08-09 x2, 2006-07-10 x4, 2012-02-16 x2, 2016-11-10 x3, 2023-03-28 x2, 2026-08-11 x2 |
| TPL | 1195 | 3485 | 0.0222 | 2007-07-13 x5, 2024-03-27 x3, 2025-12-23 x3 |
| SBS | 1172 | 3225 | 0.0333 | 2013-01-24 x2, 2013-04-30 x3, 2026-05-07 x5 |
| ATLKY | 2479 | 4034 | 0.0417 | 2005-05-26 x3, 2007-05-30 x2, 2022-05-23 x4 |
| DECK | 1849 | 3550 | 0.0556 | 2010-07-06 x3, 2024-09-17 x6 |
| NJDCY | 1726 | 3383 | 0.0625 | 2005-11-29 x2, 2014-04-08 x2, 2020-04-09 x2, 2024-10-09 x2 |
| MRTN | 2593 | 3883 | 0.079 | 2003-07-25 x1.5, 2003-12-08 x1.5, 2005-12-27 x1.5, 2013-06-17 x1.5, 2017-07-10 x1.667, 2020-08-14 x1.5 |
| BF-A | 2076 | 3572 | 0.0797 | 2004-01-21 x2, 2008-10-28 x1.25, 2012-08-13 x1.5, 2016-08-19 x2, 2018-02-07 x1.339, 2018-03-01 x1.25 |
| SHEN | 2205 | 3654 | 0.0833 | 2004-02-23 x2, 2007-08-20 x3, 2016-01-05 x2 |
| AXON | 1643 | 3132 | 0.0833 | 2004-02-11 x3, 2004-04-30 x2, 2004-11-30 x2 |
| NEOG | 2050 | 3502 | 0.0889 | 2004-01-02 x1.25, 2007-09-05 x1.5, 2009-12-16 x1.5, 2013-10-31 x1.5, 2018-01-02 x1.333, 2021-06-07 x2 |
| CSWC | 1999 | 3433 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| NSSC | 2586 | 3832 | 0.0926 | 2004-04-28 x2, 2004-11-18 x1.2, 2005-12-29 x1.5, 2006-06-08 x1.5, 2022-01-05 x2 |
| SQM | 1727 | 3117 | 0.0974 | 2008-03-31 x10, 2016-04-25 x1.027 |
| BZLFY | 2726 | 3873 | 0.1 | 2013-11-27 x5, 2024-12-09 x2 |
| MVCO | 1895 | 3277 | 0.1 | 2023-09-19 x10 |
| GEL | 2352 | 3635 | 0.11 | 2011-04-12 x10, 2013-04-04 x0.9091 |
| CRVL | 1710 | 3024 | 0.111 | 2006-12-11 x1.5, 2013-06-27 x2, 2024-12-26 x3 |

### 2004

True-basis head: HSBA 3.77e+10, VEXPQ 2.82e+10, CELSIA 8.43e+09, BBRY 8.02e+09, CADMQ 6.86e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| ORKA | 4773 | 2892 | 1.81e+05 | 2009-01-28 x0.05, 2013-03-05 x0.1667, 2015-09-04 x0.1429, 2019-04-04 x0.05556, 2024-09-03 x0.08333 |
| CMPC | 4619 | 43 | 1.75e+05 | 2005-09-22 x0.002857, 2010-03-31 x0.002 |
| CTIC | 4713 | 2503 | 1.2e+04 | 2007-04-16 x0.25, 2008-09-02 x0.1, 2011-05-16 x0.1667, 2012-09-04 x0.2, 2017-01-03 x0.1 |
| PRSO | 4645 | 1291 | 8e+03 | 2017-02-16 x0.1, 2019-08-28 x0.05, 2024-01-03 x0.025 |
| GLAE | 4590 | 1473 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| HRBR | 4584 | 1969 | 1e+03 | 2011-11-02 x0.001 |
| LIVE | 4490 | 1553 | 600 | 2007-08-27 x0.1, 2010-09-07 x0.1, 2016-12-08 x0.1667 |
| XOMA | 4505 | 2179 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| LEU | 4532 | 2414 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| OTLC | 4539 | 2557 | 240 | 2011-02-23 x0.05, 2012-12-28 x0.08333 |
| DRCT | 4428 | 1930 | 220 | 2026-01-12 x0.01818, 2026-04-27 x0.25 |
| QMCO | 4435 | 2226 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| AGEN | 4337 | 1956 | 120 | 2011-10-03 x0.1667, 2024-04-12 x0.05 |
| BLU | 4411 | 2391 | 108 | 2012-05-29 x0.03333, 2019-08-19 x0.2778 |
| STCN | 4212 | 1641 | 93.3 | 2007-11-01 x0.1, 2023-06-22 x0.1071 |
| SPEX | 4045 | 1298 | 80.8 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| ATHE | 4442 | 2999 | 60 | 2016-03-24 x0.1667, 2023-01-09 x0.1 |
| PEGX | 4140 | 1942 | 50 | 2004-08-27 x2, 2007-01-10 x0.01 |
| CDMO | 4358 | 2990 | 35 | 2009-10-19 x0.2, 2017-07-10 x0.1429 |
| TDW | 3328 | 869 | 32.3 | 2017-08-01 x0.031 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| NPSNY | 731 | 4206 | 0.00274 | 2005-07-15 x10, 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| TPL | 1308 | 3817 | 0.0222 | 2007-07-13 x5, 2024-03-27 x3, 2025-12-23 x3 |
| BHRB | 2049 | 4152 | 0.025 | 2022-11-15 x40 |
| SBS | 848 | 3171 | 0.0333 | 2013-01-24 x2, 2013-04-30 x3, 2026-05-07 x5 |
| ATLKY | 1245 | 3444 | 0.0417 | 2005-05-26 x3, 2007-05-30 x2, 2022-05-23 x4 |
| NVO | 1054 | 3141 | 0.05 | 2007-12-17 x2, 2014-01-09 x5, 2023-09-20 x2 |
| NJDCY | 2206 | 3902 | 0.0625 | 2005-11-29 x2, 2014-04-08 x2, 2020-04-09 x2, 2024-10-09 x2 |
| BRFS | 2834 | 4104 | 0.0833 | 2006-04-20 x3, 2010-04-08 x4 |
| CSWC | 2761 | 4045 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| SQM | 1891 | 3490 | 0.0974 | 2008-03-31 x10, 2016-04-25 x1.027 |
| BZLFY | 2870 | 4052 | 0.1 | 2013-11-27 x5, 2024-12-09 x2 |
| COKE | 1724 | 3347 | 0.1 | 2025-05-27 x10 |
| DASTY | 1876 | 3470 | 0.1 | 2014-07-23 x2, 2021-07-15 x5 |
| CRVL | 1678 | 3235 | 0.111 | 2006-12-11 x1.5, 2013-06-27 x2, 2024-12-26 x3 |
| BMI | 2640 | 3874 | 0.125 | 2004-12-13 x2, 2006-06-16 x2, 2016-09-16 x2 |
| EXPO | 2033 | 3464 | 0.125 | 2006-06-12 x2, 2015-06-05 x2, 2018-06-08 x2 |
| FFIN | 2055 | 3474 | 0.125 | 2005-06-02 x1.333, 2011-06-02 x1.5, 2014-06-03 x2, 2019-06-04 x2 |
| GIL | 2026 | 3457 | 0.125 | 2005-06-01 x2, 2007-05-29 x2, 2015-03-30 x2 |
| LKQ | 1520 | 3009 | 0.125 | 2006-01-17 x2, 2007-12-04 x2, 2012-09-19 x2 |
| TIE | 2564 | 3836 | 0.125 | 2005-09-07 x2, 2006-02-17 x2, 2006-05-16 x2 |

### 2005

True-basis head: HSBA 2.88e+10, IGOI 6.07e+09, AGR 5.9e+09, CELSIA 5.13e+09, YELL 3.3e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| ORKA | 4857 | 2773 | 1.81e+05 | 2009-01-28 x0.05, 2013-03-05 x0.1667, 2015-09-04 x0.1429, 2019-04-04 x0.05556, 2024-09-03 x0.08333 |
| CMPC | 4692 | 44 | 1.75e+05 | 2005-09-22 x0.002857, 2010-03-31 x0.002 |
| MBOT | 4780 | 1647 | 1.62e+04 | 2011-07-06 x0.1, 2016-05-09 x0.08333, 2016-11-29 x0.1111, 2018-09-05 x0.06667 |
| CTIC | 4791 | 2135 | 1.2e+04 | 2007-04-16 x0.25, 2008-09-02 x0.1, 2011-05-16 x0.1667, 2012-09-04 x0.2, 2017-01-03 x0.1 |
| GLAE | 4668 | 1632 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| SVRA | 4755 | 2780 | 1.75e+03 | 2010-04-26 x0.04, 2017-04-28 x0.01429 |
| AHT | 4687 | 2688 | 626 | 2013-11-20 x1.49, 2014-11-13 x1.059, 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| XOMA | 4632 | 2597 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| LEU | 4287 | 1078 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| DRCT | 4486 | 2043 | 220 | 2026-01-12 x0.01818, 2026-04-27 x0.25 |
| MOSY | 3081 | 114 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| SMSI | 4626 | 2989 | 160 | 2016-08-17 x0.25, 2024-04-11 x0.125, 2026-06-04 x0.2 |
| VCEL | 4284 | 1466 | 160 | 2010-02-18 x0.125, 2013-10-16 x0.05 |
| QMCO | 4598 | 2811 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| AGEN | 4546 | 2725 | 120 | 2011-10-03 x0.1667, 2024-04-12 x0.05 |
| BLU | 4468 | 2501 | 108 | 2012-05-29 x0.03333, 2019-08-19 x0.2778 |
| STCN | 4030 | 1259 | 93.3 | 2007-11-01 x0.1, 2023-06-22 x0.1071 |
| SPEX | 4409 | 2441 | 80.8 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| TROV | 4387 | 2425 | 72 | 2018-06-04 x0.08333, 2019-02-20 x0.1667 |
| USEG | 4392 | 2594 | 60 | 2016-06-22 x0.1667, 2020-01-06 x0.1 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| BHRB | 2076 | 4153 | 0.025 | 2022-11-15 x40 |
| ATLKY | 1947 | 3883 | 0.0422 | 2007-05-30 x2, 2022-05-23 x4 |
| SGU | 1083 | 3144 | 0.05 | 2013-12-23 x20 |
| NJDCY | 2236 | 3877 | 0.0625 | 2005-11-29 x2, 2014-04-08 x2, 2020-04-09 x2, 2024-10-09 x2 |
| BRFS | 2128 | 3690 | 0.0833 | 2006-04-20 x3, 2010-04-08 x4 |
| CSWC | 2350 | 3790 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| ARC | 1511 | 3122 | 0.1 | 2014-07-29 x10 |
| BZLFY | 2157 | 3612 | 0.1 | 2013-11-27 x5, 2024-12-09 x2 |
| COKE | 1815 | 3365 | 0.1 | 2025-05-27 x10 |
| ENS | 1641 | 3237 | 0.1 | 2011-10-20 x10 |
| MVCO | 2013 | 3500 | 0.1 | 2023-09-19 x10 |
| DASTY | 1629 | 3223 | 0.1 | 2014-07-23 x2, 2021-07-15 x5 |
| CRVL | 1894 | 3367 | 0.111 | 2006-12-11 x1.5, 2013-06-27 x2, 2024-12-26 x3 |
| NEOG | 2343 | 3686 | 0.111 | 2007-09-05 x1.5, 2009-12-16 x1.5, 2013-10-31 x1.5, 2018-01-02 x1.333, 2021-06-07 x2 |
| EXPO | 2180 | 3499 | 0.125 | 2006-06-12 x2, 2015-06-05 x2, 2018-06-08 x2 |
| FFIN | 1623 | 3072 | 0.125 | 2005-06-02 x1.333, 2011-06-02 x1.5, 2014-06-03 x2, 2019-06-04 x2 |
| TIE | 1831 | 3255 | 0.125 | 2005-09-07 x2, 2006-02-17 x2, 2006-05-16 x2 |
| AAON | 2181 | 3472 | 0.132 | 2007-08-22 x1.5, 2011-06-14 x1.5, 2013-07-03 x1.5, 2014-07-17 x1.5, 2023-08-17 x1.5 |
| SHOO | 1874 | 3258 | 0.132 | 2006-05-26 x1.5, 2010-05-03 x1.5, 2011-06-01 x1.5, 2013-10-02 x1.5, 2018-10-12 x1.5 |
| BF-A | 2853 | 3868 | 0.159 | 2008-10-28 x1.25, 2012-08-13 x1.5, 2016-08-19 x2, 2018-02-07 x1.339, 2018-03-01 x1.25 |

### 2006

True-basis head: CELSIA 8.06e+10, HSBA 4.91e+10, CTRA_old 3.94e+10, GEG_old 9.85e+09, AGR 9.78e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| ORKA | 4916 | 2960 | 1.81e+05 | 2009-01-28 x0.05, 2013-03-05 x0.1667, 2015-09-04 x0.1429, 2019-04-04 x0.05556, 2024-09-03 x0.08333 |
| MBOT | 4860 | 2496 | 1.62e+04 | 2011-07-06 x0.1, 2016-05-09 x0.08333, 2016-11-29 x0.1111, 2018-09-05 x0.06667 |
| CVM | 4855 | 2973 | 7.5e+03 | 2013-09-25 x0.1, 2017-06-15 x0.04, 2025-05-20 x0.03333 |
| GLAE | 4712 | 1603 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| AHT | 4665 | 2144 | 626 | 2013-11-20 x1.49, 2014-11-13 x1.059, 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| CMPC | 3143 | 32 | 500 | 2010-03-31 x0.002 |
| LEU | 4433 | 1501 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| MOSY | 3293 | 143 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| SMSI | 4458 | 2079 | 160 | 2016-08-17 x0.25, 2024-04-11 x0.125, 2026-06-04 x0.2 |
| QMCO | 4606 | 2802 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| VCEL | 4600 | 2772 | 160 | 2010-02-18 x0.125, 2013-10-16 x0.05 |
| ALTO | 3048 | 185 | 105 | 2011-06-08 x0.1429, 2013-05-14 x0.06667 |
| PEIX | 3047 | 184 | 105 | 2011-06-08 x0.1429, 2013-05-13 x0.06667 |
| STCN | 4398 | 2211 | 93.3 | 2007-11-01 x0.1, 2023-06-22 x0.1071 |
| SPEX | 4005 | 1177 | 80.8 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| TROV | 4455 | 2701 | 72 | 2018-06-04 x0.08333, 2019-02-20 x0.1667 |
| CDMO | 4405 | 2986 | 35 | 2009-10-19 x0.2, 2017-07-10 x0.1429 |
| HK | 3774 | 1357 | 34.5 | 2016-09-12 x0.029 |
| VEON | 3016 | 661 | 25 | 2023-03-08 x0.04 |
| AVNW | 4119 | 2394 | 24 | 2007-01-29 x0.25, 2016-06-14 x0.08333, 2021-04-08 x2 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| AKR | 4 | 3133 | 1.36e-05 | 2010-07-06 x25, 2012-10-10 x2, 2013-05-13 x0.9412, 2013-11-22 x156, 2014-12-09 x10 |
| TPL | 1301 | 3873 | 0.0222 | 2007-07-13 x5, 2024-03-27 x3, 2025-12-23 x3 |
| BHRB | 2125 | 4229 | 0.025 | 2022-11-15 x40 |
| NPSNY | 1581 | 3960 | 0.0274 | 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| SGU | 1368 | 3503 | 0.05 | 2013-12-23 x20 |
| CSWC | 2457 | 3916 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| DASTY | 2170 | 3707 | 0.1 | 2014-07-23 x2, 2021-07-15 x5 |
| COKE | 2323 | 3810 | 0.1 | 2025-05-27 x10 |
| ENS | 1638 | 3314 | 0.1 | 2011-10-20 x10 |
| MVCO | 2252 | 3755 | 0.1 | 2023-09-19 x10 |
| GEL | 2519 | 3877 | 0.11 | 2011-04-12 x10, 2013-04-04 x0.9091 |
| CRVL | 2551 | 3886 | 0.111 | 2006-12-11 x1.5, 2013-06-27 x2, 2024-12-26 x3 |
| NEOG | 2605 | 3906 | 0.111 | 2007-09-05 x1.5, 2009-12-16 x1.5, 2013-10-31 x1.5, 2018-01-02 x1.333, 2021-06-07 x2 |
| ATLKY | 2592 | 3856 | 0.125 | 2007-05-30 x2, 2022-05-23 x4 |
| EXPO | 2092 | 3517 | 0.125 | 2006-06-12 x2, 2015-06-05 x2, 2018-06-08 x2 |
| NJDCY | 2288 | 3671 | 0.125 | 2014-04-08 x2, 2020-04-09 x2, 2024-10-09 x2 |
| UGP | 1973 | 3424 | 0.125 | 2011-02-25 x4, 2019-04-25 x2 |
| AAON | 2222 | 3583 | 0.132 | 2007-08-22 x1.5, 2011-06-14 x1.5, 2013-07-03 x1.5, 2014-07-17 x1.5, 2023-08-17 x1.5 |
| BF-A | 2652 | 3770 | 0.159 | 2008-10-28 x1.25, 2012-08-13 x1.5, 2016-08-19 x2, 2018-02-07 x1.339, 2018-03-01 x1.25 |
| BRFS | 1997 | 3271 | 0.167 | 2010-04-08 x4 |

### 2007

True-basis head: HSBA 6.55e+10, CELSIA 4.12e+10, CTRA_old 1.56e+10, LAN 8.08e+09, GEG_old 4.22e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| ORKA | 4900 | 1027 | 1.81e+05 | 2009-01-28 x0.05, 2013-03-05 x0.1667, 2015-09-04 x0.1429, 2019-04-04 x0.05556, 2024-09-03 x0.08333 |
| MBOT | 4888 | 2712 | 1.62e+04 | 2011-07-06 x0.1, 2016-05-09 x0.08333, 2016-11-29 x0.1111, 2018-09-05 x0.06667 |
| ARMP | 4876 | 2947 | 7e+03 | 2015-08-07 x0.02, 2017-04-25 x0.1, 2019-05-10 x0.07143 |
| CTIC | 4858 | 2755 | 6.48e+03 | 2008-09-02 x0.1, 2011-05-16 x0.1667, 2012-09-04 x0.2, 2017-01-03 x0.1 |
| GLAE | 4720 | 1470 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| AHT | 4582 | 1507 | 626 | 2013-11-20 x1.49, 2014-11-13 x1.059, 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| CMPC | 3158 | 32 | 500 | 2010-03-31 x0.002 |
| SPR | 4287 | 948 | 300 | 2011-06-08 x0.3333, 2013-12-20 x0.01 |
| XOMA | 4700 | 2829 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| LEU | 4124 | 728 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| MOSY | 3479 | 203 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| AMRN | 4612 | 2592 | 200 | 2008-01-18 x0.1, 2025-04-11 x0.05 |
| SMSI | 4228 | 1242 | 160 | 2016-08-17 x0.25, 2024-04-11 x0.125, 2026-06-04 x0.2 |
| AGEN | 4499 | 2446 | 120 | 2011-10-03 x0.1667, 2024-04-12 x0.05 |
| BLU | 4028 | 1101 | 108 | 2012-05-29 x0.03333, 2019-08-19 x0.2778 |
| ALTO | 4261 | 1687 | 105 | 2011-06-08 x0.1429, 2013-05-14 x0.06667 |
| PEIX | 4259 | 1681 | 105 | 2011-06-08 x0.1429, 2013-05-13 x0.06667 |
| COHN | 4404 | 2277 | 100 | 2009-12-17 x0.1, 2017-09-05 x0.1 |
| STCN | 4002 | 1158 | 93.3 | 2007-11-01 x0.1, 2023-06-22 x0.1071 |
| SPEX | 4120 | 1571 | 80.7 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| FBPI | 2393 | 4742 | 0.00333 | 2008-05-12 x300 |
| TPL | 974 | 3652 | 0.0222 | 2007-07-13 x5, 2024-03-27 x3, 2025-12-23 x3 |
| BHRB | 2695 | 4415 | 0.025 | 2022-11-15 x40 |
| NPSNY | 1463 | 3891 | 0.0274 | 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| SGU | 1126 | 3338 | 0.05 | 2013-12-23 x20 |
| CSWC | 1440 | 3264 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| DASTY | 1786 | 3449 | 0.1 | 2014-07-23 x2, 2021-07-15 x5 |
| BZLFY | 2611 | 3949 | 0.1 | 2013-11-27 x5, 2024-12-09 x2 |
| COKE | 1920 | 3523 | 0.1 | 2025-05-27 x10 |
| MVCO | 1539 | 3286 | 0.1 | 2023-09-19 x10 |
| SMCI | 1459 | 3230 | 0.1 | 2024-10-01 x10 |
| GEL | 1363 | 3094 | 0.11 | 2011-04-12 x10, 2013-04-04 x0.9091 |
| NEOG | 2662 | 3933 | 0.111 | 2007-09-05 x1.5, 2009-12-16 x1.5, 2013-10-31 x1.5, 2018-01-02 x1.333, 2021-06-07 x2 |
| NJDCY | 2581 | 3851 | 0.125 | 2014-04-08 x2, 2020-04-09 x2, 2024-10-09 x2 |
| ATLKY | 2953 | 4037 | 0.127 | 2022-05-23 x4 |
| AAON | 1996 | 3460 | 0.132 | 2007-08-22 x1.5, 2011-06-14 x1.5, 2013-07-03 x1.5, 2014-07-17 x1.5, 2023-08-17 x1.5 |
| CRVL | 1681 | 3068 | 0.167 | 2013-06-27 x2, 2024-12-26 x3 |
| SHEN | 2844 | 3882 | 0.167 | 2007-08-20 x3, 2016-01-05 x2 |
| FFIN | 1884 | 3245 | 0.167 | 2011-06-02 x1.5, 2014-06-03 x2, 2019-06-04 x2 |
| REX | 2966 | 3940 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |

### 2008

True-basis head: HSBA 3.87e+10, CELSIA 2.7e+10, SOBI 1.72e+10, CTRA_old 9.02e+09, SBER 8.66e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| GLAE | 4696 | 2084 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| YDKG | 4716 | 2262 | 2e+03 | 2019-04-11 x0.2, 2022-12-12 x0.25, 2025-11-14 x0.01 |
| AHT | 4563 | 2086 | 626 | 2013-11-20 x1.49, 2014-11-13 x1.059, 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| SPR | 3979 | 863 | 300 | 2011-06-08 x0.3333, 2013-12-20 x0.01 |
| XOMA | 4605 | 2787 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| LEU | 4163 | 1305 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| MOSY | 3725 | 672 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| OPTT | 3395 | 332 | 200 | 2015-10-29 x0.1, 2019-03-12 x0.05 |
| QMCO | 4545 | 2920 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| SMSI | 4426 | 2447 | 160 | 2016-08-17 x0.25, 2024-04-11 x0.125, 2026-06-04 x0.2 |
| AGEN | 4497 | 2928 | 120 | 2011-10-03 x0.1667, 2024-04-12 x0.05 |
| ALTO | 4128 | 1930 | 105 | 2011-06-08 x0.1429, 2013-05-14 x0.06667 |
| PEIX | 4127 | 1929 | 105 | 2011-06-08 x0.1429, 2013-05-13 x0.06667 |
| COHN | 4376 | 2606 | 100 | 2009-12-17 x0.1, 2017-09-05 x0.1 |
| ESEA | 4271 | 2414 | 80 | 2015-07-23 x0.1, 2019-12-19 x0.125 |
| SBLK | 4194 | 2287 | 73.1 | 2008-11-25 x1.026, 2012-10-15 x0.06667, 2016-06-20 x0.2 |
| CHNR | 4080 | 2441 | 40 | 2023-04-03 x0.2, 2025-06-13 x0.125 |
| HK | 3583 | 1499 | 34.5 | 2016-09-12 x0.029 |
| TZOO | 4125 | 2890 | 25 | 2013-11-07 x0.04 |
| CAMP_old | 4018 | 2653 | 23 | 2024-02-02 x0.04348 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| FBPI | 1946 | 4413 | 0.00498 |  |
| AFC | 1228 | 3873 | 0.01 | 2011-07-11 x10, 2014-08-01 x10 |
| BHRB | 2790 | 4340 | 0.025 | 2022-11-15 x40 |
| ORN | 744 | 3084 | 0.025 | 2012-12-21 x40 |
| NPSNY | 1723 | 3778 | 0.0274 | 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| SGU | 1952 | 3677 | 0.05 | 2013-12-23 x20 |
| CSWC | 1923 | 3413 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| SMCI | 1559 | 3080 | 0.1 | 2024-10-01 x10 |
| BZLFY | 2553 | 3775 | 0.1 | 2013-11-27 x5, 2024-12-09 x2 |
| COKE | 1808 | 3285 | 0.1 | 2025-05-27 x10 |
| DASTY | 1994 | 3427 | 0.1 | 2014-07-23 x2, 2021-07-15 x5 |
| GEL | 1654 | 3106 | 0.11 | 2011-04-12 x10, 2013-04-04 x0.9091 |
| TPL | 2241 | 3549 | 0.111 | 2024-03-27 x3, 2025-12-23 x3 |
| NJDCY | 1827 | 3189 | 0.125 | 2014-04-08 x2, 2020-04-09 x2, 2024-10-09 x2 |
| REX | 1839 | 3027 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |
| NEOG | 2092 | 3253 | 0.167 | 2009-12-16 x1.5, 2013-10-31 x1.5, 2018-01-02 x1.333, 2021-06-07 x2 |
| AAON | 1931 | 3006 | 0.198 | 2011-06-14 x1.5, 2013-07-03 x1.5, 2014-07-17 x1.5, 2023-08-17 x1.5 |
| SNEX | 2929 | 3742 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| ICAGY | 2751 | 3626 | 0.2 | 2010-09-01 x2, 2016-10-25 x2.499 |
| HEI-A | 1990 | 3028 | 0.21 | 2010-04-27 x1.25, 2011-04-26 x1.25, 2012-04-25 x1.25, 2013-10-23 x1.25, 2017-04-19 x1.25, 2018-01-18 x1.25, 2018-06-28 x1.25 |

### 2009

True-basis head: HSBA 3.16e+10, CELSIA 2.58e+10, SBER 2.07e+10, MGDDY 8.93e+09, CTRA_old 5.94e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| MBOT | 4731 | 2101 | 1.62e+04 | 2011-07-06 x0.1, 2016-05-09 x0.08333, 2016-11-29 x0.1111, 2018-09-05 x0.06667 |
| SNOA | 4677 | 2077 | 6.3e+03 | 2013-04-01 x0.1429, 2016-06-27 x0.2, 2019-06-20 x0.1111, 2024-08-30 x0.05 |
| ACHV | 4634 | 2332 | 2.2e+03 | 2017-08-03 x0.09091, 2018-05-24 x0.1, 2020-07-31 x0.05 |
| GLAE | 4638 | 2424 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| AHT | 4509 | 2300 | 626 | 2013-11-20 x1.49, 2014-11-13 x1.059, 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| CTIC | 3855 | 986 | 300 | 2011-05-16 x0.1667, 2012-09-04 x0.2, 2017-01-03 x0.1 |
| XOMA | 4447 | 2461 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| SPR | 4101 | 1406 | 300 | 2011-06-08 x0.3333, 2013-12-20 x0.01 |
| LEU | 4063 | 1364 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| MOSY | 3801 | 1112 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| OPTT | 3415 | 583 | 200 | 2015-10-29 x0.1, 2019-03-12 x0.05 |
| SMSI | 4268 | 2232 | 160 | 2016-08-17 x0.25, 2024-04-11 x0.125, 2026-06-04 x0.2 |
| QMCO | 4282 | 2264 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| AIMI | 3941 | 1715 | 99.9 | 2025-06-12 x0.01, 2026-01-09 x1.001 |
| SPEX | 4388 | 2988 | 80.8 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| ADXS | 3881 | 1765 | 80 | 2022-06-06 x0.0125 |
| ESEA | 4330 | 2864 | 80 | 2015-07-23 x0.1, 2019-12-19 x0.125 |
| SBLK | 4130 | 2299 | 75 | 2012-10-15 x0.06667, 2016-06-20 x0.2 |
| AWEB | 4049 | 2374 | 50 | 2012-07-05 x0.02 |
| EGIOQ | 4233 | 2971 | 40 | 2024-03-01 x0.025 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| AFC | 1250 | 3704 | 0.01 | 2011-07-11 x10, 2014-08-01 x10 |
| NPPXF | 1139 | 3292 | 0.02 | 2015-06-26 x2, 2023-06-29 x25 |
| BHRB | 2258 | 4038 | 0.025 | 2022-11-15 x40 |
| NPSNY | 2260 | 4008 | 0.0274 | 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| SGU | 1594 | 3281 | 0.05 | 2013-12-23 x20 |
| BZLFY | 2723 | 3838 | 0.1 | 2013-11-27 x5, 2024-12-09 x2 |
| ABR | 1697 | 3049 | 0.1 | 2012-08-30 x10 |
| SMCI | 1778 | 3102 | 0.1 | 2024-10-01 x10 |
| TPL | 2249 | 3472 | 0.111 | 2024-03-27 x3, 2025-12-23 x3 |
| CRVL | 2352 | 3333 | 0.167 | 2013-06-27 x2, 2024-12-26 x3 |
| REX | 2375 | 3351 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |
| SNEX | 2599 | 3498 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| BF-A | 2746 | 3583 | 0.199 | 2012-08-13 x1.5, 2016-08-19 x2, 2018-02-07 x1.339, 2018-03-01 x1.25 |
| EXLS | 2388 | 3268 | 0.2 | 2023-08-02 x5 |
| HACBY | 2994 | 3781 | 0.2 | 2025-01-10 x5 |
| MURGY | 2139 | 3092 | 0.2 | 2024-10-23 x5 |
| USLM | 2666 | 3526 | 0.2 | 2024-07-15 x5 |
| ICAGY | 2593 | 3481 | 0.2 | 2010-09-01 x2, 2016-10-25 x2.499 |
| ATEYY | 2903 | 3609 | 0.25 | 2023-10-11 x4 |
| ATLKY | 2958 | 3659 | 0.25 | 2022-05-23 x4 |

### 2010

True-basis head: HSBA 2.91e+10, SBER 1.82e+10, SOBI 8.36e+09, CTRA_old 7.08e+09, AAPL 6.65e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| ORKA | 4711 | 2077 | 9.07e+03 | 2013-03-05 x0.1667, 2015-09-04 x0.1429, 2019-04-04 x0.05556, 2024-09-03 x0.08333 |
| GLAE | 4694 | 2913 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| DCTH | 4247 | 1062 | 700 | 2019-12-24 x0.001429 |
| AHT | 4519 | 2035 | 626 | 2013-11-20 x1.49, 2014-11-13 x1.059, 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| TAOP | 4618 | 2895 | 600 | 2012-03-02 x0.5, 2023-08-01 x0.1, 2025-05-29 x0.03333 |
| IRD | 4494 | 2061 | 480 | 2017-05-05 x0.1, 2019-04-12 x0.08333, 2020-11-06 x0.25 |
| AIFU | 4432 | 1932 | 400 | 2025-05-21 x0.05, 2026-06-15 x0.05 |
| XOMA | 4536 | 2681 | 300 | 2010-08-18 x0.06667, 2016-10-18 x0.05 |
| SPR | 4111 | 1197 | 300 | 2011-06-08 x0.3333, 2013-12-20 x0.01 |
| CTIC | 4440 | 2156 | 300 | 2011-05-16 x0.1667, 2012-09-04 x0.2, 2017-01-03 x0.1 |
| LEU | 4238 | 1579 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| MOSY | 3920 | 995 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| OPTT | 3647 | 656 | 200 | 2015-10-29 x0.1, 2019-03-12 x0.05 |
| QMCO | 4325 | 2181 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| SMSI | 4434 | 2576 | 160 | 2016-08-17 x0.25, 2024-04-11 x0.125, 2026-06-04 x0.2 |
| AGIG | 4216 | 1989 | 125 | 2020-08-03 x0.08, 2025-06-09 x0.1 |
| HUSA | 4217 | 1990 | 125 | 2020-08-03 x0.08, 2025-06-09 x0.1 |
| AGEN | 4294 | 2290 | 120 | 2011-10-03 x0.1667, 2024-04-12 x0.05 |
| SVRA | 4407 | 2768 | 106 | 2017-04-28 x0.01429 |
| PEIX | 4372 | 2653 | 105 | 2011-06-08 x0.1429, 2013-05-13 x0.06667 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| AFC | 765 | 3471 | 0.01 | 2011-07-11 x10, 2014-08-01 x10 |
| NPPXF | 1654 | 3927 | 0.02 | 2015-06-26 x2, 2023-06-29 x25 |
| BHRB | 2374 | 4193 | 0.025 | 2022-11-15 x40 |
| NPSNY | 2282 | 4129 | 0.0274 | 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| SGU | 1756 | 3609 | 0.05 | 2013-12-23 x20 |
| KDDIY | 1985 | 3535 | 0.0833 | 2011-08-04 x4, 2013-04-10 x2, 2015-04-02 x1.5 |
| CSWC | 2272 | 3695 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| COKE | 1579 | 3072 | 0.1 | 2025-05-27 x10 |
| DASTY | 2067 | 3509 | 0.1 | 2014-07-23 x2, 2021-07-15 x5 |
| ABR | 1752 | 3246 | 0.1 | 2012-08-30 x10 |
| BZLFY | 1959 | 3407 | 0.1 | 2013-11-27 x5, 2024-12-09 x2 |
| UHAL | 1619 | 3102 | 0.1 | 2022-11-10 x10 |
| TPL | 2545 | 3806 | 0.111 | 2024-03-27 x3, 2025-12-23 x3 |
| NJDCY | 1671 | 3042 | 0.125 | 2014-04-08 x2, 2020-04-09 x2, 2024-10-09 x2 |
| CRVL | 2165 | 3329 | 0.167 | 2013-06-27 x2, 2024-12-26 x3 |
| FUJIY | 2002 | 3171 | 0.167 | 2024-04-02 x6 |
| REX | 2587 | 3650 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |
| SNEX | 2175 | 3238 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| IX | 2463 | 3453 | 0.2 | 2025-02-28 x5 |
| MURGY | 2483 | 3467 | 0.2 | 2024-10-23 x5 |

### 2011

True-basis head: LHC-UN 1.71e+10, LHC-WS 1.71e+10, HSBA 1.69e+10, SBER 1.51e+10, MEL 8.49e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| ORKA | 4809 | 2910 | 9.07e+03 | 2013-03-05 x0.1667, 2015-09-04 x0.1429, 2019-04-04 x0.05556, 2024-09-03 x0.08333 |
| GLAE | 4738 | 2949 | 2e+03 | 2017-02-22 x0.1, 2019-08-23 x0.005 |
| DCTH | 4561 | 2054 | 700 | 2019-12-24 x0.001429 |
| AHT | 4600 | 2315 | 626 | 2013-11-20 x1.49, 2014-11-13 x1.059, 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| AIFU | 4458 | 1926 | 400 | 2025-05-21 x0.05, 2026-06-15 x0.05 |
| SPR | 4106 | 1077 | 300 | 2011-06-08 x0.3333, 2013-12-20 x0.01 |
| LEU | 4411 | 1999 | 275 | 2013-07-02 x0.04, 2014-09-30 x0.091 |
| OPTT | 3975 | 1037 | 200 | 2015-10-29 x0.1, 2019-03-12 x0.05 |
| MOSY | 3612 | 506 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| SMSI | 4405 | 2347 | 160 | 2016-08-17 x0.25, 2024-04-11 x0.125, 2026-06-04 x0.2 |
| QMCO | 4240 | 1826 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| AGIG | 4456 | 2750 | 125 | 2020-08-03 x0.08, 2025-06-09 x0.1 |
| HUSA | 4457 | 2751 | 125 | 2020-08-03 x0.08, 2025-06-09 x0.1 |
| CTIC | 4283 | 2376 | 85.3 | 2012-09-04 x0.2, 2017-01-03 x0.1 |
| SPEX | 4310 | 2489 | 80.8 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| ADXS | 3911 | 1465 | 80 | 2022-06-06 x0.0125 |
| GURE | 3986 | 1932 | 50 | 2020-01-28 x0.2, 2025-10-27 x0.1 |
| ARR | 3683 | 1489 | 40 | 2015-08-03 x0.125, 2023-10-02 x0.2 |
| EGIOQ | 3725 | 1548 | 40 | 2024-03-01 x0.025 |
| ANIP | 3980 | 2129 | 36 | 2012-06-04 x0.1667, 2013-07-18 x0.1667 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| AFC | 831 | 3635 | 0.01 | 2011-07-11 x10, 2014-08-01 x10 |
| SSC | 2113 | 4279 | 0.0133 | 2012-02-13 x75 |
| NPPXF | 1334 | 3748 | 0.02 | 2015-06-26 x2, 2023-06-29 x25 |
| BHRB | 2074 | 4093 | 0.025 | 2022-11-15 x40 |
| NPSNY | 2247 | 4129 | 0.0274 | 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| SGU | 1844 | 3717 | 0.05 | 2013-12-23 x20 |
| CSWC | 1947 | 3503 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| BZLFY | 2284 | 3705 | 0.1 | 2013-11-27 x5, 2024-12-09 x2 |
| DASTY | 2021 | 3515 | 0.1 | 2014-07-23 x2, 2021-07-15 x5 |
| ARC | 1638 | 3174 | 0.1 | 2014-07-29 x10 |
| ABR | 2655 | 3901 | 0.1 | 2012-08-30 x10 |
| TPL | 2192 | 3607 | 0.111 | 2024-03-27 x3, 2025-12-23 x3 |
| NJDCY | 1826 | 3239 | 0.125 | 2014-04-08 x2, 2020-04-09 x2, 2024-10-09 x2 |
| CRVL | 1878 | 3101 | 0.167 | 2013-06-27 x2, 2024-12-26 x3 |
| FUJIY | 1968 | 3197 | 0.167 | 2024-04-02 x6 |
| TAL | 2317 | 3465 | 0.167 | 2017-08-16 x6 |
| BYDDY | 2495 | 3604 | 0.167 | 2025-07-30 x6 |
| REX | 2725 | 3750 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |
| SNEX | 2070 | 3188 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| AAON | 2083 | 3195 | 0.198 | 2011-06-14 x1.5, 2013-07-03 x1.5, 2014-07-17 x1.5, 2023-08-17 x1.5 |

### 2012

True-basis head: CTRA_old 1.98e+10, LHC-UN 1.47e+10, LHC-WS 1.47e+10, SBER 1.47e+10, AAPL 1.33e+10

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| SLS | 4798 | 2550 | 3e+04 | 2016-11-14 x0.05, 2018-01-02 x0.03333, 2019-11-08 x0.02 |
| XWEL | 4703 | 2428 | 4e+03 | 2015-11-30 x0.1, 2019-02-25 x0.05, 2023-09-28 x0.05 |
| DCTH | 4645 | 2965 | 700 | 2019-12-24 x0.001429 |
| AHT | 4510 | 2091 | 626 | 2013-11-20 x1.49, 2014-11-13 x1.059, 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| GNUS | 4540 | 2799 | 300 | 2014-04-07 x0.01, 2016-11-09 x0.3333 |
| XSPA | 4424 | 2427 | 200 | 2015-11-30 x0.1, 2019-02-25 x0.05 |
| MOSY | 3611 | 581 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| OPTT | 4074 | 1429 | 200 | 2015-10-29 x0.1, 2019-03-12 x0.05 |
| QMCO | 4420 | 2561 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| AGIG | 4406 | 2648 | 125 | 2020-08-03 x0.08, 2025-06-09 x0.1 |
| HUSA | 4407 | 2649 | 125 | 2020-08-03 x0.08, 2025-06-09 x0.1 |
| SPR | 3792 | 1227 | 100 | 2013-12-20 x0.01 |
| AIKI | 4427 | 2987 | 80.7 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| ADXS | 3978 | 1764 | 80 | 2022-06-06 x0.0125 |
| TROV | 3957 | 1771 | 72 | 2018-06-04 x0.08333, 2019-02-20 x0.1667 |
| CTIC | 4256 | 2802 | 50 | 2012-09-04 x0.2, 2017-01-03 x0.1 |
| ARR | 3409 | 1233 | 40 | 2015-08-03 x0.125, 2023-10-02 x0.2 |
| EGIOQ | 4195 | 2781 | 40 | 2024-03-01 x0.025 |
| ANIP | 4251 | 2982 | 36 | 2012-06-04 x0.1667, 2013-07-18 x0.1667 |
| MDGL | 4226 | 2955 | 35 | 2016-07-25 x0.02857 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| NPPXF | 2956 | 4442 | 0.02 | 2015-06-26 x2, 2023-06-29 x25 |
| ORN | 1066 | 3271 | 0.025 | 2012-12-21 x40 |
| BHRB | 2278 | 4117 | 0.025 | 2022-11-15 x40 |
| NPSNY | 1016 | 3163 | 0.0274 | 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| SGU | 2085 | 3814 | 0.05 | 2013-12-23 x20 |
| CSWC | 1954 | 3416 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| ARC | 2092 | 3500 | 0.1 | 2014-07-29 x10 |
| ABR | 2542 | 3819 | 0.1 | 2012-08-30 x10 |
| BZLFY | 2224 | 3597 | 0.1 | 2013-11-27 x5, 2024-12-09 x2 |
| VIPS | 2021 | 3443 | 0.1 | 2014-11-04 x10 |
| COKE | 1651 | 3096 | 0.1 | 2025-05-27 x10 |
| AFC | 2407 | 3736 | 0.1 | 2014-08-01 x10 |
| TPL | 1740 | 3104 | 0.111 | 2024-03-27 x3, 2025-12-23 x3 |
| MGYOY | 1744 | 3046 | 0.125 | 2017-10-12 x8 |
| NJDCY | 2280 | 3528 | 0.125 | 2014-04-08 x2, 2020-04-09 x2, 2024-10-09 x2 |
| CRVL | 2394 | 3463 | 0.167 | 2013-06-27 x2, 2024-12-26 x3 |
| TAL | 2799 | 3792 | 0.167 | 2017-08-16 x6 |
| ALPMY | 2772 | 3706 | 0.2 | 2013-05-13 x4, 2014-04-02 x1.25 |
| HACBY | 2498 | 3451 | 0.2 | 2025-01-10 x5 |
| USLM | 2712 | 3660 | 0.2 | 2024-07-15 x5 |

### 2013

True-basis head: CTRA_old 2.72e+10, HSBA 1.52e+10, RICO 9.91e+09, MEL 9.75e+09, LHC-UN 8.45e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| SLS | 4843 | 2215 | 3e+04 | 2016-11-14 x0.05, 2018-01-02 x0.03333, 2019-11-08 x0.02 |
| XWEL | 4793 | 2971 | 4e+03 | 2015-11-30 x0.1, 2019-02-25 x0.05, 2023-09-28 x0.05 |
| IMNN | 4593 | 2023 | 946 | 2013-10-29 x0.222, 2017-05-30 x0.07143, 2022-03-01 x0.06667 |
| DCTH | 4637 | 2645 | 700 | 2019-12-24 x0.001429 |
| AHT | 4614 | 2512 | 626 | 2013-11-20 x1.49, 2014-11-13 x1.059, 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| VIVS | 4586 | 2912 | 240 | 2020-08-19 x0.05, 2025-03-21 x0.08333 |
| MOSY | 3251 | 199 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| OPTT | 4155 | 1404 | 200 | 2015-10-29 x0.1, 2019-03-12 x0.05 |
| XSPA | 4573 | 2968 | 200 | 2015-11-30 x0.1, 2019-02-25 x0.05 |
| QMCO | 4494 | 2732 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| SPR | 3808 | 1113 | 100 | 2013-12-20 x0.01 |
| ADXS | 4054 | 1757 | 80 | 2022-06-06 x0.0125 |
| TROV | 3538 | 935 | 72 | 2018-06-04 x0.08333, 2019-02-20 x0.1667 |
| LOTE | 4261 | 2478 | 68.8 | 2013-06-05 x4, 2016-10-31 x0.003636 |
| NBR | 3077 | 646 | 50 | 2020-04-23 x0.02 |
| ARR | 3226 | 905 | 40 | 2015-08-03 x0.125, 2023-10-02 x0.2 |
| MDGL | 3931 | 2017 | 35 | 2016-07-25 x0.02857 |
| HK | 3914 | 1987 | 34.5 | 2016-09-12 x0.029 |
| TDW | 3197 | 992 | 32.3 | 2017-08-01 x0.031 |
| VEON | 3428 | 1433 | 25 | 2023-03-08 x0.04 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| NPPXF | 814 | 3271 | 0.02 | 2015-06-26 x2, 2023-06-29 x25 |
| BHRB | 2216 | 4147 | 0.025 | 2022-11-15 x40 |
| NPSNY | 1015 | 3303 | 0.0274 | 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| SGU | 1991 | 3801 | 0.05 | 2013-12-23 x20 |
| CSWC | 2022 | 3535 | 0.0918 | 2013-08-16 x4, 2015-10-01 x2.724 |
| BZLFY | 2448 | 3783 | 0.1 | 2013-11-27 x5, 2024-12-09 x2 |
| AACAY | 2803 | 4001 | 0.1 | 2018-02-26 x10 |
| ARC | 1873 | 3363 | 0.1 | 2014-07-29 x10 |
| COKE | 1822 | 3321 | 0.1 | 2025-05-27 x10 |
| SMCI | 1503 | 3024 | 0.1 | 2024-10-01 x10 |
| AFC | 2321 | 3684 | 0.1 | 2014-08-01 x10 |
| DASTY | 1584 | 3117 | 0.1 | 2014-07-23 x2, 2021-07-15 x5 |
| TPL | 1943 | 3362 | 0.111 | 2024-03-27 x3, 2025-12-23 x3 |
| CRVL | 2342 | 3456 | 0.167 | 2013-06-27 x2, 2024-12-26 x3 |
| BYDDY | 2927 | 3889 | 0.167 | 2025-07-30 x6 |
| TAL | 2039 | 3222 | 0.167 | 2017-08-16 x6 |
| FUJIY | 2119 | 3286 | 0.167 | 2024-04-02 x6 |
| REX | 2393 | 3495 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |
| SNEX | 2285 | 3307 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| DQ | 2726 | 3652 | 0.2 | 2020-11-17 x5 |

### 2014

True-basis head: CTRA_old 3.26e+10, HSBA 1.66e+10, SBER 1.33e+10, LHC-UN 1.06e+10, LHC-WS 1.06e+10

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| SLS | 5017 | 2286 | 3e+04 | 2016-11-14 x0.05, 2018-01-02 x0.03333, 2019-11-08 x0.02 |
| DFFN | 4780 | 663 | 1.12e+04 | 2016-08-19 x0.1, 2018-12-14 x0.06667, 2022-04-19 x0.02, 2023-08-17 x0.6667 |
| DOMH | 4778 | 2129 | 1.23e+03 | 2016-03-04 x0.05263, 2019-05-10 x0.235, 2019-10-28 x1.113, 2022-06-07 x0.05882 |
| AHT | 4750 | 2096 | 933 | 2014-11-13 x1.059, 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| IRD | 4765 | 2761 | 480 | 2017-05-05 x0.1, 2019-04-12 x0.08333, 2020-11-06 x0.25 |
| VIVS | 4537 | 2032 | 240 | 2020-08-19 x0.05, 2025-03-21 x0.08333 |
| MOSY | 3706 | 337 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| OPTT | 3137 | 115 | 200 | 2015-10-29 x0.1, 2019-03-12 x0.05 |
| NETI | 4506 | 2467 | 118 | 2015-12-31 x0.08333, 2019-11-14 x1.014, 2020-04-07 x0.1 |
| TROV | 4035 | 1366 | 72 | 2018-06-04 x0.08333, 2019-02-20 x0.1667 |
| ATHE | 4453 | 2744 | 60 | 2016-03-24 x0.1667, 2023-01-09 x0.1 |
| NBR | 3048 | 484 | 50 | 2020-04-23 x0.02 |
| AKER | 4407 | 2756 | 48 | 2019-11-25 x0.04167, 2021-04-19 x0.5 |
| INO | 4095 | 1809 | 48 | 2014-06-06 x0.25, 2024-01-25 x0.08333 |
| ARR | 4026 | 1768 | 40 | 2015-08-03 x0.125, 2023-10-02 x0.2 |
| MDGL | 4211 | 2366 | 35 | 2016-07-25 x0.02857 |
| HK | 4221 | 2403 | 34.5 | 2016-09-12 x0.029 |
| TDW | 3784 | 1480 | 32.3 | 2017-08-01 x0.031 |
| VEON | 3517 | 1327 | 25 | 2023-03-08 x0.04 |
| AMRN | 4271 | 2965 | 20 | 2025-04-11 x0.05 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| NPPXF | 2110 | 4337 | 0.02 | 2015-06-26 x2, 2023-06-29 x25 |
| NPSNY | 1736 | 4090 | 0.0274 | 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| DKILY | 2339 | 4171 | 0.05 | 2018-03-14 x20 |
| COKE | 1349 | 3043 | 0.1 | 2025-05-27 x10 |
| DNBBY | 1608 | 3286 | 0.1 | 2017-06-15 x10 |
| AFC | 2310 | 3850 | 0.1 | 2014-08-01 x10 |
| ARC | 1879 | 3496 | 0.1 | 2014-07-29 x10 |
| DASTY | 1860 | 3481 | 0.1 | 2014-07-23 x2, 2021-07-15 x5 |
| HTHIY | 1467 | 3168 | 0.1 | 2024-07-10 x5, 2025-02-19 x2 |
| TPL | 1791 | 3359 | 0.111 | 2024-03-27 x3, 2025-12-23 x3 |
| FUJIY | 2758 | 3906 | 0.167 | 2024-04-02 x6 |
| PATK | 1845 | 3054 | 0.198 | 2015-06-01 x1.5, 2017-12-11 x1.5, 2018-01-11 x1.5, 2024-12-16 x1.5 |
| SNEX | 2318 | 3468 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| IX | 2433 | 3548 | 0.2 | 2025-02-28 x5 |
| NTDOY | 2151 | 3322 | 0.2 | 2022-10-04 x5 |
| MURGY | 2695 | 3763 | 0.2 | 2024-10-23 x5 |
| USLM | 2830 | 3859 | 0.2 | 2024-07-15 x5 |
| NJDCY | 2694 | 3694 | 0.224 | 2020-04-09 x2, 2024-10-09 x2 |
| CLMB | 2812 | 3735 | 0.25 | 2026-03-23 x4 |
| IDEXY | 2737 | 3661 | 0.25 | 2014-07-30 x2, 2025-06-25 x2 |

### 2015

True-basis head: HSBA 1.79e+10, LHC-UN 1.75e+10, LHC-WS 1.75e+10, CTRA_old 1.63e+10, RICO 1.2e+10

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| SLS | 5127 | 2777 | 3e+04 | 2016-11-14 x0.05, 2018-01-02 x0.03333, 2019-11-08 x0.02 |
| DFFN | 4902 | 884 | 1.12e+04 | 2016-08-19 x0.1, 2018-12-14 x0.06667, 2022-04-19 x0.02, 2023-08-17 x0.6667 |
| TPST | 4831 | 1323 | 2.92e+03 | 2018-12-10 x0.06667, 2021-06-28 x0.06667, 2025-04-09 x0.07692 |
| YDKG | 4898 | 2106 | 2e+03 | 2019-04-11 x0.2, 2022-12-12 x0.25, 2025-11-14 x0.01 |
| AHT | 4869 | 2404 | 988 | 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| GEVO | 4640 | 1715 | 400 | 2017-01-06 x0.05, 2018-06-04 x0.05 |
| VIVS | 4657 | 2196 | 240 | 2020-08-19 x0.05, 2025-03-21 x0.08333 |
| KZIA | 4667 | 2384 | 200 | 2017-07-14 x0.25, 2024-10-28 x0.1, 2025-04-17 x0.2 |
| OPTT | 4378 | 1369 | 200 | 2015-10-29 x0.1, 2019-03-12 x0.05 |
| MOSY | 4254 | 1071 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| QMCO | 4699 | 2686 | 160 | 2017-04-19 x0.125, 2024-08-27 x0.05 |
| RGLS | 4506 | 2167 | 120 | 2018-10-04 x0.08333, 2022-06-29 x0.1 |
| SPEX | 4433 | 2235 | 80.8 | 2016-03-04 x0.05263, 2019-05-10 x0.2353 |
| CRDF | 4531 | 2646 | 72 | 2018-06-04 x0.08333, 2019-02-20 x0.1667 |
| NBR | 3109 | 478 | 50 | 2020-04-23 x0.02 |
| AKER | 4345 | 2356 | 48 | 2019-11-25 x0.04167, 2021-04-19 x0.5 |
| ARR | 4300 | 2391 | 40 | 2015-08-03 x0.125, 2023-10-02 x0.2 |
| MDGL | 4398 | 2750 | 35 | 2016-07-25 x0.02857 |
| HK | 4009 | 1789 | 34.5 | 2016-09-12 x0.029 |
| TDW | 3479 | 1045 | 32.3 | 2017-08-01 x0.031 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| NPPXF | 1785 | 4264 | 0.02 | 2015-06-26 x2, 2023-06-29 x25 |
| NPSNY | 1297 | 3830 | 0.0274 | 2016-03-16 x10, 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| DKILY | 2502 | 4268 | 0.05 | 2018-03-14 x20 |
| COKE | 1620 | 3365 | 0.1 | 2025-05-27 x10 |
| DNBBY | 2884 | 4229 | 0.1 | 2017-06-15 x10 |
| HTHIY | 1339 | 3090 | 0.1 | 2024-07-10 x5, 2025-02-19 x2 |
| TPL | 1751 | 3419 | 0.111 | 2024-03-27 x3, 2025-12-23 x3 |
| BYDDY | 2758 | 3938 | 0.167 | 2025-07-30 x6 |
| DQ | 1737 | 3003 | 0.2 | 2020-11-17 x5 |
| JHX | 2851 | 3908 | 0.2 | 2015-09-22 x5 |
| MURGY | 2566 | 3705 | 0.2 | 2024-10-23 x5 |
| DASTY | 2140 | 3356 | 0.2 | 2021-07-15 x5 |
| NTDOY | 2113 | 3337 | 0.2 | 2022-10-04 x5 |
| ATLKY | 2805 | 3787 | 0.25 | 2022-05-23 x4 |
| NJDCY | 2544 | 3556 | 0.25 | 2020-04-09 x2, 2024-10-09 x2 |
| NVEE | 2512 | 3517 | 0.25 | 2024-10-11 x4 |
| PAMT | 2545 | 3557 | 0.25 | 2021-08-17 x2, 2022-03-30 x2 |
| PTSI | 2546 | 3558 | 0.25 | 2021-08-17 x2, 2022-03-30 x2 |
| BF-A | 2774 | 3659 | 0.299 | 2016-08-19 x2, 2018-02-07 x1.339, 2018-03-01 x1.25 |
| CRVL | 2801 | 3616 | 0.333 | 2024-12-26 x3 |

### 2016

True-basis head: CDO 2.85e+10, CTRA_old 1.86e+10, LHC-UN 1.76e+10, LHC-WS 1.76e+10, HSBA 1.3e+10

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| SLS | 5143 | 2795 | 3e+04 | 2016-11-14 x0.05, 2018-01-02 x0.03333, 2019-11-08 x0.02 |
| TPST | 4991 | 2606 | 2.92e+03 | 2018-12-10 x0.06667, 2021-06-28 x0.06667, 2025-04-09 x0.07692 |
| YDKG | 4997 | 2979 | 2e+03 | 2019-04-11 x0.2, 2022-12-12 x0.25, 2025-11-14 x0.01 |
| AHT | 4942 | 2947 | 988 | 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| MOSY | 4626 | 2330 | 200 | 2017-02-16 x0.1, 2019-08-28 x0.05 |
| RGLS | 4588 | 2520 | 120 | 2018-10-04 x0.08333, 2022-06-29 x0.1 |
| ETRM | 4321 | 2103 | 70 | 2016-12-28 x0.01429 |
| NBR | 3256 | 662 | 50 | 2020-04-23 x0.02 |
| HK | 3070 | 708 | 34.5 | 2016-09-12 x0.029 |
| TDW | 3917 | 1813 | 32.3 | 2017-08-01 x0.031 |
| RWLK | 3771 | 1734 | 25 | 2019-04-01 x0.04 |
| ATRA | 4231 | 2642 | 25 | 2024-06-20 x0.04 |
| FGEN | 4012 | 2173 | 25 | 2025-06-17 x0.04 |
| TOVX | 3177 | 971 | 25 | 2024-08-26 x0.04 |
| VEON | 4282 | 2740 | 25 | 2023-03-08 x0.04 |
| KYNB | 4013 | 2174 | 25 | 2025-06-17 x0.04 |
| ACRX | 3574 | 1590 | 20 | 2022-10-26 x0.05 |
| ANFIF | 4260 | 2869 | 20 | 2019-12-20 x0.05 |
| MCRB | 4006 | 2307 | 20 | 2025-04-22 x0.05 |
| RGS | 4222 | 2753 | 20 | 2023-11-29 x0.05 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| BHRB | 2861 | 4595 | 0.025 | 2022-11-15 x40 |
| NPPXF | 1920 | 3972 | 0.04 | 2023-06-29 x25 |
| DKILY | 2768 | 4355 | 0.05 | 2018-03-14 x20 |
| HCM | 2376 | 3859 | 0.1 | 2019-05-30 x10 |
| DNBBY | 2865 | 4153 | 0.1 | 2017-06-15 x10 |
| HTHIY | 2033 | 3583 | 0.1 | 2024-07-10 x5, 2025-02-19 x2 |
| TPL | 1891 | 3407 | 0.111 | 2024-03-27 x3, 2025-12-23 x3 |
| SNEX | 1827 | 3016 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| DQ | 1966 | 3131 | 0.2 | 2020-11-17 x5 |
| MURGY | 2223 | 3346 | 0.2 | 2024-10-23 x5 |
| NTDOY | 2382 | 3484 | 0.2 | 2022-10-04 x5 |
| USLM | 2666 | 3718 | 0.2 | 2024-07-15 x5 |
| DASTY | 2483 | 3562 | 0.2 | 2021-07-15 x5 |
| IX | 1917 | 3082 | 0.2 | 2025-02-28 x5 |
| GOLLQ | 2094 | 3253 | 0.2 | 2017-05-02 x2, 2017-11-22 x2.5 |
| PAMT | 2712 | 3626 | 0.25 | 2021-08-17 x2, 2022-03-30 x2 |
| PTSI | 2713 | 3627 | 0.25 | 2021-08-17 x2, 2022-03-30 x2 |
| CTO | 2898 | 3723 | 0.271 | 2020-11-18 x1.228, 2022-07-01 x3 |
| NPSNY | 2919 | 3736 | 0.274 | 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| BCH | 2178 | 3014 | 0.326 | 2016-07-06 x1.022, 2018-11-23 x3 |

### 2017

True-basis head: LDG 2.96e+10, CTRA_old 2.95e+10, LHC-UN 2.05e+10, LHC-WS 2.05e+10, HSBA 1.78e+10

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| BGMS | 5135 | 2246 | 7.2e+04 | 2020-04-15 x0.05, 2023-12-18 x0.06667, 2025-05-12 x0.0625, 2025-07-07 x0.06667 |
| DFFN | 3793 | 53 | 1.13e+03 | 2018-12-14 x0.06667, 2022-04-19 x0.02, 2023-08-17 x0.6667 |
| AHT | 4927 | 2753 | 988 | 2019-10-28 x1.012, 2020-07-16 x0.1, 2021-07-19 x0.1, 2024-10-28 x0.1 |
| AKTX | 4821 | 2146 | 800 | 2023-08-17 x0.05, 2026-03-31 x0.025 |
| DCTH | 4129 | 289 | 700 | 2019-12-24 x0.001429 |
| AQMS | 4676 | 2417 | 200 | 2024-11-05 x0.05, 2025-08-04 x0.1 |
| IRD | 4727 | 2937 | 136 | 2019-04-12 x0.08333, 2020-11-06 x0.25 |
| CBIO | 3993 | 1095 | 100 | 2025-06-16 x0.01 |
| PVLA | 4540 | 2608 | 80 | 2024-04-23 x0.0125 |
| TROV | 4087 | 1550 | 72 | 2018-06-04 x0.08333, 2019-02-20 x0.1667 |
| NBR | 3194 | 575 | 50 | 2020-04-23 x0.02 |
| AKER | 4306 | 2304 | 48 | 2019-11-25 x0.04167, 2021-04-19 x0.5 |
| BIOC | 3399 | 1079 | 30 | 2023-05-17 x0.03333 |
| TOVX | 3699 | 1636 | 25 | 2024-08-26 x0.04 |
| ATRA | 4275 | 2746 | 25 | 2024-06-20 x0.04 |
| RWLK | 4258 | 2705 | 25 | 2019-04-01 x0.04 |
| VEON | 3834 | 1867 | 25 | 2023-03-08 x0.04 |
| FGEN | 3868 | 1911 | 25 | 2025-06-17 x0.04 |
| KYNB | 3869 | 1912 | 25 | 2025-06-17 x0.04 |
| PTI | 3465 | 1456 | 20 | 2020-12-23 x0.05 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| BHRB | 2853 | 4610 | 0.025 | 2022-11-15 x40 |
| NPPXF | 1576 | 3753 | 0.04 | 2023-06-29 x25 |
| DKILY | 2465 | 4199 | 0.05 | 2018-03-14 x20 |
| DNBBY | 2229 | 3741 | 0.1 | 2017-06-15 x10 |
| HTHIY | 2478 | 3897 | 0.1 | 2024-07-10 x5, 2025-02-19 x2 |
| HCM | 2785 | 4111 | 0.1 | 2019-05-30 x10 |
| SNEX | 1914 | 3123 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| DASTY | 2423 | 3493 | 0.2 | 2021-07-15 x5 |
| IX | 1966 | 3155 | 0.2 | 2025-02-28 x5 |
| MURGY | 2479 | 3541 | 0.2 | 2024-10-23 x5 |
| USLM | 2937 | 3867 | 0.2 | 2024-07-15 x5 |
| DQ | 2162 | 3305 | 0.2 | 2020-11-17 x5 |
| BBSI | 2150 | 3172 | 0.25 | 2024-06-24 x4 |
| MBGYY | 2751 | 3628 | 0.25 | 2018-02-01 x4 |
| NVEE | 2198 | 3212 | 0.25 | 2024-10-11 x4 |
| NPSNY | 2331 | 3255 | 0.274 | 2017-08-11 x0.5, 2019-09-17 x1.462, 2025-10-09 x5 |
| GOL | 2495 | 3289 | 0.319 | 2017-11-22 x2.5 |
| POWL | 2991 | 3647 | 0.333 | 2026-04-06 x3 |
| CRVL | 2801 | 3494 | 0.333 | 2024-12-26 x3 |
| BCH | 2230 | 3073 | 0.333 | 2018-11-23 x3 |

### 2018

True-basis head: LDG 2.15e+10, SBER 1.82e+10, HSBA 1.71e+10, CTRA_old 1.64e+10, LHC-UN 9.68e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| DFFN | 4450 | 624 | 1.12e+03 | 2018-12-14 x0.06667, 2022-04-19 x0.02, 2023-08-17 x0.6667 |
| DCTH | 4592 | 1179 | 700 | 2019-12-24 x0.001429 |
| PIXY | 3844 | 156 | 600 | 2019-12-16 x0.025, 2024-10-14 x0.06667 |
| AIFU | 4817 | 2643 | 400 | 2025-05-21 x0.05, 2026-06-15 x0.05 |
| ACB | 4458 | 2177 | 120 | 2020-05-11 x0.08333, 2024-02-20 x0.1 |
| CBIO | 4490 | 2412 | 100 | 2025-06-16 x0.01 |
| TROV | 4112 | 1701 | 72 | 2018-06-04 x0.08333, 2019-02-20 x0.1667 |
| SLS | 4358 | 2547 | 50 | 2019-11-08 x0.02 |
| NBR | 3259 | 649 | 50 | 2020-04-23 x0.02 |
| EGIOQ | 4289 | 2560 | 40 | 2024-03-01 x0.025 |
| RKDA | 4276 | 2527 | 40 | 2023-03-01 x0.025 |
| BIOC | 4125 | 2436 | 30 | 2023-05-17 x0.03333 |
| TOVX | 4262 | 2814 | 25 | 2024-08-26 x0.04 |
| FGEN | 3670 | 1601 | 25 | 2025-06-17 x0.04 |
| ATRA | 3624 | 1531 | 25 | 2024-06-20 x0.04 |
| RWLK | 4344 | 2998 | 25 | 2019-04-01 x0.04 |
| ABEO | 3692 | 1660 | 25 | 2022-07-05 x0.04 |
| KYNB | 3671 | 1602 | 25 | 2025-06-17 x0.04 |
| VEON | 3813 | 1854 | 25 | 2023-03-08 x0.04 |
| MBAI | 3911 | 2280 | 20 | 2022-11-25 x0.05 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| BHRB | 2751 | 4559 | 0.025 | 2022-11-15 x40 |
| HTHIY | 2054 | 3621 | 0.1 | 2024-07-10 x5, 2025-02-19 x2 |
| HXGBY | 1838 | 3278 | 0.143 | 2021-05-28 x7 |
| REX | 1727 | 3077 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |
| BYDDY | 2633 | 3765 | 0.167 | 2025-07-30 x6 |
| SNEX | 1860 | 3093 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| IX | 1890 | 3116 | 0.2 | 2025-02-28 x5 |
| MURGY | 1981 | 3187 | 0.2 | 2024-10-23 x5 |
| ATLKY | 2581 | 3517 | 0.25 | 2022-05-23 x4 |
| NJDCY | 2545 | 3487 | 0.25 | 2020-04-09 x2, 2024-10-09 x2 |
| POWL | 2824 | 3560 | 0.333 | 2026-04-06 x3 |
| CRVL | 2803 | 3543 | 0.333 | 2024-12-26 x3 |
| BCH | 2495 | 3289 | 0.333 | 2018-11-23 x3 |
| BMRC | 2893 | 3381 | 0.5 | 2018-11-28 x2 |
| CSLLY | 2688 | 3212 | 0.5 | 2026-03-02 x2 |
| IDEXY | 2827 | 3336 | 0.5 | 2025-06-25 x2 |
| NTTYY | 2700 | 3228 | 0.5 | 2020-01-14 x2 |
| PFC | 2968 | 3444 | 0.5 | 2018-07-13 x2 |
| BEP | 2728 | 3215 | 0.533 | 2020-07-30 x1.251, 2020-12-14 x1.5 |
| ALNT | 2884 | 3200 | 0.667 | 2021-05-03 x1.5 |

### 2019

True-basis head: CTRA_old 3.31e+10, SBER 1.44e+10, VPI 1.13e+10, LHC-UN 9.53e+09, LHC-WS 9.53e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| MBRX | 4943 | 2042 | 2.25e+03 | 2021-02-01 x0.1667, 2024-03-22 x0.06667, 2025-12-01 x0.04 |
| AKTX | 4966 | 2996 | 800 | 2023-08-17 x0.05, 2026-03-31 x0.025 |
| MBIO | 4859 | 2262 | 750 | 2023-04-04 x0.06667, 2025-01-16 x0.02 |
| PIXY | 3921 | 201 | 600 | 2019-12-16 x0.025, 2024-10-14 x0.06667 |
| AIFU | 4771 | 2282 | 400 | 2025-05-21 x0.05, 2026-06-15 x0.05 |
| BIOCQ | 4742 | 2410 | 300 | 2020-09-08 x0.1, 2023-05-17 x0.03333 |
| ACB | 3446 | 384 | 120 | 2020-05-11 x0.08333, 2024-02-20 x0.1 |
| UXIN | 4260 | 1701 | 100 | 2022-10-28 x0.1, 2024-01-16 x0.1 |
| LFWD | 4636 | 2918 | 84 | 2024-03-15 x0.1429, 2026-02-23 x0.08333 |
| DFFN | 3050 | 303 | 75 | 2022-04-19 x0.02, 2023-08-17 x0.6667 |
| NBR | 3700 | 1151 | 50 | 2020-04-23 x0.02 |
| PHUN | 4396 | 2572 | 50 | 2024-02-27 x0.02 |
| AKER | 4331 | 2420 | 48 | 2019-11-25 x0.04167, 2021-04-19 x0.5 |
| EGIOQ | 4495 | 2979 | 40 | 2024-03-01 x0.025 |
| PRPO | 4042 | 2030 | 34.2 | 2023-09-22 x0.05 |
| CVM | 4167 | 2437 | 30 | 2025-05-20 x0.03333 |
| ATRA | 3656 | 1585 | 25 | 2024-06-20 x0.04 |
| KYNB | 3297 | 1090 | 25 | 2025-06-17 x0.04 |
| FGEN | 3296 | 1089 | 25 | 2025-06-17 x0.04 |
| VEON | 3779 | 1769 | 25 | 2023-03-08 x0.04 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| BHRB | 2464 | 4474 | 0.025 | 2022-11-15 x40 |
| CHGCY | 2628 | 4108 | 0.0833 | 2020-07-06 x12 |
| HXGBY | 2945 | 4079 | 0.143 | 2021-05-28 x7 |
| REX | 1744 | 3080 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |
| FUJIY | 2572 | 3732 | 0.167 | 2024-04-02 x6 |
| BYDDY | 2894 | 3979 | 0.167 | 2025-07-30 x6 |
| SNEX | 1965 | 3165 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| MURGY | 2467 | 3538 | 0.2 | 2024-10-23 x5 |
| IX | 1812 | 3012 | 0.2 | 2025-02-28 x5 |
| DASTY | 2444 | 3528 | 0.2 | 2021-07-15 x5 |
| ATLKY | 2625 | 3547 | 0.25 | 2022-05-23 x4 |
| BBSI | 2076 | 3106 | 0.25 | 2024-06-24 x4 |
| NJDCY | 2487 | 3424 | 0.25 | 2020-04-09 x2, 2024-10-09 x2 |
| CTO | 2311 | 3244 | 0.271 | 2020-11-18 x1.228, 2022-07-01 x3 |
| ACMR | 2522 | 3282 | 0.333 | 2022-03-24 x3 |
| POWL | 2896 | 3611 | 0.333 | 2026-04-06 x3 |
| MTSFY | 2735 | 3491 | 0.333 | 2024-04-02 x3 |
| CLBK | 2669 | 3233 | 0.455 | 2026-07-21 x2.2 |
| CVLG | 2655 | 3162 | 0.5 | 2025-01-02 x2 |
| DHLGY | 2811 | 3321 | 0.5 | 2026-03-30 x2 |

### 2020

True-basis head: CTRA_old 2.32e+10, VPI 2.04e+10, LDG 1.74e+10, SBER 1.52e+10, DCM 1.2e+10

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| BNBX | 5088 | 1458 | 1.5e+04 | 2024-04-25 x0.05, 2025-03-14 x0.02, 2025-06-02 x0.06667 |
| BGMS | 5086 | 2469 | 3.6e+03 | 2023-12-18 x0.06667, 2025-05-12 x0.0625, 2025-07-07 x0.06667 |
| PPBT | 5041 | 2353 | 2e+03 | 2020-08-21 x0.1, 2024-09-17 x0.05, 2026-03-02 x0.1 |
| IBIO | 4775 | 1837 | 500 | 2022-10-10 x0.04, 2023-11-29 x0.05 |
| BIOCQ | 4787 | 2257 | 300 | 2020-09-08 x0.1, 2023-05-17 x0.03333 |
| SHIP | 4636 | 2234 | 160 | 2020-06-30 x0.0625, 2023-02-16 x0.1 |
| PHIO | 4683 | 2691 | 108 | 2023-01-26 x0.08333, 2024-07-05 x0.1111 |
| AIMI | 4517 | 2190 | 99.9 | 2025-06-12 x0.01, 2026-01-09 x1.001 |
| AIM | 4506 | 2189 | 97 | 2025-06-12 x0.01, 2026-02-10 x1.031 |
| CRVO | 4462 | 2240 | 75 | 2022-04-19 x0.02, 2023-08-17 x0.6667 |
| PHUN | 4491 | 2665 | 50 | 2024-02-27 x0.02 |
| EGIOQ | 4153 | 2011 | 40 | 2024-03-01 x0.025 |
| DTIL | 4469 | 2993 | 30 | 2024-02-14 x0.03333 |
| CVM | 4079 | 2076 | 30 | 2025-05-20 x0.03333 |
| FCEL | 3975 | 1877 | 30 | 2024-11-11 x0.03333 |
| CUE | 4211 | 2334 | 30 | 2026-04-24 x0.03333 |
| VEON | 4218 | 2478 | 25 | 2023-03-08 x0.04 |
| KYNB | 3694 | 1540 | 25 | 2025-06-17 x0.04 |
| ATRA | 3829 | 1737 | 25 | 2024-06-20 x0.04 |
| MRSN | 3390 | 1159 | 25 | 2025-07-28 x0.04 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| BHRB | 2595 | 4625 | 0.025 | 2022-11-15 x40 |
| NPPXF | 2913 | 4608 | 0.04 | 2023-06-29 x25 |
| CHGCY | 1399 | 3249 | 0.0833 | 2020-07-06 x12 |
| HXGBY | 1906 | 3348 | 0.143 | 2021-05-28 x7 |
| BYDDY | 2270 | 3584 | 0.167 | 2025-07-30 x6 |
| REX | 1789 | 3174 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |
| FUJIY | 1752 | 3132 | 0.167 | 2024-04-02 x6 |
| DASTY | 1765 | 3035 | 0.2 | 2021-07-15 x5 |
| MURGY | 1934 | 3177 | 0.2 | 2024-10-23 x5 |
| ATLKY | 2135 | 3195 | 0.25 | 2022-05-23 x4 |
| BBSI | 2065 | 3130 | 0.25 | 2024-06-24 x4 |
| CTO | 2542 | 3511 | 0.271 | 2020-11-18 x1.228, 2022-07-01 x3 |
| POWL | 2650 | 3464 | 0.333 | 2026-04-06 x3 |
| NJDCY | 2366 | 3005 | 0.453 | 2024-10-09 x2 |
| CLBK | 2521 | 3147 | 0.455 | 2026-07-21 x2.2 |
| CODYY | 2708 | 3243 | 0.5 | 2026-07-09 x2 |
| CSLLY | 2657 | 3207 | 0.5 | 2026-03-02 x2 |
| CVLG | 2777 | 3291 | 0.5 | 2025-01-02 x2 |
| DHLGY | 2444 | 3031 | 0.5 | 2026-03-30 x2 |
| DNZOY | 2917 | 3412 | 0.5 | 2023-10-03 x2 |

### 2021

True-basis head: TSLA 2.11e+10, SBER 1.59e+10, AMZN 1.23e+10, AAPL 1.14e+10, MSFT 6.52e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| VTAK | 5559 | 2472 | 9.5e+03 | 2022-10-03 x0.02, 2024-07-15 x0.1, 2025-08-15 x0.05263 |
| CENN | 5464 | 1150 | 9e+03 | 2021-12-22 x0.06667, 2023-12-08 x0.1, 2026-04-13 x0.01667 |
| ERNA | 5248 | 265 | 7.5e+03 | 2022-10-17 x0.05, 2025-06-12 x0.06667, 2026-05-04 x0.04 |
| FAMI | 5450 | 2088 | 2.4e+03 | 2022-05-31 x0.04, 2023-09-25 x0.125, 2025-03-17 x0.08333 |
| SOS | 4867 | 465 | 750 | 2022-07-06 x0.02, 2024-11-19 x0.06667 |
| VELO | 5381 | 2665 | 525 | 2024-06-13 x0.02857, 2025-07-28 x0.06667 |
| IBIO | 5313 | 2192 | 500 | 2022-10-10 x0.04, 2023-11-29 x0.05 |
| PAVM | 5303 | 2246 | 450 | 2023-12-07 x0.06667, 2026-01-02 x0.03333 |
| GRTX | 5283 | 2937 | 200 | 2026-07-13 x0.005 |
| FRSX | 5120 | 2483 | 126 | 2023-04-21 x0.1667, 2025-08-25 x0.1429, 2026-02-26 x0.3333 |
| AHT | 4384 | 980 | 100 | 2021-07-19 x0.1, 2024-10-28 x0.1 |
| MAXN | 4920 | 1964 | 100 | 2024-10-09 x0.01 |
| UXIN | 4437 | 1043 | 100 | 2022-10-28 x0.1, 2024-01-16 x0.1 |
| CTRM | 4852 | 1912 | 85.5 | 2024-03-27 x0.1 |
| PVLA | 4473 | 1239 | 80 | 2024-04-23 x0.0125 |
| DFFN | 4110 | 843 | 75 | 2022-04-19 x0.02, 2023-08-17 x0.6667 |
| PHUN | 4865 | 2412 | 50 | 2024-02-27 x0.02 |
| KRRO | 4876 | 2457 | 50 | 2023-11-06 x0.02 |
| PRSO | 4285 | 1530 | 40 | 2024-01-03 x0.025 |
| CTEV | 4691 | 2226 | 40 | 2024-09-23 x0.025 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| BHRB | 2634 | 5146 | 0.025 | 2022-11-15 x40 |
| NPPXF | 2665 | 4989 | 0.04 | 2023-06-29 x25 |
| HTHIY | 1381 | 3432 | 0.1 | 2024-07-10 x5, 2025-02-19 x2 |
| HXGBY | 2125 | 3880 | 0.144 |  |
| REX | 2523 | 4118 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |
| SNEX | 1735 | 3235 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| IX | 2410 | 3883 | 0.2 | 2025-02-28 x5 |
| DASTY | 1859 | 3363 | 0.2 | 2021-07-15 x5 |
| ATLKY | 2129 | 3441 | 0.25 | 2022-05-23 x4 |
| BBSI | 2622 | 3900 | 0.25 | 2024-06-24 x4 |
| CSAN | 2282 | 3370 | 0.329 |  |
| CRVL | 2226 | 3303 | 0.333 | 2024-12-26 x3 |
| CTO | 2793 | 3813 | 0.333 | 2022-07-01 x3 |
| CANG | 2804 | 3494 | 0.5 | 2025-11-17 x2 |
| GOLD | 2417 | 3160 | 0.5 | 2022-06-07 x2 |
| KNTK | 2994 | 3662 | 0.5 | 2022-06-09 x2 |
| MMAT | 2309 | 3025 | 0.5 | 2024-02-05 x2 |
| NJDCY | 2989 | 3657 | 0.5 | 2024-10-09 x2 |
| PLUS | 2448 | 3187 | 0.5 | 2021-12-14 x2 |
| MGDDY | 2944 | 3455 | 0.625 | 2022-06-22 x1.6 |

### 2022

True-basis head: TSLA 2.42e+10, AAPL 1.55e+10, NVDA 1.19e+10, AMZN 1.15e+10, AMD 1.07e+10

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| SOS | 5473 | 2893 | 750 | 2022-07-06 x0.02, 2024-11-19 x0.06667 |
| CENN | 5365 | 2361 | 600 | 2023-12-08 x0.1, 2026-04-13 x0.01667 |
| VELO | 5403 | 2704 | 525 | 2024-06-13 x0.02857, 2025-07-28 x0.06667 |
| GOVX | 5072 | 1623 | 375 | 2024-01-31 x0.06667, 2026-01-12 x0.04 |
| BCTX | 5120 | 2488 | 150 | 2025-01-29 x0.06667, 2025-08-25 x0.1 |
| NUTX | 4609 | 1346 | 150 | 2024-04-10 x0.06667, 2024-07-03 x0.1 |
| PHIO | 4980 | 2380 | 108 | 2023-01-26 x0.08333, 2024-07-05 x0.1111 |
| XPON | 5156 | 2990 | 100 | 2024-10-09 x0.01 |
| MAXN | 5159 | 2999 | 100 | 2024-10-09 x0.01 |
| MMATQ | 5090 | 2770 | 100 | 2024-01-29 x0.01 |
| SIDU | 5048 | 2643 | 100 | 2023-12-20 x0.01 |
| ANY | 4977 | 2748 | 70 | 2023-06-29 x0.1429, 2026-02-09 x0.1 |
| COOK | 4883 | 2827 | 50 | 2026-03-18 x0.02 |
| PHUN | 4903 | 2866 | 50 | 2024-02-27 x0.02 |
| GFAI | 4760 | 2702 | 40 | 2023-02-10 x0.025 |
| CTEV | 4655 | 2489 | 40 | 2024-09-23 x0.025 |
| DNA | 3626 | 940 | 40 | 2024-08-20 x0.025 |
| DTCB | 3147 | 567 | 40 | 2025-07-09 x0.025 |
| EGIOQ | 4717 | 2641 | 40 | 2024-03-01 x0.025 |
| CVM | 4583 | 2573 | 30 | 2025-05-20 x0.03333 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| BHRB | 2562 | 4968 | 0.025 | 2022-11-15 x40 |
| NPPXF | 1454 | 3956 | 0.04 | 2023-06-29 x25 |
| FUJIY | 2153 | 3612 | 0.167 | 2024-04-02 x6 |
| DSCSY | 2578 | 3962 | 0.167 | 2023-04-04 x6 |
| REX | 1814 | 3282 | 0.167 | 2022-08-08 x3, 2025-09-16 x2 |
| SNEX | 1810 | 3172 | 0.198 | 2023-11-27 x1.5, 2025-03-24 x1.5, 2026-03-23 x1.5, 2026-07-20 x1.5 |
| IX | 1957 | 3288 | 0.2 | 2025-02-28 x5 |
| MURGY | 1679 | 3042 | 0.2 | 2024-10-23 x5 |
| NPSNY | 2171 | 3498 | 0.2 | 2025-10-09 x5 |
| ATEYY | 2851 | 3918 | 0.25 | 2023-10-11 x4 |
| BBSI | 2123 | 3274 | 0.25 | 2024-06-24 x4 |
| ATLKY | 1944 | 3023 | 0.291 |  |
| POWL | 2918 | 3777 | 0.333 | 2026-04-06 x3 |
| CTO | 2755 | 3648 | 0.333 | 2022-07-01 x3 |
| CLBK | 2691 | 3360 | 0.455 | 2026-07-21 x2.2 |
| AMRK | 2369 | 3009 | 0.5 | 2022-06-07 x2 |
| CODYY | 2938 | 3525 | 0.5 | 2026-07-09 x2 |
| CSLLY | 2874 | 3448 | 0.5 | 2026-03-02 x2 |
| FJTSY | 2977 | 3565 | 0.5 | 2024-04-02 x2 |
| NJDCY | 2469 | 3110 | 0.5 | 2024-10-09 x2 |

### 2023

True-basis head: TSLA 2.24e+10, NVDA 1.43e+10, AAPL 9.28e+09, MSFT 8.53e+09, AMZN 7.04e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| ACON | 5688 | 2905 | 1.45e+05 | 2024-01-04 x0.0625, 2025-01-30 x0.002985, 2025-03-28 x0.03704 |
| CNSP | 5581 | 1979 | 3e+04 | 2024-06-05 x0.02, 2025-02-21 x0.02, 2025-07-22 x0.08333 |
| ALLR | 5625 | 2791 | 2.4e+04 | 2023-06-29 x0.025, 2024-04-09 x0.05, 2024-09-11 x0.03333 |
| GCTK | 5033 | 2154 | 300 | 2024-05-20 x0.2, 2025-06-16 x0.01667 |
| ENVB | 4582 | 1542 | 180 | 2025-01-29 x0.06667, 2025-10-28 x0.08333 |
| DRMA | 4842 | 2236 | 150 | 2024-05-16 x0.06667, 2025-08-01 x0.1 |
| MAXN | 4076 | 1115 | 100 | 2024-10-09 x0.01 |
| QH | 4864 | 2674 | 90 | 2025-08-25 x0.01111 |
| DNA | 3848 | 1390 | 40 | 2024-08-20 x0.025 |
| INAB | 3975 | 1792 | 30 | 2025-06-06 x0.03333 |
| XFOR | 4365 | 2459 | 30 | 2025-04-28 x0.03333 |
| FCEL | 3756 | 1468 | 30 | 2024-11-11 x0.03333 |
| PSNY | 4249 | 2245 | 30 | 2025-12-09 x0.03333 |
| ORGN | 4514 | 2772 | 30 | 2026-03-20 x0.03333 |
| FGEN | 3884 | 1790 | 25 | 2025-06-17 x0.04 |
| KYNB | 3885 | 1791 | 25 | 2025-06-17 x0.04 |
| MRSN | 3990 | 1955 | 25 | 2025-07-28 x0.04 |
| ATRA | 4490 | 2860 | 25 | 2024-06-20 x0.04 |
| PTPI | 3752 | 1607 | 25 | 2025-05-01 x0.04 |
| CAMP_old | 4122 | 2237 | 23 | 2024-02-02 x0.04348 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| NPPXF | 2696 | 4655 | 0.04 | 2023-06-29 x25 |
| FUJIY | 2256 | 3587 | 0.167 | 2024-04-02 x6 |
| MURGY | 2317 | 3524 | 0.2 | 2024-10-23 x5 |
| IX | 2189 | 3405 | 0.2 | 2025-02-28 x5 |
| USLM | 2865 | 3957 | 0.2 | 2024-07-15 x5 |
| ATEYY | 2562 | 3585 | 0.25 | 2023-10-11 x4 |
| CLMB | 2744 | 3736 | 0.25 | 2026-03-23 x4 |
| NRIM | 2600 | 3612 | 0.25 | 2025-09-23 x4 |
| CVLG | 2624 | 3187 | 0.5 | 2025-01-02 x2 |
| DHLGY | 2469 | 3009 | 0.5 | 2026-03-30 x2 |
| MMAT | 2537 | 3102 | 0.5 | 2024-02-05 x2 |
| NJDCY | 2731 | 3282 | 0.5 | 2024-10-09 x2 |
| NONOF | 2721 | 3274 | 0.5 | 2023-09-13 x2 |
| REX | 2711 | 3264 | 0.5 | 2025-09-16 x2 |
| ATRO | 2971 | 3194 | 0.798 | 2026-06-15 x1.253 |
| ADRNY | 2955 | 3007 | 1 |  |
| AMPY | 2993 | 3050 | 1 |  |
| ARVL | 2995 | 3052 | 1 |  |
| ASTE | 2994 | 3051 | 1 |  |
| AVPT | 2965 | 3019 | 1 |  |

### 2024

True-basis head: NVDA 4.09e+10, TSLA 1.62e+10, AAPL 1.05e+10, AMD 8.66e+09, BRK-A 8.61e+09

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| STSS | 5535 | 2629 | 6.6e+03 | 2024-10-16 x0.04545, 2025-04-28 x0.003333 |
| IVF | 5322 | 2228 | 1.44e+03 | 2025-03-18 x0.08333, 2025-07-21 x0.3333, 2025-11-28 x0.125, 2026-03-27 x0.2 |
| BDRX | 5306 | 2242 | 1.25e+03 | 2024-10-04 x0.04, 2025-07-31 x0.1, 2026-04-06 x0.2 |
| NIVF | 5383 | 2788 | 1e+03 | 2025-05-05 x0.1, 2025-08-04 x0.2, 2025-12-01 x0.2, 2026-03-16 x0.25 |
| GMEX | 5271 | 2313 | 896 | 2025-09-23 x0.0625, 2026-01-08 x0.125, 2026-05-01 x0.1429 |
| OLOX | 5106 | 1947 | 640 | 2025-09-08 x0.01562, 2026-05-07 x0.1 |
| XHG | 5280 | 2970 | 400 | 2024-11-08 x0.05, 2025-05-09 x0.05 |
| SBFM | 5098 | 2785 | 200 | 2024-08-08 x0.05, 2026-06-01 x0.1 |
| MLEC | 5002 | 2730 | 150 | 2025-05-14 x0.1, 2026-01-05 x0.06667 |
| AKAN | 5047 | 2906 | 141 | 2024-11-14 x0.5, 2025-08-26 x0.32, 2026-01-12 x0.2, 2026-04-13 x0.222 |
| MAXN | 4694 | 2234 | 100 | 2024-10-09 x0.01 |
| DNA | 3709 | 1230 | 40 | 2024-08-20 x0.025 |
| DTCB | 3795 | 1330 | 40 | 2025-07-09 x0.025 |
| ALLR | 4432 | 2552 | 30.4 | 2024-09-11 x0.03333 |
| FCEL | 3612 | 1303 | 30 | 2024-11-11 x0.03333 |
| PSNY | 4389 | 2476 | 30 | 2025-12-09 x0.03333 |
| XFOR | 4609 | 2974 | 30 | 2025-04-28 x0.03333 |
| AGL | 3793 | 1680 | 25 | 2026-03-31 x0.04 |
| MRSN | 4425 | 2691 | 25 | 2025-07-28 x0.04 |
| ADV | 4553 | 2963 | 25 | 2026-03-27 x0.04 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| OSOL | 2334 | 4109 | 0.0667 | 2024-06-05 x15 |
| IX | 2399 | 3572 | 0.2 | 2025-02-28 x5 |
| NPSNY | 2225 | 3408 | 0.2 | 2025-10-09 x5 |
| MURGY | 2462 | 3638 | 0.2 | 2024-10-23 x5 |
| CSLLY | 2981 | 3473 | 0.5 | 2026-03-02 x2 |
| CVLG | 2492 | 3088 | 0.5 | 2025-01-02 x2 |
| IDEXY | 2603 | 3191 | 0.5 | 2025-06-25 x2 |
| SRXH | 2784 | 3081 | 0.741 | 2025-05-01 x1.35 |
| AIQUY | 2984 | 3103 | 0.909 | 2026-06-09 x1.1 |
| ACDVF | 2959 | 3008 | 1 |  |
| ACIU | 2957 | 3006 | 1 |  |
| ALIZY | 2986 | 3032 | 1 |  |
| ALTG | 3000 | 3049 | 1 |  |
| ANGO | 2971 | 3019 | 1 |  |
| AOSL | 2964 | 3013 | 1 |  |
| BBDC | 2970 | 3018 | 1 |  |
| BCG | 2961 | 3010 | 1 |  |
| BLX | 2979 | 3027 | 1 |  |
| BOOM | 2977 | 3025 | 1 |  |
| BYRN | 2985 | 3031 | 1 |  |

### 2025

True-basis head: TSLA 3.52e+10, NVDA 3.16e+10, AAPL 1.33e+10, PLTR 1.13e+10, MSFT 1.01e+10

Entering:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| OLOX | 5524 | 2914 | 640 | 2025-09-08 x0.01562, 2026-05-07 x0.1 |
| KIDZ | 4814 | 1141 | 500 | 2026-03-10 x0.02, 2026-06-08 x0.1 |
| APVO | 5358 | 2613 | 308 | 2025-12-30 x0.05556 |
| NXTS | 5150 | 2234 | 245 | 2025-09-22 x0.02857, 2026-04-08 x0.1429 |
| NEXR | 5378 | 2901 | 238 | 2025-06-16 x0.05882, 2026-02-17 x0.07143 |
| NXTT | 4861 | 1787 | 200 | 2025-09-16 x0.005 |
| CISS | 4710 | 1579 | 194 | 2026-01-26 x0.05, 2026-04-27 x0.1429 |
| IVF | 5062 | 2552 | 120 | 2025-07-21 x0.3333, 2025-11-28 x0.125, 2026-03-27 x0.2 |
| BTOG | 4982 | 2875 | 60 | 2026-01-20 x0.01667 |
| BYAH | 4908 | 2844 | 50 | 2026-02-19 x0.02 |
| AGMH | 4613 | 2321 | 50 | 2025-06-03 x0.02 |
| JYD | 4706 | 2499 | 50 | 2025-10-13 x0.02 |
| NAKA | 3665 | 1251 | 40 | 2026-05-22 x0.025 |
| ASBP | 4456 | 2199 | 40 | 2026-01-16 x0.025 |
| NVVE | 4238 | 1915 | 40 | 2025-12-15 x0.025 |
| VEEE | 4294 | 2041 | 37 | 2026-05-04 x0.02703 |
| PLRZ | 4341 | 2114 | 35.4 | 2025-11-28 x0.1667 |
| BIAF | 4215 | 2068 | 30 | 2025-09-19 x0.03333 |
| CLIK | 4302 | 2200 | 30 | 2025-10-10 x0.03333 |
| PSNY | 4775 | 2978 | 30 | 2025-12-09 x0.03333 |

Leaving:

| symbol | stored rank | true rank | true/stored | splits after |
|---|---:|---:|---:|---|
| NPSNY | 2364 | 3520 | 0.2 | 2025-10-09 x5 |
| NRIM | 2093 | 3115 | 0.25 | 2025-09-23 x4 |
| BYDDF | 2300 | 3108 | 0.333 | 2025-06-10 x3 |
| CLBK | 2789 | 3366 | 0.455 | 2026-07-21 x2.2 |
| CSLLY | 2513 | 3029 | 0.5 | 2026-03-02 x2 |
| DHLGY | 2555 | 3081 | 0.5 | 2026-03-30 x2 |
| ATS | 2977 | 3021 | 1 |  |
| BFC | 2998 | 3043 | 1 |  |
| BIGZ | 2963 | 3006 | 1 |  |
| BMEZ | 2967 | 3010 | 1 |  |
| BSTZ | 2960 | 3004 | 1 |  |
| BTT | 2990 | 3035 | 1 |  |
| BTX | 2964 | 3007 | 1 |  |
| CMPS | 2988 | 3033 | 1 |  |
| CTLP | 2969 | 3012 | 1 |  |
| DENN | 2984 | 3028 | 1 |  |
| DSP | 2972 | 3015 | 1 |  |
| FCEL | 2958 | 3002 | 1 |  |
| FDUS | 2981 | 3025 | 1 |  |
| FJTSY | 2968 | 3011 | 1 |  |

