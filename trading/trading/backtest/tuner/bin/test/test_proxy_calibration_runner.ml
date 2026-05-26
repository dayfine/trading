(** Unit tests for {!Tuner_bin.Proxy_calibration_runner}. Pin the CLI-arg
    parser, sexp loader, markdown renderer, and the end-to-end orchestrator
    against synthetic fold_actuals fixtures written to a temp dir.

    No real walk-forward run is invoked — the pure-math primitive
    {!Tuner.Proxy_calibration_lib.spearman_rho} is exercised in its own sibling
    test suite. *)

open OUnit2
open Core
open Matchers
module PCR = Tuner_bin.Proxy_calibration_runner
module PC = Tuner.Proxy_calibration_lib
module Wf = Walk_forward.Walk_forward_types

(* ---------- temp-dir helper (mirrors test_grid_search_bin.ml) ---------- *)

let _with_temp_dir f =
  let dir =
    Filename_unix.temp_dir ~in_dir:Filename.temp_dir_name
      "proxy_calibration_test_" ""
  in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      let rec rm_tree p =
        if Sys_unix.is_directory_exn p then begin
          Sys_unix.readdir p
          |> Array.iter ~f:(fun child -> rm_tree (Filename.concat p child));
          Core_unix.rmdir p
        end
        else Core_unix.unlink p
      in
      try rm_tree dir with _ -> ())

(* ---------- fixture writer --------------------------------------------- *)

let _fold_actual ?(variant_label = "cell-E") ?(total_return_pct = Float.nan)
    ?(sharpe_ratio = Float.nan) ?(max_drawdown_pct = Float.nan)
    ?(calmar_ratio = Float.nan) ?(cagr_pct = Float.nan)
    ?(avg_holding_days = Float.nan) ~fold_name () : Wf.fold_actual =
  {
    fold_name;
    variant_label;
    total_return_pct;
    sharpe_ratio;
    max_drawdown_pct;
    calmar_ratio;
    cagr_pct;
    avg_holding_days;
  }

let _write_fold_actuals path (actuals : Wf.fold_actual list) =
  let sexp = Sexp.List (List.map actuals ~f:Wf.sexp_of_fold_actual) in
  Sexp.save_hum path sexp

(* ---------- metric_arg_of_string -------------------------------------- *)

let test_metric_arg_of_string_recognised _ =
  assert_that
    (PCR.metric_arg_of_string "sharpe")
    (equal_to (PCR.Sharpe : PCR.metric_arg));
  assert_that
    (PCR.metric_arg_of_string "SHARPE")
    (equal_to (PCR.Sharpe : PCR.metric_arg));
  assert_that
    (PCR.metric_arg_of_string "totalreturn")
    (equal_to (PCR.TotalReturn : PCR.metric_arg));
  assert_that
    (PCR.metric_arg_of_string "total_return")
    (equal_to (PCR.TotalReturn : PCR.metric_arg));
  assert_that
    (PCR.metric_arg_of_string "total-return")
    (equal_to (PCR.TotalReturn : PCR.metric_arg));
  assert_that
    (PCR.metric_arg_of_string "calmar")
    (equal_to (PCR.Calmar : PCR.metric_arg));
  assert_that
    (PCR.metric_arg_of_string "CAGR")
    (equal_to (PCR.CAGR : PCR.metric_arg));
  assert_that
    (PCR.metric_arg_of_string "maxdrawdown")
    (equal_to (PCR.MaxDrawdown : PCR.metric_arg))

let test_metric_arg_of_string_unknown_raises _ =
  let f () =
    let _ = PCR.metric_arg_of_string "bogus" in
    ()
  in
  assert_raises (Failure "unknown metric: \"bogus\"") f

(* ---------- parse_args ------------------------------------------------- *)

let test_parse_args_required_only _ =
  let args =
    PCR.parse_args [ "--cheap"; "/c.sexp"; "--expensive"; "/e.sexp" ]
  in
  assert_that args
    (equal_to
       ({
          PCR.cheap_path = "/c.sexp";
          expensive_path = "/e.sexp";
          metric = PCR.Sharpe;
          threshold = PC.acceptance_threshold;
          variant_label = PCR.default_variant_label;
          out_path = None;
        }
         : PCR.cli_args))

