open Core
open OUnit2
open Matchers
module Sweep = Barbell.Barbell_floor_sweep
module Config = Barbell.Barbell_config
module Blend = Barbell.Barbell_blend

let make_axis ?(rebalance_weeks = 1) floor_weights : Sweep.axis =
  { floor_weights; rebalance_weeks }

(* cells expands one cell per weight, sorted ascending, each carrying the
   resolved enable=true config at the axis's shared cadence. *)
let test_cells_one_per_weight_ascending _ =
  let cells = Sweep.cells (make_axis ~rebalance_weeks:4 [ 0.40; 0.20; 0.30 ]) in
  let weight (c : Sweep.cell) = c.config.Config.floor_weight in
  assert_that cells
    (elements_are
       [
         all_of
           [
             field
               (fun (c : Sweep.cell) -> c.label)
               (equal_to "floor_weight=0.20");
             field
               (fun (c : Sweep.cell) -> c.config.Config.enable)
               (equal_to true);
             field weight (float_equal 0.20);
             field
               (fun (c : Sweep.cell) -> c.config.Config.rebalance_weeks)
               (equal_to 4);
           ];
         all_of
           [
             field
               (fun (c : Sweep.cell) -> c.label)
               (equal_to "floor_weight=0.30");
             field weight (float_equal 0.30);
           ];
         all_of
           [
             field
               (fun (c : Sweep.cell) -> c.label)
               (equal_to "floor_weight=0.40");
             field weight (float_equal 0.40);
           ];
       ])

(* The default weight 0.0 (pure-engine no-op) is a valid cell — enumerating it
   flips no default, it is just a searchable point. *)
let test_zero_weight_cell_is_valid _ =
  let cells = Sweep.cells (make_axis [ 0.0; 0.5 ]) in
  assert_that cells
    (elements_are
       [
         all_of
           [
             field
               (fun (c : Sweep.cell) -> c.config.Config.floor_weight)
               (float_equal 0.0);
             field
               (fun (c : Sweep.cell) -> Result.is_ok (Config.validate c.config))
               (equal_to true);
           ];
         field
           (fun (c : Sweep.cell) -> c.config.Config.floor_weight)
           (float_equal 0.5);
       ])

(* cells raises Invalid_argument on a malformed axis (mirrors
   Variant_matrix.expand raising loudly rather than yielding a degenerate cell);
   we assert the raise via Result.try_with -> is_error as a bool. *)
let raises_invalid f =
  Result.is_error (Result.try_with (fun () -> ignore (f () : Sweep.cell list)))

let test_empty_axis_rejected _ =
  assert_that
    (raises_invalid (fun () -> Sweep.cells (make_axis [])))
    (equal_to true)

let test_duplicate_weight_rejected _ =
  assert_that
    (raises_invalid (fun () -> Sweep.cells (make_axis [ 0.3; 0.5; 0.3 ])))
    (equal_to true)

let test_out_of_range_weight_rejected _ =
  assert_that
    (raises_invalid (fun () -> Sweep.cells (make_axis [ 0.3; 1.5 ])))
    (equal_to true)

let test_zero_rebalance_weeks_rejected _ =
  assert_that
    (raises_invalid (fun () ->
         Sweep.cells (make_axis ~rebalance_weeks:0 [ 0.3 ])))
    (equal_to true)

(* A deterministic stub metrics whose total_return encodes the weight, so we can
   assert the table evaluates each cell's config in ascending-weight order. *)
let stub_metrics_of_weight (config : Config.t) : Blend.metrics =
  {
    total_return_pct = config.floor_weight *. 100.0;
    sharpe = 0.0;
    max_drawdown_pct = 0.0;
    calmar = 0.0;
    ulcer_pct = 0.0;
    n_points = 1;
  }

(* metrics_table returns one row per cell, ascending, threading each cell's
   config through the blend thunk. *)
let test_metrics_table_one_row_per_cell _ =
  let table =
    Sweep.metrics_table (make_axis [ 0.5; 0.2 ]) ~blend:stub_metrics_of_weight
  in
  assert_that table
    (elements_are
       [
         all_of
           [
             field
               (fun (r : Sweep.row) -> r.label)
               (equal_to "floor_weight=0.20");
             field (fun (r : Sweep.row) -> r.floor_weight) (float_equal 0.20);
             field
               (fun (r : Sweep.row) -> r.metrics.Blend.total_return_pct)
               (float_equal 20.0);
           ];
         all_of
           [
             field
               (fun (r : Sweep.row) -> r.label)
               (equal_to "floor_weight=0.50");
             field (fun (r : Sweep.row) -> r.floor_weight) (float_equal 0.50);
             field
               (fun (r : Sweep.row) -> r.metrics.Blend.total_return_pct)
               (float_equal 50.0);
           ];
       ])

let suite =
  "barbell_floor_sweep"
  >::: [
         "cells_one_per_weight_ascending"
         >:: test_cells_one_per_weight_ascending;
         "zero_weight_cell_is_valid" >:: test_zero_weight_cell_is_valid;
         "empty_axis_rejected" >:: test_empty_axis_rejected;
         "duplicate_weight_rejected" >:: test_duplicate_weight_rejected;
         "out_of_range_weight_rejected" >:: test_out_of_range_weight_rejected;
         "zero_rebalance_weeks_rejected" >:: test_zero_rebalance_weeks_rejected;
         "metrics_table_one_row_per_cell"
         >:: test_metrics_table_one_row_per_cell;
       ]

let () = run_test_tt_main suite
