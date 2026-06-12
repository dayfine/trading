open Core
open OUnit2
open Matchers
module CV = Universe.Cross_validation
module Snapshot = Universe.Snapshot
module SC = Shiller.Shiller_client
module Runner = Cross_validation_runner_lib

(* --------------------------------------------------------------------- *)
(* Fixture builders                                                       *)
(* --------------------------------------------------------------------- *)

let _make_tmp_dir suffix =
  let dir = Stdlib.Filename.temp_file "cv_test_" ("_" ^ suffix ^ ".d") in
  (try Stdlib.Sys.remove dir with _ -> ());
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir))
      : int);
  dir

let _cleanup_dir dir =
  ignore
    (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote dir)) : int)

let _write_composition_golden ~dir ~size ~year ~aggregate_period_return =
  let snapshot : Snapshot.t =
    {
      date = Date.create_exn ~y:year ~m:Month.May ~d:31;
      method_ = Composition_from_individuals;
      size;
      entries =
        [
          {
            Snapshot.symbol = "FAKE";
            weight = 1.0;
            sector = "Test";
            synthetic = false;
            avg_dollar_volume = None;
          };
        ];
      aggregate_period_return;
    }
  in
  let path = Filename.concat dir (Printf.sprintf "top-%d-%d.sexp" size year) in
  match Snapshot.save snapshot ~path with
  | Ok () -> ()
  | Error err -> failwith ("write fixture failed: " ^ Status.show err)

(* Build a 13-month Shiller window covering year-05-31 → (year+1)-05-31 with
   a linear price ramp and no dividends. The window is anchored at the 1st
   of the month so the May-31 → June-1 to (year+1)-May-1 → (year+1)-May-30
   slice is exactly 13 observations (June..next-May inclusive of June +
   exclusive of next-June, plus the May-1 row of the start year is dropped
   because [(year, May, 1) < (year, May, 31)]). *)
let _shiller_window_for_year ~year ~p_start ~p_end : SC.monthly_observation list
    =
  let months =
    [
      (year, Month.Jun);
      (year, Month.Jul);
      (year, Month.Aug);
      (year, Month.Sep);
      (year, Month.Oct);
      (year, Month.Nov);
      (year, Month.Dec);
      (year + 1, Month.Jan);
      (year + 1, Month.Feb);
      (year + 1, Month.Mar);
      (year + 1, Month.Apr);
      (year + 1, Month.May);
    ]
  in
  let n = List.length months in
  List.mapi months ~f:(fun i (y, m) ->
      let frac = Float.of_int i /. Float.of_int (n - 1) in
      let price = p_start +. ((p_end -. p_start) *. frac) in
      {
        SC.period = Date.create_exn ~y ~m ~d:1;
        sp_price = price;
        dividend = None;
        earnings = None;
        cpi = None;
        long_rate = None;
      })

let _shiller_obs_for_years pairs =
  List.concat_map pairs ~f:(fun (year, p_start, p_end) ->
      _shiller_window_for_year ~year ~p_start ~p_end)

(* --------------------------------------------------------------------- *)
(* End-to-end with tiny fixture                                            *)
(* --------------------------------------------------------------------- *)

let test_end_to_end_two_years _ =
  let dir = _make_tmp_dir "e2e" in
  (* Year 1990: comp = +0.20, shiller = +0.10 → drift = +0.10
     Year 1991: comp = -0.05, shiller = +0.20 → drift = -0.25 *)
  _write_composition_golden ~dir ~size:500 ~year:1990
    ~aggregate_period_return:0.20;
  _write_composition_golden ~dir ~size:500 ~year:1991
    ~aggregate_period_return:(-0.05);
  let shiller_obs =
    _shiller_obs_for_years [ (1990, 100.0, 110.0); (1991, 200.0, 240.0) ]
  in
  let result =
    CV.compute ~composition_dir:dir ~shiller_obs ~size:500 ~start_year:1990
      ~end_year:1991
  in
  _cleanup_dir dir;
  assert_that result
    (is_ok_and_holds
       (field
          (fun r -> r.CV.cells)
          (elements_are
             [
               all_of
                 [
                   field (fun c -> c.CV.year) (equal_to 1990);
                   field (fun c -> c.CV.composition_return) (float_equal 0.20);
                   field (fun c -> c.CV.shiller_return) (float_equal 0.10);
                   field (fun c -> c.CV.drift) (float_equal 0.10);
                 ];
               all_of
                 [
                   field (fun c -> c.CV.year) (equal_to 1991);
                   field
                     (fun c -> c.CV.composition_return)
                     (float_equal (-0.05));
                   field (fun c -> c.CV.shiller_return) (float_equal 0.20);
                   field (fun c -> c.CV.drift) (float_equal (-0.25));
                 ];
             ])))

(* --------------------------------------------------------------------- *)
(* Missing-year skip                                                       *)
(* --------------------------------------------------------------------- *)