let test_parse_args_all_flags _ =
  let args =
    PCR.parse_args
      [
        "--cheap";
        "/c.sexp";
        "--expensive";
        "/e.sexp";
        "--metric";
        "calmar";
        "--threshold";
        "0.85";
        "--variant";
        "custom-cell";
        "--out";
        "/tmp/r.md";
      ]
  in
  assert_that args
    (equal_to
       ({
          PCR.cheap_path = "/c.sexp";
          expensive_path = "/e.sexp";
          metric = PCR.Calmar;
          threshold = 0.85;
          variant_label = "custom-cell";
          out_path = Some "/tmp/r.md";
        }
         : PCR.cli_args))

let _assert_raises_failure_containing f expected_substr =
  try
    f ();
    assert_failure "expected Failure to be raised"
  with Failure msg ->
    if String.is_substring msg ~substring:expected_substr then ()
    else
      assert_failure
        (Printf.sprintf "Failure message %S did not contain %S" msg
           expected_substr)

let test_parse_args_missing_cheap _ =
  let f () =
    let _ = PCR.parse_args [ "--expensive"; "/e.sexp" ] in
    ()
  in
  _assert_raises_failure_containing f "--cheap and --expensive are required"

let test_parse_args_unknown_flag _ =
  let f () =
    let _ =
      PCR.parse_args
        [ "--cheap"; "/c.sexp"; "--expensive"; "/e.sexp"; "--bogus"; "x" ]
    in
    ()
  in
  _assert_raises_failure_containing f "unknown argument"

(* ---------- load_fold_actuals ----------------------------------------- *)

let test_load_fold_actuals_round_trip _ =
  _with_temp_dir (fun dir ->
      let path = Filename.concat dir "fa.sexp" in
      let actuals =
        [
          _fold_actual ~fold_name:"fold-000" ~sharpe_ratio:1.0
            ~total_return_pct:10.0 ();
          _fold_actual ~fold_name:"fold-001" ~sharpe_ratio:2.0
            ~total_return_pct:20.0 ();
        ]
      in
      _write_fold_actuals path actuals;
      let loaded = PCR.load_fold_actuals path in
      assert_that
        (List.map loaded ~f:(fun fa -> fa.Wf.fold_name))
        (elements_are [ equal_to "fold-000"; equal_to "fold-001" ]);
      assert_that
        (List.map loaded ~f:(fun fa -> fa.Wf.sharpe_ratio))
        (elements_are [ float_equal 1.0; float_equal 2.0 ]))

let test_load_fold_actuals_missing _ =
  let f () =
    let _ = PCR.load_fold_actuals "/nonexistent/path.sexp" in
    ()
  in
  _assert_raises_failure_containing f "not found"

(* ---------- render_markdown ------------------------------------------- *)

let test_render_markdown_pass_verdict _ =
  let pairs =
    [
      { PC.fold_name = "f0"; cheap = 1.0; expensive = 1.5 };
      { PC.fold_name = "f1"; cheap = 2.0; expensive = 2.5 };
    ]
  in
  let md =
    PCR.render_markdown ~cheap_path:"/cheap.sexp" ~expensive_path:"/exp.sexp"
      ~metric:PCR.Sharpe ~threshold:0.7 ~variant_label:"cell-E" ~pairs ~rho:0.95
      ~verdict:PC.Pass
  in
  assert_bool "report contains PASS verdict"
    (String.is_substring md ~substring:"PASS");
  assert_bool "report contains Spearman ρ"
    (String.is_substring md ~substring:"0.950000");
  assert_bool "report contains fold rows"
    (String.is_substring md ~substring:"f0");
  assert_bool "report contains metric label"
    (String.is_substring md ~substring:"sharpe_ratio");
  assert_bool "report contains variant label"
    (String.is_substring md ~substring:"cell-E")

let test_render_markdown_fail_verdict _ =
  let pairs = [ { PC.fold_name = "f0"; cheap = 1.0; expensive = 2.0 } ] in
  let md =
    PCR.render_markdown ~cheap_path:"/c.sexp" ~expensive_path:"/e.sexp"
      ~metric:PCR.Sharpe ~threshold:0.7 ~variant_label:"cell-E" ~pairs ~rho:0.5
      ~verdict:PC.Fail
  in
  assert_bool "report contains FAIL verdict"
    (String.is_substring md ~substring:"FAIL");
  assert_bool "report contains threshold"
    (String.is_substring md ~substring:"0.7000")

