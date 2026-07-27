# Plan — LH phantom SHORT + duplicated `trades.csv` rows (issue #2059)

Date: 2026-07-27
Track: `simulation` / `trade-audit`
Branch: `fix/lh-phantom-short`

## Context

Issue #2059 reports three defects on one symbol in the promoted-bundle record
basis (`scenarios-2026-07-23-162636/m4p-baseline`, `enable_short_side false`):

```
LH,LONG, 2001-06-09,2001-06-12,   3,69.72, 68.30,3868,  -5482.50,  -2.03,...,LH-wein-536
LH,SHORT,2001-06-13,2024-08-10,8459,67.40,224.30,1934,-303450.40,-232.80,...,LH-wein-536
LH,SHORT,2001-06-13,2024-08-10,8459,67.40,224.30,1934,-303450.40,-232.80,...,LH-wein-536
```

1. A `SHORT` in a long-only run.
2. An 8,459-day hold no exit channel re-evaluated.
3. The `SHORT` row duplicated exactly, so realized-PnL aggregation double-counts.

The warehouse and run artefacts are not present in this container, so the fix
is derived from the code plus the numbers in the rows themselves.

## Evidence read off the rows

Three independent numeric facts constrain the mechanism hard:

- **`quantity` 3868 = 2 x 1934.** LabCorp (`LH`) split 2-for-1 with effect
  **2001-06-12** — exactly the LONG row's `exit_date`. So the true entry fill was
  `Buy 1934 @ 139.44` and `_make_trade_metric`'s split restatement
  (`quantity = entry.quantity *. factor`, `entry_price = entry.price /. factor`)
  turns it into the reported `3868 @ 69.72`. The SHORT row's `1934 @ 67.40` is a
  raw, unrestated post-split fill.
- **`position_id` is identical on all three rows.** This is *not* evidence that
  the three rows share a position record. `Trade_context._position_id_for_trade`
  joins round-trips to audit records by `(symbol, entry_date)` with a
  **7-calendar-day backward window** (`_audit_lookup_window_days = 7`). The
  phantom SHORT's `entry_date` 2001-06-13 is 4 days after the LONG's audit
  decision date, so it falls into the same window and inherits `LH-wein-536`. The
  join is loose; the shared id says only "no audit record of its own", i.e. **the
  strategy never decided to open this short**.
- **`days_held` 8459** = `Date.diff 2024-08-10 2001-06-13`, and `224.30` is LH's
  real Aug-2024 price. So the "cover" is an ordinary **2024 re-entry Buy** on LH
  being consumed as the closing leg of a 2001 phantom short.

## Root cause

`Trading_simulation.Metrics.extract_round_trips` (`metrics.ml`) is **not
quantity-faithful**. `_pair_step` / `_pop_matching_entry` pop an *entire* open
entry for *any* opposing trade, whatever its quantity:

```ocaml
| (_, head) :: _ when _opposes head trade -> (* pops the whole entry *)
| _ -> (open_entries @ [ t ], metrics)   (* any orphan trade OPENS an entry *)
```

Two consequences chain:

- **Residual drop.** A closing trade smaller than the open entry consumes the
  whole entry; the residual shares silently disappear from the fold. The emitted
  row books the **full entry quantity** against the **partial exit price**, so
  its P&L is over-stated.
- **Orphan re-interpretation.** The *next* closing trade then finds
  `open_entries` empty and falls into the `| _ ->` arm, which **opens a new entry
  on the closing side** — a `Sell` becomes a SHORT open. That short sits in the
  fold across the rest of the run and is eventually "covered" by an unrelated
  later re-entry `Buy`, producing a multi-decade SHORT row with inverted P&L.

For LH: entry `Buy 1934 @ 139.44` (2001-06-09); portfolio holds 3868 after the
2001-06-12 split; the stop-out sells `1934` on 2001-06-12 and the remaining
`1934` on 2001-06-13. Step by step under current code:

| trade | current behaviour | emitted row |
|---|---|---|
| `Buy 1934 @ 139.44` (06-09) | opens entry | — |
| `Sell 1934 @ 68.30` (06-12) | qty 1934x2=3868 != 1934, no match -> FIFO pop **whole** entry | `LONG 3868 @ 69.72 -> 68.30` (matches row 1 exactly) |
| `Sell 1934 @ 67.40` (06-13) | `open_entries` empty -> **opens a SHORT** | — |
| `Buy 1934 @ 224.30` (2024-08-10) | closes the phantom short | `SHORT 1934 @ 67.40 -> 224.30, 8459d` (matches rows 2/3 exactly) |

