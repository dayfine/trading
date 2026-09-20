(** End-to-end pin for the build-time store-level pass's {b wiring} (#2732 ask
    2, second half).

    {!Snapshot_pipeline.Series_level}'s own rule is already pinned by
    [test_series_level.ml] over the pure core, so what these cases exist for is
    the plumbing that rule had none of until now: that the flag actually reaches
    the detector, that the sidecar actually appears with the right shape, and
    that arming the pass changes nothing else about the warehouse. Modelled on
    [test_build_runner_tail.ml], which pins the sibling tail report the same way
    — a real {!Build_runner.build} over real CSV fixtures, read back from disk.
*)

open Core
open OUnit2
open Matchers
module Series_level = Snapshot_pipeline.Series_level
module Series_tail = Snapshot_pipeline.Series_tail
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

(* 30 consecutive daily bars, comfortably past the default [min_bars] (20). The
   span the reports below quote is therefore 2021-01-04 .. 2021-02-02. *)
let _n_bars = 30
let _series_start = Date.of_string "2021-01-04"

(* AGR's raw close (#2732): above the ceiling on EVERY bar, so there is no seam
   inside the window for either shape rule to key on — the residual class
   [Series_level] exists for, reported as [whole_window]. *)
let _high_close = 73_566.0

(* Two scales in one window: the median clears the ceiling while the low half
   does not, so the seam IS in-window and the row is [mixed_scale]. *)
let _mixed_low_close = 20.0
let _mixed_high_close = 200_000.0

(* An ordinary US equity price: no row at the default ceiling. *)
let _real_close = 50.0
let _all_symbols = [ "HIGH"; "MIXED"; "REAL" ]

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_build_runner_level" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let _bar date close =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume:10_000 ~adjusted_close:close ()

let _series closes =
  List.mapi closes ~f:(fun i close ->
      _bar (Date.add_days _series_start i) close)

let _flat close = _series (List.init _n_bars ~f:(fun _ -> close))

(* The low half comes FIRST so the terminal run is the high segment. A terminal
   run has to close below [Series_tail]'s [max_price] (1.0) to be a stub
   candidate, and the tail pass is on by default, so this ordering is what keeps
   it from editing the fixture and confounding the level rows. *)
let _mixed_series () =
  _series
    (List.init _n_bars ~f:(fun i ->
         if i < _n_bars / 2 then _mixed_low_close else _mixed_high_close))

let _write_csv ~data_dir ~symbol bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> assert_failure ("csv create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e -> assert_failure ("csv save: " ^ Status.show e)
      | Ok () -> ())

let _write_fixtures ~data_dir =
  _write_csv ~data_dir ~symbol:"HIGH" (_flat _high_close);
  _write_csv ~data_dir ~symbol:"MIXED" (_mixed_series ());
  _write_csv ~data_dir ~symbol:"REAL" (_flat _real_close)

let _armed ?(median_close_max = Series_level.Config.default.median_close_max)
    ?(min_bars = Series_level.Config.default.min_bars) () =
  { Series_level.Config.enabled = true; median_close_max; min_bars }

let _build ?level_config ~symbols ~data_dir ~output_dir () =
  Build_runner.build ?level_config ~symbols ~csv_data_dir:data_dir ~output_dir
    ~benchmark_symbol:None ~start_date:None ~end_date:None
    ~sketch_deep_days:Build_runner.default_sketch_deep_days ~incremental:false
    ~progress_every:Build_runner.default_progress_every
    ~tail_config:Series_tail.Config.default
    ~tail_exceptions:Series_tail.Exceptions.empty ()

(* [level_config] omitted entirely is the DEFAULT path — the shape every
   existing caller and every golden invocation takes. *)
let _run_build ?level_config ?(symbols = _all_symbols) f =
  _with_temp_dir (fun dir ->
      let data_dir = Filename.concat dir "csv" in
      let output_dir = Filename.concat dir "snap" in
      Core_unix.mkdir_p data_dir;
      _write_fixtures ~data_dir;
      _build ?level_config ~symbols ~data_dir ~output_dir ();
      f ~output_dir)

let _report_path ~output_dir = Filename.concat output_dir Level_pass.report_name
let _report ~output_dir = In_channel.read_all (_report_path ~output_dir)
let _header_only = Series_level.csv_header ^ "\n"
let _first_line s = List.hd_exn (String.split_lines s)

(* --- flag OFF: no sidecar, and nothing else moves ------------------------- *)

(* An un-armed build leaves NO trace in its output directory. Gating the write on
   the config rather than on "no findings" is what makes this observable: a
   header-only file would be indistinguishable from an armed pass that found
   nothing. *)
let test_unarmed_build_writes_no_sidecar _ =
  _run_build (fun ~output_dir ->
      assert_that
        (Stdlib.Sys.file_exists (_report_path ~output_dir))
        (equal_to false))

let _payload_md5s ~output_dir =
  match
    Snapshot_manifest.read ~path:(Filename.concat output_dir "manifest.sexp")
  with
  | Error e -> assert_failure ("manifest read: " ^ Status.show e)
  | Ok (m : Snapshot_manifest.t) ->
      List.map m.entries ~f:(fun (e : Snapshot_manifest.file_metadata) ->
          (e.symbol, e.payload_md5))
      |> List.sort ~compare:Poly.compare