(* ---------- run_calibration end-to-end -------------------------------- *)

(** PASS path: cheap is a 6-fold sample (indices 0,5,10,15,20,25) from a 26-fold
    expensive set, Sharpe values are perfectly monotone, so the Spearman ρ
    between cheap and expensive on the matched subset is 1.0 and the verdict is
    PASS at the default threshold of 0.7. *)
let test_run_calibration_pass _ =
  _with_temp_dir (fun dir ->
      let cheap_path = Filename.concat dir "cheap.sexp" in
      let exp_path = Filename.concat dir "expensive.sexp" in
      let expensive =
        List.init 26 ~f:(fun i ->
            _fold_actual
              ~fold_name:(Printf.sprintf "fold-%03d" i)
              ~sharpe_ratio:(Float.of_int i *. 0.1)
              ())
      in
      let cheap_indices = [ 0; 5; 10; 15; 20; 25 ] in
      let cheap =
        List.map cheap_indices ~f:(fun i ->
            _fold_actual
              ~fold_name:(Printf.sprintf "fold-%03d" i)
              ~sharpe_ratio:(Float.of_int i *. 0.1)
              ())
      in
      _write_fold_actuals cheap_path cheap;
      _write_fold_actuals exp_path expensive;
      let args =
        {
          PCR.cheap_path;
          expensive_path = exp_path;
          metric = PCR.Sharpe;
          threshold = PC.acceptance_threshold;
          variant_label = PCR.default_variant_label;
          out_path = None;
        }
      in
      let result = PCR.run_calibration args in
      assert_that (List.length result.pairs) (equal_to 6);
      assert_that result.rho (float_equal ~epsilon:1e-12 1.0);
      assert_that result.verdict (equal_to (PC.Pass : PC.verdict)))

(** FAIL path: cheap and expensive disagree fold-by-fold (perfectly inverse
    Sharpe ranks) so ρ = -1.0 < 0.7 ⇒ FAIL. *)
let test_run_calibration_fail _ =
  _with_temp_dir (fun dir ->
      let cheap_path = Filename.concat dir "cheap.sexp" in
      let exp_path = Filename.concat dir "expensive.sexp" in
      let expensive =
        [
          _fold_actual ~fold_name:"f0" ~sharpe_ratio:1.0 ();
          _fold_actual ~fold_name:"f1" ~sharpe_ratio:2.0 ();
          _fold_actual ~fold_name:"f2" ~sharpe_ratio:3.0 ();
          _fold_actual ~fold_name:"f3" ~sharpe_ratio:4.0 ();
        ]
      in
      let cheap =
        [
          _fold_actual ~fold_name:"f0" ~sharpe_ratio:4.0 ();
          _fold_actual ~fold_name:"f1" ~sharpe_ratio:3.0 ();
          _fold_actual ~fold_name:"f2" ~sharpe_ratio:2.0 ();
          _fold_actual ~fold_name:"f3" ~sharpe_ratio:1.0 ();
        ]
      in
      _write_fold_actuals cheap_path cheap;
      _write_fold_actuals exp_path expensive;
      let args =
        {
          PCR.cheap_path;
          expensive_path = exp_path;
          metric = PCR.Sharpe;
          threshold = PC.acceptance_threshold;
          variant_label = PCR.default_variant_label;
          out_path = None;
        }
      in
      let result = PCR.run_calibration args in
      assert_that result.rho (float_equal ~epsilon:1e-12 (-1.0));
      assert_that result.verdict (equal_to (PC.Fail : PC.verdict)))

(** Multi-variant fold_actuals: when both cheap and expensive contain Cell E AND
    candidate variants, the calibration filters to the requested variant_label
    and joins only Cell E rows. Without the filter, the hashtable's
    last-writer-wins behaviour would mix candidate values into the Cell E
    correlation. *)
