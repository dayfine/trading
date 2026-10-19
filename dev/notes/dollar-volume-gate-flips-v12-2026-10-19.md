# Dollar volume, round 2: entry-gate flips on the v12 lists (#3136, 2026-10-19)

The 2026-10-06 note (`dollar-volume-basis-measurement-2026-10-06.md`) measured the
true-dollar basis against the **v11-era** lists. Since then the user chose to rebuild
(2026-10-07, `pit-v12-true-dollar-volume-2026-10-07.md`): the record now reads the
`pit-v12` lists, ranked on true dollars (`dev/experiments/rebaseline-v12-2026-10-08/`).
The liquidity gates got a true-dollar mode in #3301, **default off**
(`Liquidity_config.true_dollar_volume`).

So the record currently runs on **two bases at once**. The universe is ranked on true
dollars, and the $1M entry gate scores the stored `close * volume`. This note
measures what that mix does: which gate decisions flip, on the lists the record
actually reads. It also answers the #3301 behavioral-QC note O2: does the true basis
add single-print admissions under the default `Mean` aggregation?

Nothing was rebuilt, and no default, list, golden or spec changed. The measurement
tool gained two read-only columns and a CSV (this PR).

## How to reproduce

```sh
dune build analysis/data/universe/bin/dollar_volume_measurement.exe
./_build/default/analysis/data/universe/bin/dollar_volume_measurement.exe \
  --bars-root /workspaces/trading-1/data \
  --symbol-types /workspaces/trading-1/data/symbol_types.sexp \
  --lists-dir test_data/backtest_scenarios/pit-v12/composition \
  --start-year 1998 --end-year 2025 --sizes 1000,3000 \
  --out-report <report.md> --out-rejected <rejected.csv> \
  --out-liquidity <flips.csv>
```

This took 9.5 minutes on the container and is read-only. It scanned 11,859 of 11,859
store symbols. The per-symbol, per-year flip list is
`dollar-volume-gate-flips-v12-2026-10-19.csv`, the tool's `--out-liquidity` output
verbatim. It lists every symbol-year that has a flip or a one-bar pass.

**What is measured.** For every week-end bar of every member of the governing v12
top-3000 list, the gate is evaluated at its defaults ($1M floor, 20-bar trailing
`Mean`). It is scored once on the stored basis and once on true dollars, with the
same `F(t)` that `True_dollar_divisor` arms (`Dollar_volume_basis.applied_splits`).
Like the gate, no bar is rejected here.

## 1. Membership: the v12 lists are on the true basis

`C` is the committed v12 list, `T` the true-basis ranking rebuilt from today's store,
and `L` the stored-basis ranking. Then `C\T` is 0.0 to 1.8 % per vintage (top-1000),
and 0.0 to 1.2 % (top-3000). The residual is the twin aliasing and the inventory filter
that v12 applied, not the basis. The basis effect itself (`L\T`) is unchanged from the
10-06 note: 1.6 to 4.5 % of the top-3000 per vintage, and 0.5 to 14 % of the
top-1000 (largest before 2007). The full table is in the appendix. The v11 to v12 diff
per vintage is in the 10-07 note.

## 2. Entry-gate flips on the v12 lists ($1M, 20-bar mean)

`pass->fail`: passes on the stored basis, fails on true dollars.
`fail->pass`: the reverse.

