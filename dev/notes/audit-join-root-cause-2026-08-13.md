# The audit join is date-proximity, and that is why 51% of trades.csv is empty

**Carried-forward #18 and #4 are the same bug.** Diagnosed 2026-08-13 against
the committed acceptance run (`/tmp/p02/base_out/nf-small-00-core/`, 288 trades,
302-symbol universe, 2018-2023, ladder-v4 cell-00 config).

## What was measured

`#18` was filed as "`stop_initial_distance_pct` empty on ~57% of trades.csv
rows". It is not a column bug. **Four columns are empty on exactly the same
rows:**

| column | empty | % |
|---|---|---|
| `entry_stage` | 147 | 51.0 |
| `stop_initial_distance_pct` | 147 | 51.0 |
| `position_id` | 147 | 51.0 |
| `stop_fill_distance_pct` | 147 | 51.0 |

Identical row sets, not merely identical counts. Every one of those columns is
derived from the audit record in `Trade_context.of_precomputed`, so this is
**one join failing 147 times**, not four independent emission gaps.

That rules out the obvious first hypothesis. `_stop_initial_distance_pct`
returns `None` when `suggested_entry <= 0.0`, which would have been a plausible
cause on its own — but of the 147 empty rows, **0** had a populated
`entry_stage` (which needs no `suggested_entry`). All 147 lost the audit record
itself.

## Why the join fails

`_lookup_audit_for_trade` (`trading/backtest/lib/trade_context.ml:161`) matches
on `(symbol, entry_date)`, falling back to the most recent audit record for the
symbol within `_audit_lookup_window_days = 7` **before** the trade's entry date.

For all 147 unmatched trades:

- **every symbol has audit records** — 0 rows failed for "no audit record for
  this symbol";
- **every row has a prior audit record** — 0 rows failed for "records exist only
  after the trade";
- **not one of them is within 7 days**. Mean gap to the nearest prior record
  **96.7 days**, max **1322 days**. 71 rows sit in the 0-1 month bucket, 27 in
  1-2 months, and a long tail past two years.

So the window is not marginally too narrow — for the trades it misses, the
nearest candidate is typically months away.

## The part that invalidates a published measurement

The ladder-v4 spec headers carry this caveat:

> AUDIT LIMIT: ticket-age-at-FILL is structurally capped at ~1 week until the
> position_id join lands (#2270 audit limitation).

**That cap is circular.** Ticket age at fill is capped at ~1 week *because the
join window is 1 week*: a ticket that rested longer has no audit record within
7 days of its fill, so it does not appear as an aged ticket — it appears as an
empty row and drops out of the analysis entirely. The observed distribution is
not a truncated view of ticket age; it is the join window reflected back.

The same applies to any audit-derived statistic computed over trades.csv to
date: it was computed on the ~49% of trades whose fill happened to land within
a week of a screening decision. That subset is **not random** — it is precisely
the trades that filled promptly, which is the opposite end of the distribution
from the resting-ticket behaviour the entry-ticket program is trying to measure.

## Why a wider window is the wrong fix

Widening `_audit_lookup_window_days` trades one error for another: at a 96-day
mean gap the "most recent record within the window" stops being identifiable.
A symbol re-screened several times over a quarter would attach the wrong
decision to the fill, silently — worse than an empty column, because an empty
column is visible.

The right key already exists on both sides but is not carried across:

- audit records carry `entry.position_id` (e.g. `AAL-wein-298`);
- the simulator carries position ids, including an explicit
  `(order_id, position_id)` link per generated order
  (`trading/simulation/lib/order_generator.mli:33`);
- but `Round_trip_pairing.trade_metrics` — the record `trades.csv` is written
  from — has **no position id field**, so the id is lost at the pairing step and
  `trade_context` is left to guess by date.

`trades.csv`'s own `position_id` column is populated *from the matched audit
record*, so it cannot serve as the join key: it is an output of the join, not an
input to it. This is why the fix is plumbing, not a threshold change.

## The fix (= carried-forward #4)

Thread `position_id` from the simulator through round-trip pairing into
`trade_metrics`, then join audit by position id, keeping the date window only as
a fallback for rows that genuinely lack one.

Expected acceptance: the four columns above populate on ~100% of rows, and the
ticket-age-at-fill distribution extends past one week — at which point the
ladder-v4 caveat can be retired and stop-width comparisons against the record
arm (record 100% populated vs ours 43%) become possible.

## Reproducing

```sh
# the four columns, same rows:
awk -F, 'NR>1 {n++; if ($16=="") e16++; if ($14=="") e14++; if ($20=="") e20++;
  if ($16=="" && $14!="") sig_only++}
  END {print n, e14, e16, e20, sig_only+0}' trades.csv

# gap to nearest prior audit record for the empty rows:
grep -oE '\(symbol [A-Z.-]+\) \(entry_date [0-9-]+\)' trade_audit.sexp \
  | sed -E 's/\(symbol ([A-Z.-]+)\) \(entry_date ([0-9-]+)\)/\1 \2/' | sort -u
```
