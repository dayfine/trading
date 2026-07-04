# Scale-in v1 — participation-effect measurement (P0, 2026-07-03; CORRECTED 2026-07-04)

> **CORRECTION (2026-07-04).** The first version of this writeup (merged in
> #1843) claimed the add channel "never functioned" (adds structurally
> unfillable, `StopLimit(close,close)` root cause, cash-reservation
> re-attribution). **Those claims were wrong** — artifacts of a real reporting
> bug in `Metrics.extract_round_trips` (see §"The actual bug"). A full
> pipeline trace (emit → order-gen → fill-route) shows **adds fill routinely:
> sp500 fold-001 pullback 4/4; broad fold-011 pullback 19/20.** The original
> ledger WHYs stand as written. This file now records (a) the still-valid
> participation measurements, (b) the retraction, and (c) the two genuine
> defects the investigation surfaced.

Measures the causal chain behind the scale-in verdict
(`dev/notes/scale-in-wfcv-2026-07-03.md`, ledger `2026-07-03-scale-in-v1-surface`):
*½-sizing frees cash → previously `Insufficient_cash` near-misses get funded →
broader participation*. Scenarios: sp500 fold-001 (2001-12-31..2003-12-30,
N=515) + broad top-3000 fold-010 (2019-12-27..2021-12-25, bull-divergence) and
fold-011 (2021-12-26..2023-12-25, bear) × {baseline, pullback@0.5,
either_loose@0.5+ext0.25 (broad) / either@0.15 (sp500)}, all on current main.

## Valid results — participation (audit-based; unaffected by the bug)

These come from `trade_audit.sexp` funded-entry records and alternatives
(skip reasons), not from trades.csv:

| Fold / metric | baseline | pullback | either(_loose) |
|---|---|---|---|
| **sp500 f001** entries / uniq syms / Fridays | 46 / 43 / 22 | 73 / 65 / 27 | ≡ pullback |
| **sp500 f001** cash-skip events / avg entry | 263 / $169k | 245 / $98k | ≡ |
| **broad f010** entries / uniq syms / Fridays | 85 / 79 / 47 | 147 / 134 / 68 | 137 / 122 / 62 |
| **broad f010** skips per entry-Friday | 10.5 | 10.1 | 10.2 |
| **broad f011** entries / uniq syms / Fridays | 67 / 61 / 40 | 120 / 108 / 56 | 98 / 91 / 47 |
| **broad f011** avg entry | $123k | $72k | $80k |

**Near-miss linkage (the P0 question — answered YES):** of symbols entered by
a scale-in variant but never by baseline, the fraction present in baseline's
`Insufficient_cash` skip set: sp500 f001 24/26 (92%); broad f010 56/69 (81%)
pullback, 45/55 (82%) either_loose; broad f011 48/61 (79%) pullback, 40/48
(83%) either_loose. **The freed cash demonstrably reaches the near-misses.**
Skips-per-Friday stays flat (~10) — the cash constraint always binds; ½-sizing
converts position size into breadth ~1:1.

Headline (equity-curve) metrics per cell — also valid (fold-level, not
round-trip-derived): sp500 f001 23.5%→17.6%; broad f010 72.0/64.9/54.7%
(baseline/pullback/either_loose), Sharpe 1.30/1.26/1.21, MaxDD 18.5/20.9/15.9;
broad f011 −10.2/−9.4/−1.8%, Sharpe −0.42/−0.41/−0.03, MaxDD 23.6/23.3/18.6.

## Instrumented add flow (pipeline trace: emit → order-gen → fill-route)

| Cell | adds emitted+funded | orders created | **filled** |
|---|---|---|---|
| sp500 f001 pullback | 4 | 4 | **4** |
| broad f011 pullback | 20 | 20 | **19** |
| broad f011 either_loose | 22 (≈$736k reserved at emit) | (not re-traced) | — |

**Adds fill.** The simulator translates every `CreateEntering` to a
`Market`/Day order (`Order_generator._create_order`) which fills the next
session. The original ledger note "adds DO fire ~4/fold" was accurate.

## The actual bug: sibling round-trips are chimera'd in reporting

