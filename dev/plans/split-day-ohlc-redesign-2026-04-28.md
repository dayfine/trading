# Split-day OHLC redesign — broker-model approach (2026-04-28)

Supersedes the closed PR #641 band-aid. Plan-only PR; no code lands here.
Implementation phased over 4 follow-up PRs.

## Problem statement

`Daily_price.t` carries both `close_price` (raw, as-printed-on-the-day) and
`adjusted_close` (back-rolled for splits and dividends to "now"). Each layer of
the system uses a different one:

| Layer | OHLC source | Effect |
|---|---|---|
| Simulator MtM (`_compute_portfolio_value`) | raw `close_price` | drops by `1/split_factor` on the actual split day |
| Simulator fills (`_to_price_bar` → engine) | raw OHLC | trade fills at raw prices, `cost_basis` is raw |
| Strategy `get_price` (`_make_get_price`) | raw OHLC (whatever the adapter returns) | screener sees raw highs/lows |
| Panel `weekly_view.closes` (`Ohlcv_panels.adjusted_close`) | adjusted | smooth across splits — what you want for MA / RS / breakout |
| Panel `weekly_view.highs`, `weekly_view.lows` | raw | jagged across splits |

So the screener computes a 30-week MA on adjusted closes (~$124 pre-split for
AAPL) but resistance highs from raw bars (~$211 pre-split for AAPL pre-Aug-2020):
internally inconsistent. Worse, on the actual split day the simulator's MtM
crashes by `1 - 1/split_factor` — AAPL 2020-08-31 4:1 caused a 75% phantom drop
in sp500-2019-2023 portfolio equity (briefly $25K from $520K, recovered next
bar). MaxDD on that scenario was 97.7% versus a true ~5%.

References:
- `dev/notes/session-followups-2026-04-28.md` §1 (full symptom + root cause)
- `dev/notes/goldens-performance-baselines-2026-04-28.md` (the 97.7% MaxDD)
- Closed PR #641 body (the failed band-aid + side-effect inventory)

## Why the band-aid (PR #641) failed

PR #641 added `_split_adjust_bar` to the simulator's MtM and `get_price` paths.
Algorithm: scale every OHLC field by `adjusted_close / close_price` and replace
`close_price` with `adjusted_close`.

The flaw: EODHD's `adjusted_close` is **back-rolled for every future corporate
action** — splits AND dividends. For any symbol with future corporate actions
every historical bar has `adjusted_close ≠ close_price`, by an
accumulating factor. The fix therefore rescales every pre-corporate-action
bar, not just split days.

Consequences observed in CI:
- panel-golden-2019-full: 7 → 6 round-trips
- tiered-loader-parity: HD long-hold replaced by JPM
- 6-year 2018-2023: 45/42/39 → 41/37/34
- portfolio-positive 2020-21: 6/6/6 → 5/4/4
- sp500-2019-2023: 478 trades dropped to 30 — no longer comparable to
  baseline

These are not "the bug is now fixed and prior numbers were wrong"; they're
"the fix changes fill prices and position sizing on every pre-corporate-action
day, even when no position is held across an actual split". PR #641 held
indefinitely.

## Recommended approach: broker model

The broker model treats splits as a **discrete event on the position
ledger**, not a continuous adjustment to the price series. Live brokerage
does this: a 4:1 split doesn't change the printed price history; it
multiplies your share count and divides your cost basis on settlement day.

### Core invariants

1. **All OHLC reads stay raw, everywhere.** Simulator, engine, screener,
   resistance, breakout — every consumer reads `close_price`,
   `high_price`, `low_price`, `open_price` directly from
   `Daily_price.t`. No rescaling.
2. **Positions track raw shares.** A position's `quantity` is what you'd
   see on a brokerage statement at that moment in time.
3. **On a split day, the position ledger applies the split.** Quantity
   multiplies by `split_factor`, `cost_basis_per_share` divides by
   `split_factor`. Total cost basis (= `quantity * cost_basis_per_share`)
   is preserved exactly. Realized P&L unchanged.
4. **`adjusted_close` is used only where back-rolled smoothness is what
   you want**: relative-strength line, moving averages, momentum,
   breakout-vs-historical-resistance. Not for execution; not for MtM;
   not for `cost_basis`.

### Worked example — AAPL 2020-08-31 4:1

Pre-split (2020-08-28 close): you hold 400 shares, cost basis $200/share,
total cost basis $80,000. Raw close: $499.23.

