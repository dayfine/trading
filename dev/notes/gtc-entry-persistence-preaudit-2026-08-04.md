# GTC breakout-orders — pre-audit finding (2026-08-04)

Pre-audit for `dev/plans/gtc-breakout-orders-2026-08-05.md` (plan lives on
branch `feat/stoplimit-deep-pair`, PR #2206). **The plan's central premise is
empirically false**, so this note records the true simulator behaviour before
any mechanism is built. Companion regression tests:
`trading/trading/simulation/test/test_gtc_entry_persistence.ml`.

## Premise under test

The plan (and `dev/notes/sim-entry-fill-ladder-2026-08-05.md`) states: *"an
unfilled StopLimit entry does NOT persist to later days"* — e.g. the BKE
E=28.66 Day order "expired" and never filled the Nov-2020 breakout. The task
was to add a `Gtc` persistence mode so the resting order survives across steps.

## Finding: order-generator StopLimit entries ALREADY persist and fill the later cross

Traced the full path and proved it with two synthetic-bar simulations
(`test_gtc_entry_persistence.ml`). A StopLimit entry emitted on day 1 at
E=160, with the bar staying below 160 for three days then trading through it on
day 4, **fills on day 4** at 160.09–160.55 (between the trigger and the
`E*1.15` do-not-chase cap). This holds both when the strategy emits the entry
once and when it re-runs every cadence but suppresses re-emission while a
position exists (the real `Entry_walk.held_symbols` behaviour).

### Why it persists (mechanism)

1. **`time_in_force = Day` is inert metadata.** `Order_generator._create_order`
   stamps every order `Day` (`order_generator.ml`), but nothing consumes it:
   `Trading_orders.Manager` never expires by TIF, and
   `Trading_engine.Engine.process_orders` explicitly *"If not executable,
   leave as Pending"*. An unfilled order stays `Pending` in
   `Manager.active_orders` indefinitely.
2. **The engine re-evaluates every `Pending` order against each new bar.**
   `process_orders` walks `ActiveOnly` each step and `_execute_stop_limit_order`
   fills whenever the current bar's path trades through the trigger within the
   cap — so a Pending order fills on the *first later bar* that crosses E.
3. **Fill routing survives the `order_links` reset.** `Simulator` clears
   `order_links` every step (`simulator.ml` ~line 430), but `Fill_router` has a
   `(symbol, state, side)` **heuristic fallback**: because the position stays
   `Entering` until the fill, a later Buy fill still routes to it.
4. **The Weinstein strategy never abandons an `Entering` position.** It emits no
   `CancelEntry` transition anywhere; `Cancel_handler` only cancels on a
   portfolio-*rejected* fill (cash floor, #1553). So a resting entry is pulled
   only by a cash rejection, never by candidacy loss or order age.

Net: today's behaviour is effectively an **unmanaged GTC** — the order rests
forever and fills any future cross, even long after the name stops being a
valid Stage-2 candidate.

## What this means for the plan

- **Persistence (plan §2 item 1) is a no-op** — it already exists. A
  `entry_order_persistence : Day | Gtc` flag whose `Gtc` branch "makes the
  order persist" would not change any backtest result; and there is no genuine
  `Day` (expire-same-day) behaviour today to default to, so the R1
  bit-identity gate is vacuous.
- **The real gaps are the *management* semantics** the plan lists under §2:
  - **Cancel-on-candidacy-loss** — pull the resting order when the symbol
    stops signaling (falls out of Stage 2 / macro gate closes). *Not
    implemented today; orders rest forever.* This is the genuinely-new,
    Weinstein-faithful mechanism (the book's GTC order is watched and pulled,
    not left to fill a stale setup).
  - **Re-grade amend** — cancel + re-emit at a new E when resistance is
    re-graded. *Not possible today* because `held_symbols` suppresses
    re-emission entirely while `Entering`.
  Both live in the **strategy layer** (`analysis/weinstein` /
  `trading/trading/weinstein`, `feat-weinstein` territory), not the simulator —
  they require the strategy to emit `CancelEntry` on candidacy loss, which it
  never does today.

## Recommended reframe (needs owner decision)

The deep-pair "Day order expired" observation should be re-examined against
this finding before building — trace BKE's actual `Entering`-position lifecycle
in the arm run (the resting order should have filled the Nov-2020 cross; if the
arm shows a later entry at 46.89 instead, something removed the position, which
this trace says can only be a cash rejection — a different phenomenon than
"expiry"). Then choose one of:

- **A. Managed-GTC lifecycle (recommended).** Keep persistence as-is; add a
  default-off `enable_entry_cancel_on_candidacy_loss` mechanism in the strategy
  that emits `CancelEntry` for a resting entry whose symbol is no longer a
  candidate (+ re-grade amend). This is the faithful, behaviour-changing lever
  and belongs to `feat-weinstein`; default-off preserves today's persist-forever
  behaviour (R1-safe).
- **B. True Day-expiry as an explicit axis.** Implement same-day cancellation of
  unfilled entry orders and make `Day | Gtc` a real choice. This *changes* the
  current (GTC-equivalent) default → re-pins goldens; only worth it if the ladder
  actually wants a faster expiry regime.

## This PR

Scoped to the safe, durable half: **pin the discovered behaviour** with
`test_gtc_entry_persistence.ml` (previously unpinned and mis-described) and
record this finding. No mechanism, no config field, no behaviour change.