This reproduces every field of rows 1 and 2 from a stream containing **no short
trade at all**, which is why a run with `enable_short_side false` can print one.
It is the same failure class the codebase already documents for the warmup
boundary (`Runner.round_trips_in_window` .mli: an orphaned in-window `Sell`
"reads as a short-open ... producing a spurious SHORT round-trip with inverted
P&L even in an `enable_short_side = false` backtest") — that mitigation only
covers orphans created by *window truncation*, not orphans created by a
*residual*.

**Common cause:** yes. Defects 1 and 2 are the same emission (the phantom short
is by construction never re-evaluated, because it does not exist in the portfolio
or in any strategy position map — it exists only inside the pairing fold).
Defect 3 is the same mechanism firing twice on one symbol: every orphaned `Sell`
opens its own phantom short, and two orphans with identical date/price/quantity
produce byte-identical rows that `Trade_context`'s loose join then decorates
identically.

## Approach

Make the pairing quantity-faithful: track the **unconsumed quantity** on each
open entry, and let a closing trade consume across entries.

- `_open_entry = { entry_date; trade; remaining }` (`remaining` on the entry-date
  share basis).
- A closing trade consumes `min(remaining, exit_qty_restated_to_entry_basis)` from
  the selected entry, emits **one metric per entry leg touched** carrying the
  *consumed* quantity, and repeats with what is left of the exit.
- Entry selection keeps today's rule: prefer the open entry whose split-adjusted
  `remaining` matches the exit quantity exactly, else oldest (FIFO).
- Only a genuine **over-close** (exit quantity exceeding all open entries) opens
  an entry on the closing side — which is the correct reading, since the
  portfolio really is short in that case (`Portfolio` supports direction change).

Bit-identical for the alternating full-exit stream (entry qty == exit qty
consumes exactly, no leftover), for the sibling scale-in stream (#1847), and for
every split-straddling full exit. Only streams with *partial* exits change — and
those are the ones that are wrong today.

## Files to change

- `trading/trading/simulation/lib/metrics.ml` — residual-tracking pairing.
- `trading/trading/simulation/lib/metrics.mli` — contract update on
  `extract_round_trips`.
- `trading/trading/simulation/test/test_metrics.ml` — new tests; one existing
  test updated (see below).
- `dev/status/simulation.md`, `dev/status/trade-audit.md` — status + the
  characterise-and-file item.

## Expected disposition of the three defects

- **Defect 1 (SHORT in a long-only run) — CLOSE.** The residual-orphan class is
  the only mechanism that can print a SHORT row from a long-only trade stream,
  and it is removed. A SHORT row can then only come from a real short fill.
- **Defect 2 (8,459-day zombie) — CLOSE.** Same emission. Note it was never a
  portfolio zombie: nothing was held: the row is manufactured by the fold, which
  is *why* no exit channel ever re-evaluated it.
- **Defect 3 (exact duplicate rows) — CLOSE for the residual-orphan cause,
  CHARACTERISE the residual case.** Each orphan produced its own phantom short;
  with residuals consumed, orphans stop being produced. If the real 2001-06-13
  stream additionally contained a genuine **over-sell** (two `Sell 1934` on one
  day against 1934 held), one SHORT row survives the fix — correctly, because the
  portfolio genuinely flipped short. That upstream question (can a fill flip a
  position's sign?) is filed, not fixed, here.

## Existing test being updated (not weakened)

`test_extract_round_trips_mismatched_qty_falls_back_to_fifo` currently asserts
that `Buy 100 @10 / Buy 50 @12 / Sell 70 @15` yields one row with
`quantity = 100`. That expectation *encodes the over-count bug* (100 shares
booked for a 70-share sell). It becomes `quantity = 70`; the assertion that the
row's `entry_price` is `10.0` (i.e. FIFO selection, not the 50-lot) is retained,
so the branch the test exists to pin is still pinned.

## Risks

- **Golden churn.** Any scenario golden whose stream contains a partial exit
  (trim / maintenance-reduce / harvest-rotate / split-straddling stop) changes
  `trades.csv`, `n_round_trips`, `total_pnl`, `win_rate`, `avg_holding_days`.
  This is the fix, not a regression, but it must be surfaced. Mitigation: run the
  full suite and report every golden that moves.
- **Function length / nesting linters** on the new consume loop. Mitigation: keep
  the recursion a small named helper.
- **`Metrics` is simulation-layer, not core.** No core module
  (`Portfolio`/`Orders`/`Position`/`Strategy`/`Engine`) is touched, and
  `weinstein_strategy.ml` / the stop machine are not touched.

## Acceptance

- A test reproducing **the exact numbers in issue #2059** from a pure-long trade
  stream (`Buy 1934 @139.44`, 2:1 split 06-12, `Sell 1934 @68.30`,
  `Sell 1934 @67.40`, `Buy 1934 @224.30` in 2024) fails before the fix with a
  `SHORT ... 8459` row and passes after with two correct `LONG` rows.
- A test with two orphaned sells asserts the **exact row multiset** (not a count)
  and shows no duplicate pair.
- Partial-exit arithmetic, over-close leftover, and FIFO-vs-quantity selection
  each pinned by a test whose assertion dies under mutation.
- `dune build @fmt`, `dune build`, `dune runtest` all exit 0.

## Out of scope

- `weinstein_strategy.ml` and core stop-machine code (`dev/decisions.md`, binding
  on `feat-backtest`). Nothing here needs them.
- The upstream question of whether a single fill may flip a position's sign
  long -> short (the genuine-over-sell variant of defect 1). Filed in
  `dev/status/simulation.md` with the proposed invariant and location.
- `forward_trace.ml:173` stale-anchor FLAG (another review's item).
- `Trade_context`'s loose 7-day symbol-window `position_id` join, which makes
  `position_id` unreliable as a forensic key. Filed, not fixed.
