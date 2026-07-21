(** Tests for {!Weinstein_strategy.Weekly_sidetable_reader}: the sketch-v5 (PR
    2) read path.

    The load-bearing test is the {b v5-equals-v4 bit-exact equality property}: a
    synthetic multi-symbol fixture is run through the {b real} pipeline twice —
    the v4 dense age-banded columns ([Resistance_sketch.compute_windowed]) and
    the PR-1 weekly side-table ([Weekly_sidetable_builder.of_bars]) — and the
    side-table-derived sketch is asserted bit-identical to the dense-column
    sketch at every side-table week-end date sampled (the dates the strategy
    actually scores at). Coverage folded into the fixtures: partial trailing
    week, deep-fed (>520) tables, the exactly-520 cap boundary, ties at bucket
    edges, close beyond 2x of all supply, and non-positive close guard rows.

    Plus: the [load_gated] manifest-format-hash gate. *)

open OUnit2
open Core
open Matchers
module Reader = Weinstein_strategy.Weekly_sidetable_reader
module Resistance_sketch = Snapshot_pipeline.Resistance_sketch
module Weekly_sidetable_builder = Snapshot_pipeline.Weekly_sidetable_builder
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

let _bar ~date ?(close = 5.0) ?high ?low () =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = Option.value high ~default:(close +. 1.0);
    low_price = Option.value low ~default:(close -. 1.0);
    close_price = close;
    volume = 1_000;
    adjusted_close = close;
    active_through = None;
  }

(* Monday anchor so calendar weeks align with ISO weeks (mirrors
   [test_resistance_sketch.ml]). *)
let _week_start = Date.of_string "2000-01-03"
let _day ~w ~d = Date.add_days _week_start ((7 * w) + d)

(* [n_weeks] Mon-Fri weeks; every bar of a week carries the same (close, high,
   low) so the weekly aggregate equals the override exactly. *)
let _weeks_bars ~n_weeks ~shape =
  List.init n_weeks ~f:(fun w ->
      let close, high, low = shape w in
      List.init 5 ~f:(fun d -> _bar ~date:(_day ~w ~d) ~close ~high ~low ()))
  |> List.concat

(* IEEE-754 bit mismatch count between two sketches (so nan matches nan). *)
let _bits x = Int64.bits_of_float x
let _neq x y = not (Int64.equal (_bits x) (_bits y))

let _sketch_mismatches (a : Resistance_supply.sketch)
    (b : Resistance_supply.sketch) =
  let scalar_mm =
    List.count
      [
        (a.max_high_130w, b.max_high_130w);
        (a.max_high_260w, b.max_high_260w);
        (a.max_high_520w, b.max_high_520w);
        (a.bars_seen, b.bars_seen);
        (a.anchor_close, b.anchor_close);
      ]
      ~f:(fun (x, y) -> _neq x y)
  in
  let band_mm =
    Array.foldi a.hist_bands ~init:0 ~f:(fun bi acc row ->
        Array.foldi row ~init:acc ~f:(fun ki acc2 x ->
            if _neq x b.hist_bands.(bi).(ki) then acc2 + 1 else acc2))
  in
  scalar_mm + band_mm

(* v4 dense-column sketch at window index [i] — reshapes the band-major [hist]
   columns exactly as [Resistance_sketch_reader.read_sketch] does, with the raw
   close as the anchor. *)
let _v4_sketch (cols : Resistance_sketch.t) ~i ~close : Resistance_supply.sketch
    =
  let nb = Snapshot_schema.n_hist_buckets in
  {
    max_high_130w = cols.max_high_130w.(i);
    max_high_260w = cols.max_high_260w.(i);
    max_high_520w = cols.max_high_520w.(i);
    bars_seen = cols.bars_seen.(i);
    hist_bands =
      Array.init Snapshot_schema.n_age_bands ~f:(fun band ->
          Array.init nb ~f:(fun bucket -> cols.hist.((band * nb) + bucket).(i)));
    anchor_close = close;
  }

(* Compare v5 (side-table) vs v4 (dense columns) at every window day whose date
   is a side-table week-end date — the only dates the derivation claims parity
   at. Returns (total mismatches, number of days sampled). *)
let _v5_vs_v4 ~deep ~window =
  let entries = Weekly_sidetable_builder.of_bars ~deep_bars:deep ~bars:window in
  let window_arr = Array.of_list window in
  let cols =
    Resistance_sketch.compute_windowed ~deep_bars:(Array.of_list deep)
      ~bars_arr:window_arr
  in
  let week_ends =
    List.map entries ~f:(fun e -> e.Weekly_sidetable.week_end_date)
    |> Set.of_list (module Date)
  in
  Array.foldi window_arr ~init:(0, 0)
    ~f:(fun i (mm, sampled) (b : Types.Daily_price.t) ->
      if not (Set.mem week_ends b.date) then (mm, sampled)
      else
        let close = b.close_price in
        let v5 = Reader.sketch_of_entries ~entries ~as_of:b.date ~close in
        let v4 = _v4_sketch cols ~i ~close in
        (mm + _sketch_mismatches v5 v4, sampled + 1))

