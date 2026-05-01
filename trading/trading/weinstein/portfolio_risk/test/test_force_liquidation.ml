open OUnit2
open Core
open Portfolio_risk
open Matchers
module FL = Force_liquidation

(* ---- Helpers ---- *)

let make_long ?(symbol = "AAPL") ?(position_id = "AAPL-1")
    ?(entry_price = 100.0) ?(current_price = 100.0) ?(quantity = 10.0) () :
    FL.position_input =
  {
    symbol;
    position_id;
    side = Trading_base.Types.Long;
    entry_price;
    current_price;
    quantity;
  }

let make_short ?(symbol = "TSLA") ?(position_id = "TSLA-1")
    ?(entry_price = 200.0) ?(current_price = 200.0) ?(quantity = 5.0) () :
    FL.position_input =
  {
    symbol;
    position_id;
    side = Trading_base.Types.Short;
    entry_price;
    current_price;
    quantity;
  }

let date = Date.of_string "2026-04-29"

(* ---- unrealized_pnl ---- *)

let test_pnl_long_winner _ =
  let pnl =
    FL.unrealized_pnl ~side:Trading_base.Types.Long ~entry_price:100.0
      ~current_price:120.0 ~quantity:10.0
  in
  assert_that pnl (float_equal 200.0)

let test_pnl_long_loser _ =
  let pnl =
    FL.unrealized_pnl ~side:Trading_base.Types.Long ~entry_price:100.0
      ~current_price:60.0 ~quantity:10.0
  in
  assert_that pnl (float_equal (-400.0))

let test_pnl_short_winner _ =
  (* short profits when price goes DOWN. Entry 200, now 180 → profit 20*5 = 100 *)
  let pnl =
    FL.unrealized_pnl ~side:Trading_base.Types.Short ~entry_price:200.0
      ~current_price:180.0 ~quantity:5.0
  in
  assert_that pnl (float_equal 100.0)

let test_pnl_short_loser _ =
  (* short loses when price goes UP. Entry 200, now 240 → loss 40*5 = 200 *)
  let pnl =
    FL.unrealized_pnl ~side:Trading_base.Types.Short ~entry_price:200.0
      ~current_price:240.0 ~quantity:5.0
  in
  assert_that pnl (float_equal (-200.0))

(* ---- Peak_tracker ---- *)

let test_peak_tracker_observe_monotone _ =
  let pt = FL.Peak_tracker.create () in
  FL.Peak_tracker.observe pt ~portfolio_value:100.0;
  FL.Peak_tracker.observe pt ~portfolio_value:120.0;
  FL.Peak_tracker.observe pt ~portfolio_value:90.0;
  (* peak should stay at 120 even after observing a lower value *)
  assert_that (FL.Peak_tracker.peak pt) (float_equal 120.0)

let test_peak_tracker_halt_state _ =
  let pt = FL.Peak_tracker.create () in
  assert_that (FL.Peak_tracker.halt_state pt) (equal_to FL.Active);
  FL.Peak_tracker.mark_halted pt;
  assert_that (FL.Peak_tracker.halt_state pt) (equal_to FL.Halted);
  FL.Peak_tracker.reset pt;
  assert_that (FL.Peak_tracker.halt_state pt) (equal_to FL.Active)

(* ---- Per-position trigger ---- *)

let test_per_position_long_no_fire_under_threshold _ =
  (* default long threshold 25%; long at $100 → $80 = 20% loss; should NOT
     fire *)
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_long ~entry_price:100.0 ~current_price:80.0 () ] in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  assert_that events (size_is 0)

let test_per_position_long_fires_on_exceed _ =
  (* long at $100 → $40 = 60% loss; default long threshold 25%; SHOULD fire *)
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_long ~entry_price:100.0 ~current_price:40.0 () ] in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  assert_that events
    (elements_are
       [
         all_of
           [
             field (fun (e : FL.event) -> e.symbol) (equal_to "AAPL");
             field (fun (e : FL.event) -> e.reason) (equal_to FL.Per_position);
             field
               (fun (e : FL.event) -> e.unrealized_pnl_pct)
               (float_equal (-0.6));
           ];
       ])

let test_per_position_short_fires_on_exceed _ =
  (* short at $200 → $320 = 60% loss; default short threshold 15%; SHOULD
     fire *)
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_short ~entry_price:200.0 ~current_price:320.0 () ] in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  assert_that events
    (elements_are
       [
         all_of
           [
             field (fun (e : FL.event) -> e.symbol) (equal_to "TSLA");
             field (fun (e : FL.event) -> e.reason) (equal_to FL.Per_position);
             field
               (fun (e : FL.event) -> e.side)
               (equal_to Trading_base.Types.Short);
           ];
       ])

let test_per_position_does_not_fire_on_winner _ =
  (* long at $100 → $200 = +100% gain; never fires *)
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_long ~entry_price:100.0 ~current_price:200.0 () ] in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  assert_that events (size_is 0)

(* ---- Asymmetric per-position thresholds (G15 step 1) ---- *)

