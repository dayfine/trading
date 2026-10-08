(** Issue #3138: an entry ticket the portfolio cannot fund at the fill is
    cancelled, and
    {!Trading_simulation.Simulator.dependencies.on_entry_cash_rejection} now
    receives one {!Trading_simulation.Entry_cash_rejection.t} for it: position
    id, step date, the fill's cost and the cash at the refusal.

    The end-to-end arms drive a real {!Trading_simulation.Simulator.run} on the
    G2a fixture shape: a 100-share ticket triggered at 100 opens at 108 on d2
    (needs 10,800, the book holds 10,400). The unit cases pin the per-step table
    on its own. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers
module Position = Trading_strategy.Position
module R = Trading_simulation.Entry_cash_rejection

let _date s = Date.of_string s
let _symbol = "AAPL"
let _position_id = "AAPL-3138"

(* Zero commission, so [required] reads straight off the bars. *)
let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

let _make_bar ~date ~open_price =
  Types.Daily_price.
    {
      date = _date date;
      open_price;
      high_price = open_price +. 1.0;
      low_price = open_price -. 1.0;
      close_price = open_price;
      adjusted_close = open_price;
      volume = 1_000_000;
      active_through = None;
    }

(* d1 writes the ticket; d2 gaps to 108 (refused); d3 gaps to 200; d4 back at
   100 (affordable). *)
let _bars =
  [
    _make_bar ~date:"2024-01-02" ~open_price:96.0;
    _make_bar ~date:"2024-01-03" ~open_price:108.0;
    _make_bar ~date:"2024-01-04" ~open_price:200.0;
    _make_bar ~date:"2024-01-05" ~open_price:100.0;
  ]

let _config ~cash =
  {
    start_date = _date "2024-01-02";
    end_date = _date "2024-01-06";
    initial_cash = cash;
    commission = _commission;
    strategy_cadence = Types.Cadence.Daily;
  }

(* One [CreateEntering] on the first call with a bar, then silence. *)
let _one_shot_strategy () :
    (module Trading_strategy.Strategy_interface.STRATEGY) =
  let emitted = ref false in
  let module S : Trading_strategy.Strategy_interface.STRATEGY = struct
    let name = "OneShotEntry"

    let _transition ~date : Position.transition =
      {
        position_id = _position_id;
        date;
        kind =
          CreateEntering
            {
              symbol = _symbol;
              side = Position.Long;
              target_quantity = 100.0;
              entry_price = 100.0;
              reasoning = ManualDecision { description = "#3138 fixture" };
            };
      }

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      let open Trading_strategy.Strategy_interface in
      match (!emitted, get_price _symbol) with
      | false, Some (bar : Types.Daily_price.t) ->
          emitted := true;
          Ok { transitions = [ _transition ~date:bar.date ] }
      | _ -> Ok { transitions = [] }
  end
  in
  (module S)

let _rejections ~test_name ~cash ~entry_fill_reject_retries =
  let seen = ref [] in
  let on_entry_cash_rejection r = seen := !seen @ [ r ] in
  with_test_data test_name
    [ (_symbol, _bars) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ _symbol ] ~data_dir
          ~strategy:(_one_shot_strategy ()) ~commission:_commission
          ~on_entry_cash_rejection ~entry_fill_reject_retries ()
      in
      match run (create_exn ~config:(_config ~cash) ~deps) with
      | Ok _ -> !seen
      | Error err -> assert_failure ("run failed: " ^ Status.show err))

