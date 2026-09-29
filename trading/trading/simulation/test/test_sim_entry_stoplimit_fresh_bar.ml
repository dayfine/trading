(** Tests for [sim_entry_stoplimit_fresh_bar_only] (the StopLimit sibling of
    [sim_entry_fill_next_open]).

    A StopLimit entry ticket created from a Friday-close decision is, by
    default, first checked on the Saturday step against the Friday bar the
    engine retains — and fills there if Friday's range crossed the trigger,
    although that range traded before the ticket existed. With the flag on, the
    ticket rests until Monday's fresh bar and fills against that bar.

    The scenario: Friday 2024-01-05 trades 99–112 (through the 105 trigger);
    Monday 2024-01-08 opens 106, above the trigger and under the cap, so the
    Monday fill is at its open. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers

let date_of_string s = Date.of_string s

let make_daily_price ~date ~open_price ~high ~low ~close =
  Types.Daily_price.
    {
      date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      volume = 1_000_000;
      adjusted_close = close;
      active_through = None;
    }

(* Zero costs so a fill price equals the path price exactly. *)
let sample_commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

let prices =
  [
    make_daily_price
      ~date:(date_of_string "2024-01-05")
      ~open_price:100.0 ~high:112.0 ~low:99.0 ~close:110.0;
    make_daily_price
      ~date:(date_of_string "2024-01-08")
      ~open_price:106.0 ~high:109.0 ~low:105.5 ~close:108.0;
    make_daily_price
      ~date:(date_of_string "2024-01-09")
      ~open_price:108.0 ~high:110.0 ~low:107.0 ~close:109.0;
  ]

(* The ticket: trigger at the decision price, cap 10% above it (115.5). *)
let trigger_price = 105.0
let cap_pct = 10.0

(* Emits one [CreateEntering] on the first (Friday) call, then nothing. *)
module Once_entry_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
end = struct
  let name = "OnceEntryStopLimit"
  let emitted = ref false
  let reset () = emitted := false

  let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
    if !emitted then Ok { Trading_strategy.Strategy_interface.transitions = [] }
    else begin
      emitted := true;
      Ok
        {
          Trading_strategy.Strategy_interface.transitions =
            [
              {
                Trading_strategy.Position.position_id = "AAPL-SL";
                date = date_of_string "2024-01-05";
                kind =
                  CreateEntering
                    {
                      symbol = "AAPL";
                      side = Trading_strategy.Position.Long;
                      target_quantity = 10.0;
                      entry_price = trigger_price;
                      reasoning = ManualDecision { description = "stoplimit" };
                    };
              };
            ];
        }
    end
end

let config =
  {
    start_date = date_of_string "2024-01-05";
    end_date = date_of_string "2024-01-10";
    initial_cash = 100_000.0;
    commission = sample_commission;
    strategy_cadence = Types.Cadence.Daily;
  }

let run_exn ~name ~sim_entry_stoplimit_fresh_bar_only =
  Once_entry_strategy.reset ();
  with_test_data name
    [ ("AAPL", prices) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(module Once_entry_strategy)
          ~commission:sample_commission ~entry_extension_max_pct:cap_pct
          ~sim_entry_stoplimit_fresh_bar_only ()
      in
      match run (create_exn ~config ~deps) with
      | Error err -> failwith ("run failed: " ^ Status.show err)
      | Ok result -> result)

let trade_prices result =
  List.concat_map result.steps ~f:(fun s ->
      List.map s.trades ~f:(fun (t : Trading_base.Types.trade) -> t.price))

let step_trade_counts result =
  List.map result.steps ~f:(fun s -> List.length s.trades)

(* OFF (default): the Friday ticket fills on the Saturday step (index 1) inside
   Friday's own range — the stale-bar check every existing baseline carries. *)
let test_off_fills_on_the_stale_friday_bar _ =
  let result =
    run_exn ~name:"sl_fresh_off" ~sim_entry_stoplimit_fresh_bar_only:false
  in
  assert_that (step_trade_counts result) (equal_to [ 0; 1; 0; 0; 0 ]);
  assert_that (trade_prices result)
    (elements_are [ is_between (module Float_ord) ~low:99.0 ~high:112.0 ])

(* ON: the ticket skips the stale weekend steps and fills on Monday (index 3)
   at Monday's open, which is already above the trigger and under the cap. *)
let test_on_waits_for_the_fresh_monday_bar _ =
  let result =
    run_exn ~name:"sl_fresh_on" ~sim_entry_stoplimit_fresh_bar_only:true
  in
  assert_that (step_trade_counts result) (equal_to [ 0; 0; 0; 1; 0 ]);
  assert_that (trade_prices result) (elements_are [ float_equal 106.0 ])

let suite =
  "sim_entry_stoplimit_fresh_bar_only"
  >::: [
         "off fills on the stale Friday bar"
         >:: test_off_fills_on_the_stale_friday_bar;
         "on waits for the fresh Monday bar"
         >:: test_on_waits_for_the_fresh_monday_bar;
       ]

let () = run_test_tt_main suite
