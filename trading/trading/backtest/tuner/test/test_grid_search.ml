(** Unit tests for {!Tuner.Grid_search}. The evaluator is a pure stub — no real
    backtest is run. Determinism is pinned by feeding fixed metrics keyed off
    [(cell, scenario)]. *)

open OUnit2
open Core
open Matchers
module GS = Tuner.Grid_search
module Metric_types = Trading_simulation_types.Metric_types

(* ---------- Stub helpers ---------- *)

(** Build a metric set from a single [(metric_type, value)] association. *)
let _metrics_of_alist alist = Metric_types.of_alist_exn alist

(** Constant evaluator: every [(cell, scenario)] returns the same metrics. *)
let _const_evaluator metrics : GS.evaluator = fun _cell ~scenario:_ -> metrics

(** Cell-keyed evaluator: lookup metrics by the SUM of the cell's float values.
    Useful for asserting that the argmax picks the cell whose sum is biggest. *)
let _sum_evaluator : GS.evaluator =
 fun cell ~scenario:_ ->
  let s = List.fold cell ~init:0.0 ~f:(fun acc (_, v) -> acc +. v) in
  _metrics_of_alist [ (Metric_types.SharpeRatio, s) ]

(** Synthetic evaluator: an injected per-cell-per-scenario lookup table. *)
let _table_evaluator table : GS.evaluator =
 fun cell ~scenario ->
  let key = (cell, scenario) in
  match
    List.find table ~f:(fun (k, _) ->
        let cell_eq =
          List.equal
            (fun (k1, v1) (k2, v2) -> String.equal k1 k2 && Float.equal v1 v2)
            (fst k) (fst key)
        in
        cell_eq && String.equal (snd k) (snd key))
  with
  | Some (_, m) -> m
  | None -> _metrics_of_alist [ (Metric_types.SharpeRatio, 0.0) ]

(* ---------- Cells / Cartesian product ---------- *)

let test_cartesian_3x3x3_yields_27 _ =
  let spec =
    [
      ("a", [ 1.0; 2.0; 3.0 ]);
      ("b", [ 1.0; 2.0; 3.0 ]);
      ("c", [ 1.0; 2.0; 3.0 ]);
    ]
  in
  assert_that (GS.cells_of_spec spec) (size_is 27)

let test_cartesian_3x3x3x3_yields_81 _ =
  (* The flagship 81-cell scoring-weight grid from the M5.5 T-A spec. *)
  let spec =
    [
      ("screening.weights.rs", [ 0.2; 0.3; 0.4 ]);
      ("screening.weights.volume", [ 0.2; 0.3; 0.4 ]);
      ("screening.weights.breakout", [ 0.2; 0.3; 0.4 ]);
      ("screening.weights.sector", [ 0.2; 0.3; 0.4 ]);
    ]
  in
  assert_that (GS.cells_of_spec spec) (size_is 81)

let test_cartesian_empty_spec_yields_one_empty_cell _ =
  assert_that (GS.cells_of_spec []) (elements_are [ is_empty ])

let test_cartesian_with_empty_values_yields_zero_cells _ =
  let spec = [ ("a", [ 1.0; 2.0 ]); ("b", []); ("c", [ 1.0 ]) ] in
  assert_that (GS.cells_of_spec spec) is_empty

let test_cartesian_lex_order_innermost_varies_fastest _ =
  (* For [[("a", [1; 2]); ("b", [10; 20])]] the order should be:
     [a=1, b=10]; [a=1, b=20]; [a=2, b=10]; [a=2, b=20]. *)
  let spec = [ ("a", [ 1.0; 2.0 ]); ("b", [ 10.0; 20.0 ]) ] in
  assert_that (GS.cells_of_spec spec)
    (elements_are
       [
         equal_to [ ("a", 1.0); ("b", 10.0) ];
         equal_to [ ("a", 1.0); ("b", 20.0) ];
         equal_to [ ("a", 2.0); ("b", 10.0) ];
         equal_to [ ("a", 2.0); ("b", 20.0) ];
       ])

let test_cell_to_overrides_top_level _ =
  let cell = [ ("initial_stop_buffer", 1.05) ] in
  let sexps = GS.cell_to_overrides cell in
  assert_that sexps (size_is 1)

let test_cell_to_overrides_nested _ =
  let cell = [ ("stops_config.initial_stop_buffer", 1.08) ] in
  let sexps = GS.cell_to_overrides cell in
  (* Each sexp is the wrapped record form: ((stops_config ((initial_stop_buffer 1.08)))) *)
  assert_that sexps
    (elements_are
       [
         (fun s ->
           let s_str = Sexp.to_string s in
           assert_that
             (String.is_substring s_str ~substring:"stops_config")
             (equal_to true);
           assert_that
             (String.is_substring s_str ~substring:"initial_stop_buffer")
             (equal_to true));
       ])

