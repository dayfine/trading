open Core

let default_stage_and_ma_for_side = function
  | Trading_base.Types.Long ->
      ( Weinstein_types.Stage2 { weeks_advancing = 1; late = false },
        Weinstein_types.Rising )
  | Trading_base.Types.Short ->
      (Weinstein_types.Stage4 { weeks_declining = 1 }, Weinstein_types.Declining)

let trailing_ma_value ?ma_cache ~(stage_config : Stage.config) ~period ~symbol
    (weekly : Snapshot_runtime.Snapshot_bar_views.weekly_view) =
  if period <= 0 then
    invalid_arg
      (Printf.sprintf "Stop_ma_stage.trailing_ma_value: period must be > 0 (%d)"
         period);
  if weekly.n < period then None
  else
    let config = { stage_config with Stage.ma_period = period } in
    let callbacks =
      Panel_callbacks.stage_callbacks_of_weekly_view ?ma_cache ~symbol ~config
        ~weekly ()
    in
    callbacks.get_ma ~week_offset:0

(* The stop MA: the stage MA unless a trailing period is configured and the
   view is deep enough for it. *)
let _stop_ma ?ma_cache ?trailing_stop_ma_period ~stage_config ~symbol ~weekly
    ~stage_ma () =
  match trailing_stop_ma_period with
  | None -> stage_ma
  | Some period ->
      trailing_ma_value ?ma_cache ~stage_config ~period ~symbol weekly
      |> Option.value ~default:stage_ma

let compute ?ma_cache ?prior_stage_ma_values ?trailing_stop_ma_period
    ~(stage_config : Stage.config) ~lookback_bars ~bar_reader ~as_of
    ~prior_stages ~symbol ~side ~fallback_price ~to_stop_basis () =
  let weekly =
    Bar_reader.weekly_view_for bar_reader ~symbol ~n:lookback_bars ~as_of
  in
  if weekly.n < stage_config.ma_period then
    let stage, ma_direction = default_stage_and_ma_for_side side in
    (ma_direction, fallback_price, stage)
  else
    let prior_stage = Hashtbl.find prior_stages symbol in
    let callbacks =
      Panel_callbacks.stage_callbacks_of_weekly_view ?ma_cache ~symbol
        ~config:stage_config ~weekly ()
    in
    let result =
      Stage.classify_with_callbacks ~config:stage_config
        ~get_ma:callbacks.get_ma ~get_close:callbacks.get_close ~prior_stage
    in
    Hashtbl.set prior_stages ~key:symbol ~data:result.stage;
    Option.iter prior_stage_ma_values ~f:(fun tbl ->
        Hashtbl.set tbl ~key:symbol ~data:result.ma_value);
    let stop_ma =
      _stop_ma ?ma_cache ?trailing_stop_ma_period ~stage_config ~symbol ~weekly
        ~stage_ma:result.ma_value ()
    in
    (result.ma_direction, to_stop_basis stop_ma, result.stage)
