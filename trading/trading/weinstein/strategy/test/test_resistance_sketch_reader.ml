(** Direct unit tests for {!Weinstein_strategy.Resistance_sketch_reader}.

    Pins the documented guards ({!Resistance_sketch_reader.read_sketch},
    {!Resistance_sketch_reader.read} three-generation dispatch, and
    {!Resistance_sketch_reader.closure}) that the [Stock_analysis]-layer tests
    bypass by injecting [get_sketch] directly:

    - [read_sketch]: every required cell [Ok] -> [Some] sketch with the read
      field values ([anchor_close] from the raw [Close] column; the age-banded
      histogram reshaped into [n_age_bands] bands of [n_hist_buckets], with the
      v3-width fallback packing the 20 age-blind columns into the youngest
      band); ANY required scalar cell read failing -> [None] — a partial read
      never fabricates a sketch (the read-layer expression of "a window-starved
      warehouse can no longer masquerade as virgin").
    - [read]: a [Some] side-table selects the v5 score-time derivation (anchored
      at the [Close] read); a [None] side-table falls through to the v4/v3
      dense-column path; a failed [Close] read on the v5 path collapses to
      [None].
    - [closure]: a [fun () -> None] thunk when [snapshot_cb] / [stock_symbol] is
      absent or the [stock] view is empty ([n = 0]); the happy path reads at the
      view's last-bar date. *)

open OUnit2
open Core
open Matchers
module Reader = Weinstein_strategy.Resistance_sketch_reader
module Weekly_sidetable_reader = Weinstein_strategy.Weekly_sidetable_reader
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

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
   field)], except any field in [fail_on] returns [Error NotFound]. [hist_width]
   models a warehouse's [Res_hist] column count: reads of [Res_hist k] for
   [k >= hist_width] return [Error] (a v3 warehouse has [hist_width =
   n_hist_buckets], a v4 has [n_hist_cells]). The two remaining closures are
   unused by [read_sketch] and fail loudly if touched. *)
let stub_cb ?(fail_on = []) ?(hist_width = Snapshot_schema.n_hist_cells) () :
    Snapshot_callbacks.t =
  {
    Snapshot_callbacks.read_field =
      (fun ~symbol:_ ~date:_ ~field ->
        let absent =
          match field with
          | Snapshot_schema.Res_hist k -> k >= hist_width
          | _ -> false
        in
        if absent || List.mem fail_on field ~equal:Snapshot_schema.equal_field
        then Status.error_not_found "stub: field forced to fail"
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

(* A tiny side-table with one week above the [Close] anchor (150). *)
let sidetable_entries =
  [
    {
      Weekly_sidetable.week_end_date = Date.of_string "2024-05-31";
      mid = 160.0;
      high = 165.0;
    };
    { Weekly_sidetable.week_end_date = as_of; mid = 152.0; high = 158.0 };
  ]

(* Happy path (v4 warehouse): all 80 cells Ok -> Some sketch whose fields equal
   the stubbed reads. The band-major histogram reshapes into [n_age_bands] bands
   of [n_hist_buckets] each: cell [k] -> band [k / 20], bucket [k mod 20], so
   [hist_bands.(0).(3)] = cell 3 = 3.0 and [hist_bands.(1).(0)] = cell 20 = 20. *)
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
              (fun (s : Resistance_supply.sketch) -> Array.length s.hist_bands)
              (equal_to Snapshot_schema.n_age_bands);
            field
              (fun (s : Resistance_supply.sketch) ->
                Array.length s.hist_bands.(0))
              (equal_to Snapshot_schema.n_hist_buckets);
            field
              (fun (s : Resistance_supply.sketch) -> s.hist_bands.(0).(3))
              (float_equal 3.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.hist_bands.(1).(0))
              (float_equal 20.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.hist_bands.(3).(0))
              (float_equal 60.0);
          ]))

(* v3 back-compat: a warehouse with only the 20 age-blind [Res_hist] columns
   (the trailing v4 cells absent) reads via the width-detection fallback — the
   20 cells pack into the youngest age band, the rest zero. [hist_bands.(0).(3)]
   = cell 3 = 3.0; the older bands are empty (a NaN/absent cell never
   fabricated). This is the "v3-shaped sketch reads with no rebuild" gate. *)