let test_run_calibration_multi_variant_filtered _ =
  _with_temp_dir (fun dir ->
      let cheap_path = Filename.concat dir "cheap.sexp" in
      let exp_path = Filename.concat dir "expensive.sexp" in
      (* Both Cell E and candidate variants are in the same file. The candidate
         carries radically different Sharpe values; if the filter is wrong, the
         join would pick up candidate's Sharpe and ρ would diverge from 1. *)
      _write_fold_actuals cheap_path
        [
          _fold_actual ~variant_label:"cell-E" ~fold_name:"f0" ~sharpe_ratio:1.0
            ();
          _fold_actual ~variant_label:"candidate" ~fold_name:"f0"
            ~sharpe_ratio:99.0 ();
          _fold_actual ~variant_label:"cell-E" ~fold_name:"f1" ~sharpe_ratio:2.0
            ();
          _fold_actual ~variant_label:"candidate" ~fold_name:"f1"
            ~sharpe_ratio:99.0 ();
          _fold_actual ~variant_label:"cell-E" ~fold_name:"f2" ~sharpe_ratio:3.0
            ();
        ];
      _write_fold_actuals exp_path
        [
          _fold_actual ~variant_label:"cell-E" ~fold_name:"f0" ~sharpe_ratio:1.0
            ();
          _fold_actual ~variant_label:"candidate" ~fold_name:"f0"
            ~sharpe_ratio:99.0 ();
          _fold_actual ~variant_label:"cell-E" ~fold_name:"f1" ~sharpe_ratio:2.0
            ();
          _fold_actual ~variant_label:"candidate" ~fold_name:"f1"
            ~sharpe_ratio:99.0 ();
          _fold_actual ~variant_label:"cell-E" ~fold_name:"f2" ~sharpe_ratio:3.0
            ();
        ];
      let args =
        {
          PCR.cheap_path;
          expensive_path = exp_path;
          metric = PCR.Sharpe;
          threshold = PC.acceptance_threshold;
          variant_label = "cell-E";
          out_path = None;
        }
      in
      let result = PCR.run_calibration args in
      assert_that (List.length result.pairs) (equal_to 3);
      assert_that result.rho (float_equal ~epsilon:1e-12 1.0);
      assert_that result.verdict (equal_to (PC.Pass : PC.verdict)))

(** Disjoint fold_names raise (no matched pairs). *)
let test_run_calibration_disjoint_raises _ =
  _with_temp_dir (fun dir ->
      let cheap_path = Filename.concat dir "cheap.sexp" in
      let exp_path = Filename.concat dir "expensive.sexp" in
      _write_fold_actuals cheap_path
        [
          _fold_actual ~fold_name:"alpha" ~sharpe_ratio:1.0 ();
          _fold_actual ~fold_name:"beta" ~sharpe_ratio:2.0 ();
        ];
      _write_fold_actuals exp_path
        [
          _fold_actual ~fold_name:"gamma" ~sharpe_ratio:1.0 ();
          _fold_actual ~fold_name:"delta" ~sharpe_ratio:2.0 ();
        ];
      let args =
        {
          PCR.cheap_path;
          expensive_path = exp_path;
          metric = PCR.Sharpe;
          threshold = PC.acceptance_threshold;
          variant_label = PCR.default_variant_label;
          out_path = None;
        }
      in
      let f () =
        let _ = PCR.run_calibration args in
        ()
      in
      _assert_raises_failure_containing f "need >=2 matched folds")

(* ---------- suite ------------------------------------------------------ *)

let suite =
  "test_proxy_calibration_runner"
  >::: [
         "metric_arg_of_string_recognised"
         >:: test_metric_arg_of_string_recognised;
         "metric_arg_of_string_unknown_raises"
         >:: test_metric_arg_of_string_unknown_raises;
         "parse_args_required_only" >:: test_parse_args_required_only;
         "parse_args_all_flags" >:: test_parse_args_all_flags;
         "parse_args_missing_cheap" >:: test_parse_args_missing_cheap;
         "parse_args_unknown_flag" >:: test_parse_args_unknown_flag;
         "load_fold_actuals_round_trip" >:: test_load_fold_actuals_round_trip;
         "load_fold_actuals_missing" >:: test_load_fold_actuals_missing;
         "render_markdown_pass_verdict" >:: test_render_markdown_pass_verdict;
         "render_markdown_fail_verdict" >:: test_render_markdown_fail_verdict;
         "run_calibration_pass" >:: test_run_calibration_pass;
         "run_calibration_fail" >:: test_run_calibration_fail;
         "run_calibration_multi_variant_filtered"
         >:: test_run_calibration_multi_variant_filtered;
         "run_calibration_disjoint_raises"
         >:: test_run_calibration_disjoint_raises;
       ]

let () = run_test_tt_main suite