(* Fixture shapes. *)
let _flat _ = (5.0, 6.0, 4.0)

(* Anchor 10; buckets exercised: below-anchor (gated), in-bucket, dropped >2x. *)
let _rich w =
  match w with
  | 5 -> (10.0, 11.0, 10.0) (* mid 10.5 -> in bucket *)
  | 8 -> (10.0, 25.0, 24.0) (* mid 24.5 > 2x -> dropped *)
  | 12 -> (10.0, 10.5, 8.0) (* mid 9.25 < anchor -> dropped *)
  | 20 -> (10.0, 13.0, 12.0) (* mid 12.5 -> in a higher bucket *)
  | _ -> (10.0, 9.0, 8.0)
(* high below anchor -> gated *)

(* Long series with an early spike (ages into band 3) + periodic recent supply. *)
let _deep_long w =
  if w = 3 then (10.0, 30.0, 12.0)
  else if w mod 25 = 0 then (10.0, 11.0, 10.5)
  else (10.0, 9.5, 9.0)

(* Full weeks then a Mon-Wed partial trailing week. *)
let _partial_trailing_bars ~n_full_weeks =
  let full = _weeks_bars ~n_weeks:n_full_weeks ~shape:_rich in
  let partial =
    List.init 3 ~f:(fun d ->
        _bar ~date:(_day ~w:n_full_weeks ~d) ~close:10.0 ~high:11.5 ~low:10.5 ())
  in
  full @ partial

let test_v5_equals_v4_property _ =
  let deep_600 = _weeks_bars ~n_weeks:600 ~shape:_deep_long in
  let deep_arr = Array.of_list deep_600 in
  let split = 5 * 550 in
  let deep = Array.to_list (Array.sub deep_arr ~pos:0 ~len:split) in
  let deep_window =
    Array.to_list
      (Array.sub deep_arr ~pos:split ~len:(Array.length deep_arr - split))
  in
  let fixtures =
    [
      ("flat-131", [], _weeks_bars ~n_weeks:131 ~shape:_flat);
      ("rich-60", [], _weeks_bars ~n_weeks:60 ~shape:_rich);
      ("partial-trailing-40", [], _partial_trailing_bars ~n_full_weeks:40);
      ("deep-fed-600", deep, deep_window);
    ]
  in
  let total_mm, total_sampled =
    List.fold fixtures ~init:(0, 0) ~f:(fun (mm, s) (_name, deep, window) ->
        let m, n = _v5_vs_v4 ~deep ~window in
        (mm + m, s + n))
  in
  assert_that (total_mm, total_sampled)
    (all_of
       [
         field (fun (m, _) -> m) (equal_to 0);
         field (fun (_, s) -> s) (gt (module Int_ord) 200);
       ])

(* Non-positive close guard row: at a week-end whose close is 0, both the v5
   derivation and the v4 columns degrade every cell to NaN (bit-identical). *)
let test_corrupt_close_matches_v4_nan _ =
  let bars =
    _weeks_bars ~n_weeks:10 ~shape:_rich
    @ List.init 5 ~f:(fun d ->
        if d = 4 then
          _bar ~date:(_day ~w:10 ~d) ~close:0.0 ~high:1.0 ~low:0.0 ()
        else _bar ~date:(_day ~w:10 ~d) ~close:10.0 ~high:11.0 ~low:10.0 ())
  in
  let mm, sampled = _v5_vs_v4 ~deep:[] ~window:bars in
  (* The last week's Friday (close 0) is a sampled week-end and is all-NaN in
     both derivations; every other week-end matches too. *)
  assert_that (mm, sampled)
    (all_of
       [
         field (fun (m, _) -> m) (equal_to 0);
         field (fun (_, s) -> s) (gt (module Int_ord) 5);
       ])

(* Direct corrupt-close unit: NaN cells, anchor_close carries the raw close. *)
let test_sketch_of_entries_corrupt_close _ =
  let bars = _weeks_bars ~n_weeks:5 ~shape:_rich in
  let entries = Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars in
  let as_of = _day ~w:4 ~d:4 in
  let s = Reader.sketch_of_entries ~entries ~as_of ~close:0.0 in
  assert_that
    ( Float.is_nan s.max_high_520w,
      Float.is_nan s.bars_seen,
      Float.is_nan s.hist_bands.(0).(0),
      s.anchor_close )
    (all_of
       [
         field (fun (a, _, _, _) -> a) (equal_to true);
         field (fun (_, b, _, _) -> b) (equal_to true);
         field (fun (_, _, c, _) -> c) (equal_to true);
         field (fun (_, _, _, d) -> d) (float_equal 0.0);
       ])

