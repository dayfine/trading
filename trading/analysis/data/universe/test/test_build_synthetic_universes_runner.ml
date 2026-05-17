open Core
open OUnit2
open Matchers
module Runner = Build_synthetic_universes_runner_lib
module SC = Shiller.Shiller_client
module KF = Kenneth_french.Kenneth_french_client

(* ---------------------------------------------------------------------- *)
(* Fixture builders                                                        *)
(* ---------------------------------------------------------------------- *)

let _industries = [ "Cnsmr"; "Manuf"; "HiTec"; "Hlth"; "Other" ]
let _industry_pcts = [ 0.04; 0.05; 0.06; 0.03; 0.02 ]

let _industry_returns_for_day () =
  List.zip_exn _industries _industry_pcts
  |> List.map ~f:(fun (industry, pct) -> (industry, Some pct))

(* Build a Shiller fixture spanning year-06 .. (year+1)-05 with a linear
   price ramp from p_start to p_end. The build date is (year, May, 31), so
   the in-window slice is anchored at year-06-01 through (year+1)-05-01. *)
let _shiller_fixture_for_year ~year ~p_start ~p_end :
    SC.monthly_observation list =
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

let _french_fixture_for_year ~year : KF.daily_return list =
  let n_days = 252 in
  let anchor = Date.create_exn ~y:year ~m:Month.May ~d:31 in
  List.init n_days ~f:(fun i ->
      {
        KF.date = Date.add_days anchor i;
        industry_returns = _industry_returns_for_day ();
      })

let _make_tmp_dir suffix =
  let dir = Stdlib.Filename.temp_file "runner_test_" ("_" ^ suffix ^ ".d") in
  (try Stdlib.Sys.remove dir with _ -> ());
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir))
      : int);
  dir

let _cleanup_dir dir =
  ignore
    (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote dir)) : int)

let _files_in_dir dir =
  Stdlib.Sys.readdir dir |> Array.to_list |> List.sort ~compare:String.compare

(* ---------------------------------------------------------------------- *)
(* Tests                                                                   *)
(* ---------------------------------------------------------------------- *)

let test_smoke_writes_one_file _ =
  let out_dir = _make_tmp_dir "smoke" in
  let shiller_obs =
    _shiller_fixture_for_year ~year:1990 ~p_start:100.0 ~p_end:110.0
  in
  let french_obs = _french_fixture_for_year ~year:1990 in
  let result =
    Runner.run ~shiller_obs ~french_obs ~out_dir ~start_year:1990 ~end_year:1990
      ~top_ns:[ 100 ] ~rng_seed:42
  in
  let files = _files_in_dir out_dir in
  let snapshot_path = Filename.concat out_dir "top-100-1990.sexp" in
  let loaded = Universe.Snapshot.load ~path:snapshot_path in
  _cleanup_dir out_dir;
  assert_that result
    (all_of
       [
         field (fun r -> r.Runner.written) (equal_to 1);
         field (fun r -> r.Runner.skipped) (equal_to 0);
       ]);
  assert_that files (elements_are [ equal_to "top-100-1990.sexp" ]);
  assert_that loaded
    (is_ok_and_holds
       (all_of
          [
            field (fun s -> s.Universe.Snapshot.size) (equal_to 100);
            field
              (fun s -> List.length s.Universe.Snapshot.entries)
              (equal_to 100);
          ]))

let test_skip_on_missing_shiller_window _ =
  let out_dir = _make_tmp_dir "skip" in
  (* Asking for year=1989 but fixture only covers 1990: the Shiller window
     slice is empty, so Build_from_index emits an Invalid_argument and the
     pair is skipped (not crashed). *)
  let shiller_obs =
    _shiller_fixture_for_year ~year:1990 ~p_start:100.0 ~p_end:110.0
  in
  let french_obs = _french_fixture_for_year ~year:1990 in
  let result =
    Runner.run ~shiller_obs ~french_obs ~out_dir ~start_year:1989 ~end_year:1989
      ~top_ns:[ 100 ] ~rng_seed:42
  in
  let files = _files_in_dir out_dir in
  _cleanup_dir out_dir;
  assert_that result
    (all_of
       [
         field (fun r -> r.Runner.written) (equal_to 0);
         field (fun r -> r.Runner.skipped) (equal_to 1);
         field
           (fun r -> r.Runner.skip_reasons)
           (elements_are
              [
                all_of
                  [
                    field (fun (y, _, _) -> y) (equal_to 1989);
                    field (fun (_, t, _) -> t) (equal_to 100);
                  ];
              ]);
       ]);
  assert_that files (elements_are [])