| year | member-weeks | pass->fail | fail->pass | flip share | symbols p->f | symbols f->p | one-bar passes stored | one-bar passes true | fail->pass on one bar |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1998 | 88848 | 4410 | 1356 | 6.5% | 336 | 91 | 2529 | 2664 | 138 |
| 1999 | 146787 | 4964 | 2107 | 4.8% | 321 | 87 | 4272 | 4616 | 182 |
| 2000 | 142596 | 2330 | 2274 | 3.2% | 186 | 98 | 3225 | 3580 | 113 |
| 2001 | 142500 | 2113 | 2714 | 3.4% | 157 | 106 | 3301 | 3586 | 180 |
| 2002 | 144001 | 2875 | 2576 | 3.8% | 184 | 99 | 2999 | 3266 | 136 |
| 2003 | 145660 | 2724 | 3061 | 4.0% | 170 | 108 | 2708 | 3033 | 142 |
| 2004 | 147361 | 976 | 3149 | 2.8% | 104 | 114 | 2069 | 2176 | 116 |
| 2005 | 143147 | 408 | 3102 | 2.5% | 47 | 112 | 1459 | 1516 | 108 |
| 2006 | 142615 | 203 | 3137 | 2.3% | 29 | 111 | 1018 | 887 | 80 |
| 2007 | 141484 | 92 | 3311 | 2.4% | 12 | 119 | 650 | 541 | 50 |
| 2008 | 141534 | 162 | 3678 | 2.7% | 26 | 143 | 870 | 870 | 111 |
| 2009 | 145827 | 645 | 3743 | 3.0% | 53 | 129 | 1795 | 1884 | 191 |
| 2010 | 142964 | 425 | 4044 | 3.1% | 49 | 139 | 1437 | 1458 | 174 |
| 2011 | 142522 | 158 | 3833 | 2.8% | 18 | 148 | 1036 | 1050 | 127 |
| 2012 | 142344 | 344 | 3496 | 2.7% | 34 | 128 | 1347 | 1394 | 123 |
| 2013 | 142077 | 209 | 3296 | 2.5% | 25 | 112 | 917 | 824 | 50 |
| 2014 | 141925 | 21 | 3279 | 2.3% | 7 | 112 | 629 | 420 | 33 |
| 2015 | 144319 | 41 | 3365 | 2.4% | 3 | 123 | 534 | 430 | 75 |
| 2016 | 141075 | 60 | 2678 | 1.9% | 7 | 106 | 515 | 430 | 79 |
| 2017 | 141530 | 47 | 2181 | 1.6% | 5 | 84 | 437 | 344 | 56 |
| 2018 | 142094 | 10 | 2304 | 1.6% | 3 | 88 | 387 | 276 | 53 |
| 2019 | 141957 | 4 | 2341 | 1.7% | 2 | 94 | 416 | 379 | 88 |
| 2020 | 146114 | 4 | 2081 | 1.4% | 1 | 99 | 445 | 367 | 84 |
| 2021 | 143012 | 0 | 2872 | 2.0% | 0 | 130 | 356 | 242 | 70 |
| 2022 | 144156 | 0 | 3156 | 2.2% | 0 | 143 | 304 | 288 | 102 |
| 2023 | 147259 | 2 | 2120 | 1.4% | 1 | 105 | 345 | 406 | 130 |
| 2024 | 148630 | 0 | 1379 | 0.9% | 0 | 73 | 381 | 465 | 127 |
| 2025 | 150301 | 0 | 907 | 0.6% | 0 | 67 | 543 | 635 | 181 |
| 2026 | 62831 | 0 | 123 | 0.2% | 0 | 18 | 204 | 208 | 29 |

**Totals.** There are 4,037,470 member-weeks. 100,890 of them flip (2.5 %):

- 23,227 pass->fail, across 596 symbols;
- 77,663 fail->pass, across 654 symbols.

**The direction reversed against the 10-06 (v11) measurement.** On the v11 lists,
pass->fail dominated in every year until 2018. On v12, fail->pass dominates from
2004 on and stays at 1.4 to 2.8 % of member-weeks every year through 2023. That is 84
to 148 symbols a year.

**Why.** v12 ranks on true dollars, so it now admits names whose stored ADV is
understated: future reverse splitters. The default gate still scores the stored
basis, and it blocks those names for years after the list admitted them.

- **fail->pass, most weeks:** RGS (1,074), JAKK (816), VEON (768), NKTR (746),
  XOMA (741), AHT, PDS, SPEX, AGEN, GLAE, HHS, QMCO, RIGL, ONIT, TRST. Each later
  reverse-split (RGS 1:20 in 2023, JAKK 1:10 in 2020, VEON 1:25 in 2023, NKTR 1:15
  in 2025, XOMA 1:15 and 1:20, AHT 1:10 three times): the C-2010 shape.
- **pass->fail, most weeks:** NTDOY (255), NVO (230), ATW, REX, CRVL, WSFS, COKE,
  CHDN, SCVL, CHE, UFPI, FUJIY, DINO, DASTY, WST. These are later forward splitters
  (NVO 2:1, 5:1, 2:1 after 2001; NTDOY 5:1 in 2022; COKE 10:1 in 2025) whose true
  early ADV was under $1M; the AMZN-2018 shape at the bottom of the list. They are
  concentrated in 1998 to 2003, when the top-3000 cutoff sat near $1M a day.

**What this is not.** It is a superset of the decisions the record makes. The
gate is consulted only for screener candidates (Stage 2 breakouts that cleared the
cascade), not for every member every week. Which **entries** flip, and what that
does to P&L, needs a paired run: the same v12 spec with
`((liquidity_config true_dollar_volume) (true false))`, V6-gated
(`mechanism-validation-rigor.md` check 8). That run was not made here. The flag is
a default-off axis (R1/R2), and a default flip is a config-default change that
needs a paired golden run (`config-default-blast-radius.md`).

## 3. O2: does the true basis add one-bar admissions under `Mean`?

