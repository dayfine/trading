(** Direct unit tests for {!Weinstein_strategy.Resistance_sketch_reader}.

    Pins the two documented guards ({!Resistance_sketch_reader.read_sketch} and
    {!Resistance_sketch_reader.closure}) that the [Stock_analysis]-layer tests
    bypass by injecting [get_sketch] directly:

    - [read_sketch]: every required cell [Ok] -> [Some] sketch with the read
      field values ([anchor_close] from the raw [Close] column; [hist] length
      [= Snapshot_schema.n_hist_buckets]); ANY required cell read failing
      (scalar or a histogram bucket via [Option.all]) -> [None] — a partial read
      never fabricates a sketch (the read-layer expression of "a window-starved
      warehouse can no longer masquerade as virgin").
    - [closure]: a [fun () -> None] thunk when [snapshot_cb] / [stock_symbol] is
      absent or the [stock] view is empty ([n = 0]); the happy path reads at the
      view's last-bar date. *)

open OUnit2
open Core
open Matchers
module Reader = Weinstein_strategy.Resistance_sketch_reader
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

let as_of = Date.of_string "2024-06-07"

(* Stubbed scalar for each sketch cell. [Res_hist k] maps to [Float.of_int k] so
   the reconstructed histogram array is index-identifiable in assertions. *)
let stub_value : Snapshot_schema.field -> float = function
  | Snapshot_schema.Res_max_high_130w -> 200.0
  | Snapshot_schema.Res_max_high_260w -> 210.0
  | Snapshot_schema.Res_max_high_520w -> 220.0
  | Snapshot_schema.Res_bars_seen -> 300.0
  | Snapshot_schema.Close -> 150.0
  | Snapshot_schema.Res_hist k -> Float.of_int k
  | _ -> 0.0

(* A stub [Snapshot_callbacks.t] whose [read_field] returns [Ok (stub_value
   field)], except any field in [fail_on] returns [Error NotFound]. The two
   remaining closures are unused by [read_sketch] and fail loudly if touched. *)
let stub_cb ?(fail_on = []) () : Snapshot_callbacks.t =
  {
    Snapshot_callbacks.read_field =
      (fun ~symbol:_ ~date:_ ~field ->
        if List.mem fail_on field ~equal:Snapshot_schema.equal_field then
          Status.error_not_found "stub: field forced to fail"
        else Ok (stub_value field));
    read_field_history =
      (fun ~symbol:_ ~from:_ ~until:_ ~field:_ ->
        failwith "read_field_history: not used by read_sketch");
    active_through_for = (fun ~symbol:_ -> None);
  }

let one_bar_view : Snapshot_bar_views.weekly_view =
  {
    closes = [| 150.0 |];
    raw_closes = [| 150.0 |];
    highs = [| 155.0 |];
    lows = [| 145.0 |];
    volumes = [| 1000.0 |];
    dates = [| as_of |];
    n = 1;
  }

let empty_view : Snapshot_bar_views.weekly_view =
  {
    closes = [||];
    raw_closes = [||];
    highs = [||];
    lows = [||];
    volumes = [||];
    dates = [||];
    n = 0;
  }

(* Happy path: all cells Ok -> Some sketch whose fields equal the stubbed reads,
   incl. anchor_close from the raw Close column and hist length = n_hist_buckets. *)
let test_read_sketch_all_ok_reads_fields _ =
  assert_that
    (Reader.read_sketch ~cb:(stub_cb ()) ~symbol:"AAPL" ~as_of)
    (is_some_and
       (all_of
          [
            field
              (fun (s : Resistance_supply.sketch) -> s.max_high_130w)
              (float_equal 200.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.max_high_260w)
              (float_equal 210.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.max_high_520w)
              (float_equal 220.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.bars_seen)
              (float_equal 300.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.anchor_close)
              (float_equal 150.0);
            field
              (fun (s : Resistance_supply.sketch) -> Array.length s.hist)
              (equal_to Snapshot_schema.n_hist_buckets);
            field
              (fun (s : Resistance_supply.sketch) -> s.hist.(3))
              (float_equal 3.0);
          ]))

(* A failing scalar cell collapses the whole read to None. *)
let test_read_sketch_scalar_cell_error_none _ =
  assert_that
    (Reader.read_sketch
       ~cb:(stub_cb ~fail_on:[ Snapshot_schema.Res_bars_seen ] ())
       ~symbol:"AAPL" ~as_of)
    is_none

(* A failing histogram bucket collapses the read via Option.all -> None. *)
let test_read_sketch_hist_cell_error_none _ =
  assert_that
    (Reader.read_sketch
       ~cb:(stub_cb ~fail_on:[ Snapshot_schema.Res_hist 7 ] ())
       ~symbol:"AAPL" ~as_of)
    is_none

(* closure with no snapshot_cb -> None thunk. *)
let test_closure_missing_cb_none _ =
  let thunk = Reader.closure ~stock_symbol:"AAPL" ~stock:one_bar_view () in
  assert_that (thunk ()) is_none

(* closure with no stock_symbol -> None thunk. *)
let test_closure_missing_symbol_none _ =
  let thunk = Reader.closure ~snapshot_cb:(stub_cb ()) ~stock:one_bar_view () in
  assert_that (thunk ()) is_none

(* closure over an empty (n = 0) stock view -> None thunk. *)
let test_closure_empty_view_none _ =
  let thunk =
    Reader.closure ~snapshot_cb:(stub_cb ()) ~stock_symbol:"AAPL"
      ~stock:empty_view ()
  in
  assert_that (thunk ()) is_none

(* Happy path: cb + symbol + non-empty view -> thunk reads Some sketch at the
   view's last-bar date (anchor_close from the Close column). *)
let test_closure_reads_sketch_at_last_bar _ =
  let thunk =
    Reader.closure ~snapshot_cb:(stub_cb ()) ~stock_symbol:"AAPL"
      ~stock:one_bar_view ()
  in
  assert_that (thunk ())
    (is_some_and
       (field
          (fun (s : Resistance_supply.sketch) -> s.anchor_close)
          (float_equal 150.0)))

let suite =
  "Resistance_sketch_reader"
  >::: [
         "read_sketch all Ok reads fields"
         >:: test_read_sketch_all_ok_reads_fields;
         "read_sketch scalar cell error -> None"
         >:: test_read_sketch_scalar_cell_error_none;
         "read_sketch hist cell error -> None"
         >:: test_read_sketch_hist_cell_error_none;
         "closure missing cb -> None" >:: test_closure_missing_cb_none;
         "closure missing symbol -> None" >:: test_closure_missing_symbol_none;
         "closure empty view -> None" >:: test_closure_empty_view_none;
         "closure reads sketch at last bar"
         >:: test_closure_reads_sketch_at_last_bar;
       ]

let () = run_test_tt_main suite
