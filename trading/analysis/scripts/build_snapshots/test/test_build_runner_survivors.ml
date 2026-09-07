(** End-to-end pin for the survivor-marker derivation (#2693): build a tiny
    warehouse whose [--end-date] deliberately runs {b past} the CSV store's own
    last bar, and check which symbols came back marked.

    That is the exact shape of the defect. The 2026-09-06 rebuild
    ([dev/experiments/warehouse-rebuild-2026-09-06/] §"Run log") passed
    [-end-date 2026-09-06] against a store whose last bar was 2026-08-17, so the
    old rule (["last bar < --end-date"]) stamped [active_through] on
    {b 2,999 of 2,999} symbols — every one of the 778 still-trading names
    included. The reference must be the universe's own last bar, with a small
    tolerance for names the vendor lags by a day or two. *)

open Core
open OUnit2
open Matchers
module Series_tail = Snapshot_pipeline.Series_tail
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

(* Deliberately far past the fixtures' last bar — the #2693 condition. *)
let _cli_end_date = Date.of_string "2026-09-06"

(* The universe's own end: LIVE_END's last bar, the latest any fixture prints. *)
let _universe_end = Date.of_string "2021-12-31"

(* Three calendar days behind the universe — inside the default 7-day
   tolerance, so still trading. *)
let _lagging_end = Date.of_string "2021-12-28"

(* Two years earlier: unambiguously delisted at any tolerance. *)
let _dead_end = Date.of_string "2019-12-31"

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_build_runner_survivors" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let _bar date close =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume:10_000 ~adjusted_close:close ()

(* A flat 5-bar series ending on [last] — flat so the series-tail pass finds
   nothing to truncate and only the marker derivation is under test. *)
let _series ~last =
  List.init 5 ~f:(fun i -> _bar (Date.add_days last (i - 4)) 50.0)

let _write_csv ~data_dir ~symbol bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> failwith ("csv create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e -> failwith ("csv save: " ^ Status.show e)
      | Ok () -> ())

let _symbols = [ "LIVE_END"; "LIVE_LAG"; "DEAD" ]

let _write_fixtures ~data_dir =
  _write_csv ~data_dir ~symbol:"LIVE_END" (_series ~last:_universe_end);
  _write_csv ~data_dir ~symbol:"LIVE_LAG" (_series ~last:_lagging_end);
  _write_csv ~data_dir ~symbol:"DEAD" (_series ~last:_dead_end)

let _build ?survivor_tolerance_days ~data_dir ~output_dir () =
  Build_runner.build ?survivor_tolerance_days ~symbols:_symbols
    ~csv_data_dir:data_dir ~output_dir ~benchmark_symbol:None ~start_date:None
    ~end_date:(Some _cli_end_date)
    ~sketch_deep_days:Build_runner.default_sketch_deep_days ~incremental:false
    ~progress_every:Build_runner.default_progress_every
    ~tail_config:Series_tail.Config.default
    ~tail_exceptions:Series_tail.Exceptions.empty ()

let _manifest_of ~output_dir =
  match
    Snapshot_manifest.read ~path:(Filename.concat output_dir "manifest.sexp")
  with
  | Error e -> failwith ("manifest read: " ^ Status.show e)
  | Ok m -> m

let _panels ~output_dir manifest =
  match
    Snapshot_runtime.Daily_panels.create ~snapshot_dir:output_dir ~manifest
      ~max_cache_mb:8
  with
  | Error e -> failwith ("panels create: " ^ Status.show e)
  | Ok p -> p

(* Markers for [LIVE_END; LIVE_LAG; DEAD], read back through the same runtime
   seam the strategy's entry gate and the simulator's delisted exit use. *)
let _markers ?survivor_tolerance_days () =
  _with_temp_dir (fun dir ->
      let data_dir = Filename.concat dir "csv" in
      let output_dir = Filename.concat dir "snap" in
      Core_unix.mkdir_p data_dir;
      _write_fixtures ~data_dir;
      _build ?survivor_tolerance_days ~data_dir ~output_dir ();
      let panels = _panels ~output_dir (_manifest_of ~output_dir) in
      List.map _symbols ~f:(fun symbol ->
          Snapshot_runtime.Daily_panels.active_through_for panels ~symbol))

let _is_date d = is_some_and (equal_to ~cmp:Date.equal d)

(** At the default tolerance, only the two-years-dead symbol is marked — even
    though [--end-date] is years past every fixture's last bar. Under the
    pre-#2693 rule all three would carry a marker. *)
let test_only_the_ended_series_is_marked _ =
  assert_that (_markers ())
    (elements_are [ is_none; is_none; _is_date _dead_end ])

(** The tolerance is the knob that decides "lagging vendor" vs "delisted": at
    one day, the symbol three days behind the universe is marked too, and it is
    marked at its own last bar. *)
let test_tolerance_narrowed_marks_the_lagging_symbol _ =
  assert_that
    (_markers ~survivor_tolerance_days:1 ())
    (elements_are [ is_none; _is_date _lagging_end; _is_date _dead_end ])

let () =
  run_test_tt_main
    ("build_runner_survivors"
    >::: [
           "only the ended series is marked"
           >:: test_only_the_ended_series_is_marked;
           "a narrowed tolerance marks the lagging symbol"
           >:: test_tolerance_narrowed_marks_the_lagging_symbol;
         ])
