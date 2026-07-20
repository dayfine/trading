(** Tests for the deterministic short-side buy-in stress-path mode (margin M3b).

    Pins the R1 default-off invariant, the HTB selection ([select_buyins]), the
    weekly (Friday) cadence, the [buyin_stress] exit tag, and the fact that only
    held shorts marked strictly below the HTB threshold are force-covered — on
    the pure {!Trading_simulation.Short_buyin} surface. *)

open OUnit2
open Core
open Matchers
module Short_buyin = Trading_simulation.Short_buyin
module Margin_config = Trading_portfolio.Margin_config
module Position = Trading_strategy.Position

(* ------------------------------------------------------------------ *)
(* Fixtures                                                            *)
(* ------------------------------------------------------------------ *)

let _friday = Date.of_string "2024-04-05" (* Friday *)
let _monday = Date.of_string "2024-04-08" (* Monday *)

(* Armed stress mode: names marked strictly below $5 are hard-to-borrow. *)
let _armed =
  {
    Margin_config.default_config with
    Margin_config.short_buyin_stress_mode = true;
    Margin_config.short_buyin_htb_price_below = 5.0;
  }

let _hold ~id ~mark = { Short_buyin.position_id = id; symbol = id; mark }

(* CHEAP marked $3 (HTB), RICH marked $50 (liquid). *)
let _holdings = [ _hold ~id:"CHEAP" ~mark:3.0; _hold ~id:"RICH" ~mark:50.0 ]
let _prices = [ ("CHEAP", 3.0); ("RICH", 50.0) ]
let _ids buyins = List.map buyins ~f:(fun h -> h.Short_buyin.position_id)

(* Build a Position.t short in the Holding state (mirrors the M2 test helper). *)
let _make_short ~id ~entry ~qty =
  let make_trans kind = { Position.position_id = id; date = _friday; kind } in
  let unwrap = function
    | Ok p -> p
    | Error _ -> assert_failure "position setup failed"
  in
  let open Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = id;
              side = Trading_base.Types.Short;
              target_quantity = qty;
              entry_price = entry;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = qty; fill_price = entry }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let _positions_map ids =
  List.map ids ~f:(fun id -> (id, _make_short ~id ~entry:10.0 ~qty:100.0))
  |> Map.of_alist_exn (module String)

(* ------------------------------------------------------------------ *)
(* Pure selector                                                       *)
(* ------------------------------------------------------------------ *)

(* R1: the default (disarmed) config selects nothing, even for a sub-$1 name. *)
let test_default_selects_nothing _ =
  assert_that
    (Short_buyin.select_buyins ~margin_config:Margin_config.default_config
       ~holdings:_holdings)
    (size_is 0)

(* Armed: only the HTB (below-threshold) short is selected; the liquid one is
   left untouched, and input order is preserved. *)
let test_armed_selects_only_htb _ =
  assert_that
    (_ids (Short_buyin.select_buyins ~margin_config:_armed ~holdings:_holdings))
    (elements_are [ equal_to "CHEAP" ])

(* Armed with a 0.0 threshold selects nothing (no positive mark is below 0). *)
let test_zero_threshold_selects_nothing _ =
  let armed_zero =
    { _armed with Margin_config.short_buyin_htb_price_below = 0.0 }
  in
  assert_that
    (Short_buyin.select_buyins ~margin_config:armed_zero ~holdings:_holdings)
    (size_is 0)

(* ------------------------------------------------------------------ *)
(* Wired transition builder                                            *)
(* ------------------------------------------------------------------ *)

(* Matcher: the transition is a TriggerExit tagged [buyin_stress] with the given
   exit price (the mark). *)
let _is_buyin_exit ~exit_price =
  field
    (fun (t : Position.transition) -> t.kind)
    (matching ~msg:"TriggerExit buyin_stress"
       (function
         | Position.TriggerExit
             {
               exit_reason = Position.StrategySignal { label; _ };
               exit_price = ep;
             }
           when String.equal label "buyin_stress" ->
             Some ep
         | _ -> None)
       (float_equal exit_price))

(* Armed on a Friday: the HTB short (CHEAP) is force-covered at its mark with the
   [buyin_stress] tag; the liquid short (RICH) is not touched. *)
let test_friday_armed_emits_buyin _ =
  assert_that
    (Short_buyin.buyin_stress_transitions ~margin_config:_armed
       ~positions:(_positions_map [ "CHEAP"; "RICH" ])
       ~prices:_prices ~date:_friday)
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Position.transition) -> t.position_id)
               (equal_to "CHEAP");
             _is_buyin_exit ~exit_price:3.0;
           ];
       ])

(* R1: the default (disarmed) config emits nothing on a Friday, even with an HTB
   short held — the baseline replays bit-identically. *)
let test_disarmed_friday_no_op _ =
  assert_that
    (Short_buyin.buyin_stress_transitions
       ~margin_config:Margin_config.default_config
       ~positions:(_positions_map [ "CHEAP"; "RICH" ])
       ~prices:_prices ~date:_friday)
    (size_is 0)

(* Weekly cadence: the same armed HTB state on a Monday emits nothing. *)
let test_armed_non_friday_no_op _ =
  assert_that
    (Short_buyin.buyin_stress_transitions ~margin_config:_armed
       ~positions:(_positions_map [ "CHEAP"; "RICH" ])
       ~prices:_prices ~date:_monday)
    (size_is 0)

(* A held short with no mark today is unfillable and skipped (no price for it). *)
let test_unmarked_short_skipped _ =
  assert_that
    (Short_buyin.buyin_stress_transitions ~margin_config:_armed
       ~positions:(_positions_map [ "CHEAP" ])
       ~prices:[ ("RICH", 50.0) ]
       ~date:_friday)
    (size_is 0)

(* No held positions => nothing to cover, even armed on a Friday. *)
let test_no_positions_no_op _ =
  assert_that
    (Short_buyin.buyin_stress_transitions ~margin_config:_armed
       ~positions:(Map.empty (module String))
       ~prices:_prices ~date:_friday)
    (size_is 0)

let suite =
  "short_buyin"
  >::: [
         "default selects nothing (R1)" >:: test_default_selects_nothing;
         "armed selects only HTB" >:: test_armed_selects_only_htb;
         "zero threshold selects nothing"
         >:: test_zero_threshold_selects_nothing;
         "friday armed emits buyin (tagged)" >:: test_friday_armed_emits_buyin;
         "disarmed friday => no-op (R1)" >:: test_disarmed_friday_no_op;
         "armed non-friday => no-op (weekly cadence)"
         >:: test_armed_non_friday_no_op;
         "unmarked short => skipped" >:: test_unmarked_short_skipped;
         "no positions => no-op" >:: test_no_positions_no_op;
       ]

let () = run_test_tt_main suite
