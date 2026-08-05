# GTC breakout orders — book-faithful entry persistence (plan, 2026-08-05)

**Motivation:** the fill-model ladder
(`dev/notes/sim-entry-fill-ladder-2026-08-05.md`) showed (a) the record's
Market-at-open fill is unfaithful (64% of trades fill below the designed
trigger — pre-breakout base buys), (b) the live StopLimit(E, cap15) shape is
the best of its family but Day-scoped orders structurally miss slow breakouts
(BKE-2020: order expired, Nov breakout arrived unarmed, later chase lost).
**Book authority (verbatim, Ch.3 p.67-68 + Ch.4 checklist):**
"Buy 1,000 XYZ at 12⅛ stop – 12⅜ limit – GTC" — GTC persistence + tight
(~+2%) limit band, resting for weeks. See
`docs/design/weinstein-book-reference.md` §4.7 (added 2026-08-05).

## Mechanism (default-off, experiment-flag R1/R2/R3)

New config: `entry_order_persistence : Day | Gtc [@sexp.default Day]`
(+ existing `entry_extension_max_pct` reused as the band; the book's 2pp joins
the axis values). Armed = `enable_sim_entry_stoplimit && persistence=Gtc`.

Semantics when armed:
1. `CreateEntering` emits `StopLimit(E, E×(1+band/100))` with GTC TIF: the
   order + its `Entering` position persist across steps until filled or
   cancelled.
2. **Weekly refresh:** on each strategy call, if the symbol is re-signaled
   with a different E (level re-graded), amend (cancel + re-emit). If the
   symbol is NO LONGER a candidate (fell out of Stage 2, stop-basis
   invalidated, macro gate closed), cancel the resting order
   (`CancelEntry`). The early-Stage-2 window governs *signaling*; the resting
   order governs *execution* — a name that stops signaling gets its order
   pulled, i.e. invalidation = candidacy loss, not order age.
   OPEN QUESTION (surface axis or fixed rule): should the order survive
   candidacy loss for K weeks (book's "surprised 2-3 weeks later" implies
   yes-ish)? v1: order lives exactly as long as candidacy; K>0 as a later axis.
3. **Sizing:** computed at arm time from E (as today); portfolio must not
   double-commit cash across many resting orders — resting orders are
   *contingent* commitments. v1 keeps today's behavior (each Entering position
   reserves its slot; entry walk already caps concurrent positions); measure
   crowding in the surface (skipped-entry counters).
4. Live symmetry: `Weinstein_order_gen` emits `GTC` on the printed ticket;
   weekly report shows a "resting orders" section (carried tickets) instead
   of re-issuing from scratch.

## Implementation notes (pre-audit)

- **TIF plumbing:** orders carry `time_in_force = Day` today; find where Day
  expiry/cleanup actually happens in the sim loop (empirically entries do not
  persist — locate the mechanism: order manager expiry vs strategy-side
  re-emission gating vs Cancel_handler) BEFORE building. The build may need
  `Trading_orders` changes → **A1 watch-list (orders/ is core)**: propose as
  decision item per CLAUDE.md if the type must change; prefer sim-side
  persistence (re-submitting the resting order each step from the Entering
  position) if it avoids touching core order types.
- Engine already fills StopLimit correctly per intraday path — no engine work.
- Fill-date stamping, order-id determinism (G6), and fill_router exact-routing
  must hold across multi-day order lifetimes.

## Validation plan

1. Unit: persistence across steps; cancel-on-candidacy-loss; re-grade amend;
   determinism (bit-identical when flag off — R1).
2. Deep pair extension: 4th arm `gtc-band2` + 5th `gtc-band15` on the
   record-convention basis → completes the ladder
   (market 84.7× / stop-Day-uncapped 29.5× / stopLimit-Day-15 42.1× / GTC-?).
   Prediction from the BKE class: GTC recovers a meaningful slice of the
   class-4 tail without the base-buy unfaithfulness.
3. WF-CV surface: {Day, Gtc} × band {2, 15} on sp500 31-fold + broad 13-fold,
   Pareto + DSR, ledger verdict. Promotion (incl. any live default change)
   only via `promotion-confirmation.md` grid.
4. NOT invalidated by the early_stage2_max_weeks {6,8} REJECT: that widened
   MARKET-fill admission (stale entries bought immediately); GTC-stop admits
   nothing — it only fills actual breakouts.

## Out of scope here

- Record-basis decision (Market vs faithful fill model as the published
  convention) — user call after the GTC arms exist.
- Resistance anchoring (local range top vs 520w graded top) — resistance-v2.
- Class-4 split (pre-breakout base vs true pullback) — analysis follow-up.
