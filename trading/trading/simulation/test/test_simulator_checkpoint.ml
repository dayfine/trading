(** [Simulator.Checkpoint] (#3477 PR 3): capture mid-run, restore into a fresh
    simulator, and finish both; the two [run_result]s must be equal.

    Fixture (Tue 2024-01-02 .. Fri 2024-01-12, daily cadence, StopLimit entry
    fills and trigger-bar stop exits both armed):
    - AAPL: entry ticket at 105 rests as a StopLimit until the 01-08 bar trades
      through it; the position then exits on 01-10 through a [StopLoss] at 104,
      filled on the trigger bar by a resting [Stop] order. Dividends: $1.00 ex
      01-09 (held) and $0.50 ex 01-10 (the exit day: still held when the step
      starts).
    - MSFT: entry ticket at 400 never triggers, so a resting StopLimit order
      survives every checkpoint and the end of the run.

    Checkpoints are taken with the entry ticket resting (01-05), with the
    position held and its dividend cache warm (01-10, the day before the stop
    exit), and with the stop exit already filled (01-11). The comparison blanks
    order clocks (wall time). The strategy is stateless — its state is PR 4. *)

open OUnit2
open Core
open Matchers
open Test_helpers
module Simulator = Trading_simulation.Simulator
module Dividend_crediting = Trading_simulation_dividends.Dividend_crediting
module Metric_types = Trading_simulation_types.Metric_types
module Position = Trading_strategy.Position

let _date = Date.of_string
let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

let _bar ?(open_ = 100.0) ?(high = 101.0) ?(low = 99.0) ?(close = 100.0) d :
    Types.Daily_price.t =
  {
    date = _date d;
    open_price = open_;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

let _aapl =
  [
    _bar "2024-01-02";
    _bar "2024-01-03";
    _bar "2024-01-04";
    _bar "2024-01-05";
    _bar "2024-01-08" ~open_:104.5 ~high:107.0 ~low:104.0 ~close:106.0;
    _bar "2024-01-09" ~open_:106.0 ~high:107.0 ~low:105.0 ~close:106.0;
    _bar "2024-01-10" ~open_:106.0 ~high:106.5 ~low:103.0 ~close:103.5;
    _bar "2024-01-11" ~open_:103.5 ~high:104.0 ~low:102.0 ~close:103.0;
    _bar "2024-01-12" ~open_:103.0 ~high:104.0 ~low:102.0 ~close:103.0;
  ]

let _msft =
  List.map _aapl ~f:(fun (b : Types.Daily_price.t) ->
      {
        b with
        open_price = 300.0;
        high_price = 301.0;
        low_price = 299.0;
        close_price = 300.0;
        adjusted_close = 300.0;
      })

let _config =
  {
    Simulator.start_date = _date "2024-01-02";
    end_date = _date "2024-01-13";
    initial_cash = 100_000.0;
    commission = _commission;
    strategy_cadence = Types.Cadence.Daily;
  }

let _create_entering ~id ~symbol ~price d : Position.transition =
  {
    position_id = id;
    date = _date d;
    kind =
      CreateEntering
        {
          symbol;
          side = Long;
          target_quantity = 10.0;
          entry_price = price;
          reasoning = ManualDecision { description = "checkpoint fixture" };
        };
  }

let _stop_exit d : Position.transition =
  {
    position_id = "AAPL-1";
    date = _date d;
    kind =
      TriggerExit
        {
          exit_reason =
            StopLoss
              { stop_price = 104.0; actual_price = 103.0; loss_percent = 0.0 };
          exit_price = 103.0;
        };
  }

let _is_holding = function
  | Some pos -> (
      match Position.get_state pos with Holding _ -> true | _ -> false)
  | None -> false

(* A pure function of the date and the positions it is handed. *)
module Strategy : Trading_strategy.Strategy_interface.STRATEGY = struct
  let name = "CheckpointFixture"

  let on_market_close ~get_price ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    let transitions =
      match get_price "AAPL" with
      | Some (bar : Types.Daily_price.t)
        when Date.equal bar.date _config.start_date ->
          [
            _create_entering ~id:"AAPL-1" ~symbol:"AAPL" ~price:105.0
              "2024-01-02";
            _create_entering ~id:"MSFT-1" ~symbol:"MSFT" ~price:400.0
              "2024-01-02";
          ]
      | Some bar
        when Date.equal bar.date (_date "2024-01-10")
             && _is_holding (Map.find portfolio.positions "AAPL-1") ->
          [ _stop_exit "2024-01-10" ]
      | _ -> []
    in
    Ok { Trading_strategy.Strategy_interface.transitions }
end

let _dividends : (string * Corporate_actions.dividend list) list =
  [
    ( "AAPL",
      List.map
        [ ("2024-01-09", 1.0); ("2024-01-10", 0.5) ]
        ~f:(fun (d, amt) ->
          {
            Corporate_actions.ex_date = _date d;
            unadjusted_amount = Some amt;
            adjusted_amount = amt;
          }) );
  ]

(* MSFT has no file: restoring must not count the miss a second time. *)
let _crediting () =
  Dividend_crediting.create
    ~load:(fun sym ->
      match List.Assoc.find _dividends sym ~equal:String.equal with
      | Some d -> Ok d
      | None -> Status.error_not_found sym)
    ~start_date:_config.start_date

let _fresh_sim ?dividends data_dir =
  let dividends = Option.value dividends ~default:(_crediting ()) in
  let deps =
    Simulator.create_deps ~symbols:[ "AAPL"; "MSFT" ] ~data_dir
      ~strategy:(module Strategy)
      ~commission:_commission ~entry_extension_max_pct:5.0
      ~sim_stop_exit_fill_on_trigger_bar:true ~dividends ()
  in
  create_exn ~config:_config ~deps

let _with_data name f =
  with_test_data name [ ("AAPL", _aapl); ("MSFT", _msft) ] ~f

let _step_until sim date =
  let rec go sim =
    if Date.equal (Simulator.Checkpoint.capture sim).current_date (_date date)
    then sim
    else go (fst (step_exn sim))
  in
  go sim

let _finish sim = ok_or_fail_status (Simulator.run sim)

(* Orders are stamped with the wall clock when created or updated, so two runs
   of the same inputs differ there by construction. Blank it. *)
let _no_clock (s : Simulator.step_result) =
  let blank (o : Trading_orders.Types.order) =
    { o with created_at = Time_ns_unix.epoch; updated_at = Time_ns_unix.epoch }
  in
  { s with orders_submitted = List.map s.orders_submitted ~f:blank }

(* [run_result] has no equality; this is every field of it as sexps. *)
let _digest (r : Simulator.run_result) =
  Sexp.List
    [
      List.sexp_of_t Simulator.sexp_of_step_result
        (List.map r.steps ~f:_no_clock);
      Trading_portfolio.Portfolio.sexp_of_t r.final_portfolio;
      Int.sexp_of_t r.n_stop_eligible_positions;
      String.Map.sexp_of_t String.sexp_of_t r.order_position_links;
      Metric_types.sexp_of_metric_set r.metrics;
    ]

let _roundtrip snap =
  snap |> Simulator.Checkpoint.sexp_of_snapshot
  |> Simulator.Checkpoint.snapshot_of_sexp

(* Run [uninterrupted]; capture a second run at [at], restore into a fresh
   simulator through a sexp round trip, finish it, return both digests. *)
let _resume_at at =
  _with_data ("sim_checkpoint_" ^ at) (fun data_dir ->
      let uninterrupted = _finish (_fresh_sim data_dir) in
      let paused = _step_until (_fresh_sim data_dir) at in
      let snap = _roundtrip (Simulator.Checkpoint.capture paused) in
      let resumed =
        ok_or_fail_status
          (Simulator.Checkpoint.restore (_fresh_sim data_dir) snap)
      in
      (_digest uninterrupted, _digest (_finish resumed), _finish paused))

let _resumes_equal at =
  let uninterrupted, resumed, paused_continued = _resume_at at in
  assert_that
    (resumed, _digest paused_continued)
    (pair (equal_to uninterrupted) (equal_to uninterrupted))

let test_resume_with_resting_entry_tickets _ = _resumes_equal "2024-01-05"
let test_resume_holding_with_warm_dividend_cache _ = _resumes_equal "2024-01-10"
let test_resume_after_the_stop_exit_fills _ = _resumes_equal "2024-01-11"

(* The fixture must exercise what the tests claim, or equality is vacuous. *)
let test_fixture_fills_stop_pays_dividends_and_leaves_a_resting_order _ =
  let result =
    _with_data "sim_checkpoint_fixture" (fun d -> _finish (_fresh_sim d))
  in
  let sells =
    List.concat_map result.steps ~f:(fun s ->
        List.filter s.trades ~f:(fun t -> Poly.equal t.side Sell))
  in
  assert_that (result, sells)
    (pair
       (field
          (fun (r : Simulator.run_result) -> r.metrics)
          (contains_entry Metric_types.DividendIncomeTotal (float_equal 15.0)))
       (size_is 1))

let test_capture_holds_the_resting_orders_and_dividend_state _ =
  let snap =
    _with_data "sim_checkpoint_content" (fun data_dir ->
        Simulator.Checkpoint.capture
          (_step_until (_fresh_sim data_dir) "2024-01-10"))
  in
  assert_that snap
    (all_of
       [
         field
           (fun (s : Simulator.Checkpoint.snapshot) -> s.deps.orders)
           (size_is 2);
         field
           (fun (s : Simulator.Checkpoint.snapshot) -> s.deps.dividends)
           (is_some_and
              (field
                 (fun (d : Dividend_crediting.snapshot) -> d.cached_symbols)
                 (elements_are [ equal_to "AAPL" ])));
         field
           (fun (s : Simulator.Checkpoint.snapshot) -> List.length s.steps)
           (equal_to 8);
       ])

let test_restore_refuses_a_different_dividend_arming _ =
  let result =
    _with_data "sim_checkpoint_mismatch" (fun data_dir ->
        let snap =
          Simulator.Checkpoint.capture
            (_step_until (_fresh_sim data_dir) "2024-01-05")
        in
        let deps =
          Simulator.create_deps ~symbols:[ "AAPL"; "MSFT" ] ~data_dir
            ~strategy:(module Strategy)
            ~commission:_commission ()
        in
        Simulator.Checkpoint.restore (create_exn ~config:_config ~deps) snap)
  in
  assert_that result is_error

let suite =
  "simulator_checkpoint"
  >::: [
         "resume with resting entry tickets"
         >:: test_resume_with_resting_entry_tickets;
         "resume holding with warm dividend cache"
         >:: test_resume_holding_with_warm_dividend_cache;
         "resume after the stop exit fills"
         >:: test_resume_after_the_stop_exit_fills;
         "fixture fills a stop, pays dividends, leaves a resting order"
         >:: test_fixture_fills_stop_pays_dividends_and_leaves_a_resting_order;
         "capture holds the resting orders and dividend state"
         >:: test_capture_holds_the_resting_orders_and_dividend_state;
         "restore refuses a different dividend arming"
         >:: test_restore_refuses_a_different_dividend_arming;
       ]

let () = run_test_tt_main suite
