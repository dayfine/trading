open OUnit2
open Matchers
module F = Faithfulness_report

let tr ?(symbol = "X") ?(entry_year = 2020) ?(days_held = 30) ?(pnl = 100.0)
    ?(stop_dist = None) () : F.trade =
  { symbol; entry_year; days_held; pnl; stop_dist }

(* ---- profile_by_year --------------------------------------------------- *)

(* Two 2020 entries (one 1-day whipsaw, one 300-day runner) and one 2021 entry.
   Years come back ascending; whipsaw counts days_held<=3, runner days_held>=200. *)
let test_profile_by_year _ =
  let trades =
    [
      tr ~entry_year:2020 ~days_held:1 ~pnl:(-50.0) ();
      tr ~entry_year:2020 ~days_held:300 ~pnl:900.0 ();
      tr ~entry_year:2021 ~days_held:40 ~pnl:200.0 ();
    ]
  in
  assert_that
    (F.profile_by_year trades ~whipsaw_days:3 ~hold_ge:200)
    (elements_are
       [
         all_of
           [
             field (fun (s : F.year_stat) -> s.year) (equal_to 2020);
             field (fun (s : F.year_stat) -> s.n) (equal_to 2);
             field (fun (s : F.year_stat) -> s.pnl) (float_equal 850.0);
             field (fun (s : F.year_stat) -> s.n_whipsaw) (equal_to 1);
             field (fun (s : F.year_stat) -> s.n_runner) (equal_to 1);
             field (fun (s : F.year_stat) -> s.avg_days) (float_equal 150.5);
           ];
         all_of
           [
             field (fun (s : F.year_stat) -> s.year) (equal_to 2021);
             field (fun (s : F.year_stat) -> s.n) (equal_to 1);
             field (fun (s : F.year_stat) -> s.n_whipsaw) (equal_to 0);
           ];
       ])

(* ---- stop_width_summary ------------------------------------------------ *)

let test_stop_width_summary _ =
  let trades =
    [
      tr ~stop_dist:(Some 0.10) ();
      tr ~stop_dist:(Some 0.40) ();
      tr ~stop_dist:(Some 0.94) ();
      tr ~stop_dist:None ();
    ]
  in
  assert_that
    (F.stop_width_summary trades ~gt:0.15)
    (all_of
       [
         field (fun (s : F.stop_summary) -> s.n) (equal_to 3);
         field (fun (s : F.stop_summary) -> s.n_over) (equal_to 2);
         field (fun (s : F.stop_summary) -> s.max) (float_equal 0.94);
         field (fun (s : F.stop_summary) -> s.mean) (float_equal 0.48);
       ])

(* ---- divergence_by_year ------------------------------------------------ *)

let test_divergence_by_year _ =
  let a =
    [ tr ~entry_year:2020 ~pnl:1000.0 (); tr ~entry_year:2021 ~pnl:500.0 () ]
  in
  let b = [ tr ~entry_year:2020 ~pnl:100.0 () ] in
  assert_that
    (F.divergence_by_year ~a ~b)
    (elements_are
       [
         all_of
           [
             field (fun (d : F.year_div) -> d.year) (equal_to 2020);
             field (fun (d : F.year_div) -> d.a_pnl) (float_equal 1000.0);
             field (fun (d : F.year_div) -> d.b_pnl) (float_equal 100.0);
           ];
         all_of
           [
             field (fun (d : F.year_div) -> d.year) (equal_to 2021);
             field (fun (d : F.year_div) -> d.a_n) (equal_to 1);
             field (fun (d : F.year_div) -> d.b_n) (equal_to 0);
             field (fun (d : F.year_div) -> d.b_pnl) (float_equal 0.0);
           ];
       ])

(* ---- top_symbol_divergences -------------------------------------------- *)

(* AXTI diverges by 64000 (a huge fill-model gap), FOO by 100; ranked by
   |delta| desc, capped at k. B-only symbols count with a_pnl=0. *)
let test_top_symbol_divergences _ =
  let a =
    [ tr ~symbol:"AXTI" ~pnl:64000.0 (); tr ~symbol:"FOO" ~pnl:200.0 () ]
  in
  let b =
    [ tr ~symbol:"AXTI" ~pnl:(-15.0) (); tr ~symbol:"FOO" ~pnl:100.0 () ]
  in
  assert_that
    (F.top_symbol_divergences ~a ~b ~k:1)
    (elements_are
       [
         all_of
           [
             field (fun (s : F.sym_div) -> s.symbol) (equal_to "AXTI");
             field (fun (s : F.sym_div) -> s.delta) (float_equal 64015.0);
           ];
       ])

let suite =
  "faithfulness_report"
  >::: [
         "profile_by_year" >:: test_profile_by_year;
         "stop_width_summary" >:: test_stop_width_summary;
         "divergence_by_year" >:: test_divergence_by_year;
         "top_symbol_divergences" >:: test_top_symbol_divergences;
       ]

let () = run_test_tt_main suite
