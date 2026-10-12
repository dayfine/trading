(** Holiday-Friday weekly review (#3139): with
    [config.screen_holiday_friday_weeks] on, a week whose Friday is an exchange
    holiday is screened on its last trading day (the Thursday); with it off the
    week is skipped, exactly as before.

    Pinned end to end through the real [on_market_close]: a resting entry ticket
    on a declining symbol is cancelled by the weekly re-screen, which only runs
    on a screening tick. So "the ticket was cancelled" is observable evidence
    that the tick screened, and "it was not" that the week was skipped. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position
module FL = Portfolio_risk.Force_liquidation

let _index_symbol = "GSPCX"
let _thursday_before = Date.of_string "2025-04-17"
let _ordinary_thursday = Date.of_string "2025-04-10"
let _ordinary_friday = Date.of_string "2025-04-11"

let test_config_flag_defaults_off _ =
  assert_that
    (Weinstein_strategy.default_config ~universe:[ "ZZZ" ]
       ~index_symbol:_index_symbol)
      .screen_holiday_friday_weeks
    (equal_to false)

(* ------------------------------------------------------------------ *)
(* End to end                                                          *)
(* ------------------------------------------------------------------ *)

let _ok_or_fail what r =
  Result.map_error r ~f:Status.show
  |> Result.map_error ~f:(fun e -> what ^ " failed: " ^ e)
  |> Result.ok_or_failwith

let _resting_ticket ~created =
  let trans kind : Position.transition =
    { position_id = "ZZZ-1"; date = created; kind }
  in
  Position.create_entering
    (trans
       (Position.CreateEntering
          {
            symbol = "ZZZ";
            side = Trading_base.Types.Long;
            target_quantity = 10.0;
            entry_price = 100.0;
            reasoning = ManualDecision { description = "3139 test" };
          }))
  |> _ok_or_fail "position setup"
  |> fun (p : Position.t) -> String.Map.singleton p.id p

let _daily_bar ~date ~price =
  {
    Types.Daily_price.date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
    active_through = None;
  }

let _daily_bars ~start_date ~n ~start_price ~step =
  List.init n ~f:(fun i ->
      _daily_bar
        ~date:(Date.add_days start_date i)
        ~price:(start_price +. (Float.of_int i *. step)))

(* Rising index (Bullish macro, so the screen runs) and a symbol in a sustained
   decline (Stage 4: never a long candidate, so a resting ticket on it fails the
   weekly re-screen). The last bar is [end_date]. *)
let _reader ~end_date =
  let n = 260 in
  let start_date = Date.add_days end_date (-(n - 1)) in
  Bar_reader.of_in_memory_bars
    [
      (_index_symbol, _daily_bars ~start_date ~n ~start_price:100.0 ~step:1.0);
      ("ZZZ", _daily_bars ~start_date ~n ~start_price:200.0 ~step:(-0.5));
    ]

let _get_price_of ~bar_reader ~current_date symbol =
  match Bar_reader.daily_bars_for bar_reader ~symbol ~as_of:current_date with
  | [] -> None
  | bars -> List.last bars

(* Ids of the entry tickets the tick cancels. *)
let _cancelled_ids transitions =
  List.filter_map transitions ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.CancelEntry _ -> Some t.position_id
      | _ -> None)

let _drive ~screen_holiday_friday_weeks ~current_date =
  let bar_reader = _reader ~end_date:current_date in
  let config =
    {
      (Weinstein_strategy.default_config ~universe:[ "ZZZ" ]
         ~index_symbol:_index_symbol)
      with
      enable_entry_ticket_rescreen = true;
      screen_holiday_friday_weeks;
    }
  in
  let result =
    Internal_for_test.on_market_close ~fold_start_date:None ~config ~ad_bars:[]
      ~stop_states:(ref String.Map.empty)
      ~last_stop_out_dates:(Hashtbl.create (module String))
      ~prior_macro:(ref Weinstein_types.Neutral)
      ~prior_macro_result:(ref None)
      ~prior_decline_character:(ref Decline_character.Not_declining)
      ~peak_tracker:(FL.Peak_tracker.create ())
      ~bar_reader
      ~prior_stages:(Hashtbl.create (module String))
      ~prior_stage_ma_values:(Hashtbl.create (module String))
      ~sector_prior_stages:(Hashtbl.create (module String))
      ~ticker_sectors:(Hashtbl.create (module String))
      ~stage3_streaks:(Hashtbl.create (module String))
      ~laggard_streaks:(Hashtbl.create (module String))
      ~audit_recorder:Audit_recorder.noop
      ~get_price:(_get_price_of ~bar_reader ~current_date)
      ~get_indicator:(fun _ _ _ _ -> None)
      ~portfolio:
        {
          cash = 100_000.0;
          positions = _resting_ticket ~created:(Date.add_days current_date (-7));
        }
  in
  let output = _ok_or_fail "on_market_close" result in
  _cancelled_ids output.Trading_strategy.Strategy_interface.transitions

(** The Thursday before Good Friday: screened (ticket cancelled by the weekly
    re-screen) with the flag on, skipped (ticket rests) with it off. *)
let test_holiday_week_screens_on_thursday_end_to_end _ =
  assert_that
    ( _drive ~screen_holiday_friday_weeks:true ~current_date:_thursday_before,
      _drive ~screen_holiday_friday_weeks:false ~current_date:_thursday_before
    )
    (equal_to ([ "ZZZ-1" ], ([] : string list)))

(** The flag does not turn every Thursday into a review day: an ordinary
    Thursday is skipped with the flag on, and an ordinary Friday screens with it
    on or off. *)
let test_flag_leaves_ordinary_weeks_alone_end_to_end _ =
  assert_that
    [
      _drive ~screen_holiday_friday_weeks:true ~current_date:_ordinary_thursday;
      _drive ~screen_holiday_friday_weeks:true ~current_date:_ordinary_friday;
      _drive ~screen_holiday_friday_weeks:false ~current_date:_ordinary_friday;
    ]
    (elements_are
       [
         is_empty;
         elements_are [ equal_to "ZZZ-1" ];
         elements_are [ equal_to "ZZZ-1" ];
       ])

let suite =
  "holiday_friday_screening"
  >::: [
         "config flag defaults off" >:: test_config_flag_defaults_off;
         "holiday week screens on Thursday end to end"
         >:: test_holiday_week_screens_on_thursday_end_to_end;
         "flag leaves ordinary weeks alone end to end"
         >:: test_flag_leaves_ordinary_weeks_alone_end_to_end;
       ]

let () = run_test_tt_main suite
