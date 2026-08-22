(** Tests for {!Walk_forward.Effect_null_report} and its CLI.

    The library tests pin the pairing / band / verdict contract; the two CLI
    tests pin the exit-code behaviour of the run-context guardrail, which is a
    property of the binary rather than of the pure core. *)

open OUnit2
open Core
open Matchers
module R = Walk_forward.Effect_null_report
module Render = Walk_forward.Effect_null_render

(* -------------- builders -------------- *)

(* A result file's metric set, as [parse_metrics] would return it. *)
let _metrics pairs : R.metrics = pairs

let _result_sexp pairs =
  Sexp.List
    (List.map pairs ~f:(fun (k, v) -> Sexp.List [ Sexp.Atom k; Sexp.Atom v ]))

let _row report metric =
  List.find report.R.rows ~f:(fun r -> String.equal r.R.metric metric)

let _verdict_of report metric =
  Option.map (_row report metric) ~f:(fun r -> Render.verdict_label r.R.verdict)

let _build_exn ~arm ~null ~no_direction =
  match R.build ~arm ~null ~no_direction with
  | Ok report -> report
  | Error err -> assert_failure ("build failed: " ^ Status.show err)

(* Assert on the message inside a [Status] error without a second assert_that. *)
let _error_message_is matcher =
  matching ~msg:"expected an Error"
    (function Error (err : Status.t) -> Some err.message | Ok _ -> None)
    matcher

(* Single-metric salted fixture: one metric ["m"] per file. *)
let _series metric values =
  List.map values ~f:(fun v -> _metrics [ (metric, v) ])

(* -------------- parsing -------------- *)

(* 1. A real scenario result carries floats, ints, a bool and a string; only
   the numeric pairs are metrics, and they keep file order. *)
let test_parse_metrics_keeps_numeric_pairs_in_order _ =
  let sexp =
    _result_sexp
      [
        ("total_return_pct", "305.25");
        ("total_trades", "1270");
        ("crashed", "false");
        ("crash_message", "");
      ]
  in
  assert_that (R.parse_metrics sexp)
    (is_ok_and_holds
       (elements_are
          [
            equal_to (("total_return_pct", 305.25) : string * float);
            equal_to (("total_trades", 1270.0) : string * float);
          ]))

(* 2. A sexp with no numeric pair is an error, not an empty metric set. *)
let test_parse_metrics_rejects_non_numeric_file _ =
  assert_that
    (R.parse_metrics (_result_sexp [ ("crashed", "false") ]))
    (_error_message_is (contains_substring "no numeric"))

(* 3. Run context is read from a flat params.sexp and from a scenario spec's
   nested (period ...) block alike. *)
let test_parse_context_accepts_params_and_spec_shapes _ =
  let params =
    Sexp.of_string
      "((universe_size 3000) (start_date 2000-01-01) (end_date 2026-06-26))"
  in
  let spec =
    Sexp.of_string
      "((name grid1) (universe_size 3000) (period ((start_date 2000-01-01) \
       (end_date 2026-06-26))))"
  in
  assert_that (R.parse_context spec) (equal_to (R.parse_context params))

(* -------------- context guardrail -------------- *)

let _ctx ?universe_size ?start_date ?end_date () : R.run_context =
  { universe_size; start_date; end_date }

(* 4. A universe-size difference is a refusal, and the message names the field
   plus why importing the null is wrong. *)
let test_check_context_refuses_universe_mismatch _ =
  assert_that
    (R.check_context
       ~arm:(_ctx ~universe_size:3000 ~start_date:"2000-01-01" ())
       ~null:(_ctx ~universe_size:500 ~start_date:"2000-01-01" ()))
    (matching ~msg:"expected Mismatch"
       (function R.Mismatch m -> Some m | _ -> None)
       (all_of
          [
            contains_substring "universe_size differs";
            contains_substring "does not transfer across scales";
          ]))

(* 5. A window difference is equally fatal. *)
let test_check_context_refuses_window_mismatch _ =
  assert_that
    (R.check_context
       ~arm:(_ctx ~universe_size:3000 ~end_date:"2026-06-26" ())
       ~null:(_ctx ~universe_size:3000 ~end_date:"2021-06-26" ()))
    (matching ~msg:"expected Mismatch"
       (function R.Mismatch m -> Some m | _ -> None)
       (contains_substring "end_date differs"))

(* 6. Matching contexts verify; nothing comparable is Unverified (a warning,
   not a failure). *)
let test_check_context_verified_and_unverified _ =
  assert_that
    [
      R.check_context
        ~arm:(_ctx ~universe_size:3000 ~start_date:"2000-01-01" ())
        ~null:(_ctx ~universe_size:3000 ~start_date:"2000-01-01" ());
      R.check_context ~arm:(_ctx ()) ~null:(_ctx ~universe_size:3000 ());
    ]
    (elements_are
       [
         equal_to R.Verified;
         matching ~msg:"expected Unverified"
           (function R.Unverified m -> Some m | _ -> None)
           (contains_substring "could not be verified");
       ])

(* -------------- build: pairing and metric-set agreement -------------- *)

(* 7. A metric present in the arm but missing from a null file is a hard error
   naming that metric — never a silent intersection. *)
let test_build_rejects_mismatched_metric_sets _ =
  assert_that
    (R.build
       ~arm:[ _metrics [ ("sharpe_ratio", 1.0); ("calmar_ratio", 0.5) ] ]
       ~null:[ _metrics [ ("sharpe_ratio", 0.9) ] ]
       ~no_direction:[])
    (_error_message_is
       (all_of
          [ contains_substring "null[0]"; contains_substring "calmar_ratio" ]))

(* 8. Positional pairing needs equal counts. *)
let test_build_rejects_unequal_counts _ =
  assert_that
    (R.build
       ~arm:(_series "m" [ 1.0; 2.0 ])
       ~null:(_series "m" [ 1.0 ]) ~no_direction:[])
    (_error_message_is (contains_substring "paired by position"))

(* -------------- build: the single-pair table -------------- *)

(* 9. One pair: gaps are reported, but the band is nan and the verdict makes no
   noise claim. *)
let test_single_pair_reports_gap_without_noise_claim _ =
  let report =
    _build_exn
      ~arm:[ _metrics [ ("total_return_pct", 305.25) ] ]
      ~null:[ _metrics [ ("total_return_pct", 300.0) ] ]
      ~no_direction:[]
  in
  assert_that
    (_row report "total_return_pct")
    (is_some_and
       (all_of
          [
            field (fun r -> r.R.mean_gap) (float_equal 5.25);
            field (fun r -> r.R.paired_gaps) (elements_are [ float_equal 5.25 ]);
            field (fun r -> Float.is_nan r.R.null_band) (equal_to true);
            field (fun r -> r.R.ratio) is_none;
            field (fun r -> r.R.verdict) (equal_to R.No_null_band);
          ]))

(* -------------- build: the three-salt verdicts -------------- *)

(* 10. Three salts, all gaps positive and every |gap| above the null's own
   spread → PASS. *)
let test_three_salt_pass _ =
  let report =
    _build_exn
      ~arm:(_series "m" [ 25.0; 27.0; 26.0 ])
      ~null:(_series "m" [ 10.0; 11.0; 12.0 ])
      ~no_direction:[]
  in
  assert_that (_row report "m")
    (is_some_and
       (all_of
          [
            field (fun r -> r.R.null_band) (float_equal 2.0);
            field (fun r -> r.R.mean_gap) (float_equal 15.0);
            field (fun r -> r.R.ratio) (is_some_and (float_equal 7.5));
            field (fun r -> r.R.verdict) (equal_to R.Pass);
          ]))

(* 11. Same sign every salt, but each |gap| sits under the null band →
   INSIDE-NOISE. *)
let test_three_salt_inside_noise_by_magnitude _ =
  let report =
    _build_exn
      ~arm:(_series "m" [ 11.0; 21.0; 31.0 ])
      ~null:(_series "m" [ 10.0; 20.0; 30.0 ])
      ~no_direction:[]
  in
  assert_that (_row report "m")
    (is_some_and
       (all_of
          [
            field (fun r -> r.R.null_band) (float_equal 20.0);
            field (fun r -> r.R.mean_gap) (float_equal 1.0);
            field (fun r -> r.R.verdict) (equal_to R.Inside_noise);
          ]))

(* 12. A sign flip is INSIDE-NOISE even when the mean gap is large. *)
let test_three_salt_inside_noise_by_sign_flip _ =
  let report =
    _build_exn
      ~arm:(_series "m" [ 30.0; 10.5; 11.5 ])
      ~null:(_series "m" [ 10.0; 11.0; 12.0 ])
      ~no_direction:[]
  in
  assert_that (_row report "m")
    (is_some_and
       (all_of
          [
            field
              (fun r -> r.R.paired_gaps)
              (elements_are
                 [ float_equal 20.0; float_equal (-0.5); float_equal (-0.5) ]);
            field (fun r -> r.R.verdict) (equal_to R.Inside_noise);
          ]))

(* 13. THE #2432-class error, pinned. Same fixture as test 12: a
   difference-of-pooled-means would read +6.33 against a null band of 2.0 —
   a ratio above 3, which naively reads as PASS. The paired within-salt view
   sees the sign flip and returns INSIDE-NOISE. This test asserts both halves
   so the distinction cannot silently regress into a means comparison. *)
let test_paired_beats_difference_of_means _ =
  let arm = [ 30.0; 10.5; 11.5 ] and null = [ 10.0; 11.0; 12.0 ] in
  let mean xs =
    List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int (List.length xs)
  in
  let difference_of_means = mean arm -. mean null in
  let report =
    _build_exn ~arm:(_series "m" arm) ~null:(_series "m" null) ~no_direction:[]
  in
  (* The naive statistic clears the band by more than 3x ... *)
  assert_that (difference_of_means /. 2.0) (gt (module Float_ord) 3.0);
  (* ... and the paired statistic still refuses to call it an effect. *)
  assert_that (_verdict_of report "m") (is_some_and (equal_to "INSIDE-NOISE"))

(* 14. A null whose salts are identical has an unmeasured — not zero — noise
   floor, so no gap against it can PASS. *)
let test_degenerate_null_gets_no_band _ =
  let report =
    _build_exn
      ~arm:(_series "m" [ 5.0; 5.0; 5.0 ])
      ~null:(_series "m" [ 1.0; 1.0; 1.0 ])
      ~no_direction:[]
  in
  assert_that (_verdict_of report "m") (is_some_and (equal_to "NO-BAND"))

(* 15. A directionless metric is reported but never judged, while its
   neighbours in the same report still are. *)
let test_directionless_metric_is_not_judged _ =
  let arm =
    List.map
      [ (25.0, 100.0); (27.0, 400.0); (26.0, 250.0) ]
      ~f:(fun (s, t) -> _metrics [ ("sharpe_ratio", s); ("total_trades", t) ])
  in
  let null =
    List.map
      [ (10.0, 90.0); (11.0, 95.0); (12.0, 92.0) ]
      ~f:(fun (s, t) -> _metrics [ ("sharpe_ratio", s); ("total_trades", t) ])
  in
  let report = _build_exn ~arm ~null ~no_direction:[ "total_trades" ] in
  assert_that
    (List.map report.R.rows ~f:(fun r ->
         (r.R.metric, Render.verdict_label r.R.verdict)))
    (elements_are
       [
         equal_to (("sharpe_ratio", "PASS") : string * string);
         equal_to
           (("total_trades", "not judged (directionless)") : string * string);
       ])

(* -------------- rendering -------------- *)

(* 16. The markdown is the table a writeup pastes: a header, the note that a
   single pair supports no noise claim, and one row per metric. *)
let test_render_markdown_single_pair _ =
  let report =
    _build_exn
      ~arm:[ _metrics [ ("sharpe_ratio", 0.5) ] ]
      ~null:[ _metrics [ ("sharpe_ratio", 0.4) ] ]
      ~no_direction:[]
  in
  assert_that
    (Render.markdown ~arm_label:"arm" ~null_label:"ctl" report)
    (all_of
       [
         contains_substring "# Effect vs null";
         contains_substring "1 pair(s), matched by position";
         contains_substring "no noise claim is possible";
         contains_substring "| sharpe_ratio | +0.1000 |";
         (* The .mli contract: a non-finite cell prints as "n/a", never
            "0.0000" — the band and ratio cells of a single-pair row. *)
         contains_substring "| n/a | n/a | NO-BAND |";
         contains_substring "NO-BAND";
       ])

(* -------------- CLI: the guardrail's exit codes -------------- *)

let _binary_path =
  Filename.concat
    (Filename.dirname Stdlib.Sys.executable_name)
    "../bin/effect_null_report.exe"

let _make_tmpdir () = Stdlib.Filename.temp_dir "effect_null_report_test_" ""

let _write ~dir ~name sexp =
  let path = Filename.concat dir name in
  Out_channel.write_all path ~data:(Sexp.to_string_hum sexp);
  path

type invoke_result = { exit_code : int; stdout : string; stderr : string }

let _invoke ~dir args =
  let stdout_path = Filename.concat dir "stdout.txt" in
  let stderr_path = Filename.concat dir "stderr.txt" in
  let exit_code =
    Stdlib.Sys.command
      (sprintf "%s %s > %s 2> %s" _binary_path
         (String.concat ~sep:" " args)
         (Filename.quote stdout_path)
         (Filename.quote stderr_path))
  in
  {
    exit_code;
    stdout = In_channel.read_all stdout_path;
    stderr = In_channel.read_all stderr_path;
  }

(* Write an arm/null pair plus their params into [dir], returning the four
   paths. [universe_size] applies to the null's params only. *)
let _write_pair ~dir ~null_universe_size =
  let arm = _write ~dir ~name:"arm.sexp" (_result_sexp [ ("m", "2.0") ]) in
  let null = _write ~dir ~name:"null.sexp" (_result_sexp [ ("m", "1.0") ]) in
  let arm_params =
    _write ~dir ~name:"arm_params.sexp"
      (Sexp.of_string "((universe_size 3000) (start_date 2000-01-01))")
  in
  let null_params =
    _write ~dir ~name:"null_params.sexp"
      (Sexp.of_string
         (sprintf "((universe_size %d) (start_date 2000-01-01))"
            null_universe_size))
  in
  (arm, null, arm_params, null_params)

(* 17. Mismatched universes: the binary refuses with a non-zero exit and no
   table on stdout. *)
let test_cli_refuses_universe_mismatch _ =
  let dir = _make_tmpdir () in
  let arm, null, arm_params, null_params =
    _write_pair ~dir ~null_universe_size:500
  in
  let res =
    _invoke ~dir
      [
        "--arm";
        arm;
        "--null";
        null;
        "--arm-params";
        arm_params;
        "--null-params";
        null_params;
      ]
  in
  assert_that res
    (all_of
       [
         field (fun r -> r.exit_code) (gt (module Int_ord) 0);
         field (fun r -> r.stderr) (contains_substring "universe_size differs");
         field (fun r -> r.stdout) (equal_to "");
       ])

(* 18. Matching contexts: the binary renders the table, exits 0, and emits no
   unverified-context warning. *)
let test_cli_accepts_matching_context _ =
  let dir = _make_tmpdir () in
  let arm, null, arm_params, null_params =
    _write_pair ~dir ~null_universe_size:3000
  in
  let res =
    _invoke ~dir
      [
        "--arm";
        arm;
        "--null";
        null;
        "--arm-params";
        arm_params;
        "--null-params";
        null_params;
      ]
  in
  assert_that res
    (all_of
       [
         field (fun r -> r.exit_code) (equal_to 0);
         field (fun r -> r.stdout) (contains_substring "| m | +1.0000 |");
         field (fun r -> r.stderr) (not_ (contains_substring "WARNING"));
       ])

(* 19. No context available on either side: the binary WARNS and continues —
   exit 0, a loud stderr line, and the warning carried into the table as a
   blockquote note so the pasted markdown cannot read as verified. This is the
   most-travelled path (committed result sets usually ship no params.sexp), so
   it is pinned in its presence, not only its absence. *)
let test_cli_warns_and_continues_without_context _ =
  let dir = _make_tmpdir () in
  let arm = _write ~dir ~name:"arm.sexp" (_result_sexp [ ("m", "2.0") ]) in
  let null = _write ~dir ~name:"null.sexp" (_result_sexp [ ("m", "1.0") ]) in
  let res = _invoke ~dir [ "--arm"; arm; "--null"; null ] in
  assert_that res
    (all_of
       [
         field (fun r -> r.exit_code) (equal_to 0);
         field (fun r -> r.stderr) (contains_substring "could not be verified");
         field
           (fun r -> r.stdout)
           (all_of
              [
                contains_substring "> WARNING: run context could not be";
                contains_substring "| m | +1.0000 |";
              ]);
       ])

(* -------------- suite -------------- *)

let suite =
  "effect_null_report"
  >::: [
         "parse_metrics_keeps_numeric_pairs_in_order"
         >:: test_parse_metrics_keeps_numeric_pairs_in_order;
         "parse_metrics_rejects_non_numeric_file"
         >:: test_parse_metrics_rejects_non_numeric_file;
         "parse_context_accepts_params_and_spec_shapes"
         >:: test_parse_context_accepts_params_and_spec_shapes;
         "check_context_refuses_universe_mismatch"
         >:: test_check_context_refuses_universe_mismatch;
         "check_context_refuses_window_mismatch"
         >:: test_check_context_refuses_window_mismatch;
         "check_context_verified_and_unverified"
         >:: test_check_context_verified_and_unverified;
         "build_rejects_mismatched_metric_sets"
         >:: test_build_rejects_mismatched_metric_sets;
         "build_rejects_unequal_counts" >:: test_build_rejects_unequal_counts;
         "single_pair_reports_gap_without_noise_claim"
         >:: test_single_pair_reports_gap_without_noise_claim;
         "three_salt_pass" >:: test_three_salt_pass;
         "three_salt_inside_noise_by_magnitude"
         >:: test_three_salt_inside_noise_by_magnitude;
         "three_salt_inside_noise_by_sign_flip"
         >:: test_three_salt_inside_noise_by_sign_flip;
         "paired_beats_difference_of_means"
         >:: test_paired_beats_difference_of_means;
         "degenerate_null_gets_no_band" >:: test_degenerate_null_gets_no_band;
         "directionless_metric_is_not_judged"
         >:: test_directionless_metric_is_not_judged;
         "render_markdown_single_pair" >:: test_render_markdown_single_pair;
         "cli_refuses_universe_mismatch" >:: test_cli_refuses_universe_mismatch;
         "cli_accepts_matching_context" >:: test_cli_accepts_matching_context;
         "cli_warns_and_continues_without_context"
         >:: test_cli_warns_and_continues_without_context;
       ]

let () = run_test_tt_main suite
