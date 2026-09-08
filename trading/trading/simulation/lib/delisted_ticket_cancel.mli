(** Cancels a resting entry ticket once its symbol's delisting marker has passed
    (#2696).

    The fill-time third of the delisting trio. {!Delisted_exit_runner} (#2692)
    acts on a {b held} position; [Delisted_entry_gate] (#2695) acts at
    {b admission}, where candidates are assembled. Neither reaches an
    {e unfilled resting order}: the exit runner selects on a non-zero broker
    quantity, and the admission gate has already run by the time the ticket
    exists.

    {2 The gap this closes}

    A ticket admitted on the marker day itself is kept deliberately — both
    sibling gates use [Date.(as_of <= active_through)], so the marker day is a
    trading day on all three sides. That ticket is a resting order, and every
    mechanism that would otherwise retire it declines to:

    - [Market_state.update] overwrites the per-symbol bar table for the symbols
      it is handed and clears only the intraday-path memo, so a dark symbol
      keeps serving its final bar indefinitely;
    - [Engine.process_orders] iterates every {e active order}, not today's bars,
      so it fills against that retained bar — including on a bar-less calendar
      day, which is why this module is {b not} gated on [today_bars] the way
      both exit runners are;
    - resting tickets are not re-screened at the default config
      ([enable_entry_ticket_rescreen = false],
      [entry_order_max_rest_weeks = 52]), so no weekly pass revisits the
      decision;
    - the StopLimit entry model is exempt from the next-open fill gate.

    The residual is therefore a fill one to a few days past the marker — under
    the post-run validator's V17 threshold of 7 days
    ({!Backtest_validation.Validator_fallback_check.check_v17}), which is why a
    clean V17 after #2695 was evidence by margin rather than by construction.
    This module makes it construction: past the marker the ticket is cancelled
    and its order retired, so no fill on a dead series is reachable at any
    staleness.

    {2 Data-driven, not a strategy mechanism — no config flag}

    There is deliberately no knob, for the same reason the two siblings have
    none: whether a ticket dies is a function of the {b data} (does the
    warehouse carry a marker for this symbol?), not of a tuning choice — see
    [dev/plans/delisting-data-fix-2026-09-06.md] §"Principle: fallbacks are
    quality flags, not mechanisms". Every warehouse built before #2691 leaves
    [active_through] [None] on every symbol, so every lookup returns [None],
    every such run is a no-op and every golden is bit-identical; that is
    [experiment-flag-discipline.md] R1's default-off obligation met structurally
    rather than by a flag. On a marker-carrying warehouse it fires without a
    spec change.

    {2 Why the cancel does not simply re-arm next screen}

    A cancelled ticket returns its symbol to the candidate pool, but
    [Delisted_entry_gate] drops that symbol at admission on every later
    screening date (its marker is by then strictly in the past), so the ticket
    cannot be rewritten. The three guards compose: admission blocks new tickets,
    this module retires the one that slipped through on the marker day, and the
    exit runner closes anything that filled before either.

    Strategy-agnostic: it reads the generic [Position.t] state machine and the
    order manager, and knows nothing about Weinstein. Run from
    {!Forced_exit_step}, which owns the phase. *)

open Core
module Position = Trading_strategy.Position

val cancel_reason : string
(** The reason token stamped on every [CancelEntry] this module builds:
    ["delisted"]. It is {!Delisted_exit_runner.label} — {b defined once there},
    not repeated here — so one token covers both halves of a delisting in the
    audit and the two halves cannot drift apart. Exposed, like
    {!Cancel_handler.portfolio_rejection_reason}, so a [trade_audit.sexp] reader
    can group ticket deaths by cause without matching prose.

    {b It is the fourth token in the cancel-reason closed list, and a third
       category.} The other three are {!Weinstein_strategy.Entry_ticket_ttl}'s
    [entry_ticket_ttl_expired] / [entry_ticket_requalification_failed] —
    strategy {e decisions} — and {!Cancel_handler.portfolio_rejection_reason}
    ([entry_fill_rejected_by_portfolio]) — an {e accident of capital timing}.
    This one is neither: it is a {e data-driven death}, the symbol's series
    having ended, which no policy choice and no cash collision could have
    avoided. Any consumer that splits on [cancel_reason] — the split the
    {!Backtest.Ticket_lifecycle.cancel_reason} docstring calls "load-bearing,
    not cosmetic" — must give it its own bucket rather than folding it into
    either of the other two. Pinned by
    [trading/trading/backtest/test/test_cancel_reason_closed_list.ml]. *)

val tick :
  order_manager:Trading_orders.Manager.order_manager ->
  active_through_for:(string -> Date.t option) ->
  date:Date.t ->
  positions:Position.t String.Map.t ->
  unit ->
  Position.t String.Map.t * Position.transition list
(** [tick ~order_manager ~active_through_for ~date ~positions ()] cancels every
    resting entry ticket whose symbol's delisting marker has passed, returning
    the post-cancel [(positions, transitions)].

    A ticket is selected when all of:

    - its position is [Entering] with [filled_quantity = 0.0] — a
      {b wholly-unfilled} ticket. A partially-filled entry is left alone: its
      shares are already booked with the portfolio, and the core [CancelEntry]
      validator rejects such a transition anyway
      ([Position._validate_no_fills]). The resulting position is left for
      {!Delisted_exit_runner} once it completes;
    - [active_through_for symbol = Some d] — the symbol carries a marker;
    - [Core.Date.(d < date)] — the marker is strictly in the past. The same
      strict boundary the exit runner and the admission gate use, so the marker
      day itself stays tradeable on all three sides and a ticket admitted that
      day dies on the next step.

    For each selected ticket it emits a [CancelEntry] tagged {!cancel_reason},
    retires the matching resting order through
    {!Cancel_handler.cancel_resting_entry_orders} (matched on symbol + entry
    order side, [filled_quantity = 0.0]) so the "cancelled" ticket cannot fill
    anyway — a cancelled ticket that still fills being worse than no cancel —
    and applies the transition, dropping the now-[Closed] position from the map.

    Not gated on [today_bars]: unlike both exit runners, which must not trip on
    a weekend, a resting order {e can} fill on a bar-less day against the
    symbol's retained last bar, so waiting for bars would leave the hole open.
    Returns [(positions, [])] — touching neither the order manager nor the map —
    when nothing is selected, which is every run on every warehouse that carries
    no markers.

    The returned transitions are the caller's to announce; {!Forced_exit_step}
    folds them into the batch it hands [on_transitions], which is how the cancel
    reaches [trade_audit.sexp]. *)
