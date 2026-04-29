# Historical universe membership — long-horizon backtests gap

**Status**: gap captured, no implementation. Owned by `ops-data` track.

## Problem

`universes/sp500.sexp` (and equivalent) is a **single point-in-time
snapshot** — the 491 symbols in SP500 as of 2026-04-26. Back-testing
this static set over a 10y / 30y horizon carries massive **survivorship
bias**:

- Companies that went bankrupt during the window (Lehman 2008, Enron 2001,
  WorldCom 2002, Sears 2018, etc.) aren't in the snapshot.
- Companies that were in SP500 at any point during the window but later
  removed (lots of them — index has high churn) aren't in the snapshot.
- Companies that joined SP500 mid-window (NVDA promoted 2001, TSLA
  promoted 2020, etc.) ARE in the snapshot — and the strategy "knows
  about them" before they would have been investable.

For a 30y window 1996-2026, the authentic universe is **~1,000+ unique
symbols** (every company that was ever in SP500), not 491.

The same shape applies to any indexed universe (S&P 100, Russell 1000,
Nasdaq 100, sector indices). All are point-in-time today.

## What's actually needed

Two missing data sources + one consumer-side filter:

### Data 1 — Historical membership index

Per-month (or per-event) snapshots of "who was in SP500 on this date"
from 1996-present. Each event is `(date, symbol, action)` where action
is `Added` or `Removed`.

**Sources**:

- S&P itself sells the index-membership history (paid).
- Wikipedia maintains a text-based historical changes list — usable but
  requires scraping + parsing; quality varies.
- Some FOSS data sets exist (e.g. `IndexMembership` from various
  finance-data repos on GitHub).

**Representation** (per user 2026-04-30): more efficient than
`(date, full membership list)` for every day. Two cheaper shapes:

- **Snapshot + deltas**: store `(initial_membership_at_T0, [(date, +/- symbol)])`.
  Reconstructing membership at any date is `O(events)` from baseline.
- **Per-symbol intervals**: each symbol carries a list of `(start_date, end_date_or_none)`
  intervals during which it was in the index. Membership query at date `d`
  filters to symbols where `start_date ≤ d ≤ end_date`. `O(symbols × intervals)`
  but indices small enough that this is fast.

The interval representation is probably nicer because it composes with
the existing `universes/*.sexp` shape — augment each entry from
`(symbol)` to `(symbol [(in_window_start in_window_end)+])`.

### Data 2 — Delisted / bankrupt symbol data

EODHD has a delisted-symbols endpoint. We need to:

1. Identify every ex-SP500 symbol that's not in current `universes/sp500.sexp`
   but was at some point during 1996-2026. Cross-reference with the
   historical membership data above.
2. Verify our data layer fetches their OHLCV up through delisting date.
3. Add a "delisted" or "active_through" field on `Daily_price` metadata so
   downstream loaders know not to expect bars after that date.

The audit in `dev/notes/data-availability-2026-04-29.md` found 37,877
total symbols in `/workspaces/trading-1/data/`. SOME of those are
likely delisted, but we don't know which, and we don't know if coverage
is complete for the relevant set.

### Consumer 3 — Point-in-time membership filter

In the screener (or panel-loader), accept a `membership_at` callback /
table. On each decision date, filter the loaded universe to symbols
actually in the index on that date. Symbols whose interval doesn't
include the current date are dropped from candidate consideration.

This is a small change in the screener cascade — a new pre-filter that
runs before stage classification. Doesn't touch the cascade logic
itself.

## Why this is on `ops-data`, not on a feature track

The data fetch + persistence + reconciliation work is data-pipeline
infrastructure — same shape as the existing sector-data + universe-snapshot
work. Once the data + filter exist, individual feature tracks (backtest,
short-side, optimal-strategy) consume them transparently.

## Phasing (suggested)

| Phase | Scope | Owner |
|---|---|---|
| **P1** — membership data fetch | Pull SP500 historical membership from a chosen source (Wikipedia first, paid SP later). Persist as `data/index-membership/sp500.sexp` in the per-symbol-intervals shape. | ops-data |
| **P2** — delisted-symbol audit | Cross-reference ever-SP500 symbols against current data inventory. Identify gaps. Fetch missing via EODHD delisted endpoint. | ops-data |
| **P3** — `Daily_price` metadata extension | Add `active_through : Date.t option` field. Loaders treat post-`active_through` as missing rather than expecting bars. | data-types |
| **P4** — universe sexp shape extension | Augment `universes/*.sexp` entries with intervals. Backward-compat: a single open-ended interval = "always present" preserves current behavior. | data-types |
| **P5** — screener point-in-time filter | New pre-filter in `Screener.screen` that drops out-of-window symbols on each decision date. | feat-weinstein |
| **P6** — historical-universe scenario | New `goldens-broad/sp500-historical-30y.sexp` that exercises the full pipeline. Re-run capacity validation with point-in-time membership active. | feat-backtest |

## Until this lands

Long-horizon (≥10y) backtests on indexed universes are **capacity validations
only, not strategy validations.** Metrics are inflated by survivorship bias.
Document this caveat on every long-horizon scenario's results note.

The 6y / 10y `goldens-broad` cells are mildly affected (some companies
were removed from SP500 during 2018-2024, e.g. AT&T, GE downgrades);
30y is severely affected.

## Cross-references

- `dev/notes/data-availability-2026-04-29.md` — coverage audit that
  surfaced this (305/491 of current SP500 has ≥30y history; doesn't
  account for ex-members).
- `dev/notes/session-followups-2026-04-29-evening.md` — the broader
  followups index.
- `dev/status/sector-data.md` — the analogous data-pipeline track for
  sector membership (already MERGED; provides the template).
- `analysis/data/sources/eodhd_*.ml` — EODHD client; probably needs a
  new endpoint binding for delisted symbols.

## Why "snapshot series" representation matters

(Per user's 2026-04-30 insight.)

Naive: `(date, [symbol_1, symbol_2, ..., symbol_N])` for every trading
day in a 30y window = ~7,500 days × ~500 symbols × 5 chars = ~19 MB
just for SP500. Across all indexed universes (Nasdaq, Russell, sectors,
etc.) it scales linearly.

Snapshot + deltas: ~500 symbols at T0 + ~30 events/year × 30 years
= ~1,400 events total ≈ ~50 KB. ~400× smaller.

Per-symbol intervals: ~1,000 unique-ever symbols × ~2 intervals avg ≈
~2,000 entries ≈ ~80 KB. Slightly larger than snapshot+deltas but
trivially queryable (filter symbols by interval inclusion).

For very long windows (50y, 100y) the difference becomes catastrophic.
The interval representation is the right abstraction.