(* ---------- Objectives ---------- *)

let test_objective_label _ =
  assert_that (GS.objective_label GS.Sharpe) (equal_to "sharpe");
  assert_that (GS.objective_label GS.Calmar) (equal_to "calmar");
  assert_that
    (GS.objective_label (GS.Composite [ (Metric_types.SharpeRatio, 1.0) ]))
    (equal_to "composite")

let test_objective_metric_type_simple _ =
  assert_that
    (GS.objective_metric_type GS.Sharpe)
    (is_some_and (equal_to Metric_types.SharpeRatio));
  assert_that
    (GS.objective_metric_type
       (GS.Composite [ (Metric_types.SharpeRatio, 1.0) ]))
    is_none

let test_evaluate_objective_simple _ =
  let metrics =
    _metrics_of_alist
      [ (Metric_types.SharpeRatio, 1.5); (Metric_types.CalmarRatio, 2.0) ]
  in
  assert_that (GS.evaluate_objective GS.Sharpe metrics) (float_equal 1.5);
  assert_that (GS.evaluate_objective GS.Calmar metrics) (float_equal 2.0)

let test_evaluate_objective_composite_weighted_sum _ =
  let metrics =
    _metrics_of_alist
      [
        (Metric_types.SharpeRatio, 2.0);
        (Metric_types.CalmarRatio, 3.0);
        (Metric_types.MaxDrawdown, -10.0);
      ]
  in
  let composite =
    GS.Composite
      [
        (Metric_types.SharpeRatio, 1.0);
        (Metric_types.CalmarRatio, 0.5);
        (Metric_types.MaxDrawdown, -0.1);
      ]
  in
  (* 1.0*2.0 + 0.5*3.0 + -0.1*(-10.0) = 2.0 + 1.5 + 1.0 = 4.5 *)
  assert_that (GS.evaluate_objective composite metrics) (float_equal 4.5)

let test_evaluate_objective_missing_metric_is_zero _ =
  let metrics = Metric_types.empty in
  assert_that (GS.evaluate_objective GS.Sharpe metrics) (float_equal 0.0)

(* ---------- Run / argmax ---------- *)

let test_run_picks_argmax_cell _ =
  (* Sum-evaluator: best cell maximises the sum of its values. With spec
     a∈{1,2,3} × b∈{10,20,30}, best is (3, 30) with sum 33. *)
  let spec = [ ("a", [ 1.0; 2.0; 3.0 ]); ("b", [ 10.0; 20.0; 30.0 ]) ] in
  let result =
    GS.run spec ~scenarios:[ "scn" ] ~objective:GS.Sharpe
      ~evaluator:_sum_evaluator
  in
  assert_that result.best_cell (equal_to [ ("a", 3.0); ("b", 30.0) ]);
  assert_that result.best_score (float_equal 33.0)

let test_run_emits_one_row_per_cell_per_scenario _ =
  (* 3 cells × 2 scenarios = 6 rows. *)
  let spec = [ ("a", [ 1.0; 2.0; 3.0 ]) ] in
  let result =
    GS.run spec ~scenarios:[ "s1"; "s2" ] ~objective:GS.Sharpe
      ~evaluator:_sum_evaluator
  in
  assert_that result.rows (size_is 6)

let test_run_argmax_averages_across_scenarios _ =
  (* Two cells, two scenarios. Cell A has Sharpe (1.0, 5.0) → mean 3.0.
     Cell B has Sharpe (4.0, 4.0) → mean 4.0. B wins. *)
  let spec = [ ("a", [ 1.0; 2.0 ]) ] in
  let cell_a = [ ("a", 1.0) ] in
  let cell_b = [ ("a", 2.0) ] in
  let table =
    [
      ((cell_a, "s1"), _metrics_of_alist [ (Metric_types.SharpeRatio, 1.0) ]);
      ((cell_a, "s2"), _metrics_of_alist [ (Metric_types.SharpeRatio, 5.0) ]);
      ((cell_b, "s1"), _metrics_of_alist [ (Metric_types.SharpeRatio, 4.0) ]);
      ((cell_b, "s2"), _metrics_of_alist [ (Metric_types.SharpeRatio, 4.0) ]);
    ]
  in
  let result =
    GS.run spec ~scenarios:[ "s1"; "s2" ] ~objective:GS.Sharpe
      ~evaluator:(_table_evaluator table)
  in
  assert_that result.best_cell (equal_to cell_b);
  assert_that result.best_score (float_equal 4.0)

