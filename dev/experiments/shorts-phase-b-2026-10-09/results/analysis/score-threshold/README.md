# Score-threshold check (exploratory addendum, 2026-10-12)

**Exploratory and not pre-registered.** This answers a question the user asked after round 1. It does not change the
round-1 verdict or decision 10.

**Question** (user, 2026-10-12): should the short threshold be stricter? In other words, would a higher minimum
screener score have picked better shorts?

**Answer: not reliably.**
- **Filled shorts.** The top-scored shorts did better, but they still lost. At score ≥ 100 there were 25 trades, a
  32 % win rate and a −0.6 % / −1.1 % mean (v0 without the HRC defect trade / v1). Below 100 there were 170 / 142
  trades, a 16 % win rate and a −4.8 % / −4.9 % mean.
- **Why that is not enough.** The top-scored set is small, on one trade path, still negative, and carried by three
  trades (DB, TAC, M).
- **The candidate pool does not confirm it.** On the 1,491 ranked candidates, measured without stops against an SPY
  short, every threshold is a coin flip.

So there is a weak, unconfirmed signal that the top scores hurt less. There is no evidence that a stricter threshold
makes the short book profitable.

## Method

`run.sh` regenerates every output from the repo root.

**The candidate pool** (`pool.csv`, 1,491 rows):
- Every ranked short candidate in `alternatives_considered` of v0 s0's 219 entry decisions.
- Deduplicated on symbol and decision date (2,184 raw rows, no score conflicts), and keyed to the decision's
  `placement_date`, a Friday.
- **2,024 of the 2,184 raw rows were skipped for `No_structural_stop`** (`pool-skip-reasons.txt`). The pool is
  therefore mostly names the book could not take.
- It covers only the weeks in which a short was entered. The same stock in consecutive weeks appears more than once,
  so rows are not independent.

**Forward return** (`fwd.csv`):
- Entry at the adjusted close of the first bar after the decision date (the Monday). This is not the trigger fill, and
  no stops are applied.
- Side-signed returns at +20 / +60 / +120 bars. 4 rows are truncated at +120 by the end of their data.

**Excess** (`excess.csv`): the candidate's short return minus an SPY short over the same two dates.

**Filled shorts:** the committed v0 and v1 s0 `trades.csv`. `trades-summary.txt` is cumulative by
`screener_score_at_entry`. `trades-split-100.txt` splits them at 100, with and without HRC-wein-121.

**Inputs:**
- the v0 and v1 s0 `trade_audit.sexp` from the sweep output (3.2 MB each, not committed; `pool.csv` and
  `entry-attrs-*.csv` are their extracts);
- host `data/` bars, which are gitignored (SPY md5 `447bca148f4385bcd3b5c19a144f21bf`).

## Results

### Candidate pool (`pool-summary.txt`)

| score ≥ | n | beat SPY, +20 | mean vs SPY, +20 | beat SPY, +60 | mean vs SPY, +60 | beat SPY, +120 | mean vs SPY, +120 |
|---|---:|---:|---:|---:|---:|---:|---:|
| all | 1,491 | 50.7 % | +0.1 % | 50.0 % | +0.9 % | 51.2 % | +0.5 % |
| 90 | 973 | 52.6 % | +0.5 % | 49.8 % | +0.6 % | 50.5 % | −0.1 % |
| 95 | 728 | 51.2 % | +0.2 % | 50.4 % | +0.5 % | 50.7 % | −0.4 % |
| 100 | 398 | 51.8 % | +0.4 % | 52.0 % | +1.0 % | 51.5 % | −0.1 % |
| 105 | 149 | 53.7 % | +0.4 % | 49.7 % | +0.5 % | 43.0 % | −3.2 % |
| 110 | 68 | 50.0 % | +0.4 % | 48.5 % | +1.7 % | 45.6 % | −1.3 % |

- **Dispersion:** p10 / p90 is −12.6 / +13.0 % at +20 bars and −28.7 / +31.7 % at +120 (all candidates).
- **The weaker +120 reading at score ≥ 105 and ≥ 110 rests on few rows.** There are 149 and 68 of them, overlapping
  across weeks, so it is not a reliable sign that the top scores are worse.
- **In absolute terms,** 47.9 % of all candidates were lower after 60 bars, 48.7 % at score ≥ 100 and 46.3 % at score ≥ 105.

### Filled shorts (`trades-split-100.txt`, `trades-summary.txt`)

| arm (s0) | score ≥ 100 | score < 100 |
|---|---|---|
| v0, all | 26 trades, win 31 %, mean −4.12 %, median −4.10 %, −$82k | 170, win 16 %, −4.78 % / −7.89 %, −$528k |
| v0, excluding HRC-wein-121 (−92.8 % splice, §8.7 defect 2) | 25, win 32 %, −0.57 % / −3.94 %, −$29k | 170, win 16 %, −4.78 % / −7.89 %, −$528k |
| v1 (HRC not traded) | 25, win 32 %, −1.13 % / −4.10 %, −$36k | 142, win 16 %, −4.94 % / −8.07 %, −$510k |

- **Size.** Top-scored shorts are a small slice of the book: 25 of 195 trades, −$29k of −$557k, v0 without HRC.
- **Why the means are near zero.** Their means sit near zero because of DB 2015–16 (+45.2 %), TAC 2008–09 (+26.5 %) and
  M 2015–16 (+24.4 %). Their medians stay at about −4 %.

### Sector and RS split (`sector-rs-summary.txt`; v0 / v1 s0, joined on `position_id` with the audit's entry `sector_rating` and `rs_trend`, `entry-attrs-*.csv`)

| sector / RS at entry | trades | mean |
|---|---:|---:|
| Weak / negative and declining (the "weakest stock in the weakest sector") | 19 / 15 | −6.9 % / −8.9 % |
| Weak / bearish crossover | 95 / 87 | −3.8 % / −3.2 % |
| Neutral / bearish crossover | 75 / 60 | −6.9 % / −5.8 % |
| Neutral / negative and declining | 4 / 2 | +23.9 % / +18.8 % (too few trades to read) |

The remaining rows are Weak or Neutral with RS "negative improving", 1 trade each, plus one Weak row with no RS label.

## Reading

- **The pool says the score does not predict.** On the broad candidate pool, the short score does not predict which
  Stage-4 breakdowns keep falling, and that includes its weak-sector and weak-RS bonuses. This is consistent with the
  blind read's 3,643 skipped candidates (a coin flip against SPY) and the 14 negative book-rule cohorts. Both are in
  round 1's "Second, independent read".
- **The filled book shows a weak tilt the pool does not confirm.** Shorts the book actually took at score ≥ 100 lost
  less per trade and won twice as often as the rest. The rest of this section explains why that tilt is not evidence
  for a stricter threshold.
- **The two estimands differ.** The pool is mostly names the book could not take (`No_structural_stop`), measured
  from Monday's close with no stops. The filled shorts carry the book's own entry and stop path.
- **The filled tilt is weak evidence.** It is n = 25, one path (salts only re-seed the intraday fill), still negative,
  and carried by three trades.
- **What a test would need.** A stricter threshold would have to be pre-registered and tested as a surface. Even the
  best-case reading (−0.6 % per trade on 25 trades over 26 years) would not make the short book worth running.
- **What remains untested** is the book's short-interest ("sucker short") filter. It needs data the warehouse lacks.
