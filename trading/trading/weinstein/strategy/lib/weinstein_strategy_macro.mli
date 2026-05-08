open Core

(** Macro computation and screen-dispatch helpers, factored out of
    [Weinstein_strategy_screening] to keep that file within the 300-line soft
    limit. All three functions are wired directly by [Weinstein_strategy] and
    are not intended for external callers. *)

val run_macro_only :
  config:Weinstein_strategy_config.config ->
  ad_bars:Macro.ad_bar list ->
  prior_macro:Weinstein_types.market_trend ref ->
  prior_macro_result:Macro.result option ref ->
  bar_reader:Bar_reader.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  current_date:Date.t ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  Macro.result
(** Compute the macro result for [current_date] and update [prior_macro] /
    [prior_macro_result] refs in place. Runs unconditionally on every Friday so
    that halt-reset logic can consult the freshest macro trend even when the
    universe screen is gated off. *)

val run_screen_after_macro :
  config:Weinstein_strategy_config.config ->
  stop_states:Weinstein_stops.stop_state String.Map.t ref ->
  last_stop_out_dates:Date.t Hashtbl.M(String).t ->
  bar_reader:Bar_reader.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  sector_prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  ticker_sectors:(string, string) Hashtbl.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  portfolio:Trading_strategy.Portfolio_view.t ->
  current_date:Date.t ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  audit_recorder:Audit_recorder.t ->
  macro_result:Macro.result ->
  Trading_strategy.Position.transition list
(** Run the Friday universe screener given an already-computed [macro_result].
    Builds the sector map, delegates to
    {!Weinstein_strategy_screening.screen_universe}, and returns entry
    transitions. *)

val entry_transitions_if_active :
  halted:bool ->
  is_screening_day:bool ->
  macro_result_opt:Macro.result option ->
  config:Weinstein_strategy_config.config ->
  stop_states:Weinstein_stops.stop_state String.Map.t ref ->
  last_stop_out_dates:Date.t Hashtbl.M(String).t ->
  bar_reader:Bar_reader.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  sector_prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  ticker_sectors:(string, string) Hashtbl.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  portfolio:Trading_strategy.Portfolio_view.t ->
  current_date:Date.t ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  audit_recorder:Audit_recorder.t ->
  Trading_strategy.Position.transition list
(** Run the universe screen only when [halted = false],
    [is_screening_day = true], and [macro_result_opt = Some _]. Returns [[]]
    when any guard is false. Keeps [_on_market_close] at a shallow nesting
    level. *)