- Pre-split MtM: 400 × $499.23 = $199,692.

Split day (2020-08-31): broker model applies the split before MtM.

- Quantity: 400 × 4 = **1600 shares**.
- Cost basis: $200/4 = $50/share. Total cost basis: 1600 × $50 = $80,000
  (preserved).
- Raw close 2020-08-31: $129.04.
- Post-split MtM: 1600 × $129.04 = $206,464.

Continuous through the split — no phantom 75% drop. The actual day's price
move (~3.4% up) is what shows up.

### Why this beats the band-aid

- **Fixes split-day MtM exactly.** No phantom drop, no rescaling.
- **No effect on non-split days.** Raw OHLC flows through unchanged, so
  pre-#641 baselines on windows containing no actual splits stay
  bit-identical.
- **No coupling to dividends.** Adjusted-close back-rolls dividends too,
  but we no longer touch `adjusted_close` in the simulator. Dividends
  are a separate-ledger concern (out of scope; see §Risks).
- **Matches live broker semantics.** A future live-mode adapter applies
  the same split event to the position ledger when EODHD reports a
  corporate action — same code path as the simulator.

## Detection of split days

We must identify "today is a split day for symbol S, with factor F".
EODHD's daily bars don't carry a `corporate_action` field directly, but
the relationship between `close_price` and `adjusted_close` encodes it.

### Three candidate detectors

**Option 1 — close ratio comparison (chosen).** On day t:
```
raw_ratio  = close_price[t] / close_price[t-1]
adj_ratio  = adjusted_close[t] / adjusted_close[t-1]
split_factor[t] = adj_ratio / raw_ratio
```

For non-split, non-dividend days, `split_factor[t] ≈ 1.0`. For pure split
days, `split_factor[t] = N/M` (e.g. 4.0 for 4:1, 0.5 for 1:2 reverse, 1.5
for 3:2). Dividends produce a small `≠ 1.0` deviation (typically
< 1.01); discriminate splits from dividends by **a tolerance band**:
declare a split when `|split_factor - 1.0| > 0.05` (5%) AND
`split_factor` is within ε of a small rational `N/M` for `N, M ≤ 20`.

**Option 2 — adjustment-factor jump.** Track
`f[t] = adjusted_close[t] / close_price[t]`. On non-corporate-action days
`f[t] = f[t-1]` (back-roll factor is constant). On split day,
`f[t] = f[t-1] / split_factor`. Detect when `f[t] / f[t-1]` deviates from
1.0 by more than dividend tolerance.

**Option 3 — explicit corporate-action feed.** Query EODHD's
`/api/splits/{symbol}` endpoint. Cleanest semantics, but pulls a
second data dependency, requires cache + offline support, and the live
DATA_SOURCE seam grows.

**Choosing Option 1.** Reasons:

1. **Self-contained in the panel.** No new EODHD endpoint, no cache
   plumbing, no new IO. The detector is a pure function on the existing
   `Daily_price.t` series.
2. **Discriminates splits from dividends.** The 5% threshold separates
   real splits (always ≥ 1.5× or ≤ 0.67×) from dividends (typically
   < 1%). `Option 2` requires a similar threshold but the jump signal is
   harder to interpret because dividends accumulate into the back-roll
   factor.
3. **Robust to floating-point noise.** Snapping to `N/M` for small N, M
   filters numerical artefacts. PR-1 pins the snap tolerance via tests.
4. **Easy to upgrade later.** If we later need fractional splits or
   spinoffs, switching to Option 3 is a localised change behind the
   detector's interface.

The detector is a pure function:
```ocaml
(** Detect a split between consecutive Daily_price bars.
    Returns Some factor where factor = new_shares / old_shares
    (e.g. 4.0 for 4:1 forward split, 0.5 for 1:2 reverse split).
    Returns None for non-split days (including pure-dividend days). *)
val detect_split :
  prev:Daily_price.t -> curr:Daily_price.t -> float option
```

## Implementation phases

Four PRs. PR-1 is a self-contained primitive + tests; PR-4 re-enables the
regression test from the closed #641 and asserts the original goldens
unchanged.

### PR-1 — split-day detection primitive (smallest unit)

- `trading/analysis/data/types/lib/split_detector.{ml,mli}` — new module.
  Pure function `detect_split` per §Detection. Configurable tolerance
  (`?dividend_threshold = 0.05`, `?rational_snap_tolerance = 1e-3`,
  `?max_denominator = 20`).
