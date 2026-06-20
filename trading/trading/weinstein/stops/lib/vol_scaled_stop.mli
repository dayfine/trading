(** Volatility-scaled minimum installed-stop distance (default-off).

    Pure primitive that widens the {e minimum} distance the installed initial
    stop must sit from entry, in proportion to the candidate's ATR (volatility).
    Feeds the [?min_stop_distance_pct] argument of
    {!Entry_audit_capture.make_entry_transition} via
    {!Weinstein_stops.Stop_widen.widen_initial_to_min_distance}.

    The mechanism only ever {b widens} the floor (it takes the [Float.max] of
    the fixed [base_min_distance_pct] and the ATR-derived distance), so a quiet
    name keeps the existing 8% floor while a volatile name gets a structurally
    wider stop. See {!Stop_types.config.vol_scaled_stop_atr_mult} for the full
    rationale (whipsaw reduction at its source) and faithful-core framing
    (initial-stop-placement dial; spine untouched). *)

open Types

val effective_min_stop_distance_pct :
  config:Stop_types.config ->
  base_min_distance_pct:float ->
  entry_price:float ->
  bars:Daily_price.t list ->
  float
(** [effective_min_stop_distance_pct ~config ~base_min_distance_pct ~entry_price
     ~bars] is the minimum-distance floor to install on the initial stop.

    - When [config.vol_scaled_stop_atr_mult <= 0.0] (the default), returns
      [base_min_distance_pct] {b unchanged} — an exact no-op, so every existing
      golden replays bit-identically.
    - Otherwise computes [atr_pct = ATR / entry_price] from
      [Atr.atr ~period:config.vol_scaled_stop_atr_period bars] and returns
      [Float.max base_min_distance_pct (config.vol_scaled_stop_atr_mult *.
       atr_pct)]. The [Float.max] guarantees the result is never narrower than
      the fixed floor.

    Degenerate inputs fall back to [base_min_distance_pct] (never narrower):
    [Atr.atr] returning [None] (fewer than [period + 1] bars), a non-positive
    [entry_price], or a non-positive computed ATR. The [max_stop_distance_pct]
    reject cap is applied by the caller {e after} this floor, so a vol-widened
    stop that exceeds the cap still rejects the candidate. *)