(** Long at $100 → $70 = 30% loss; default long threshold is 25% — fires. Pins
    the long-side cap at the new 0.25 threshold. *)
let test_per_position_long_threshold _ =
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_long ~entry_price:100.0 ~current_price:70.0 () ] in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  assert_that events
    (elements_are
       [
         all_of
           [
             field
               (fun (e : FL.event) -> e.side)
               (equal_to Trading_base.Types.Long);
             field (fun (e : FL.event) -> e.reason) (equal_to FL.Per_position);
             field
               (fun (e : FL.event) -> e.unrealized_pnl_pct)
               (float_equal (-0.3));
           ];
       ])

(** Short at $200 → $236 = 18% loss; default short threshold is 15% — fires.
    Pins the short-side cap at the tighter 0.15 threshold (asymmetric per
    Weinstein's short-sale guidance — short downside is unbounded, so the loss
    budget is held tighter than for longs). *)
let test_per_position_short_threshold _ =
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_short ~entry_price:200.0 ~current_price:236.0 () ] in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  assert_that events
    (elements_are
       [
         all_of
           [
             field
               (fun (e : FL.event) -> e.side)
               (equal_to Trading_base.Types.Short);
             field (fun (e : FL.event) -> e.reason) (equal_to FL.Per_position);
             field
               (fun (e : FL.event) -> e.unrealized_pnl_pct)
               (float_equal (-0.18));
           ];
       ])

(** Long at $100 → $80 = 20% loss; below the 25% long threshold — must NOT fire.
    Pins the asymmetry: a 20% long loss survives, but a 20% short loss would
    exceed the 15% short threshold. *)
let test_per_position_long_no_fire_at_20pct _ =
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_long ~entry_price:100.0 ~current_price:80.0 () ] in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  assert_that events is_empty

(** Short at $200 → $224 = 12% loss; below the 15% short threshold — must NOT
    fire. Pins the asymmetric counterpart: a 12% loss survives on a short, but
    the same 12% loss on a short above the long threshold would not survive on a
    long if scaled (e.g. 25%+ on a long). *)
let test_per_position_short_no_fire_at_12pct _ =
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_short ~entry_price:200.0 ~current_price:224.0 () ] in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  assert_that events is_empty

let test_per_position_custom_threshold _ =
  (* tighter threshold of 20% — long at 100 → 75 = 25% loss; SHOULD fire *)
  let pt = FL.Peak_tracker.create () in
  let config =
    { FL.default_config with max_long_unrealized_loss_fraction = 0.2 }
  in
  let positions = [ make_long ~entry_price:100.0 ~current_price:75.0 () ] in
  let events =
    FL.check ~config ~date ~positions ~portfolio_value:1_000_000.0
      ~peak_tracker:pt
  in
  assert_that events (size_is 1)

(* ---- Portfolio-floor trigger ---- *)

let test_portfolio_floor_first_observation_no_fire _ =
  (* On the first observe, peak starts at 0 and is set to portfolio_value;
     no fire on bar 1 even at very low values — there is no prior peak. *)
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_long () ] in
  let events =
    FL.check ~config:FL.default_config ~date ~positions ~portfolio_value:100.0
      ~peak_tracker:pt
  in
  assert_that events (size_is 0)

let test_portfolio_floor_fires_after_drawdown _ =
  (* observe peak at 1M, drop to 350K = 65% drawdown; default 60% threshold
     (40% of peak floor); fires. *)
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_long (); make_short () ] in
  let _events1 =
    FL.check ~config:FL.default_config ~date ~positions:[]
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  let events2 =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:350_000.0 ~peak_tracker:pt
  in
  (* Both positions should be force-closed under Portfolio_floor reason *)
  assert_that events2
    (all_of
       [
         size_is 2;
         elements_are
           [
             field
               (fun (e : FL.event) -> e.reason)
               (equal_to FL.Portfolio_floor);
             field
               (fun (e : FL.event) -> e.reason)
               (equal_to FL.Portfolio_floor);
           ];
       ])

let test_portfolio_floor_marks_halted _ =
  let pt = FL.Peak_tracker.create () in
  let _ =
    FL.check ~config:FL.default_config ~date ~positions:[]
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  let _ =
    FL.check ~config:FL.default_config ~date ~positions:[]
      ~portfolio_value:350_000.0 ~peak_tracker:pt
  in
  assert_that (FL.Peak_tracker.halt_state pt) (equal_to FL.Halted)

let test_portfolio_floor_no_fire_under_threshold _ =
  (* peak at 1M, drop to 500K = 50% drawdown; default fraction 0.4 means
     fire below 400K. 500K is above the floor — no fire. *)
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_long () ] in
  let _ =
    FL.check ~config:FL.default_config ~date ~positions:[]
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:500_000.0 ~peak_tracker:pt
  in
  assert_that events (size_is 0)

(* ---- Precedence: portfolio-floor wins over per-position ---- *)