- `trading/analysis/data/types/test/test_split_detector.ml` — fixtures:
  - Synthetic AAPL Aug-2020 4:1 day (raw 499.23 → 129.04, adjusted 124.81
    → 129.04) → `Some 4.0`.
  - Reverse-split fixture (1:5) → `Some 0.2`.
  - Pure-dividend day (raw 100.00 → 100.50, adjusted 99.40 → 100.50,
    quarterly $0.50 dividend on $100) → `None`.
  - Quiet day (raw == adjusted modulo back-roll factor) → `None`.
  - Boundary: 3:2 split (factor 1.5) → `Some 1.5`.
- LOC estimate: ~150.

PR-1 ships standalone — useful as a primitive for any future split-aware
analysis (e.g. RS line sanity check, dividend-yield computation).

### PR-2 — split-event ledger + position adjustment

- `trading/trading/portfolio/lib/split_event.{ml,mli}` — new module
  alongside `Portfolio` (per CLAUDE.md "build alongside, don't modify").
  Types:
  ```ocaml
  type t = {
    symbol : string;
    date : Date.t;
    factor : float;  (* new_shares / old_shares *)
  }

  (** Apply a split event to a single position. Quantity multiplies,
      cost_basis_per_share divides, total cost basis preserved. *)
  val apply_to_position : t -> Position.t -> Position.t

  (** Apply to all positions in a portfolio that hold the symbol. No-op
      if symbol not held. Pure; returns a new portfolio. *)
  val apply_to_portfolio : t -> Portfolio.t -> Portfolio.t
  ```
- `trading/trading/portfolio/test/test_split_event.ml` — fixtures:
  - 4:1 forward split on a held position preserves total cost basis,
    quadruples quantity, quarters per-share cost.
  - 1:5 reverse split on held position: 500 → 100 shares, $10 → $50/share.
  - Split applied to portfolio not holding the symbol: no-op (cash and
    positions unchanged).
  - Fractional split (3:2): integer-quantity invariant; PR-2 picks the
    handling — either round to nearest share (with a tiny cash adjustment
    to preserve total value, mirroring brokerage practice) or keep
    fractional shares. Decision: **fractional shares** (matches existing
    `Position.quantity : float`). Pin via test.
- LOC estimate: ~250.

PR-2 establishes the ledger primitive but does not invoke it from the
simulator yet. Existing `test_weinstein_backtest`, `test_panel_loader_parity`,
all goldens stay bit-identical to main.

### PR-3 — wire detection + ledger into the simulator step

- `trading/trading/simulation/lib/simulator.ml` — at the start of each
  daily step, before `_get_today_bars` and before strategy invocation:
  1. For each symbol held in the portfolio, call
     `Split_detector.detect_split ~prev ~curr` using the symbol's bars
     for `t-1` (last seen) and `t` (current_date).
  2. For each detection, build a `Split_event.t` and apply to portfolio.
  3. Log the event (count + symbol + factor) to the simulator's step
     history for diagnostics.
- `_to_price_bar`, `_compute_portfolio_value`, `_make_get_price` —
  **unchanged**. They keep using raw OHLC. No `_split_adjust_bar`. The
  ledger fix is the only change.
- `trading/trading/simulation/test/test_split_day_mtm.ml` — port from
  PR #641 (content in the closed PR's commit `uwvsmxkp`):
  - `test_portfolio_value_continuous_through_split` — synthetic AAPL-like
    CSV with a 4:1 split between day 2 and day 3, holds 100 shares
    spanning the split. Pre-fix: ~75% one-day MtM drop (corrected from
    PR #641's "37.5%" — the original test used a 1.6:1, the canonical
    test should use 4:1 to match the AAPL case). Post-fix: zero phantom
    drop; portfolio value moves only by the day's true return.
  - `test_no_split_window_unchanged` — when no split occurs in the
    window, simulator output is bit-identical to the pre-broker-model
    main.
  - `test_split_day_with_no_position_held` — split day for a symbol
    not in the portfolio: no-op, portfolio unchanged. Distinguishes
    the broker model from the band-aid (which rescaled bars
    universe-wide).
- LOC estimate: ~200.

After PR-3, the regression test from the closed #641 is re-enabled and
passes; existing pinned goldens (`test_weinstein_backtest`,
`test_panel_loader_parity`) stay bit-identical because no rescaling
happens on non-split days.