let test_read_sketch_v3_width_packs_youngest_band _ =
  assert_that
    (Reader.read_sketch
       ~cb:(stub_cb ~hist_width:Snapshot_schema.n_hist_buckets ())
       ~symbol:"AAPL" ~as_of)
    (is_some_and
       (all_of
          [
            field
              (fun (s : Resistance_supply.sketch) -> Array.length s.hist_bands)
              (equal_to Snapshot_schema.n_age_bands);
            field
              (fun (s : Resistance_supply.sketch) -> s.hist_bands.(0).(3))
              (float_equal 3.0);
            field
              (fun (s : Resistance_supply.sketch) ->
                Array.count s.hist_bands.(1) ~f:(fun c -> Float.(c <> 0.0)))
              (equal_to 0);
            field
              (fun (s : Resistance_supply.sketch) ->
                Array.count s.hist_bands.(3) ~f:(fun c -> Float.(c <> 0.0)))
              (equal_to 0);
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

(* Dispatch: [Some] side-table selects v5 — the returned sketch equals the pure
   [sketch_of_entries] derivation anchored at the read [Close] (150), NOT the v4
   stub columns (which would give max_high_520w = 220). *)
let test_read_v5_selects_sidetable _ =
  let expected =
    Weekly_sidetable_reader.sketch_of_entries ~entries:sidetable_entries ~as_of
      ~close:150.0
  in
  assert_that
    (Reader.read ~cb:(stub_cb ()) ~symbol:"AAPL" ~as_of
       ~weekly_sidetable:sidetable_entries ())
    (is_some_and
       (all_of
          [
            field
              (fun (s : Resistance_supply.sketch) -> s.max_high_520w)
              (float_equal expected.max_high_520w);
            field
              (fun (s : Resistance_supply.sketch) -> s.bars_seen)
              (float_equal expected.bars_seen);
            field
              (fun (s : Resistance_supply.sketch) -> s.anchor_close)
              (float_equal 150.0);
            (* both weeks (highs 165, 158 > anchor 150) are age < 26 -> band 0 *)
            field
              (fun (s : Resistance_supply.sketch) ->
                Array.sum (module Float) s.hist_bands.(0) ~f:Fn.id)
              (float_equal 2.0);
          ]))

(* Dispatch: [None] side-table falls through to the v4 dense columns
   ([max_high_520w] = the stubbed 220, not a side-table value). *)
let test_read_none_falls_through_to_v4 _ =
  assert_that
    (Reader.read ~cb:(stub_cb ()) ~symbol:"AAPL" ~as_of ())
    (is_some_and
       (field
          (fun (s : Resistance_supply.sketch) -> s.max_high_520w)
          (float_equal 220.0)))

(* [true] iff [f ()] raises [Failure] — the armed loud-fail signature. *)
let raises_failure f =
  try
    ignore (f () : Resistance_supply.sketch option);
    false
  with Failure _ -> true

(* Sketch-v5 PR 4 loud-fail: a thin (13-col) warehouse retired the dense [Res_*]
   columns, so [read_sketch] returns None (modelled by forcing the first sketch
   column absent). With NO side-table AND [armed] AND [sketch_warehouse] (a
   genuine sketch warehouse — manifest advertises side-tables), [read] must RAISE
   rather than silently drop the supply term. *)
let test_read_armed_thin_no_sidetable_raises _ =
  assert_that
    (raises_failure (fun () ->
         Reader.read
           ~cb:(stub_cb ~fail_on:[ Snapshot_schema.Res_max_high_130w ] ())
           ~symbol:"AAPL" ~as_of ~armed:true ~sketch_warehouse:true ()))
    (equal_to true)

(* 2026-07-23 bundle promotion (armed by default): the SAME thin/no-side-table
   situation but NOT a sketch warehouse ([sketch_warehouse = false], the default)
   — an in-process CSV / panel-mode snapshot. Even when [armed], [read] must
   DEGRADE to None (the v1 binary grade) rather than crash; only a genuine sketch
   warehouse must carry a side-table for every scored symbol. *)
let test_read_armed_thin_no_sidetable_csv_degrades _ =
  assert_that
    (Reader.read
       ~cb:(stub_cb ~fail_on:[ Snapshot_schema.Res_max_high_130w ] ())
       ~symbol:"AAPL" ~as_of ~armed:true ())
    is_none

(* Same thin/no-side-table situation but UNARMED: the sketch is never consulted,
   so [read] returns None harmlessly (no raise) regardless of [sketch_warehouse]. *)
let test_read_unarmed_thin_no_sidetable_none _ =
  assert_that
    (Reader.read
       ~cb:(stub_cb ~fail_on:[ Snapshot_schema.Res_max_high_130w ] ())
       ~symbol:"AAPL" ~as_of ~sketch_warehouse:true ())
    is_none

(* Armed but the side-table IS present (the normal v5 case): the v5 path resolves
   the sketch, so no raise. *)
let test_read_armed_with_sidetable_no_raise _ =
  assert_that
    (Reader.read ~cb:(stub_cb ()) ~symbol:"AAPL" ~as_of
       ~weekly_sidetable:sidetable_entries ~armed:true ())
    (is_some_and
       (field
          (fun (s : Resistance_supply.sketch) -> s.anchor_close)
          (float_equal 150.0)))

(* Dispatch: on the v5 path a failed [Close] read collapses to None (the same
   partial-read discipline as read_sketch). *)
let test_read_v5_close_error_none _ =
  assert_that
    (Reader.read
       ~cb:(stub_cb ~fail_on:[ Snapshot_schema.Close ] ())
       ~symbol:"AAPL" ~as_of ~weekly_sidetable:sidetable_entries ())
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

(* closure with a side-table routes the thunk through the v5 path. *)
let test_closure_with_sidetable_uses_v5 _ =
  let thunk =
    Reader.closure ~snapshot_cb:(stub_cb ()) ~stock_symbol:"AAPL"
      ~weekly_sidetable:sidetable_entries ~stock:one_bar_view ()
  in
  let expected =
    Weekly_sidetable_reader.sketch_of_entries ~entries:sidetable_entries ~as_of
      ~close:150.0
  in
  assert_that (thunk ())
    (is_some_and
       (field
          (fun (s : Resistance_supply.sketch) -> s.max_high_520w)
          (float_equal expected.max_high_520w)))

let suite =
  "Resistance_sketch_reader"
  >::: [
         "read_sketch all Ok reads fields (v4)"
         >:: test_read_sketch_all_ok_reads_fields;
         "read_sketch v3 width packs youngest band"
         >:: test_read_sketch_v3_width_packs_youngest_band;
         "read_sketch scalar cell error -> None"
         >:: test_read_sketch_scalar_cell_error_none;
         "read_sketch hist cell error -> None"
         >:: test_read_sketch_hist_cell_error_none;
         "read v5 selects side-table" >:: test_read_v5_selects_sidetable;
         "read None falls through to v4" >:: test_read_none_falls_through_to_v4;
         "read armed + thin + no side-table + sketch warehouse raises"
         >:: test_read_armed_thin_no_sidetable_raises;
         "read armed + thin + no side-table + CSV (not sketch warehouse) -> \
          None" >:: test_read_armed_thin_no_sidetable_csv_degrades;
         "read unarmed + thin + no side-table -> None"
         >:: test_read_unarmed_thin_no_sidetable_none;
         "read armed + side-table present -> no raise"
         >:: test_read_armed_with_sidetable_no_raise;
         "read v5 close error -> None" >:: test_read_v5_close_error_none;
         "closure missing cb -> None" >:: test_closure_missing_cb_none;
         "closure missing symbol -> None" >:: test_closure_missing_symbol_none;
         "closure empty view -> None" >:: test_closure_empty_view_none;
         "closure reads sketch at last bar"
         >:: test_closure_reads_sketch_at_last_bar;
         "closure with side-table uses v5"
         >:: test_closure_with_sidetable_uses_v5;
       ]

let () = run_test_tt_main suite