let test_multi_size_writes_one_file_per_size _ =
  let out_dir = _make_tmp_dir "multi" in
  let shiller_obs =
    _shiller_fixture_for_year ~year:1990 ~p_start:100.0 ~p_end:110.0
  in
  let french_obs = _french_fixture_for_year ~year:1990 in
  let result =
    Runner.run ~shiller_obs ~french_obs ~out_dir ~start_year:1990 ~end_year:1990
      ~top_ns:[ 50; 100; 200 ] ~rng_seed:42
  in
  let files = _files_in_dir out_dir in
  _cleanup_dir out_dir;
  assert_that result
    (all_of
       [
         field (fun r -> r.Runner.written) (equal_to 3);
         field (fun r -> r.Runner.skipped) (equal_to 0);
       ]);
  assert_that files
    (elements_are
       [
         equal_to "top-100-1990.sexp";
         equal_to "top-200-1990.sexp";
         equal_to "top-50-1990.sexp";
       ])

(* ---------------------------------------------------------------------- *)
(* Cache CSV parser tests                                                  *)
(* ---------------------------------------------------------------------- *)

let _shiller_csv =
  "period,sp_price,dividend,earnings,cpi,long_rate\n\
   1990-06-01,360.39,11.36,22.42,129.9,8.4\n\
   1990-07-01,360.03,,,,\n"

let test_parse_shiller_cache_csv_two_rows _ =
  let result = Runner.parse_shiller_cache_csv _shiller_csv in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            all_of
              [
                field
                  (fun (o : SC.monthly_observation) -> o.period)
                  (equal_to (Date.create_exn ~y:1990 ~m:Month.Jun ~d:1));
                field
                  (fun (o : SC.monthly_observation) -> o.sp_price)
                  (float_equal 360.39);
                field
                  (fun (o : SC.monthly_observation) -> o.dividend)
                  (is_some_and (float_equal 11.36));
              ];
            all_of
              [
                field
                  (fun (o : SC.monthly_observation) -> o.period)
                  (equal_to (Date.create_exn ~y:1990 ~m:Month.Jul ~d:1));
                field
                  (fun (o : SC.monthly_observation) -> o.sp_price)
                  (float_equal 360.03);
                field (fun (o : SC.monthly_observation) -> o.dividend) is_none;
              ];
          ]))

let test_parse_shiller_cache_csv_header_drift_is_invalid_argument _ =
  let body = "date,sp_price,dividend\n1990-06-01,100.0,1.0\n" in
  assert_that
    (Runner.parse_shiller_cache_csv body)
    (is_error_with Status.Invalid_argument)

let _french_csv =
  "block,date,Cnsmr,Manuf,HiTec,Hlth,Other\n\
   VW,1990-06-01,0.04,0.05,0.06,0.03,0.02\n\
   VW,1990-06-04,0.01,0.02,0.03,-0.01,0.00\n\
   EW,1990-06-01,0.05,0.06,0.07,0.04,0.03\n"

let test_parse_french_cache_csv_keeps_vw_drops_ew _ =
  let result = Runner.parse_french_cache_csv _french_csv in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            all_of
              [
                field
                  (fun (o : KF.daily_return) -> o.date)
                  (equal_to (Date.create_exn ~y:1990 ~m:Month.Jun ~d:1));
                field
                  (fun (o : KF.daily_return) -> List.length o.industry_returns)
                  (equal_to 5);
              ];
            field
              (fun (o : KF.daily_return) -> o.date)
              (equal_to (Date.create_exn ~y:1990 ~m:Month.Jun ~d:4));
          ]))

let test_parse_french_cache_csv_header_drift_is_invalid_argument _ =
  let body = "date,Cnsmr,Manuf\n1990-06-01,0.04,0.05\n" in
  assert_that
    (Runner.parse_french_cache_csv body)
    (is_error_with Status.Invalid_argument)

let suite =
  "Build_synthetic_universes_runner"
  >::: [
         "test_smoke_writes_one_file" >:: test_smoke_writes_one_file;
         "test_skip_on_missing_shiller_window"
         >:: test_skip_on_missing_shiller_window;
         "test_multi_size_writes_one_file_per_size"
         >:: test_multi_size_writes_one_file_per_size;
         "test_parse_shiller_cache_csv_two_rows"
         >:: test_parse_shiller_cache_csv_two_rows;
         "test_parse_shiller_cache_csv_header_drift_is_invalid_argument"
         >:: test_parse_shiller_cache_csv_header_drift_is_invalid_argument;
         "test_parse_french_cache_csv_keeps_vw_drops_ew"
         >:: test_parse_french_cache_csv_keeps_vw_drops_ew;
         "test_parse_french_cache_csv_header_drift_is_invalid_argument"
         >:: test_parse_french_cache_csv_header_drift_is_invalid_argument;
       ]

let () = run_test_tt_main suite