(* The report-only claim, pinned in both directions: arming the pass over
   fixtures it DOES flag still writes byte-identical [.snap] files. The md5s come
   from the manifest, which checksums the payloads, so a single changed bar in
   any of the three symbols reddens this. *)
let test_arming_does_not_change_the_warehouse _ =
  _with_temp_dir (fun dir ->
      let data_dir = Filename.concat dir "csv" in
      Core_unix.mkdir_p data_dir;
      _write_fixtures ~data_dir;
      let build_into name level_config =
        let output_dir = Filename.concat dir name in
        _build ~level_config ~symbols:_all_symbols ~data_dir ~output_dir ();
        _payload_md5s ~output_dir
      in
      let unarmed = build_into "off" Series_level.Config.default in
      let armed = build_into "on" (_armed ()) in
      assert_that armed
        (equal_to ~msg:"arming the level pass changed a .snap payload" unarmed))

(* --- flag ON: the detector runs and the sidecar carries its rows ---------- *)

let test_armed_build_writes_the_sidecar_header _ =
  _run_build ~level_config:(_armed ()) (fun ~output_dir ->
      assert_that
        (_first_line (_report ~output_dir))
        (equal_to Series_level.csv_header))

(* The row is asserted as a literal rather than re-rendered through
   [Series_level]'s own formatter, so it pins the class, the counts and the
   statistics the detector computed instead of restating its code. *)
let test_armed_build_reports_the_whole_window_symbol _ =
  _run_build ~level_config:(_armed ()) (fun ~output_dir ->
      assert_that (_report ~output_dir)
        (contains_substring
           "HIGH,whole_window,30,2021-01-04,2021-02-02,73566.0000,73566.0000,73566.0000,30"))

(* [100010.0000] is the mean of the two central closes at even length — half the
   bars at 20 and half at 200,000 — which is above the 10,000 ceiling while 15 of
   the 30 closes sit below it: median-above plus [n_above < n_bars] is exactly
   [mixed_scale]. *)
let test_armed_build_sub_classifies_a_mixed_scale_series _ =
  _run_build ~level_config:(_armed ()) (fun ~output_dir ->
      assert_that (_report ~output_dir)
        (contains_substring
           "MIXED,mixed_scale,30,2021-01-04,2021-02-02,100010.0000,20.0000,200000.0000,15"))

let test_plausible_symbol_is_not_reported _ =
  _run_build ~level_config:(_armed ()) (fun ~output_dir ->
      assert_that (_report ~output_dir)
        (not_
           ~msg:"an ordinary 50.00 series should not be a store-level finding"
           (contains_substring "REAL,")))

(* An EMPTY report is an expected outcome, not broken wiring: the [whole_window]
   sub-class is code-level certain but has no instance in any committed
   2026-ending vintage, so the first armed warehouse report may carry no row at
   all. What must still hold is that the file exists and carries the header —
   positive evidence the scan ran. *)
let test_empty_report_is_header_only _ =
  _run_build ~level_config:(_armed ()) ~symbols:[ "REAL" ] (fun ~output_dir ->
      assert_that (_report ~output_dir) (equal_to _header_only))

(* --- the tuning knobs reach the detector too ------------------------------ *)

(* Below the ordinary fixture's own close, so the knob being live is the only
   thing that can produce this row. Asserting a row (rather than its absence)
   keeps a broken flag from passing: dead wiring writes no row either. *)
let _ceiling_below_real_close = 30.0

let test_median_max_flag_is_routed_to_the_detector _ =
  _run_build
    ~level_config:(_armed ~median_close_max:_ceiling_below_real_close ())
    ~symbols:[ "REAL" ] (fun ~output_dir ->
      assert_that (_report ~output_dir)
        (contains_substring "REAL,whole_window,30,"))

(* One more bar than the fixture has, so the series is too short to classify and
   the symbol that otherwise flags drops out of the report. *)
let _min_bars_above_fixture = _n_bars + 1

let test_min_bars_flag_is_routed_to_the_detector _ =
  _run_build ~level_config:(_armed ~min_bars:_min_bars_above_fixture ())
    ~symbols:[ "HIGH" ] (fun ~output_dir ->
      assert_that (_report ~output_dir) (equal_to _header_only))

let suite =
  "build_runner_level"
  >::: [
         "unarmed_build_writes_no_sidecar"
         >:: test_unarmed_build_writes_no_sidecar;
         "arming_does_not_change_the_warehouse"
         >:: test_arming_does_not_change_the_warehouse;
         "armed_build_writes_the_sidecar_header"
         >:: test_armed_build_writes_the_sidecar_header;
         "armed_build_reports_the_whole_window_symbol"
         >:: test_armed_build_reports_the_whole_window_symbol;
         "armed_build_sub_classifies_a_mixed_scale_series"
         >:: test_armed_build_sub_classifies_a_mixed_scale_series;
         "plausible_symbol_is_not_reported"
         >:: test_plausible_symbol_is_not_reported;
         "empty_report_is_header_only" >:: test_empty_report_is_header_only;
         "median_max_flag_is_routed_to_the_detector"
         >:: test_median_max_flag_is_routed_to_the_detector;
         "min_bars_flag_is_routed_to_the_detector"
         >:: test_min_bars_flag_is_routed_to_the_detector;
       ]

let () = run_test_tt_main suite