A **one-bar pass** is a week that clears $1M on the 20-bar mean, while the mean of
the other 19 bars (the largest left out) does not. This is the LINK-2026-05-11
spoof shape (#2060).

- **One-bar passes are about as common on both bases.** The true basis has 4 to 12 %
  more of them in 1998 to 2005 and 17 to 22 % more in 2023 to 2025, about the same in
  2008 to 2012, and up to a third fewer in 2014 to 2021. Neither basis is clean:
  0.2 to 3 % of member-weeks pass on one bar either way, under `Mean`.
- **The flips that rest on one bar are a small part of fail->pass.** Of the 77,663
  fail->pass weeks, **3,128 (4.0 %)** pass on true dollars only because of one bar.
  The other 96 % clear $1M on the remaining 19 bars too, so they are real
  understated names, not artefacts of dividing by `F`.

**Answer to O2.** The true basis does not materially worsen the `Mean` spoof. The
residual exists on both bases. The fix for it is the existing `adv_aggregation`
axis (`Median` or `Trimmed_mean`), not a basis change. A flag-on run under `Mean`
can still admit one of those ~3k weeks on a single print. If the flag is ever
promoted, arm it with a robust aggregation, or read those trades out explicitly.

## 4. Junk ADV

The rejected bars are byte-identical to the 10-06 run: 702 bars across 11 symbols,
each above $200B a day or not finite. VEXPQ, ETP_old2, VPGC, OCHTQ, CELSIA, CMPC,
ELP, TNM, HCD, FTGX and MEL; the list is in
`dollar-volume-basis-rejected-bars-2026-10-06.csv`.

- **PIT ranking:** they are rejected (dropped from the window average). That is
  how v12 was built.
- **Gates:** `Liquidity_metric` does not reject bars on either basis. A junk bar can
  only **raise** a reading, and it raises it on both bases (a $1e13 day clears $1M
  either way). So it can never cause a flip; it can only make a name pass that
  should not. Its exposure is the one-bar row above, and the same robust-aggregation
  axis removes it. Most of these names are delisted shells, and
  `pit-v12-true-dollar-volume-2026-10-07.md` already excludes MEL from the warehouse.
  Only 16 of the 702 bars fall in a year the symbol is a v12 top-3000 member
  (CELSIA 11; FTGX, HCD, MEL, OCHTQ and TNM 1 each).
- **Not caught by any cap** (as the 10-06 and 10-07 notes say): foreign-currency and
  unit/warrant lines whose single bars stay under $200B (HSBA, SBER, LHC-UN) still
  head some lists. That needs a symbol-class filter, which is a separate decision.

## 5. Other open notes

- **O1:** the post-run validator V3 (`validator_step.dollar_adv`) still computes the
  stored `close * volume`. On a flag-on run it disagrees with the gate. It sits in
  `trading/trading/backtest/validation` and needs fixing before any default flip.
  Not in this PR.
- The hold exit (`min_hold_dollar_adv = 0`) and the short-borrow gate
  (`short_borrow_min_dollar_adv = 0`) are off by default, so nothing flips there
  today. At an armed floor they read through the same `dollar_adv`, and the
  direction would be the same as section 2.

## 6. For the [after-merge] item

The PIT rebuild decision was taken by the user on 2026-10-07 (v12 lists and
warehouse; record rebaselined 2026-10-08). What remains open on #3136 is the
**gate basis**. The record ranks on true dollars and gates on stored dollars. The
cost: about 2 % of member-weeks a year blocked that a consistent basis would admit,
and 0.6 % admitted that it would block (front-loaded before 2004). Deciding that
needs the paired v12 run above, not more measurement.

## Appendix: membership change per vintage (generated, v12 lists as C)

L = rebuilt on the stored basis, T = true-dollar basis, C = committed list.

| year | N | in (T\L) | out (L\T) | out share | C\T | C\T share | C\L (store drift) |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1998 | 1000 | 140 | 140 | 14.0% | 17 | 1.8% | 151 |
| 1998 | 3000 | 81 | 81 | 2.7% | 27 | 0.9% | 108 |
| 1999 | 1000 | 121 | 121 | 12.1% | 16 | 1.7% | 127 |
| 1999 | 3000 | 122 | 122 | 4.1% | 30 | 1.0% | 146 |
| 2000 | 1000 | 105 | 105 | 10.5% | 15 | 1.5% | 116 |
| 2000 | 3000 | 135 | 135 | 4.5% | 36 | 1.2% | 162 |
| 2001 | 1000 | 111 | 111 | 11.1% | 16 | 1.7% | 119 |
| 2001 | 3000 | 105 | 105 | 3.5% | 31 | 1.1% | 133 |
| 2002 | 1000 | 115 | 115 | 11.5% | 17 | 1.8% | 124 |
| 2002 | 3000 | 96 | 96 | 3.2% | 28 | 1.0% | 118 |
| 2003 | 1000 | 111 | 111 | 11.1% | 17 | 1.8% | 119 |
| 2003 | 3000 | 89 | 89 | 3.0% | 33 | 1.1% | 118 |
| 2004 | 1000 | 128 | 128 | 12.8% | 11 | 1.2% | 128 |
| 2004 | 3000 | 86 | 86 | 2.9% | 21 | 0.7% | 101 |
| 2005 | 1000 | 128 | 128 | 12.8% | 9 | 1.0% | 127 |
| 2005 | 3000 | 79 | 79 | 2.6% | 16 | 0.6% | 92 |
| 2006 | 1000 | 128 | 128 | 12.8% | 9 | 1.0% | 126 |
| 2006 | 3000 | 91 | 91 | 3.0% | 17 | 0.6% | 101 |
| 2007 | 1000 | 96 | 96 | 9.6% | 11 | 1.2% | 97 |
| 2007 | 3000 | 100 | 100 | 3.3% | 15 | 0.5% | 111 |
| 2008 | 1000 | 89 | 89 | 8.9% | 13 | 1.4% | 95 |
| 2008 | 3000 | 96 | 96 | 3.2% | 14 | 0.5% | 107 |
| 2009 | 1000 | 77 | 77 | 7.7% | 10 | 1.1% | 77 |
| 2009 | 3000 | 97 | 97 | 3.2% | 17 | 0.6% | 108 |
| 2010 | 1000 | 82 | 82 | 8.2% | 9 | 1.0% | 81 |
| 2010 | 3000 | 111 | 111 | 3.7% | 17 | 0.6% | 123 |
| 2011 | 1000 | 75 | 75 | 7.5% | 7 | 0.8% | 72 |
| 2011 | 3000 | 98 | 98 | 3.3% | 12 | 0.4% | 105 |
| 2012 | 1000 | 65 | 65 | 6.5% | 6 | 0.6% | 64 |
| 2012 | 3000 | 91 | 91 | 3.0% | 15 | 0.5% | 101 |
| 2013 | 1000 | 59 | 59 | 5.9% | 6 | 0.6% | 58 |
| 2013 | 3000 | 88 | 88 | 2.9% | 13 | 0.5% | 98 |
| 2014 | 1000 | 56 | 56 | 5.6% | 9 | 1.0% | 58 |
| 2014 | 3000 | 103 | 103 | 3.4% | 15 | 0.5% | 115 |
| 2015 | 1000 | 42 | 42 | 4.2% | 7 | 0.8% | 41 |
| 2015 | 3000 | 102 | 102 | 3.4% | 12 | 0.4% | 109 |
| 2016 | 1000 | 41 | 41 | 4.1% | 6 | 0.6% | 41 |
| 2016 | 3000 | 82 | 82 | 2.7% | 12 | 0.4% | 88 |
| 2017 | 1000 | 35 | 35 | 3.5% | 5 | 0.5% | 36 |
| 2017 | 3000 | 73 | 73 | 2.4% | 8 | 0.3% | 76 |
| 2018 | 1000 | 32 | 32 | 3.2% | 8 | 0.9% | 36 |
| 2018 | 3000 | 80 | 80 | 2.7% | 10 | 0.4% | 84 |
| 2019 | 1000 | 27 | 27 | 2.7% | 4 | 0.4% | 28 |
| 2019 | 3000 | 80 | 80 | 2.7% | 9 | 0.3% | 83 |
| 2020 | 1000 | 23 | 23 | 2.3% | 1 | 0.1% | 23 |
| 2020 | 3000 | 75 | 75 | 2.5% | 7 | 0.2% | 77 |
| 2021 | 1000 | 30 | 30 | 3.0% | 5 | 0.5% | 31 |
| 2021 | 3000 | 117 | 117 | 3.9% | 9 | 0.3% | 119 |
| 2022 | 1000 | 21 | 21 | 2.1% | 1 | 0.1% | 20 |
| 2022 | 3000 | 106 | 106 | 3.5% | 3 | 0.1% | 102 |
| 2023 | 1000 | 13 | 13 | 1.3% | 2 | 0.2% | 13 |
| 2023 | 3000 | 65 | 65 | 2.2% | 5 | 0.2% | 66 |
| 2024 | 1000 | 11 | 11 | 1.1% | 1 | 0.1% | 11 |
| 2024 | 3000 | 55 | 55 | 1.8% | 3 | 0.1% | 56 |
| 2025 | 1000 | 5 | 5 | 0.5% | 0 | 0.0% | 5 |
| 2025 | 3000 | 49 | 49 | 1.6% | 0 | 0.0% | 48 |
