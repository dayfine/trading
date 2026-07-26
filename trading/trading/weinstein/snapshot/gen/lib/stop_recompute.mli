(** Recompute a weekly-pick candidate's or held position's stop from real bar
    history, via the same primitive the live strategy uses at actual fill / hold
    time. Consolidates two call sites that both wrap
    {!Weinstein_stops.compute_initial_stop_with_floor} — one for not-yet-filled
    candidates, one for already-held positions — so the "recompute from bars"
    logic lives in a single place.

    {1 Background (issue #2084 Finding 2)}

    {!Screener.scored_candidate.suggested_stop} (surfaced on
    {!Weinstein_snapshot.Weekly_snapshot.candidate.stop}) is computed by the
    pure screener library as a flat percentage below entry
    ([entry * (1 - initial_stop_pct)]) — the screener has no daily bar access,
    so it cannot derive a real support floor. The live strategy's actual entry
    path ([Entry_walk] / [Entry_audit_helpers]) never uses this proxy: it
    installs the stop via {!Weinstein_stops.compute_initial_stop_with_floor},
    which derives a real support floor (prior correction low for longs / rally
    high for shorts) from the symbol's daily bar history, falling back to a
    fixed buffer only when no qualifying counter-move exists in the lookback
    window (weinstein-book-reference.md §5.1 "Initial Stop Placement": "Place
    below the significant support floor (prior correction low) BEFORE the
    breakout").

    Before {!for_candidate} existed, the weekly-pick report's displayed stop and
    its sized "on fill place SELL STOP" instruction both used the naive proxy —
    a live/sim divergence, since the backtest's real entry for the same symbol
    uses the structural stop. {!for_held_long} predates this fix and already
    applied the same primitive to held positions' displayed "recommended stop"
    column.

    Neither function touches {!Screener.scored_candidate.suggested_stop} or any
    of the screener's pure cascade computation. The optimal-strategy
    counterfactual tool ({!Stage_transition_scanner}), which reads
    [Screener.scored_candidate.suggested_stop] directly, is unaffected. *)

val for_candidate :
  stops_config:Weinstein_stops.config ->
  initial_stop_buffer:float ->
  bar_reader:Weinstein_strategy.Bar_reader.t ->
  as_of:Core.Date.t ->
  side:Trading_base.Types.position_side ->
  Weinstein_snapshot.Weekly_snapshot.candidate ->
  Weinstein_snapshot.Weekly_snapshot.candidate
(** [for_candidate ~stops_config ~initial_stop_buffer ~bar_reader ~as_of ~side
     c] returns [c] with [stop] and [stop_is_structural] recomputed from [c]'s
    resident daily bars
    ([Bar_reader.daily_bars_for bar_reader ~symbol:c.symbol ~as_of]).

    - No resident daily bars for [c.symbol]: [c] is returned unchanged — [stop]
      stays whatever the caller passed in (typically the screener's fallback
      proxy) and [stop_is_structural] is untouched (graceful degradation, same
      shape as {!for_held_long}'s "no bars" case).
    - Bars present: [stop] becomes
      [Weinstein_stops.get_stop_level
       (Weinstein_stops.compute_initial_stop_with_floor ~config:stops_config
       ~side ~entry_price:c.entry ~bars:daily ~as_of
       ~fallback_buffer:initial_stop_buffer)]. [stop_is_structural] is [true]
      iff {!Weinstein_stops.Support_floor.find_recent_level} (same
      [min_correction_pct] / [support_floor_lookback_bars] the compute call
      reads internally) finds a qualifying counter-move; [false] otherwise (the
      fallback-buffer branch fired).

    [c.entry] is read as the prospective fill price (the candidate's suggested
    breakout entry) — the same role [entry_price] plays for a real fill. Pure
    function: no I/O beyond the read-only [bar_reader] lookup. *)

val for_held_long :
  stops_config:Weinstein_stops.config ->
  initial_stop_buffer:float ->
  entry_price:float ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  float option
(** [for_held_long ~stops_config ~initial_stop_buffer ~entry_price ~bars ~as_of]
    returns this week's recomputed Weinstein support-floor stop for a held long,
    shown beside the trader's current stop so the reader sees the delta. [None]
    when [bars] is empty (no bars to derive a floor from) — reuses the existing
    stop primitive; no new stop logic. The full trailing state machine is not
    threaded here (deferred to a later phase). Always [Long] side — held
    positions are long-only in the current live strategy. *)
