(** [Weinstein_strategy.config.neutral_blocks_longs] / [neutral_blocks_shorts]
    reach the screener cascade through [_run_screener]
    (weinstein_strategy_screening.ml).

    [test_screener.ml] pins both gates on a bare [Screener.config]; this file
    pins the strategy -> screener thread, driving a real Friday screen via
    {!Weinstein_strategy.Weinstein_strategy_macro.run_screen_after_macro} on a
    [Neutral] tape with one fresh candidate per side. Only the flag differs
    between the two arms of each assertion.

    EFFECTIVENESS-PIN: neutral_blocks_longs -- goes red if
    [Screener.neutral_blocks_longs = config.neutral_blocks_longs] is dropped
    from [_run_screener] (the armed flag never blocks the Neutral long).

    EFFECTIVENESS-PIN: neutral_blocks_shorts -- goes red if
    [Screener.neutral_blocks_shorts = config.neutral_blocks_shorts] is dropped
    from [_run_screener] (the flag never reaches the cascade, so the Neutral
    short is admitted whatever the strategy field says). *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position
module WSM = Weinstein_strategy.Weinstein_strategy_macro

let _index_symbol = "NBX"
let _long_symbol = "NBLONG"
let _short_symbol = "NBSHORT"
let _friday = Date.of_string "2024-04-26"
let _base_price = 150.0
let _base_noise_pct = 0.02
let _base_volume = 1_000_000
let _breakout_volume_mult = 3
let _move_start_factor = 1.05
let _daily_move = 1.004
let _drop_start_factor = 0.90
let _daily_drop = 0.99
let _move_weeks = 6
let _history_weeks = 80
let _bars_per_week = 5
let _flat_index_price = 4500.0
let _noise_period = 10

let _bar ~date ~price ~volume : Types.Daily_price.t =
  {
    date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume;
    active_through = None;
  }

let _weekdays_ending_at last n =
  let prev d =
    match Date.day_of_week d with
    | Day_of_week.Sun -> Date.add_days d (-2)
    | Day_of_week.Mon -> Date.add_days d (-3)
    | _ -> Date.add_days d (-1)
  in
  let rec back d k acc =
    if k = 0 then acc else back (prev d) (k - 1) (d :: acc)
  in
  back last n []

let _dates = _weekdays_ending_at _friday (_history_weeks * _bars_per_week)

(* A noisy flat base, then six weeks of a 2%-per-week move whose first week
   carries triple volume: up (factor 1.05, gain) is a Stage-2 breakout, down
   (factor 1/1.05, loss) the Stage-4 breakdown mirror. *)
let _bars ~start_factor ~daily =
  let start = (_history_weeks - _move_weeks) * _bars_per_week in
  List.mapi _dates ~f:(fun i date ->
      if i < start then
        let phase =
          Float.of_int (i % _noise_period) /. Float.of_int _noise_period
        in
        let price =
          _base_price
          +. _base_price *. _base_noise_pct
             *. Float.sin (phase *. 2.0 *. Float.pi)
        in
        _bar ~date ~price ~volume:_base_volume
      else
        let k = i - start in
        let price = _base_price *. start_factor *. (daily ** Float.of_int k) in
        let volume =
          if k < _bars_per_week then _base_volume * _breakout_volume_mult
          else _base_volume
        in
        _bar ~date ~price ~volume)

let _long_bars = _bars ~start_factor:_move_start_factor ~daily:_daily_move
let _short_bars = _bars ~start_factor:_drop_start_factor ~daily:_daily_drop

let _flat_index_bars =
  List.map _dates ~f:(fun date ->
      _bar ~date ~price:_flat_index_price ~volume:_base_volume)

let _bar_reader =
  Bar_reader.of_in_memory_bars
    [
      (_index_symbol, _flat_index_bars);
      (_long_symbol, _long_bars);
      (_short_symbol, _short_bars);
    ]

let _index_view =
  Bar_reader.weekly_view_for _bar_reader ~symbol:_index_symbol ~n:70
    ~as_of:_friday

let _neutral_macro : Macro.result =
  {
    index_stage =
      {
        stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
        ma_value = 100.0;
        ma_direction = Weinstein_types.Rising;
        ma_slope_pct = 0.01;
        transition = None;
        above_ma_count = 8;
      };
    indicators = [];
    trend = Weinstein_types.Neutral;
    breadth_state =
      Weinstein_types.breadth_state_of_market_trend Weinstein_types.Neutral;
    confidence = 0.5;
    regime_changed = false;
    rationale = [];
  }

let _get_price symbol =
  let bars =
    if String.equal symbol _long_symbol then _long_bars
    else if String.equal symbol _short_symbol then _short_bars
    else []
  in
  List.last bars

(** Symbols and sides the Friday screen opened entry tickets on, [Neutral] tape,
    empty portfolio. *)
let _entries ~neutral_blocks_longs ~neutral_blocks_shorts =
  let config =
    {
      (Weinstein_strategy_config.default_config
         ~universe:[ _long_symbol; _short_symbol ]
         ~index_symbol:_index_symbol)
      with
      neutral_blocks_longs;
      neutral_blocks_shorts;
    }
  in
  WSM.run_screen_after_macro ~pending_entry_e:(Entry_freeze.create ())
    ~suspended_tickets:(Entry_ticket_suspend.create ())
    ~fold_start_date:None ~universe_membership_at:None ~config
    ~stop_states:(ref String.Map.empty)
    ~last_stop_out_dates:(Hashtbl.create (module String))
    ~bar_reader:_bar_reader
    ~prior_stages:(Hashtbl.create (module String))
    ~sector_prior_stages:(Hashtbl.create (module String))
    ~ticker_sectors:(Hashtbl.create (module String))
    ~get_price:_get_price
    ~portfolio:{ cash = 100_000.0; positions = String.Map.empty }
    ~current_date:_friday ~index_view:_index_view
    ~audit_recorder:Audit_recorder.noop ~macro_result:_neutral_macro
  |> List.filter_map ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.CreateEntering { symbol; side; _ } -> Some (symbol, side)
      | _ -> None)

let test_neutral_blocks_longs_reaches_the_cascade _ =
  assert_that
    (List.map [ false; true ] ~f:(fun on ->
         _entries ~neutral_blocks_longs:on ~neutral_blocks_shorts:true
         |> List.filter_map ~f:(fun (s, side) ->
             if Poly.equal side Trading_base.Types.Long then Some s else None)))
    (elements_are [ elements_are [ equal_to _long_symbol ]; is_empty ])

let test_neutral_blocks_shorts_reaches_the_cascade _ =
  assert_that
    (List.map [ false; true ] ~f:(fun on ->
         _entries ~neutral_blocks_longs:true ~neutral_blocks_shorts:on
         |> List.filter_map ~f:(fun (s, side) ->
             if Poly.equal side Trading_base.Types.Short then Some s else None)))
    (elements_are [ elements_are [ equal_to _short_symbol ]; is_empty ])

let suite =
  "neutral_blocks_screener_thread"
  >::: [
         "neutral_blocks_longs reaches the cascade"
         >:: test_neutral_blocks_longs_reaches_the_cascade;
         "neutral_blocks_shorts reaches the cascade"
         >:: test_neutral_blocks_shorts_reaches_the_cascade;
       ]

let () = run_test_tt_main suite
