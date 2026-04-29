(** Per-tick split-event detector and stop-state rescaler.

    The Weinstein strategy stores stop levels as {b absolute} dollar prices in
    [stop_states : Weinstein_stops.stop_state Map.M(String).t ref]. When the
    issuer splits a held symbol the broker-side share count rescales (handled in
    [Simulator._apply_splits_to_positions]) but the strategy's [stop_state] does
    not — so the next call to {!Weinstein_stops.check_stop_hit} compares
    pre-split stop prices against post-split bar prices and fires spuriously on
    the very first post-split bar.

    This module closes that gap. For every held position, it reads the most
    recent two daily bars from the [Bar_reader] and runs
    {!Types.Split_detector.detect_split}. If a split is detected, the matching
    entry in [stop_states] is rescaled in place via
    {!Weinstein_stops.Stop_split_adjust.scale}. Symbols with fewer than two bars
    or no qualifying ratio are left untouched.

    The strategy invokes [adjust] once per [on_market_close] tick, BEFORE
    [Stops_runner.update] consumes [stop_states]. *)

open Core
open Trading_strategy

val adjust :
  positions:Position.t Map.M(String).t ->
  stop_states:Weinstein_stops.stop_state Map.M(String).t ref ->
  bar_reader:Bar_reader.t ->
  as_of:Date.t ->
  unit
(** [adjust ~positions ~stop_states ~bar_reader ~as_of] mutates [stop_states] so
    any stop level on a symbol that just split (between the prior trading day's
    bar and [as_of]'s bar) is rescaled by the inverse split factor.

    For each held position whose symbol has an entry in [stop_states]:

    1. Read the daily bars up to and including [as_of] via
    {!Bar_reader.daily_bars_for}. 2. If at least two bars are present, run
    {!Types.Split_detector.detect_split} on the prior bar and the most recent
    bar. 3. On [Some factor], rescale the stop_state via
    {!Weinstein_stops.Stop_split_adjust.scale}.

    Positions without a [stop_states] entry, symbols with <2 bars, and symbols
    with no detected split are no-ops. The function never emits transitions and
    never raises (input validation lives downstream in
    [Stop_split_adjust.scale], which only rejects non-positive factors — a
    contract guaranteed by [Split_detector.detect_split]).

    Pure with respect to [bar_reader] and [positions]; the only side-effect is
    the in-place update of [stop_states]. *)