### PR-4 — sp500 + perf-tier3 verification + status updates

Verification + cleanup, no new mechanism.

- Run `goldens-sp500/sp500-2019-2023` post-PR-3. Expected outcome: trade
  count ≈ pre-#641 baseline (per `dev/notes/sp500-golden-baseline-2026-04-26.md`
  this was 133, though the number is currently in dispute — see memory
  `project_sp500_baseline_conflict`). MaxDD ≈ 5% (the true value;
  no longer 97.7%).
- Update `dev/status/backtest-perf-catalog.md` row for sp500 with
  post-broker-model baseline.
- Re-pin the small goldens **only if they shift** — they should not
  shift on windows without splits. If they do, that's a bug in PR-3
  (broker-model is touching non-split days), not a re-pin.
- Promote the broker-model decision into `dev/decisions.md` (per
  `dev/plans/README.md` lifecycle: archive after the plan executes).
- LOC estimate: ~50 (mostly status / decision / golden file edits).

PR-4 is the integration / verification step. If the sp500 baseline
matches expectation, the redesign is complete.

## What stays / what changes

### Untouched

- `Daily_price.t` shape (`trading/analysis/data/types/lib/daily_price.{ml,mli}`)
  — keeps both `close_price` and `adjusted_close`. The redesign's
  decision is *which one each consumer reads*, not the storage shape.
- `Trading_engine` order fill path — fills at raw OHLC unchanged.
- All `analysis/weinstein/*` modules — already use `adjusted_close` via
  the panel's `closes` accessor where they want smoothness; that's
  correct and stays.
- `Ohlcv_panels` — keeps both raw and adjusted columns. No structural
  change.
- `Trading_portfolio.Portfolio` core type — the redesign builds
  `Split_event` *alongside* it. Per CLAUDE.md "build alongside, don't
  modify".
- `Position.t` — quantity stays `float`; the ledger writes a new
  position record, no schema change.

### Touched

- `trading/analysis/data/types/lib/split_detector.{ml,mli}` — new (PR-1).
- `trading/trading/portfolio/lib/split_event.{ml,mli}` — new (PR-2).
- `trading/trading/simulation/lib/simulator.ml` — adds split-event
  application at step start (PR-3). ~30 LOC delta.