let test_run_tie_break_picks_first_cell _ =
  (* All cells have the same score; first cell wins by enumeration order. *)
  let spec = [ ("a", [ 1.0; 2.0; 3.0 ]) ] in
  let result =
    GS.run spec ~scenarios:[ "s" ] ~objective:GS.Sharpe
      ~evaluator:
        (_const_evaluator
           (_metrics_of_alist [ (Metric_types.SharpeRatio, 7.0) ]))
  in
  assert_that result.best_cell (equal_to [ ("a", 1.0) ])

let test_run_empty_scenarios_raises _ =
  let spec = [ ("a", [ 1.0 ]) ] in
  let f () =
    let _ =
      GS.run spec ~scenarios:[] ~objective:GS.Sharpe
        ~evaluator:(_const_evaluator Metric_types.empty)
    in
    ()
  in
  assert_raises
    (Invalid_argument "Grid_search.run: scenarios must be non-empty") f

let test_run_determinism _ =
  let spec = [ ("a", [ 1.0; 2.0 ]); ("b", [ 10.0; 20.0 ]) ] in
  let r1 =
    GS.run spec ~scenarios:[ "s1" ] ~objective:GS.Sharpe
      ~evaluator:_sum_evaluator
  in
  let r2 =
    GS.run spec ~scenarios:[ "s1" ] ~objective:GS.Sharpe
      ~evaluator:_sum_evaluator
  in
  assert_that r1.best_cell (equal_to r2.best_cell);
  assert_that r1.best_score (float_equal r2.best_score);
  assert_that (List.length r1.rows) (equal_to (List.length r2.rows))

(* ---------- Sensitivity ---------- *)

let test_sensitivity_one_row_per_param _ =
  let spec = [ ("a", [ 1.0; 2.0 ]); ("b", [ 10.0; 20.0 ]) ] in
  let result =
    GS.run spec ~scenarios:[ "s" ] ~objective:GS.Sharpe
      ~evaluator:_sum_evaluator
  in
  let sens = GS.compute_sensitivity spec result in
  assert_that sens
    (elements_are
       [
         field (fun (r : GS.sensitivity_row) -> r.param) (equal_to "a");
         field (fun (r : GS.sensitivity_row) -> r.param) (equal_to "b");
       ])

let test_sensitivity_holds_others_at_best _ =
  (* spec: a∈{1,2}, b∈{10,20}. Sum-evaluator. Best cell is (2, 20) sum 22.
     Sensitivity for "a" holds b=20 (best): a=1 → 21; a=2 → 22.
     Sensitivity for "b" holds a=2 (best): b=10 → 12; b=20 → 22. *)
  let spec = [ ("a", [ 1.0; 2.0 ]); ("b", [ 10.0; 20.0 ]) ] in
  let result =
    GS.run spec ~scenarios:[ "s" ] ~objective:GS.Sharpe
      ~evaluator:_sum_evaluator
  in
  let sens = GS.compute_sensitivity spec result in
  match sens with
  | [ a_row; b_row ] ->
      assert_that a_row.varied_values
        (elements_are
           [
             pair (float_equal 1.0) (float_equal 21.0);
             pair (float_equal 2.0) (float_equal 22.0);
           ]);
      assert_that b_row.varied_values
        (elements_are
           [
             pair (float_equal 10.0) (float_equal 12.0);
             pair (float_equal 20.0) (float_equal 22.0);
           ])
  | _ -> assert_failure "expected exactly two sensitivity rows"

let test_sensitivity_empty_spec_yields_empty_rows _ =
  let result =
    GS.run [] ~scenarios:[ "s" ] ~objective:GS.Sharpe
      ~evaluator:(_const_evaluator Metric_types.empty)
  in
  assert_that (GS.compute_sensitivity [] result) is_empty

(* ---------- Output writers ---------- *)

let _with_temp_dir f =
  let dir =
    Filename_unix.temp_dir ~in_dir:Filename.temp_dir_name "grid_search_test_" ""
  in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      (* Best-effort cleanup; OS will reap on shutdown otherwise. *)
      let rec rm_tree p =
        if Sys_unix.is_directory_exn p then begin
          Sys_unix.readdir p
          |> Array.iter ~f:(fun child -> rm_tree (Filename.concat p child));
          Core_unix.rmdir p
        end
        else Core_unix.unlink p
      in
      try rm_tree dir with _ -> ())

