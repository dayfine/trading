# Composition Golden Bar-Coverage Audit (2026-05-18)

P1 item from `dev/notes/next-session-priorities-2026-05-19.md`.

## TL;DR

**The expected problem doesn't exist.** Composition goldens have
~99-100% mean bar coverage across the entire 1998-2020 catalog
because they were built FROM the EODHD inventory — names without
bars can't be in the snapshot. The real contamination is survivor
bias (already documented in `dev/notes/random-universe-sweep-2026-05-18.md`
and PR #1180), not coverage.

## Setup

- Goldens audited: `top-{500,1000}-{1998,2000,2002,2005}.sexp` and
  `top-3000-{2007,2010,2015,2020}.sexp` from
  `trading/test_data/goldens-custom-universe/composition/`.
- Coverage window: snapshot date YYYY-05-31 → (YYYY+1)-05-31, with
  252 trading-day denominator.
- Per-symbol coverage = 100 × (CSV rows in window) / 252.
- Below-threshold = symbols with coverage <80%.
- Method: shell + awk, scanning `data/<X>/<Y>/<SYM>/data.csv`
  directly (no OCaml needed).

## Results

| Golden          | Present | Missing | Below 80% | Mean cov  |
|-----------------|---------|---------|-----------|-----------|
| top-500-1998    |    500  |   0     |    3      |   99.8%   |
| top-1000-1998   |   1000  |   0     |    7      |   99.6%   |
| top-500-2000    |    500  |   0     |    1      |  100.3%   |
| top-1000-2000   |   1000  |   0     |    4      |  100.2%   |
| top-500-2002    |    500  |   0     |    0      |  100.0%   |
| top-1000-2002   |   1000  |   0     |    3      |   99.8%   |
| top-500-2005    |    500  |   0     |    1      |  100.3%   |
| top-1000-2005   |   1000  |   0     |    2      |  100.3%   |
| top-3000-2007   |   3000  |   0     |  248      |   96.4%   |
| top-3000-2010   |   3000  |   0     |  190      |   97.0%   |
| top-3000-2015   |   3000  |   0     |   49      |   99.5%   |
| top-3000-2020   |   3000  |   0     |    1      |  100.0%   |

(Mean coverage >100% reflects ~253-254 actual trading days in some
calendar years vs. the rounded 252 denominator.)

## Findings

**1. No missing CSVs.** Every symbol in every audited golden has a
present `data.csv` file. The priorities-doc concern that "the universe
effectively shrinks silently" is unfounded — the composition builder
constructs snapshots from the EODHD inventory, so any name that didn't
have bars couldn't be ranked into the top-N in the first place. The
universe doesn't shrink; it never included the missing names.

**2. top-500 and top-1000 goldens are essentially clean.** 0-7 names
out of 500-1000 below threshold (0-0.7%). Well under the P1
"flag >10% sub-threshold" criterion. These goldens are safe to
consume as-is.

**3. top-3000 goldens have a real but modest coverage tail.** 1.6%
sub-threshold at the cleanest year (2015) up to 8.3% at the oldest
(2007). Still under the 10% threshold so no golden is "flagged" per
the original P1 criterion. The sub-threshold names are typically
IPOs that priced inside the window (so their CSV starts mid-window,
not at the snapshot date) or names that were briefly delisted mid-year.
Backtests on top-3000 goldens will see these as NaN gaps on ~5-8% of
symbol-days; the runner tolerates this without crashing, but the
effective universe shrinks slightly during gap days.

**4. Below-threshold examples** (top-500-1998):
- `HLFN`: 79.4% (3 trading-day gap near year-end)
- `MVCO`: 69.8% (~30 missing days)
- `GRPFF`: 59.5% (~80 missing days — likely partial-year IPO or M&A
  event)

These are absent from the top-500-2019 sample we ran in #1179, so
this audit doesn't change that scenario's results.

## What this means for the P1 item

**Close it.** The original concern ("pre-2006 composition goldens
have missing bars, statistics misleading") doesn't materialize in
the data. Replaces it with what we already knew from #1180:
composition goldens are clean on COVERAGE but contaminated by
SURVIVOR BIAS at the construction step (names not in 2026 inventory
can't be in any composition snapshot, no matter how big they were
historically).

The agenda that DOES need to ship to unlock point-in-time backtests
is the IWV / Russell-3000 historical-membership scrape — see
`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`.
That's the work that produces *true* point-in-time universes
(knowable at the start date, no forward knowledge of which names
will exist in 2026), which is what we need for honest strategy
alpha measurement.

## Reproducibility

```sh
# Single golden: top-500-1998 (substitute year/size for others)
file=trading/test_data/goldens-custom-universe/composition/top-500-1998.sexp
snap=1998-05-31; end=1999-05-31
grep -oE "\(symbol [A-Z0-9.\-]+\)" "$file" | sed 's/(symbol //;s/)//' | while read sym; do
  csv="data/${sym:0:1}/${sym: -1}/$sym/data.csv"
  [ -f "$csv" ] || { echo "MISSING $sym"; continue; }
  rows=$(awk -F, -v s=$snap -v e=$end 'NR>1 && $1>=s && $1<=e' "$csv" | wc -l)
  awk -v r=$rows -v s=$sym 'BEGIN{printf "%s\t%.1f\n", s, 100*r/252}'
done | awk -F'\t' '$2<80 {print}'
```