let test_portfolio_floor_precedence _ =
  (* Single position with 60% loss; portfolio_value down to 30% of peak.
     Both triggers would fire; portfolio-floor takes precedence and emits
     the Portfolio_floor reason for every position. *)
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_long ~entry_price:100.0 ~current_price:40.0 () ] in
  let _ =
    FL.check ~config:FL.default_config ~date ~positions:[]
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:300_000.0 ~peak_tracker:pt
  in
  assert_that events
    (elements_are
       [ field (fun (e : FL.event) -> e.reason) (equal_to FL.Portfolio_floor) ])

(* ---- Defensive guards (PR #695, qc-behavioral B3) ---- *)

(** Guard: [_check_per_position] short-circuits when cost basis is non-positive
    (zero or negative). Pin the no-fire behaviour so a refactor that drops the
    [cost_basis <= 0] guard fails deterministically. Per-position threshold
    semantics are undefined when there's no cost basis to size the loss against
    (would otherwise divide by zero / produce NaN). *)
let test_zero_cost_basis_does_not_fire _ =
  let pt = FL.Peak_tracker.create () in
  let positions =
    [ make_long ~entry_price:0.0 ~current_price:50.0 ~quantity:100.0 () ]
  in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  assert_that events is_empty

let test_zero_quantity_does_not_fire _ =
  (* Symmetric: cost_basis = entry_price * quantity; quantity = 0 yields 0
     cost_basis. Pin no-fire here too. *)
  let pt = FL.Peak_tracker.create () in
  let positions =
    [ make_long ~entry_price:100.0 ~current_price:40.0 ~quantity:0.0 () ]
  in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  assert_that events is_empty

(* ---- Default config ---- *)

let test_default_config_values _ =
  assert_that FL.default_config
    (all_of
       [
         field
           (fun c -> c.FL.max_long_unrealized_loss_fraction)
           (float_equal 0.25);
         field
           (fun c -> c.FL.max_short_unrealized_loss_fraction)
           (float_equal 0.15);
         field
           (fun c -> c.FL.min_portfolio_value_fraction_of_peak)
           (float_equal 0.4);
       ])

(* ---- Sexp round-trip ---- *)

let test_event_sexp_round_trip _ =
  let pt = FL.Peak_tracker.create () in
  let positions = [ make_long ~entry_price:100.0 ~current_price:40.0 () ] in
  let events =
    FL.check ~config:FL.default_config ~date ~positions
      ~portfolio_value:1_000_000.0 ~peak_tracker:pt
  in
  match events with
  | [ event ] ->
      let sexp = FL.sexp_of_event event in
      let round_tripped = FL.event_of_sexp sexp in
      assert_that round_tripped (equal_to event)
  | _ -> assert_failure "expected exactly one event"

(* ---- Suite ---- *)

let suite =
  "force_liquidation"
  >::: [
         "pnl_long_winner" >:: test_pnl_long_winner;
         "pnl_long_loser" >:: test_pnl_long_loser;
         "pnl_short_winner" >:: test_pnl_short_winner;
         "pnl_short_loser" >:: test_pnl_short_loser;
         "peak_tracker_observe_monotone" >:: test_peak_tracker_observe_monotone;
         "peak_tracker_halt_state" >:: test_peak_tracker_halt_state;
         "per_position_long_no_fire_under_threshold"
         >:: test_per_position_long_no_fire_under_threshold;
         "per_position_long_fires_on_exceed"
         >:: test_per_position_long_fires_on_exceed;
         "per_position_short_fires_on_exceed"
         >:: test_per_position_short_fires_on_exceed;
         "per_position_does_not_fire_on_winner"
         >:: test_per_position_does_not_fire_on_winner;
         "per_position_long_threshold (G15)"
         >:: test_per_position_long_threshold;
         "per_position_short_threshold (G15)"
         >:: test_per_position_short_threshold;
         "per_position_long_no_fire_at_20pct (G15)"
         >:: test_per_position_long_no_fire_at_20pct;
         "per_position_short_no_fire_at_12pct (G15)"
         >:: test_per_position_short_no_fire_at_12pct;
         "per_position_custom_threshold" >:: test_per_position_custom_threshold;
         "portfolio_floor_first_observation_no_fire"
         >:: test_portfolio_floor_first_observation_no_fire;
         "portfolio_floor_fires_after_drawdown"
         >:: test_portfolio_floor_fires_after_drawdown;
         "portfolio_floor_marks_halted" >:: test_portfolio_floor_marks_halted;
         "portfolio_floor_no_fire_under_threshold"
         >:: test_portfolio_floor_no_fire_under_threshold;
         "portfolio_floor_precedence" >:: test_portfolio_floor_precedence;
         "zero cost basis does not fire" >:: test_zero_cost_basis_does_not_fire;
         "zero quantity does not fire" >:: test_zero_quantity_does_not_fire;
         "default_config_values" >:: test_default_config_values;
         "event_sexp_round_trip" >:: test_event_sexp_round_trip;
       ]

let () = run_test_tt_main suite