`Metrics._pair_trades_for_symbol` pairs each symbol's **date-sorted trade
stream** as consecutive (entry-side, exit-side) pairs, with no quantity or
position-identity check. Sibling positions (scale-in's parent + add on one
symbol) produce the stream `Buy(parent), Buy(add), Sell(parent), Sell(add)`:

- `(B_parent, B_add)` fails the side check → **B_parent silently dropped**;
- `(B_add, S_parent)` pairs → a **chimera row** with the add's entry
  date/quantity against the parent's exit date/price;
- `S_add` is left unpaired → **dropped**.

Verified end-to-end on NPKI (broad f011 pullback): parent filled 2022-02-12
qty 11051, add filled 2022-03-05 qty 10684 — trades.csv contains ONE row
(entry 2022-03-05, qty 10684, exit 2022-04-26). The parent's round trip is
gone. `open_positions.csv` merges siblings the same way (CERN row = 3149 sh =
parent 2623 + add 526).

**Blast radius:** `trades.csv`, `total_trades`, `win_rate`,
`avg_holding_days`, and every per-trade analysis for any scale-in-enabled
run. Equity-curve metrics (return / Sharpe / MaxDD / Calmar — everything the
WF-CV verdict used) are unaffected. **All trades.csv-based add counting —
including this writeup's first version and its "4/4 fills collide with parent
exits" claim — is invalid.** The "collisions" were chimera rows whose entry
date happened to equal an adjacent leg's exit date.

## Retractions (from this writeup's first version, merged in #1843)

1. ~~"The add channel never functioned; adds structurally unfillable."~~
   WRONG — adds fill via Market orders (4/4, 19/20 traced). The "1–2 filled
   adds" counts were chimera artifacts.
2. ~~"Root cause: zero-width `StopLimit(close,close)`."~~ That order shape
   exists only on the **live-broker path** (`Weinstein_order_gen`), which
   backtests do not use (simulator = Market orders; the divergence is a
   documented TODO in `order_generator.ml`). Still a live-path concern — see
   "Genuine defects" — but not an explanation of any backtest result.
3. ~~"either_loose's smoothing = cash-reservation throttle, not adds."~~ The
   emit-Friday reservation is real (measured ≈$590–736k cumulative per f011
   cell) but adds fill, so the original WHY(2) attribution is restored: the
   Either-triggered continuation adds @ ext 0.25 are the risk-improving
   half. The fold-011 contrast (pullback: more breadth, ≈ baseline;
   either_loose: the whole improvement) is consistent with WHY(2) —
   pullback-triggered adds ≈ neutral.
4. The ledger amendment and writeup amendment shipped in #1843 are superseded
   by the corrected text shipped with this file.

## Genuine defects surfaced (kept)

1. **Reporting: `Metrics.extract_round_trips` breaks under sibling
   positions** (chimera + dropped legs). Fix: quantity-aware pairing (or
   position-id attribution). Scale-in is default-off, so goldens / default
   runs are unaffected; the fix must be bit-identical for
   single-position-per-symbol streams.
2. **Live/backtest order divergence for adds:** live emits
   `StopLimit(close, close)` for every entry including adds
   (`Weinstein_order_gen._entry_order`); the simulator uses Market. For
   breakout entries the stop-limit sits above market at the breakout level
   (reasonable); for adds it sits AT market on a strength signal — live, a
   gap-up never fills and a retreat fills adversely. If scale-in is ever
   promoted, the live add path needs a fillable order shape.
3. **`add_fraction` coupling** (still true): v1 sizes adds as
   `1 − initial_entry_fraction`, so the "full-size entries + continuation
   adds" untested shape needs an explicit `add_fraction` knob first.

## Bottom line

- REJECT verdict and all three original ledger WHYs: **unchanged, restored.**
- P0 participation question: **answered and valid** — near-miss linkage
  79–92%, breadth conversion ~1:1, fat-tail tax visible per-decision
  (avg entry roughly halves; sp500 f001 return 23.5→17.6%).
- New actionable work: fix the round-trip pairing bug (real, code); live
  add-order shape + `add_fraction` knob remain prerequisites if the untested
  shape is ever built.
