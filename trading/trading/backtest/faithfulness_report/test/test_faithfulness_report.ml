open OUnit2
open Matchers
module F = Faithfulness_report

let tr ?(symbol = "X") ?(entry_year = 2020) ?(days_held = 30) ?(pnl = 100.0)
    ?(stop_dist = None) () : F.trade =
  { symbol; entry_year; days_held; pnl; stop_dist }

(* ---- parse_trades ------------------------------------------------------ *)

(* A 20-column trades.csv row with only the parsed cells (0 symbol,
   2 entry_date, 4 days_held, 8 pnl, 15 stop_dist) populated — pins the
   column mapping against Trade_context's schema. *)
let _csv_row ~symbol ~entry_date ~days_held ~pnl ~stop_dist =
  let cells = Array.make 20 "" in
  cells.(0) <- symbol;
  cells.(2) <- entry_date;
  cells.(4) <- days_held;
  cells.(8) <- pnl;
  cells.(15) <- stop_dist;
  String.concat "," (Array.to_list cells)

let _write_temp_csv lines =
  let path = Filename.temp_file "faithfulness_test" ".csv" in
  let oc = open_out path in
  List.iter (fun l -> output_string oc (l ^ "\n")) lines;
  close_out oc;
  path

(* Header dropped; malformed row (non-numeric days_held) filtered out;
   missing stop_dist parses as None. *)
let test_parse_trades _ =
  let path =
    _write_temp_csv
      [
        "symbol,side,entry_date,exit_date,days_held";
        _csv_row ~symbol:"AAA" ~entry_date:"2020-03-01" ~days_held:"5"
          ~pnl:"12.5" ~stop_dist:"0.2";
        _csv_row ~symbol:"BAD" ~entry_date:"2020-03-01" ~days_held:"oops"
          ~pnl:"1.0" ~stop_dist:"";
        _csv_row ~symbol:"BBB" ~entry_date:"2021-07-09" ~days_held:"40"
          ~pnl:"-3.0" ~stop_dist:"";
      ]
  in
  assert_that (F.parse_trades path)
    (elements_are
       [
         equal_to
           ({
              symbol = "AAA";
              entry_year = 2020;
              days_held = 5;
              pnl = 12.5;
              stop_dist = Some 0.2;
            }
             : F.trade);
         equal_to
           ({
              symbol = "BBB";
              entry_year = 2021;
              days_held = 40;
              pnl = -3.0;
              stop_dist = None;
            }
             : F.trade);
       ])

(* ---- run: single-arm vs two-arm branch --------------------------------- *)

let test_run_single_arm _ =
  let a =
    _write_temp_csv
      [
        "header";
        _csv_row ~symbol:"AAA" ~entry_date:"2020-03-01" ~days_held:"5"
          ~pnl:"12.5" ~stop_dist:"0.2";
      ]
  in
  assert_that
    (F.run ~a_path:a ~a_label:"rec" ())
    (all_of
       [
         contains_substring "Sensibility profile — rec";
         not_ (contains_substring "Divergence");
       ])

let test_run_two_arm _ =
  let row =
    _csv_row ~symbol:"AAA" ~entry_date:"2020-03-01" ~days_held:"5" ~pnl:"12.5"
      ~stop_dist:"0.2"
  in
  let a = _write_temp_csv [ "header"; row ] in
  let b = _write_temp_csv [ "header"; row ] in
  assert_that
    (F.run ~a_path:a ~b_path:b ~a_label:"rec" ~b_label:"book" ())
    (all_of
       [
         contains_substring "Sensibility profile — rec";
         contains_substring "Sensibility profile — book";
         contains_substring "Divergence — rec (A) vs book (B)";
         contains_substring "Top symbol divergences";
       ])

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

(* The 0.15 entry sits exactly AT the gate: [n_over] is strictly greater-than,
   so it is not counted (3 parsed + it = 4, but n_over stays 2). *)
let test_stop_width_summary _ =
  let trades =
    [
      tr ~stop_dist:(Some 0.10) ();
      tr ~stop_dist:(Some 0.40) ();
      tr ~stop_dist:(Some 0.94) ();
      tr ~stop_dist:(Some 0.15) ();
      tr ~stop_dist:None ();
    ]
  in
  assert_that
    (F.stop_width_summary trades ~gt:0.15)
    (all_of
       [
         field (fun (s : F.stop_summary) -> s.n) (equal_to 4);
         field (fun (s : F.stop_summary) -> s.n_over) (equal_to 2);
         field (fun (s : F.stop_summary) -> s.max) (float_equal 0.94);
         field (fun (s : F.stop_summary) -> s.mean) (float_equal 0.3975);
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

(* AXTI diverges by 64015 (a huge fill-model gap), FOO by 100, B-only BONLY
   by 50 (a_pnl side defaults to 0); ranked by |delta| desc, capped at k
   (k:2 drops BONLY). *)
let test_top_symbol_divergences _ =
  let a =
    [ tr ~symbol:"AXTI" ~pnl:64000.0 (); tr ~symbol:"FOO" ~pnl:200.0 () ]
  in
  let b =
    [
      tr ~symbol:"AXTI" ~pnl:(-15.0) ();
      tr ~symbol:"FOO" ~pnl:100.0 ();
      tr ~symbol:"BONLY" ~pnl:50.0 ();
    ]
  in
  assert_that
    (F.top_symbol_divergences ~a ~b ~k:3)
    (elements_are
       [
         all_of
           [
             field (fun (s : F.sym_div) -> s.symbol) (equal_to "AXTI");
             field (fun (s : F.sym_div) -> s.delta) (float_equal 64015.0);
           ];
         field (fun (s : F.sym_div) -> s.symbol) (equal_to "FOO");
         all_of
           [
             field (fun (s : F.sym_div) -> s.symbol) (equal_to "BONLY");
             field (fun (s : F.sym_div) -> s.a_pnl) (float_equal 0.0);
             field (fun (s : F.sym_div) -> s.delta) (float_equal (-50.0));
           ];
       ]);
  assert_that (F.top_symbol_divergences ~a ~b ~k:2) (size_is 2)

let suite =
  "faithfulness_report"
  >::: [
         "parse_trades" >:: test_parse_trades;
         "profile_by_year" >:: test_profile_by_year;
         "stop_width_summary" >:: test_stop_width_summary;
         "divergence_by_year" >:: test_divergence_by_year;
         "top_symbol_divergences" >:: test_top_symbol_divergences;
         "run_single_arm" >:: test_run_single_arm;
         "run_two_arm" >:: test_run_two_arm;
       ]

let () = run_test_tt_main suite