- `trading/trading/simulation/test/test_split_day_mtm.ml` — new (PR-3).
- `dev/status/backtest-perf-catalog.md`, `dev/decisions.md`,
  affected golden `.sexp` files (only if they shift, which they
  shouldn't) — PR-4.

### Out of scope vs the closed #641 diff

The closed #641 touched `Simulator._to_price_bar`, `_make_get_price`, and
added `_split_adjust_bar`. None of those changes carry over. The new
design leaves both functions as they are on main and adds the split
event at a different seam (start-of-day ledger application).

## Risks & open questions

1. **Dividends in `adjusted_close` aren't fixed by the broker model.**
   The strategy uses adjusted-close for the RS line, MA, breakout
   detection — that's fine, smoothness across dividends is desirable
   there. But realized total return on a long-held dividend payer
   *should* include dividend cash; the simulator currently doesn't
   model dividend payments at all, so the position's MtM omits the
   dividend cash flow. This is a **separate ledger concern** (a
   `Dividend_event` track), not part of this redesign. Flag for
   `dev/plans/dividend-ledger-*.md` if it becomes material — for the
   sp500-2019-2023 backtest it's a few percent of total return at
   most.

2. **Detection false positives on illiquid symbols.** A small-cap with
   a thinly traded day might show a >5% one-day adjustment that isn't
   a split (e.g. a special dividend). The rational-snap filter
   (`split_factor ∈ {N/M : N,M ≤ 20}`) catches most of these, but
   a 1.07× ratio (close to 15:14) is plausible for a special
   dividend. Mitigation: PR-1 logs all detections at debug level;
   PR-3 emits the count to the step history. If the sp500 run
   detects more splits than the actual EODHD corporate-actions log
   for the period, the threshold needs tightening or we move to
   Option 3 (explicit feed).

3. **Reverse splits.** AMC, Citigroup-2011, etc. The broker model
   handles them symmetrically — `factor < 1.0`, `quantity` shrinks,
   per-share cost grows. PR-2's reverse-split fixture pins this. No
   special-case needed.

4. **Symbol delisted on the split day.** Edge case where the only
   bar after the split is at a different ticker (e.g. spinoffs).
   `detect_split` requires both `prev` and `curr`; if `curr` is
   missing, no event fires and the position is closed at the prior
   day's close per existing simulator semantics. Acceptable for v1;
   spinoff handling is out of scope.

5. **Live-mode integration.** The future live `DATA_SOURCE` adapter
   needs to surface splits. Two options: (a) re-run `Split_detector`
   on the live bar stream — works for daily cadence, may have a
   1-day lag for weekly cadence; (b) consume EODHD's
   corporate-actions feed directly. Option (b) is cleaner for live;
   v1 ships (a) and we revisit when live mode lands. The simulator
   path is unaffected by this choice.

6. **Bar-panel cache layout.** `Ohlcv_panels` caches the raw + adjusted
   columns; nothing in this redesign requires a cache flush. The
   `Split_detector` reads existing fields; no schema change. PR-1
   verifies by hitting `Daily_price.t` directly, not the panel.

7. **The 30-trade post-#641 sp500 number.** PR #641's rebase run showed
   30 trades. Per memory `project_sp500_baseline_conflict`, the
   pre-#641 baseline was variously 133 / 478 / 298 / 30 in different
   measurements; investigation (PR #647) reproduced 30 across 4 SHAs.
   PR-4's verification step lands after the broker model fix — if
   the count is 30 again, that's neither a regression nor an
   improvement: it's the existing canonical value once the MaxDD
   bug is removed. Tracking in `project_sp500_baseline_conflict`.

## Out of scope

- **Dividend ledger.** A separate-track `Dividend_event` to credit
  cash on ex-div days. Independent from splits; see Risk 1.
- **Spinoffs / special dividends / mergers.** Generally a
  position-replacement event; needs its own ledger primitive. Out
  of v1.
- **Live-mode corporate-action feed.** This redesign targets the
  simulator path. Live mode (a) inherits the broker-model ledger
  but (b) sources events from a different feed; that integration is
  a separate plan once live mode is closer.
- **Re-pin sweep on small goldens.** PR-3 expects no movement on
  non-split windows. If movement appears, that's a bug to fix in
  PR-3, not a re-pin. The redesign explicitly does not authorise
  golden re-pins.
- **Removal of `adjusted_close` from `Daily_price.t`.** It's still
  used by `analysis/weinstein/rs`, panel `closes`, etc. Keep both
  fields; the redesign just disciplines who reads which.
- **Performance work.** `Split_detector` runs once per held symbol
  per day (`O(positions)` per step, not `O(universe)`). Negligible.
  No perf-tier benchmarks needed.

## Phasing summary

| PR | What | LOC est. |
|---|---|---:|
| PR-1 | `Split_detector` primitive + tests against synthetic AAPL fixture | 150 |
| PR-2 | `Split_event` ledger + apply-to-portfolio + tests | 250 |
| PR-3 | Wire into simulator step; re-enable PR #641's regression test | 200 |
| PR-4 | sp500 verification, status updates, decisions archive | 50 |
| **Total** | | **~650** |

Each PR is independently mergeable; PR-3 onward depends on prior PRs. PR-3
is the riskiest (touches the simulator). Test pinning at each layer keeps
the blast radius small.

## Acceptance criteria

By the time PR-3 merges:

- `test_split_day_mtm.ml` passes (the original PR #641 regression).
- `test_weinstein_backtest`, `test_panel_loader_parity`, panel-golden,
  tiered-loader-parity tests stay **bit-identical** to pre-#641 main
  on windows without splits.
- sp500-2019-2023 MaxDD ≈ 5% (down from 97.7%); trade count tracks
  pre-#641 baseline (modulo `project_sp500_baseline_conflict`).
- `dune build && dune runtest && dune build @fmt` clean.
- The split-day MtM phantom drop (75% on AAPL Aug-2020 4:1) is gone:
  asserted by the regression test.

By the time PR-4 merges:

- `dev/decisions.md` records the broker-model decision.
- `dev/status/backtest-perf-catalog.md` reflects the new sp500
  baseline.
- The closed PR #641 is referenced in `dev/decisions.md` as the
  superseded approach.

## Relationship to the closed #641

PR #641 stays closed. The `test_split_day_mtm.ml` content is preserved
verbatim (modulo the 4:1 vs 1.6:1 fixture correction noted in PR-3).
The `_split_adjust_bar` function is **not** ported; the broker model
replaces it. No revival of #641's branch; PR-3 lands the regression
test fresh on the broker-model branch.
