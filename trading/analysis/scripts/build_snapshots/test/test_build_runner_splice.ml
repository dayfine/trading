(** End-to-end pin for the build-time splice cut (#2672 class ii): a cut symbol
    must lose the earlier issuer's bars from {b both} halves of what the
    warehouse stores.

    The [.snap] half is the obvious one. The half this test exists for is the
    [SYMBOL.weekly] side-table, which [Weekly_sidetable_builder.of_bars] builds
    over [deep_bars @ bars] — up to ten years of history loaded from {e before}
    the build window to widen the resistance prefix. A cut date is inside the
    window, so for a cut symbol the whole deep prefix is the previous company's;
    leaving it uncut would keep the side-table (the reader's only
    overhead-supply source) describing two issuers while the [.snap] describes
    one. *)

open Core
open OUnit2
open Matchers
module Series_tail = Snapshot_pipeline.Series_tail
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

(* The window starts here; [CHS]'s series starts three years earlier, so the
   deep-history slice is non-empty and entirely pre-cut. *)
let _start_date = Date.of_string "2004-01-05"
let _end_date = Date.of_string "2004-12-31"
let _series_start = Date.of_string "2001-01-01"
let _cut_date = Date.of_string "2004-06-01"

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_build_runner_splice" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let _bar date close =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume:10_000 ~adjusted_close:close ()

(* One bar per week from [_series_start] through [_end_date]. The earlier
   issuer prints near $10 and the later one near $40 — the x3.9 jump CHS
   actually shows (#2646) — so a leaked deep bar is visible in the side-table's
   highs as well as in its dates. *)
let _weekly_series () =
  let rec build date acc =
    if Date.( > ) date _end_date then List.rev acc
    else
      let close = if Date.( < ) date _cut_date then 10.0 else 40.0 in
      build (Date.add_days date 7) (_bar date close :: acc)
  in
  build _series_start []

let _write_csv ~data_dir ~symbol bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> assert_failure ("csv create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e -> assert_failure ("csv save: " ^ Status.show e)
      | Ok () -> ())

let _build ~splice_cuts ~data_dir ~output_dir =
  Build_runner.build ~splice_cuts ~symbols:[ "CHS" ] ~csv_data_dir:data_dir
    ~output_dir ~benchmark_symbol:None ~start_date:(Some _start_date)
    ~end_date:(Some _end_date)
    ~sketch_deep_days:Build_runner.default_sketch_deep_days ~incremental:false
    ~progress_every:Build_runner.default_progress_every
    ~tail_config:Series_tail.Config.default
    ~tail_exceptions:Series_tail.Exceptions.empty ()

let _run ~splice_cuts f =
  _with_temp_dir (fun dir ->
      let data_dir = Filename.concat dir "csv" in
      let output_dir = Filename.concat dir "snap" in
      Core_unix.mkdir_p data_dir;
      _write_csv ~data_dir ~symbol:"CHS" (_weekly_series ());
      _build ~splice_cuts ~data_dir ~output_dir;
      f ~output_dir)

let _weekly_entries ~output_dir =
  match
    Weekly_sidetable.read_file ~path:(Filename.concat output_dir "CHS.weekly")
  with
  | Error e -> assert_failure ("weekly side-table read: " ^ Status.show e)
  | Ok entries -> entries

let _cut_plan = Map.singleton (module String) "CHS" _cut_date
let _no_cuts = Map.empty (module String)

(* Weekly entries strictly before the cut, and their highs. Zero of both is the
   claim; the highs make a leak legible (the earlier issuer prints at 10.0). *)
let _pre_cut_entries ~output_dir =
  List.filter (_weekly_entries ~output_dir)
    ~f:(fun (e : Weekly_sidetable.entry) ->
      Date.( < ) e.week_end_date _cut_date)

(* The control: without a cut, the deep prefix IS in the side-table. Without
   this arm the assertion below would also pass if [deep_bars] never reached
   the side-table at all. *)
let test_uncut_symbol_keeps_its_deep_prefix _ =
  _run ~splice_cuts:_no_cuts (fun ~output_dir ->
      assert_that
        (List.length (_pre_cut_entries ~output_dir))
        (gt (module Int_ord) 0))

let test_cut_symbol_has_no_weekly_entry_before_the_cut _ =
  _run ~splice_cuts:_cut_plan (fun ~output_dir ->
      assert_that (_pre_cut_entries ~output_dir) is_empty)

let _weekly_highs ~output_dir =
  List.map (_weekly_entries ~output_dir) ~f:(fun (e : Weekly_sidetable.entry) ->
      e.high)

(* The side-table is not merely trimmed to the window: every surviving entry
   carries the LATER issuer's price level, so no earlier-issuer bar leaked in
   under a post-cut week-end date either. *)
let test_cut_symbol_weekly_highs_are_all_the_later_issuer _ =
  _run ~splice_cuts:_cut_plan (fun ~output_dir ->
      assert_that (_weekly_highs ~output_dir) (each (float_equal 40.0)))

let suite =
  "build_runner_splice"
  >::: [
         "uncut_symbol_keeps_its_deep_prefix"
         >:: test_uncut_symbol_keeps_its_deep_prefix;
         "cut_symbol_has_no_weekly_entry_before_the_cut"
         >:: test_cut_symbol_has_no_weekly_entry_before_the_cut;
         "cut_symbol_weekly_highs_are_all_the_later_issuer"
         >:: test_cut_symbol_weekly_highs_are_all_the_later_issuer;
       ]

let () = run_test_tt_main suite
