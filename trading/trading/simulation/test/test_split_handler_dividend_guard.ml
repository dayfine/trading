(** Issue #3173, simulator side: {!Trading_simulation.Split_handler} drops a
    detected split that {!Split_dividend_guard} identifies as a vendor cash
    dividend, so a held position gains no phantom shares; with no guard (the
    default, flag off) every detected split is applied as before. *)

open OUnit2
open Core
open Matchers
module Split_handler = Trading_simulation.Split_handler
module Adapter = Trading_simulation_data.Market_data_adapter
module CA = Corporate_actions

let _bar date ~close ~adjusted : Types.Daily_price.t =
  {
    date = Date.of_string date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = adjusted;
    volume = 1_000_000;
    active_through = None;
  }

(* A two-bar adapter for one symbol: [curr] on its date, [prev] before it. *)
let _adapter ~prev ~(curr : Types.Daily_price.t) =
  Adapter.create_with_callbacks
    ~get_price:(fun ~symbol:_ ~date ->
      Option.some_if (Date.equal date curr.date) curr)
    ~get_previous_bar:(fun ~symbol:_ ~date ->
      Option.some_if (Date.equal date curr.date) prev)

(* TDG 2013-07-11: $22.00 special on 160.80, read by the detector as 22/19. *)
let _tdg_prev = _bar "2013-07-10" ~close:160.80 ~adjusted:138.80
let _tdg_curr = _bar "2013-07-11" ~close:139.50 ~adjusted:139.50

let _guard ~dividends ~splits =
  Split_dividend_guard.create
    ~load_dividends:(fun _ -> Ok dividends)
    ~load_splits:(fun _ -> Ok splits)
    ()

let _tdg_guard () =
  _guard
    ~dividends:
      [
        {
          CA.ex_date = Date.of_string "2013-07-11";
          unadjusted_amount = Some 22.0;
          adjusted_amount = 22.0;
        };
      ]
    ~splits:[]

let _detect ?split_guard ~symbol ~prev ~curr () =
  Split_handler.detect_for_symbol ?split_guard ~adapter:(_adapter ~prev ~curr)
    ~date:curr.Types.Daily_price.date ~symbol ()

(* Flag off: no guard, the pre-#3173 behaviour (the phantom 22/19 split). *)
let test_no_guard_applies_detected_split _ =
  assert_that
    (_detect ~symbol:"TDG" ~prev:_tdg_prev ~curr:_tdg_curr ())
    (is_some_and
       (field
          (fun (e : Trading_portfolio.Split_event.t) -> e.factor)
          (float_equal (22.0 /. 19.0))))

let test_guard_drops_dividend_split _ =
  assert_that
    (_detect ~split_guard:(_tdg_guard ()) ~symbol:"TDG" ~prev:_tdg_prev
       ~curr:_tdg_curr ())
    is_none

let test_guard_keeps_vendor_split _ =
  let guard =
    _guard ~dividends:[]
      ~splits:[ { CA.date = Date.of_string "2020-08-31"; factor = 4.0 } ]
  in
  assert_that
    (_detect ~split_guard:guard ~symbol:"AAPL"
       ~prev:(_bar "2020-08-28" ~close:499.23 ~adjusted:124.81)
       ~curr:(_bar "2020-08-31" ~close:129.04 ~adjusted:129.04)
       ())
    (is_some_and
       (field
          (fun (e : Trading_portfolio.Split_event.t) -> e.factor)
          (float_equal 4.0)))

let suite =
  "split_handler_dividend_guard"
  >::: [
         "no guard applies detected split"
         >:: test_no_guard_applies_detected_split;
         "guard drops dividend split" >:: test_guard_drops_dividend_split;
         "guard keeps vendor split" >:: test_guard_keeps_vendor_split;
       ]

let () = run_test_tt_main suite
