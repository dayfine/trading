(** Support-floor callback bundles over the snapshot daily view.

    Extracted from {!Panel_callbacks} (which re-exports both functions
    unchanged) to keep that coordinator under the file-length cap. Unlike the
    Sector / Macro / Stock_analysis constructors — which re-call the Stage
    constructor and so must stay co-located — the support-floor constructor has
    no such back-edge, which is what makes this one safe to lift out. *)

val of_daily_view :
  Snapshot_runtime.Snapshot_bar_views.daily_view -> Weinstein_stops.callbacks
(** [of_daily_view view] builds a {!Weinstein_stops.callbacks} (=
    {!Weinstein_stops.Support_floor.callbacks}) bundle keyed by day offset.

    {!Weinstein_stops.Support_floor} uses day_offset [0] = newest bar in the
    eligible window; the daily view is laid out the other way (index [0] =
    oldest, [n_days - 1] = newest), so each accessor flips the index. The view
    is already pre-windowed by the caller's chosen [lookback].

    [get_close] reads [raw_closes] — the same (raw) price basis as [highs] /
    [lows], so a [Close]-anchored scan stays on one scale. [get_adjusted_close]
    reads [adjusted_closes]; the pair is what
    {!Weinstein_stops.compute_initial_stop_with_floor_with_callbacks} divides to
    recover each bar's split-adjustment factor under [split_safe_floors].

    Returns [None]-yielding callbacks (with [n_days = 0]) for empty views. *)

val of_snapshot_views :
  cb:Snapshot_runtime.Snapshot_callbacks.t ->
  symbol:string ->
  as_of:Core.Date.t ->
  lookback:int ->
  calendar:Core.Date.t array ->
  Weinstein_stops.callbacks
(** [of_snapshot_views ~cb ~symbol ~as_of ~lookback ~calendar] fetches the daily
    view for [symbol] over the most recent [lookback] daily bars ending on or
    before [as_of] via {!Snapshot_runtime.Snapshot_bar_views.daily_view_for},
    then delegates to {!of_daily_view}.

    The [~calendar] parameter is the trading-day calendar the runner uses;
    passing it pins the resulting window deterministically (#848 forward fix).
*)
