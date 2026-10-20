(** Direct pins for {!Splice_plan}: window edges of [load_windowed_bars], and
    the survivor / cut / sidecar contract of [plan_splices]. *)

open Core
open OUnit2
open Matchers
module Series_splice = Snapshot_pipeline.Series_splice

let _d = Date.of_string
let _first = _d "2020-01-01"
let _n_bars = 400
let _jump_idx = 100
let _jump_date = Date.add_days _first _jump_idx
let _last = Date.add_days _first (_n_bars - 1)

let _bar date close =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume:10_000 ~adjusted_close:close ()

(* Flat at 10, or at 40 from [_jump_idx] on when [spliced] (a x4 step). *)
let _series ~spliced =
  List.init _n_bars ~f:(fun i ->
      let c = if spliced && i >= _jump_idx then 40.0 else 10.0 in
      _bar (Date.add_days _first i) c)

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_splice_plan" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let _write_csv ~data_dir ~symbol bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> failwith ("csv create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e -> failwith ("csv save: " ^ Status.show e)
      | Ok () -> ())

let _setup data_dir =
  _write_csv ~data_dir ~symbol:"SPL" (_series ~spliced:true);
  _write_csv ~data_dir ~symbol:"CLN" (_series ~spliced:false)

let _armed = { Splice_detector.Config.default with enabled = true }

let _plan ?(config = _armed) ?(exceptions = Series_splice.Exceptions.empty)
    ~data_dir ~output_dir symbols =
  Splice_plan.plan_splices ~config ~splice_config:Series_splice.Config.default
    ~exceptions ~data_dir:(Fpath.v data_dir) ~warmup_start:_first
    ~end_date:_last ~output_dir symbols

let _dates bars =
  Option.map bars ~f:(fun a ->
      Array.to_list a |> List.map ~f:(fun (b : Types.Daily_price.t) -> b.date))

let test_window_edges_inclusive _ =
  _with_temp_dir (fun dir ->
      _setup dir;
      let load s e =
        Splice_plan.load_windowed_bars ~data_dir:(Fpath.v dir) ~warmup_start:s
          ~end_date:e "CLN"
        |> _dates
      in
      assert_that
        (load (Date.add_days _first 5) (Date.add_days _first 7))
        (is_some_and
           (equal_to
              [
                Date.add_days _first 5;
                Date.add_days _first 6;
                Date.add_days _first 7;
              ])))

let test_window_empty_or_missing _ =
  _with_temp_dir (fun dir ->
      _setup dir;
      let load symbol s e =
        Splice_plan.load_windowed_bars ~data_dir:(Fpath.v dir) ~warmup_start:s
          ~end_date:e symbol
      in
      assert_that
        ( load "CLN" (_d "2030-01-01") (_d "2030-12-31"),
          load "NOCSV" _first _last )
        (equal_to
           ( (None : Types.Daily_price.t array option),
             (None : Types.Daily_price.t array option) )))

let test_unarmed_is_inert _ =
  _with_temp_dir (fun dir ->
      _setup dir;
      let out = Filename.concat dir "out" in
      let result =
        _plan
          ~config:{ _armed with enabled = false }
          ~data_dir:dir ~output_dir:out [ "SPL"; "CLN" ]
      in
      assert_that
        (fst result, Map.length (snd result), Stdlib.Sys.file_exists out)
        (equal_to ([ "SPL"; "CLN" ], 0, false)))

let test_reuse_is_reported_not_acted_on _ =
  _with_temp_dir (fun dir ->
      _setup dir;
      let out = Filename.concat dir "out" in
      let survivors, cuts =
        _plan ~data_dir:dir ~output_dir:out [ "SPL"; "CLN" ]
      in
      let rows name =
        List.drop (In_channel.read_lines (Filename.concat out name)) 1
      in
      assert_that
        ( survivors,
          Map.length cuts,
          rows "splices.csv",
          rows "splice_actions.csv" )
        (equal_to
           ( [ "SPL"; "CLN" ],
             0,
             [ "SPL,2020-04-10,10.0000,40.0000,4.000,10000,10000" ],
             [ "SPL,reuse,1,2020-04-09,100,300,kept" ] )))

let test_drop_exception_removes_symbol _ =
  _with_temp_dir (fun dir ->
      _setup dir;
      let exceptions =
        Series_splice.Exceptions.of_rules
          [ Series_splice.Exceptions.Drop "SPL" ]
      in
      let survivors, _ =
        _plan ~exceptions ~data_dir:dir
          ~output_dir:(Filename.concat dir "out")
          [ "CLN"; "SPL"; "NOCSV" ]
      in
      assert_that survivors (equal_to [ "CLN"; "NOCSV" ]))

let test_cut_exception_yields_cut_plan _ =
  _with_temp_dir (fun dir ->
      _setup dir;
      let exceptions =
        Series_splice.Exceptions.of_rules
          [ Series_splice.Exceptions.Cut_at ("SPL", _jump_date) ]
      in
      let survivors, cuts =
        _plan ~exceptions ~data_dir:dir
          ~output_dir:(Filename.concat dir "out")
          [ "SPL"; "CLN" ]
      in
      assert_that
        (survivors, Map.to_alist cuts)
        (equal_to ([ "SPL"; "CLN" ], [ ("SPL", _jump_date) ])))

let test_sidecars_written_for_clean_input _ =
  _with_temp_dir (fun dir ->
      _setup dir;
      let out = Filename.concat dir "out" in
      let _ = _plan ~data_dir:dir ~output_dir:out [ "CLN" ] in
      assert_that
        (In_channel.read_lines (Filename.concat out "splice_actions.csv")
        |> List.hd_exn)
        (equal_to Series_splice.csv_header))

let suite =
  "splice_plan"
  >::: [
         "window edges inclusive" >:: test_window_edges_inclusive;
         "window empty or missing" >:: test_window_empty_or_missing;
         "unarmed is inert" >:: test_unarmed_is_inert;
         "reuse reported, not acted on" >:: test_reuse_is_reported_not_acted_on;
         "drop exception removes symbol" >:: test_drop_exception_removes_symbol;
         "cut exception yields cut plan" >:: test_cut_exception_yields_cut_plan;
         "sidecars written for clean input"
         >:: test_sidecars_written_for_clean_input;
       ]

let () = run_test_tt_main suite