let test_missing_composition_year_skipped _ =
  let dir = _make_tmp_dir "missing_comp" in
  (* Composition golden for 1990 only; Shiller for both 1990 and 1991. *)
  _write_composition_golden ~dir ~size:500 ~year:1990
    ~aggregate_period_return:0.15;
  let shiller_obs =
    _shiller_obs_for_years [ (1990, 100.0, 110.0); (1991, 200.0, 240.0) ]
  in
  let result =
    CV.compute ~composition_dir:dir ~shiller_obs ~size:500 ~start_year:1990
      ~end_year:1991
  in
  _cleanup_dir dir;
  assert_that result
    (is_ok_and_holds
       (field
          (fun r -> r.CV.cells)
          (elements_are
             [
               all_of
                 [
                   field (fun c -> c.CV.year) (equal_to 1990);
                   field (fun c -> c.CV.composition_return) (float_equal 0.15);
                 ];
             ])))

let test_missing_shiller_window_skipped _ =
  let dir = _make_tmp_dir "missing_shi" in
  (* Composition golden for both years; Shiller only for 1990 — so 1991 is
     skipped because the window has zero observations. *)
  _write_composition_golden ~dir ~size:500 ~year:1990
    ~aggregate_period_return:0.20;
  _write_composition_golden ~dir ~size:500 ~year:1991
    ~aggregate_period_return:(-0.05);
  let shiller_obs = _shiller_obs_for_years [ (1990, 100.0, 110.0) ] in
  let result =
    CV.compute ~composition_dir:dir ~shiller_obs ~size:500 ~start_year:1990
      ~end_year:1991
  in
  _cleanup_dir dir;
  assert_that result
    (is_ok_and_holds
       (field
          (fun r -> r.CV.cells)
          (elements_are
             [
               all_of
                 [
                   field (fun c -> c.CV.year) (equal_to 1990);
                   field (fun c -> c.CV.shiller_return) (float_equal 0.10);
                 ];
             ])))

(* --------------------------------------------------------------------- *)
(* Statistics (mean / median / max-abs / worst-year)                       *)
(* --------------------------------------------------------------------- *)

let test_statistics_three_cells _ =
  let dir = _make_tmp_dir "stats" in
  (* drifts: 1990 → +0.10, 1991 → -0.25, 1992 → +0.05
     mean = (0.10 - 0.25 + 0.05) / 3 = -0.10/3 = -0.0333...
     sorted abs-drifts: 0.05, 0.10, 0.25 → median raw = -0.25? no,
     median is of raw drifts: sorted raw = -0.25, 0.05, 0.10 → 0.05
     max_abs_drift = 0.25, worst_year = 1991 *)
  _write_composition_golden ~dir ~size:500 ~year:1990
    ~aggregate_period_return:0.20;
  _write_composition_golden ~dir ~size:500 ~year:1991
    ~aggregate_period_return:(-0.05);
  _write_composition_golden ~dir ~size:500 ~year:1992
    ~aggregate_period_return:0.55;
  let shiller_obs =
    _shiller_obs_for_years
      [
        (1990, 100.0, 110.0);
        (* 0.10 *)
        (1991, 200.0, 240.0);
        (* 0.20 *)
        (1992, 100.0, 150.0);
        (* 0.50 *)
      ]
  in
  let result =
    CV.compute ~composition_dir:dir ~shiller_obs ~size:500 ~start_year:1990
      ~end_year:1992
  in
  _cleanup_dir dir;
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun r -> r.CV.mean_drift)
              (float_equal ~epsilon:1e-9 (-0.10 /. 3.0));
            field (fun r -> r.CV.median_drift) (float_equal 0.05);
            field (fun r -> r.CV.max_abs_drift) (float_equal 0.25);
            field (fun r -> r.CV.worst_year) (equal_to 1991);
          ]))

(* --------------------------------------------------------------------- *)
(* Markdown formatter                                                      *)
(* --------------------------------------------------------------------- *)

let _markdown_contains body needle = String.is_substring body ~substring:needle

let test_markdown_formatter_has_header_and_rows _ =
  let dir = _make_tmp_dir "md" in
  _write_composition_golden ~dir ~size:500 ~year:1990
    ~aggregate_period_return:0.20;
  _write_composition_golden ~dir ~size:500 ~year:1991
    ~aggregate_period_return:(-0.05);
  let shiller_obs =
    _shiller_obs_for_years [ (1990, 100.0, 110.0); (1991, 200.0, 240.0) ]
  in
  let result =
    CV.compute ~composition_dir:dir ~shiller_obs ~size:500 ~start_year:1990
      ~end_year:1991
  in
  _cleanup_dir dir;
  let md_of_report report = CV.format_markdown report in
  let needles =
    [
      "# Cross-validation: composition vs Shiller";
      "## Summary";
      "## Per-year drift";
      "| Year | Composition | Shiller | Drift |";
      "| 1990 |";
      "| 1991 |";
    ]
  in
  assert_that result
    (is_ok_and_holds
       (matching ~msg:"markdown contains all expected substrings"
          (fun report ->
            let md = md_of_report report in
            Some (List.map needles ~f:(_markdown_contains md)))
          (elements_are
             [
               equal_to true;
               equal_to true;
               equal_to true;
               equal_to true;
               equal_to true;
               equal_to true;
             ])))

