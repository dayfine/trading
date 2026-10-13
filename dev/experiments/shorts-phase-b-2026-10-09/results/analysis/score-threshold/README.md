# Score-threshold check (addendum, 2026-10-12)

**Question** (user, 2026-10-12): should the short threshold be stricter? In other words, would a higher minimum
screener score have picked better shorts?

**Answer: no.** A stricter score does not separate shorts that keep falling from those that don't. On the whole
candidate pool, every threshold is a coin flip against an SPY short, and at 120 bars the highest scores do worse.

## Method

`run.sh` regenerates every output from the repo root.

**The candidate pool** (`pool.csv`, 1,491 rows):
- Every ranked short candidate in `alternatives_considered` of v0 s0's 219 entry decisions.
- Deduplicated on symbol and decision date, and keyed to the decision's `placement_date`.
- This covers only the weeks in which a short was entered. The same stock in consecutive weeks appears more than
  once, so rows are not independent.

**Forward return** (`fwd.csv`):
- Entry at the adjusted close of the first bar after the decision date. This is not the trigger fill, and no stops
  are applied.
- Side-signed returns at +20 / +60 / +120 bars.

**Excess** (`excess.csv`): the candidate's short return minus an SPY short over the same two dates.

**Filled shorts** (`trades-summary.txt`): the committed v0 and v1 s0 `trades.csv`, cumulative by
`screener_score_at_entry`.

**Inputs:**
- the v0 s0 `trade_audit.sexp`, from the sweep output (11 MB, not committed; `pool.csv` is its extract);
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

- **The dispersion is wide:** p10 / p90 is about −12 / +13 % at +20 bars and about −28 / +28 % at +120.
- **In absolute terms,** 47.9 % of all candidates were lower after 60 bars, 48.7 % at score ≥ 100 and 46.3 % at score ≥ 105.

### Filled shorts (v0 s0)

| score ≥ | trades | win rate | mean | P&L |
|---|---:|---:|---:|---:|
| all | 196 | 18 % | −4.7 % | −$610k |
| 90 | 136 | 19 % | −5.1 % | −$493k |
| 100 | 26 | 31 % | −4.1 % | −$82k |

- The score ≥ 100 row is 26 small trades.
- It includes HRC 2005 (−92.8 %), the data-defect splice (§8.7 defect 2).
- v1 is the same shape (`trades-summary.txt`).

### Sector and RS split (`sector-rs-summary.txt`; v0 / v1 s0, joined on `position_id` with the audit's entry `sector_rating` and `rs_trend`, `entry-attrs-*.csv`)

| sector / RS at entry | trades | mean |
|---|---:|---:|
| Weak / negative and declining (the "weakest stock in the weakest sector") | 19 / 15 | −6.9 % / −8.9 % |
| Weak / bearish crossover | 95 / 87 | −3.8 % / −3.2 % |
| Neutral / bearish crossover | 75 / 60 | −6.9 % / −5.8 % |

## Reading

- **The score does not predict.** The short score, including its weak-sector and weak-RS bonuses, does not predict which
  Stage-4 breakdowns keep falling. A stricter threshold shrinks the book toward zero trades without improving the
  shorts it keeps.
- **It is the same finding from a third angle.** It matches the blind read's 3,643 skipped candidates, which were a
  coin flip against SPY, and the 14 negative book-rule cohorts in §8.
- **The verdict is unchanged.** It does not change the round-1 verdict or decision 10.
- **What remains untested** is the book's short-interest ("sucker short") filter, which needs data the warehouse
  lacks.
