(** Per-tick split-event detector and stop-state rescaler.

    The Weinstein strategy stores stop levels as {b absolute} dollar prices in
    [stop_states : Weinstein_stops.stop_state Map.M(String).t ref]. When the
    issuer splits a held symbol the broker-side share count rescales (handled in
    [Split_handler.apply_events]) but the strategy's [stop_state] does not — so
    the next call to {!Weinstein_stops.check_stop_hit} compares pre-split stop
    prices against post-split bar prices and fires spuriously on the very first
    post-split bar.

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

val detect_split :
  ?raw_confirm_min_share:float ->
  bar_reader:Bar_reader.t ->
  symbol:string ->
  as_of:Date.t ->
  unit ->
  float option
(** [detect_split ~bar_reader ~symbol ~as_of ()] runs
    {!Types.Split_detector.detect_split} on [symbol]'s last two daily bars up to
    and including [as_of]. [Some factor] when a split happened between the prior
    trading day and [as_of]; [None] with fewer than two bars or no qualifying
    ratio. The one detector {!adjust} uses, shared with {!Split_ticket_cancel}
    so the stop rescale and the resting-ticket cancel fire on the same days.

    When [bar_reader] carries a {!Bar_reader.split_guard} (issue #3173), a
    detected split the guard identifies as a vendor cash dividend returns
    [None], the same verdict the simulator's held-position split step reaches.

    [raw_confirm_min_share] (issue #3109, default absent = the pre-#3109
    behaviour) is passed to {!Types.Split_detector.detect_split}: a factor the
    raw close gap does not confirm, or a small factor on a frozen-adjusted day,
    is not a split. A caller that sets it here should set it on
    [Split_handler.detect_and_apply] too, so the stop and the share count
    rescale on the same days. *)

val adjust :
  ?on_split:(position_id:string -> factor:float -> unit) ->
  ?raw_confirm_min_share:float ->
  positions:Position.t Map.M(String).t ->
  stop_states:Weinstein_stops.stop_state Map.M(String).t ref ->
  bar_reader:Bar_reader.t ->
  as_of:Date.t ->
  unit ->
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

    [on_split], when given, is called once per held position whose stop state
    was rescaled, with the position id and the factor used (issue #3127). It is
    an observability hook: [Stop_log] uses it to rescale its stop columns by the
    same factor, so they stay on the price basis of the exit. Defaults to a
    no-op; the rescale itself is identical with or without it.

    Pure with respect to [bar_reader] and [positions]; the only side-effect is
    the in-place update of [stop_states] and the [on_split] calls.

    [raw_confirm_min_share] is passed to {!detect_split} for every held
    position; absent (the default) leaves the detection unchanged. *)
