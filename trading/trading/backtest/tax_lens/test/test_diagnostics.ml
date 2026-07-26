(** Unit tests for [Tax_lens.Diagnostics.top_winners] — the days-to-LT measure.
*)

open OUnit2
open Matchers
module TC = Tax_lens.Tax_config
module TT = Tax_lens.Tax_types
module DG = Tax_lens.Diagnostics

let _trade ~symbol ~days_held ~pnl ?(side = "LONG") () : TT.realized_trade =
  { symbol; exit_year = 2020; days_held; pnl; side }

let _config : TC.t =
  {
    mode = Realized_st_lt;
    flat_rate = 0.5;
    st_rate = 0.5;
    lt_rate = 0.2;
    lt_days = 365;
    carryforward = true;
    top_winners = 3;
  }

(* A: +200 ST at 100d, B: +100 LT at 400d, C: -50 loss (dropped), D: +80 ST at
   50d. Winners sorted desc = [A; B; D]. Boundary tax delta = pnl*(st-lt) for ST
   winners, 0 for LT. A: 265 days short, 200*0.3=60. B: LT, 0. D: 315 short. *)
let _trades =
  [
    _trade ~symbol:"A" ~days_held:100 ~pnl:200. ();
    _trade ~symbol:"B" ~days_held:400 ~pnl:100. ();
    _trade ~symbol:"C" ~days_held:30 ~pnl:(-50.) ();
    _trade ~symbol:"D" ~days_held:50 ~pnl:80. ();
  ]

let test_top_winners _ =
  let winners = DG.top_winners _config _trades in
  assert_that winners
    (elements_are
       [
         all_of
           [
             field (fun w -> w.DG.symbol) (equal_to "A");
             field (fun w -> w.DG.days_to_lt) (equal_to 265);
             field (fun w -> w.DG.is_long_term) (equal_to false);
             field (fun w -> w.DG.boundary_tax_delta) (float_equal 60.);
           ];
         all_of
           [
             field (fun w -> w.DG.symbol) (equal_to "B");
             field (fun w -> w.DG.days_to_lt) (equal_to 0);
             field (fun w -> w.DG.is_long_term) (equal_to true);
             field (fun w -> w.DG.boundary_tax_delta) (float_equal 0.);
           ];
         all_of
           [
             field (fun w -> w.DG.symbol) (equal_to "D");
             field (fun w -> w.DG.days_to_lt) (equal_to 315);
             field (fun w -> w.DG.is_long_term) (equal_to false);
           ];
       ])

let suite = "diagnostics" >::: [ "top_winners" >:: test_top_winners ]
let () = run_test_tt_main suite