(* --------------------------------------------------------------------- *)
(* Sexp round-trip                                                         *)
(* --------------------------------------------------------------------- *)

(* Save [report] to a fresh file, load it back, return [(loaded, original)]
   so the caller can compose a single [assert_that] over both. Returns
   [None] on any I/O failure so the matcher tree surfaces that as a clean
   test failure rather than a stack trace from [Sexp.load_sexp]. *)
let _round_trip_sexp report ~path : (CV.report * CV.report) option =
  match CV.save_sexp report ~path with
  | Error _ -> None
  | Ok () -> (
      match Sexp.load_sexp path with
      | sexp -> Some (CV.report_of_sexp sexp, report)
      | exception _ -> None)

let test_sexp_round_trip _ =
  let dir = _make_tmp_dir "sexp" in
  _write_composition_golden ~dir ~size:500 ~year:1990
    ~aggregate_period_return:0.20;
  _write_composition_golden ~dir ~size:500 ~year:1991
    ~aggregate_period_return:(-0.05);
  let shiller_obs =
    _shiller_obs_for_years [ (1990, 100.0, 110.0); (1991, 200.0, 240.0) ]
  in
  let path = Filename.concat dir "report.sexp" in
  let result =
    CV.compute ~composition_dir:dir ~shiller_obs ~size:500 ~start_year:1990
      ~end_year:1991
  in
  let round_tripped =
    Result.map result ~f:(fun report -> _round_trip_sexp report ~path)
  in
  _cleanup_dir dir;
  assert_that round_tripped
    (is_ok_and_holds
       (is_some_and
          (matching ~msg:"round-tripped report equals original"
             (fun (loaded, original) ->
               if CV.equal_report loaded original then Some () else None)
             (equal_to ()))))

(* --------------------------------------------------------------------- *)
(* Runner — end-to-end through the CSV parser + file writes                *)
(* --------------------------------------------------------------------- *)

let _make_shiller_cache_csv obs =
  let header = "period,sp_price,dividend,earnings,cpi,long_rate" in
  let body_row (o : SC.monthly_observation) =
    Printf.sprintf "%s,%s,,,," (Date.to_string o.period)
      (Float.to_string o.sp_price)
  in
  String.concat ~sep:"\n" (header :: List.map obs ~f:body_row)

let test_runner_writes_sexp_and_markdown _ =
  let dir = _make_tmp_dir "runner" in
  _write_composition_golden ~dir ~size:500 ~year:1990
    ~aggregate_period_return:0.20;
  let shiller_obs =
    _shiller_window_for_year ~year:1990 ~p_start:100.0 ~p_end:110.0
  in
  let csv = _make_shiller_cache_csv shiller_obs in
  let out_sexp = Filename.concat dir "report.sexp" in
  let out_md = Filename.concat dir "report.md" in
  let result =
    Runner.run ~composition_dir:dir ~shiller_cache_body:csv ~size:500
      ~start_year:1990 ~end_year:1990 ~out_sexp_path:out_sexp
      ~out_markdown_path:out_md
  in
  let sexp_exists = Stdlib.Sys.file_exists out_sexp in
  let md_exists = Stdlib.Sys.file_exists out_md in
  _cleanup_dir dir;
  assert_that result
    (is_ok_and_holds
       (field
          (fun r -> r.Runner.report.CV.cells)
          (elements_are
             [
               all_of
                 [
                   field (fun c -> c.CV.year) (equal_to 1990);
                   field (fun c -> c.CV.drift) (float_equal 0.10);
                 ];
             ])));
  assert_that [ sexp_exists; md_exists ]
    (elements_are [ equal_to true; equal_to true ])

(* --------------------------------------------------------------------- *)
(* Suite                                                                   *)
(* --------------------------------------------------------------------- *)

let suite =
  "test_cross_validation"
  >::: [
         "end_to_end_two_years" >:: test_end_to_end_two_years;
         "missing_composition_year_skipped"
         >:: test_missing_composition_year_skipped;
         "missing_shiller_window_skipped"
         >:: test_missing_shiller_window_skipped;
         "statistics_three_cells" >:: test_statistics_three_cells;
         "markdown_formatter_has_header_and_rows"
         >:: test_markdown_formatter_has_header_and_rows;
         "sexp_round_trip" >:: test_sexp_round_trip;
         "runner_writes_sexp_and_markdown"
         >:: test_runner_writes_sexp_and_markdown;
       ]

let () = run_test_tt_main suite