let test_write_csv_has_header_and_one_row_per_input _ =
  let spec = [ ("a", [ 1.0; 2.0 ]) ] in
  let result =
    GS.run spec ~scenarios:[ "s1"; "s2" ] ~objective:GS.Sharpe
      ~evaluator:_sum_evaluator
  in
  _with_temp_dir (fun dir ->
      let path = Filename.concat dir "grid.csv" in
      GS.write_csv ~output_path:path ~objective:GS.Sharpe result;
      let lines = In_channel.read_lines path in
      (* 1 header + 4 rows (2 cells × 2 scenarios) = 5 lines *)
      assert_that lines (size_is 5);
      let header = List.hd_exn lines in
      assert_that
        (String.is_substring header ~substring:"objective_sharpe")
        (equal_to true);
      assert_that
        (String.is_substring header ~substring:"scenario")
        (equal_to true);
      assert_that (String.is_substring header ~substring:"a") (equal_to true))

let test_write_best_sexp_round_trips_to_overrides _ =
  let spec = [ ("a", [ 1.0; 2.0 ]); ("b", [ 10.0; 20.0 ]) ] in
  let result =
    GS.run spec ~scenarios:[ "s" ] ~objective:GS.Sharpe
      ~evaluator:_sum_evaluator
  in
  _with_temp_dir (fun dir ->
      let path = Filename.concat dir "best.sexp" in
      GS.write_best_sexp ~output_path:path result;
      let parsed = Sexp.load_sexp path in
      let s_str = Sexp.to_string parsed in
      assert_that (String.is_substring s_str ~substring:"a") (equal_to true);
      assert_that (String.is_substring s_str ~substring:"b") (equal_to true))

let test_write_sensitivity_md_emits_per_param_section _ =
  let spec = [ ("a", [ 1.0; 2.0 ]); ("b", [ 10.0; 20.0 ]) ] in
  let result =
    GS.run spec ~scenarios:[ "s" ] ~objective:GS.Sharpe
      ~evaluator:_sum_evaluator
  in
  let sens = GS.compute_sensitivity spec result in
  _with_temp_dir (fun dir ->
      let path = Filename.concat dir "sensitivity.md" in
      GS.write_sensitivity_md ~output_path:path ~objective:GS.Sharpe sens;
      let body = In_channel.read_all path in
      assert_that
        (String.is_substring body ~substring:"## Param: `a`")
        (equal_to true);
      assert_that
        (String.is_substring body ~substring:"## Param: `b`")
        (equal_to true);
      assert_that (String.is_substring body ~substring:"sharpe") (equal_to true))

let suite =
  "Tuner.Grid_search"
  >::: [
         "cartesian 3x3x3 yields 27" >:: test_cartesian_3x3x3_yields_27;
         "cartesian 3x3x3x3 yields 81 (T-A flagship grid)"
         >:: test_cartesian_3x3x3x3_yields_81;
         "cartesian empty spec yields one empty cell"
         >:: test_cartesian_empty_spec_yields_one_empty_cell;
         "cartesian with an empty values list yields zero cells"
         >:: test_cartesian_with_empty_values_yields_zero_cells;
         "cartesian lex order: innermost varies fastest"
         >:: test_cartesian_lex_order_innermost_varies_fastest;
         "cell_to_overrides: top-level field"
         >:: test_cell_to_overrides_top_level;
         "cell_to_overrides: nested field" >:: test_cell_to_overrides_nested;
         "objective_label" >:: test_objective_label;
         "objective_metric_type" >:: test_objective_metric_type_simple;
         "evaluate_objective: simple metric lookup"
         >:: test_evaluate_objective_simple;
         "evaluate_objective: composite weighted sum"
         >:: test_evaluate_objective_composite_weighted_sum;
         "evaluate_objective: missing metric is 0.0"
         >:: test_evaluate_objective_missing_metric_is_zero;
         "run picks argmax cell" >:: test_run_picks_argmax_cell;
         "run emits one row per cell per scenario"
         >:: test_run_emits_one_row_per_cell_per_scenario;
         "run argmax averages across scenarios"
         >:: test_run_argmax_averages_across_scenarios;
         "run tie-break picks first cell"
         >:: test_run_tie_break_picks_first_cell;
         "run with empty scenarios raises" >:: test_run_empty_scenarios_raises;
         "run is deterministic" >:: test_run_determinism;
         "sensitivity: one row per param" >:: test_sensitivity_one_row_per_param;
         "sensitivity: holds others at best"
         >:: test_sensitivity_holds_others_at_best;
         "sensitivity: empty spec yields empty rows"
         >:: test_sensitivity_empty_spec_yields_empty_rows;
         "write_csv: header + one row per input"
         >:: test_write_csv_has_header_and_one_row_per_input;
         "write_best_sexp: round-trips to overrides"
         >:: test_write_best_sexp_round_trips_to_overrides;
         "write_sensitivity_md: per-param section"
         >:: test_write_sensitivity_md_emits_per_param_section;
       ]

let () = run_test_tt_main suite