(* No retry budget: the d2 refusal cancels the ticket and is recorded once,
   dated d2, with the fill's cost and the cash the book held. *)
let test_cancelled_ticket_recorded _ =
  assert_that
    (_rejections ~test_name:"cash_rej_zero" ~cash:10_400.0
       ~entry_fill_reject_retries:0)
    (elements_are
       [
         equal_to
           ({
              position_id = _position_id;
              symbol = _symbol;
              date = _date "2024-01-03";
              required = 10_800.0;
              available = 10_400.0;
            }
             : R.t);
       ])

(* One retry: the d2 refusal is re-offered, not cancelled, so it is not
   recorded; the retry's d3 refusal at 200 is the cancellation. *)
let test_retried_refusal_not_recorded _ =
  assert_that
    (_rejections ~test_name:"cash_rej_retry" ~cash:10_400.0
       ~entry_fill_reject_retries:1)
    (elements_are
       [
         all_of
           [
             field (fun (r : R.t) -> r.date) (equal_to (_date "2024-01-04"));
             field (fun (r : R.t) -> r.required) (float_equal 20_000.0);
             field (fun (r : R.t) -> r.available) (float_equal 10_400.0);
           ];
       ])

(* A funded ticket fills on d2; nothing is recorded. *)
let test_funded_ticket_not_recorded _ =
  assert_that
    (_rejections ~test_name:"cash_rej_funded" ~cash:20_000.0
       ~entry_fill_reject_retries:0)
    is_empty

let _trade ?(commission = 0.0) ~symbol ~quantity ~price () :
    Trading_base.Types.trade =
  {
    id = symbol ^ "-t";
    order_id = symbol ^ "-o";
    symbol;
    side = Trading_base.Types.Buy;
    quantity;
    price;
    commission;
    timestamp = Time_ns_unix.epoch;
  }

let _entering ~id ~symbol =
  match
    Position.create_entering
      {
        position_id = id;
        date = _date "2024-01-02";
        kind =
          CreateEntering
            {
              symbol;
              side = Position.Long;
              target_quantity = 1.0;
              entry_price = 1.0;
              reasoning = ManualDecision { description = "unit" };
            };
      }
  with
  | Ok p -> p
  | Error err -> assert_failure (Status.show err)

let _cancel id : Position.transition =
  {
    position_id = id;
    date = _date "2024-01-03";
    kind = CancelEntry { reason = "r" };
  }

(* The first refusal of a symbol in a step wins; [required] includes the
   commission; non-cancel transitions and cancels with no noted refusal are
   skipped. *)
let test_pending_maps_cancels_to_notes _ =
  let seen = ref [] in
  let p =
    R.pending ~date:(_date "2024-01-03")
      ~emit:(Some (fun r -> seen := !seen @ [ r ]))
  in
  R.note p
    (_trade ~symbol:"ADMA" ~quantity:10.0 ~price:44.0 ~commission:1.0 ())
    ~available_cash:427.0;
  R.note p
    (_trade ~symbol:"ADMA" ~quantity:1.0 ~price:1.0 ())
    ~available_cash:9.0;
  let positions =
    String.Map.of_alist_exn
      [
        ("adma-1", _entering ~id:"adma-1" ~symbol:"ADMA");
        ("msft-1", _entering ~id:"msft-1" ~symbol:"MSFT");
      ]
  in
  R.emit p ~positions
    ~cancels:
      [
        _cancel "adma-1";
        _cancel "msft-1";
        {
          (_cancel "adma-1") with
          kind =
            UpdateRiskParams
              {
                new_risk_params =
                  {
                    stop_loss_price = None;
                    take_profit_price = None;
                    max_hold_days = None;
                  };
              };
        };
      ];
  assert_that !seen
    (elements_are
       [
         equal_to
           ({
              position_id = "adma-1";
              symbol = "ADMA";
              date = _date "2024-01-03";
              required = 441.0;
              available = 427.0;
            }
             : R.t);
       ])

(* ADMA, 26y investor s1: $446,712.52 needed, $427,489.55 available. *)
let test_funded_fraction _ =
  assert_that
    ( R.funded_fraction
        {
          position_id = "p";
          symbol = "ADMA";
          date = _date "2024-01-03";
          required = 446_712.52;
          available = 427_489.55;
        },
      R.funded_fraction
        {
          position_id = "p";
          symbol = "X";
          date = _date "2024-01-03";
          required = 0.0;
          available = 5.0;
        } )
    (pair (float_equal ~epsilon:1e-4 0.95697) (float_equal 0.0))

let suite =
  "entry_cash_rejection"
  >::: [
         "cancelled ticket recorded" >:: test_cancelled_ticket_recorded;
         "retried refusal not recorded" >:: test_retried_refusal_not_recorded;
         "funded ticket not recorded" >:: test_funded_ticket_not_recorded;
         "pending maps cancels to notes" >:: test_pending_maps_cancels_to_notes;
         "funded fraction" >:: test_funded_fraction;
       ]

let () = run_test_tt_main suite