(* Windowing off-by-one at the 130/260/520 horizon boundaries, pinned on a
   directly-constructed entry series (bypassing calendar-week aggregation): the
   130w window is ages 0..129, 260w is 0..259, 520w is 0..519. Spikes at ages
   129 / 130 / 300 must appear in exactly the horizons whose window reaches
   their age. *)
let test_windowing_horizon_boundaries _ =
  let n = 600 in
  let base = Date.of_string "2000-01-03" in
  let high_at age =
    if age = 129 then 100.0
    else if age = 130 then 200.0
    else if age = 300 then 300.0
    else 6.0
  in
  let entries =
    List.init n ~f:(fun i ->
        let age = n - 1 - i in
        {
          Weekly_sidetable.week_end_date = Date.add_days base (7 * i);
          mid = 4.0;
          high = high_at age;
        })
  in
  let as_of = Date.add_days base (7 * (n - 1)) in
  let s = Reader.sketch_of_entries ~entries ~as_of ~close:5.0 in
  assert_that
    (s.max_high_130w, s.max_high_260w, s.max_high_520w)
    (all_of
       [
         (* age 129 in; 130 + 300 out *)
         field (fun (a, _, _) -> a) (float_equal 100.0);
         (* ages 129 + 130 in; 300 out *)
         field (fun (_, b, _) -> b) (float_equal 200.0);
         (* all three in *)
         field (fun (_, _, c) -> c) (float_equal 300.0);
       ])

(* ---- load_gated: manifest-format-hash gate ---- *)

let _sample_entries =
  [
    {
      Weekly_sidetable.week_end_date = Date.of_string "2020-01-03";
      mid = 10.0;
      high = 11.0;
    };
    {
      Weekly_sidetable.week_end_date = Date.of_string "2020-01-10";
      mid = 12.0;
      high = 13.0;
    };
  ]

let _with_temp_dir f =
  let dir =
    Core_unix.mkdtemp (Filename.concat Filename.temp_dir_name "wksidetbl")
  in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      ignore
        (Core_unix.system (Printf.sprintf "rm -rf %s" (Filename.quote dir))
          : Core_unix.Exit_or_signal.t))

let _write_sidetable ~dir ~symbol =
  match
    Weekly_sidetable.write_file
      ~path:(Filename.concat dir (symbol ^ ".weekly"))
      _sample_entries
  with
  | Ok () -> ()
  | Error err -> assert_failure ("write side-table: " ^ Status.show err)

let test_load_gated_match_loads _ =
  _with_temp_dir (fun dir ->
      _write_sidetable ~dir ~symbol:"AAA";
      assert_that
        (Reader.load_gated ~snapshot_dir:dir ~symbol:"AAA"
           ~manifest_format_hash:(Some Weekly_sidetable.format_hash))
        (is_ok_and_holds
           (is_some_and
              (elements_are (List.map _sample_entries ~f:(fun e -> equal_to e))))))

let test_load_gated_hash_mismatch_errors _ =
  _with_temp_dir (fun dir ->
      _write_sidetable ~dir ~symbol:"AAA";
      assert_that
        (Reader.load_gated ~snapshot_dir:dir ~symbol:"AAA"
           ~manifest_format_hash:(Some "not-the-format-hash"))
        is_error)

let test_load_gated_no_hash_none _ =
  _with_temp_dir (fun dir ->
      _write_sidetable ~dir ~symbol:"AAA";
      assert_that
        (Reader.load_gated ~snapshot_dir:dir ~symbol:"AAA"
           ~manifest_format_hash:None)
        (is_ok_and_holds is_none))

let test_load_gated_absent_file_none _ =
  _with_temp_dir (fun dir ->
      assert_that
        (Reader.load_gated ~snapshot_dir:dir ~symbol:"MISSING"
           ~manifest_format_hash:(Some Weekly_sidetable.format_hash))
        (is_ok_and_holds is_none))

let suite =
  "Weekly_sidetable_reader"
  >::: [
         "v5 equals v4 bit-exact property" >:: test_v5_equals_v4_property;
         "corrupt close matches v4 NaN" >:: test_corrupt_close_matches_v4_nan;
         "sketch_of_entries corrupt close"
         >:: test_sketch_of_entries_corrupt_close;
         "windowing horizon boundaries" >:: test_windowing_horizon_boundaries;
         "load_gated match loads" >:: test_load_gated_match_loads;
         "load_gated hash mismatch errors"
         >:: test_load_gated_hash_mismatch_errors;
         "load_gated no hash None" >:: test_load_gated_no_hash_none;
         "load_gated absent file None" >:: test_load_gated_absent_file_none;
       ]

let () = run_test_tt_main suite
