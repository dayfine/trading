# Axis observatory: the pair reader (P2a)

`obs_read.sh` is the mechanical read of one arm against the baseline S, as set in
`dev/plans/axis-observatory-2026-11-14.md` §1 and §3. Each read appends one mark-free row to `surface.tsv`, the
public, append-only record of every arm the observatory has run. The price-derived detail goes to a private out dir.
A results-analyst reads an arm only when its row carries a flag.

It is POSIX sh plus awk (mawk, BWK awk or gawk), and needs no build or container.

## Run it

```sh
sh dev/experiments/observatory/obs_read.sh \
  -r <results dir> -p <cell prefix> -a <arm letter> \
  -l <arm label> -v '<config overlay>' -c <commit> \
  -O .sweep-output/observatory/<label> [-y <SPY years file>]
```

For example, `-r dev/experiments/price-band-confirm-2026-11-13/results -p pbc2 -a P` reads the
`Price_band_seeded` breadth cell. Its median D_end of -0.2803 matches that README's median Δ ln(1+R) of -0.280.

| flag | meaning | default |
|---|---|---|
| `-r` | run dir: per seed K, `kK/` or flat, files `<prefix>-<arm>-kK[-<salt>]-<kind>` as the chains write them | required |
| `-p` | cell prefix (`pbc2`, `sec`, ...) | required |
| `-a` | the arm's letter in the file names | required |
| `-b` | the baseline's letter | `S` |
| `-l` | arm label for the row | required |
| `-v` | the arm's config overlay, inline or `@file` | required |
| `-c` | the build's commit | required |
| `-O` | private out dir | required |
| `-k` | seeds | `0 1 2 3 4` |
| `-y` | SPY years file: one `YYYY bull` or `YYYY bear` per line, `#` comments | none: the bull/bear split is NA |
| `-t` | surface file to append to | `surface.tsv` beside the script |

## Inputs, per seed and arm

Each input is a file the chains already produce:

- `equity_curve.csv`
- `trades.csv`
- `open_positions.csv`
- `summary.sexp`
- `macro_trend.sexp` (base arm only)
- the arm's V6 diff log against the base, `<arm tag>.v6diff-<base>.log`, if the chain wrote one

## Public and private: what goes where

EODHD terms forbid redistributing price data (`project_eodhd_terms_private_bucket`), and a NAV curve lets a reader
back out closes.

**Private: the `-O` out dir.** These files hold price-derived data and go to `dayfine/trading-results`, never to
this repo:

| file | content |
|---|---|
| `D.tsv` | weekly D(t), one column per seed |
| `steps-kK.tsv` | every weekly step: its macro state, its share of D_end, and the three heaviest diff positions active in its week |
| `years-kK.tsv` | yearly increment, regime, and entries and mean positions held per arm |
| `firstdiff-kK.tsv` | the keyed trades diff, which includes prices |
| `seeds.tsv` | the per-seed lines the row aggregates |
| `row.tsv` | the row that was appended |

The script refuses an out dir that git would track: any path inside a work tree that is not ignored. An ignored path
such as `.sweep-output/observatory/<label>` is fine.

**Public: `surface.tsv`.** It holds only logs, rates, shares, percentage points, counts, dates and symbols. Before it
appends, the reader refuses a row with any computed number of magnitude 10,000 or more; such a number is a leaked
level.

## Definitions

- **D(t)** = ln(NAV_A / NAV_S), sampled at the last equity-curve row of each Monday-aligned week. It starts from 0 on
  the first row, since both arms start from the same cash. The weekly steps therefore sum to D_end.
- **The pair must share every equity date.** If the curves differ, the reader exits 2.
- **Yearly increment**: the sum of a calendar year's steps.
  - Each seed's positive rate is the share of its years with an increment above 0; the negative rate is the mirror.
    A zero year counts as neither.
  - `yr_pos_rate` and `yr_neg_rate` pool all years across all seeds.
  - `seeds_pos60` and `seeds_neg60` count the seeds whose own rate is at least 60 %.
- **Macro split**: each step is assigned the base's `macro_trend.sexp` state from the latest record on or before the
  previous sample date, which is the state in force when the week was traded. `d_mac_bull`, `d_mac_neut` and
  `d_mac_bear` sum the steps under Bullish, Neutral and Bearish.
- **Bull/bear years**: `d_bull_yr` and `d_bear_yr` sum the yearly increments of the years the `-y` file marks bull or
  bear. Without `-y` they are NA.
- **Step share**: step / D_end. It is NA when |D_end| < 0.00005.
  - The per-seed maximum (`step_max_seeds`, median `step_max_med`) is the largest share toward D_end.
  - `top5_steps` lists the five largest shares of the median-D_end seed (`top5_seed`) as `week-end share [positions]`.
  - Each step names up to three diff positions held at some point in its week, heaviest first, as
    `SYM@entry_date/class`. The class is `A` (arm only), `S` (base only, i.e. crowded out) or `C` (both arms, but
    the rows differ).
  - The weight is the position's whole-trade contribution as a percentage of entry NAV; an open position uses its
    size instead.
  - This is a pointer to where to look, not a decomposition of the step.
- **Positions**: keyed by symbol and entry date, the firstdiff key. A shifted position_id is not a change.
  - `s_out` counts the base's positions the arm lacks; `a_new` counts the arm's positions the base lacks.
  - `d_pos_held` is the change in the mean count of positions held at the weekly samples.
  - `d_entries_yr` is the change in positions entered per year.
- `d_maxdd_pp` and `d_ulcer` come from the two `summary.sexp` files, arm minus base.
- **Cross-seed values**: every value without a per-seed list is the median over seeds.
- `v6` is `ok` when every seed's V6 log passed, `unchecked` when none had one, and `partial` otherwise. A failed log
  stops the read.
- `arms_run` is the row's ordinal in the surface. A flagged read quotes it, per plan §3, "Multiple comparisons".

## The flag rule (plan §3: set before any arm ran; change it only before P3 starts)

**UP** when all three hold:

- median D_end is at least 0.20;
- `seeds_pos60` is at least 4;
- the median over seeds of the largest step share is under 0.5.

**HARM** is the mirror: median D_end of -0.20 or less, `seeds_neg60` at least 4, and the same step clause. Every other
row is `none`. The constants live in `read/lib/row.awk`.

A flag opens a pre-registration on a disjoint window. It is not a promotion.

## Check

`trading/devtools/checks/obs_read_check.sh` runs under `dune runtest`.

**Fixture.** `trading/devtools/checks/fixtures/obs_read/gen_fixture.sh` builds five seeds of made-up NAVs, with no
bars, over seven years. Its eleven arms (table in the generator's header) pin every clause of the flag rule in both
directions:

- a slope arm, which must flag UP, and a harm arm, which must flag HARM;
- an UP arm and a HARM arm that sit on every boundary (median D_end ±0.2000, exactly 4 seeds at 60 % or more with
  three at 5/7, largest step share 0.499), which must flag;
- for each clause and each direction, an arm that misses only that clause by a hair and must not flag: median D_end
  ±0.1999; 3 seeds at 60 % or more, with two at 4/7 = 0.571; a step share of 0.500, or the one-step lottery at 0.85;
- a zero year (seed k0 of each seeds near-miss is identical to S through 2010), which must count as neither sign.

The appended rows must equal `expected_surface.tsv` beside it.

**Refusals.** Each of these must leave the surface it targets byte-identical:

- a failed V6 log;
- an out dir that git would track;
- unpaired equity curves;
- a surface with another header;
- a max-drawdown delta the size of a price or NAV level, read end to end through `obs_read.sh`.
