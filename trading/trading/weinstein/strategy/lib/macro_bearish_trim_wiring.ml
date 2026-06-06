(** Strategy-integration layer for {!Macro_bearish_trim_runner}. See
    [macro_bearish_trim_wiring.mli]. *)

open Core
open Trading_strategy
open Weinstein_strategy_config

(** Relative-strength score for a held position over the laggard RS window
    (default 13 weeks): the position's window return minus the benchmark's.
    Lower = weaker (the trim exits weakest-first). Returns [None] when either
    the position or the benchmark has insufficient weekly history — the trim
    then leaves the position held rather than ranking it arbitrarily. Reuses the
    same window-return primitive the laggard runner uses, so the two RS notions
    stay consistent. *)
let _rs_score ~config ~bar_reader ~benchmark_window_return ~current_date
    (pos : Position.t) : float option =
  let n = config.laggard_rotation_config.Laggard_rotation.rs_window_weeks in
  let pos_bars =
    Bar_reader.weekly_bars_for bar_reader ~symbol:pos.symbol ~n:(n + 1)
      ~as_of:current_date
  in
  match
    (Laggard_rotation_runner.window_return ~n pos_bars, benchmark_window_return)
  with
  | Some pos_ret, Some bench_ret -> Some (pos_ret -. bench_ret)
  | _ -> None

(** Whether the trim should fire this tick: flag on, a screening (Friday) day,
    and a confirmed Bearish macro trend. *)
let _should_fire ~config ~is_screening_day ~macro_result_opt =
  let is_bearish =
    match macro_result_opt with
    | Some ({ trend = Weinstein_types.Bearish; _ } : Macro.result) -> true
    | _ -> false
  in
  config.enable_macro_bearish_exposure_trim && is_screening_day && is_bearish

(** Benchmark RS window return for the weakest-first ranking — the same
    rolling-window return the laggard runner uses on the primary index. *)
let _benchmark_return ~config ~bar_reader ~current_date =
  let n = config.laggard_rotation_config.Laggard_rotation.rs_window_weeks in
  Laggard_rotation_runner.window_return ~n
    (Bar_reader.weekly_bars_for bar_reader ~symbol:config.indices.primary
       ~n:(n + 1) ~as_of:current_date)

let run ~config ~positions ~(portfolio : Portfolio_view.t) ~get_price
    ~bar_reader ~current_date ~is_screening_day ~macro_result_opt ~skip_ids =
  if not (_should_fire ~config ~is_screening_day ~macro_result_opt) then []
  else
    let benchmark_window_return =
      _benchmark_return ~config ~bar_reader ~current_date
    in
    let portfolio_value =
      Portfolio_view.portfolio_value
        { cash = portfolio.cash; positions }
        ~get_price
    in
    Macro_bearish_trim_runner.update
      ~max_long_exposure_pct:config.macro_bearish_max_long_exposure_pct
      ~portfolio_value ~positions ~get_price
      ~rs_ranking:
        (_rs_score ~config ~bar_reader ~benchmark_window_return ~current_date)
      ~skip_position_ids:skip_ids ~current_date
