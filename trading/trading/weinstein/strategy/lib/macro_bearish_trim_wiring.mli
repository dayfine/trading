(** Strategy-integration layer for {!Macro_bearish_trim_runner}.

    Builds the pure runner's inputs from the live strategy context — the macro
    trend / screening-day gate, the portfolio mark-to-market value, and the
    weakest-first RS ranking (reusing {!Laggard_rotation_runner.window_return}
    so the laggard and trim RS notions stay consistent). Extracted from
    {!Weinstein_strategy} so the top-level strategy module stays within its
    length budget. *)

open Core
open Trading_strategy

val run :
  config:Weinstein_strategy_config.config ->
  positions:Position.t Map.M(String).t ->
  portfolio:Portfolio_view.t ->
  get_price:Strategy_interface.get_price_fn ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  is_screening_day:bool ->
  macro_result_opt:Macro.result option ->
  skip_ids:String.Set.t ->
  Position.transition list
(** Run the macro-bearish held-exposure trim pass. No-op [[]] unless
    [config.enable_macro_bearish_exposure_trim] is set, [is_screening_day] is
    true, and [macro_result_opt] is [Some] with a [Bearish] trend. Otherwise
    caps held long exposure at [config.macro_bearish_max_long_exposure_pct] of
    portfolio value and exits weakest-RS longs first via
    {!Macro_bearish_trim_runner.update}. [skip_ids] is the union of all
    earlier-channel exit ids this tick (stop / Stage-3 / laggard / force-liq) so
    a position already exiting is never double-exited. *)
