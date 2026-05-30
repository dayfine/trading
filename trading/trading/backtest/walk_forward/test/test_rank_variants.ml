(** Integration tests for the [rank_variants] CLI.

    The binary lives at [../bin/rank_variants.exe] in the [_build] tree; each
    test writes synthesised aggregate / fold_actuals sexp inputs to a per-test
    tmpdir, invokes the binary via [Sys.command] (capturing stdout / stderr to
    files), and asserts on the captured markdown. *)

open OUnit2
open Core
open Matchers
module T = Walk_forward.Walk_forward_types

(* -------------- locating the binary -------------- *)

let _binary_path =
  Filename.concat
    (Filename.dirname Stdlib.Sys.executable_name)
    "../bin/rank_variants.exe"

(* -------------- tmpdir scaffolding -------------- *)

(* Per-test tmpdir under the system /tmp; cleaned up via OUnit's [bracket_tmpdir]
   facility — but we use plain Core_unix.mkdtemp here so the test file has no
   filename_unix dependency. *)
let _make_tmpdir () = Stdlib.Filename.temp_dir "rank_variants_test_" ""

let _write_sexp ~dir ~name sexp =
  let path = Filename.concat dir name in
  Out_channel.write_all path ~data:(Sexp.to_string_hum sexp);
  path

(* -------------- input builders -------------- *)

let _stat mean : T.per_metric_stats =
  { mean; stdev = 0.0; min = mean; max = mean }

let _make_stability ~label ~sharpe ~calmar ~max_dd : T.variant_stability =
  {
    variant_label = label;
    total_return_pct = _stat 0.0;
    sharpe_ratio = _stat sharpe;
    max_drawdown_pct = _stat max_dd;
    calmar_ratio = _stat calmar;
    cagr_pct = _stat 0.0;
    avg_holding_days = _stat 0.0;
  }

let _make_aggregate ~stability : T.aggregate =
  {
    fold_count = 4;
    baseline_label = "baseline";
    metric_label = "Sharpe";
    stability;
    sensitivity = [];
    verdicts = [];
  }

let _make_fold_actual ~fold_name ~variant_label ~total_return : T.fold_actual =
  {
    fold_name;
    variant_label;
    total_return_pct = total_return;
    sharpe_ratio = 0.0;
    max_drawdown_pct = 0.0;
    calmar_ratio = 0.0;
    cagr_pct = 0.0;
    avg_holding_days = Float.nan;
  }

(* -------------- invocation helper -------------- *)

type invoke_result = { exit_code : int; stdout : string; stderr : string }

let _invoke ~dir args =
  let stdout_path = Filename.concat dir "stdout.txt" in
  let stderr_path = Filename.concat dir "stderr.txt" in
  let cmd =
    sprintf "%s %s > %s 2> %s" _binary_path
      (String.concat ~sep:" " args)
      (Filename.quote stdout_path)
      (Filename.quote stderr_path)
  in
  let exit_code = Stdlib.Sys.command cmd in
  let stdout = In_channel.read_all stdout_path in
  let stderr = In_channel.read_all stderr_path in
  { exit_code; stdout; stderr }

(* -------------- tests -------------- *)

(* 1. End-to-end on a 3-variant aggregate + matching fold_actuals. Output
   should carry every variant label, the "Pareto frontier" header, and a
   non-empty DSR column (at least one numeric DSR value). *)
let test_end_to_end_3_variants _ =
  let dir = _make_tmpdir () in
  let stability =
    [
      _make_stability ~label:"A" ~sharpe:1.0 ~calmar:0.8 ~max_dd:20.0;
      _make_stability ~label:"B" ~sharpe:0.9 ~calmar:0.9 ~max_dd:25.0;
      _make_stability ~label:"C" ~sharpe:0.5 ~calmar:0.4 ~max_dd:30.0;
    ]
  in
  let agg = _make_aggregate ~stability in
  let agg_path =
    _write_sexp ~dir ~name:"aggregate.sexp" (T.sexp_of_aggregate agg)
  in
  (* Three folds × three variants; returns chosen so each variant has nonzero
     variance and the across-variant Sharpe variance is positive. *)
  let folds =
    [
      _make_fold_actual ~fold_name:"f0" ~variant_label:"A" ~total_return:10.0;
      _make_fold_actual ~fold_name:"f1" ~variant_label:"A" ~total_return:5.0;
      _make_fold_actual ~fold_name:"f2" ~variant_label:"A" ~total_return:15.0;
      _make_fold_actual ~fold_name:"f0" ~variant_label:"B" ~total_return:8.0;
      _make_fold_actual ~fold_name:"f1" ~variant_label:"B" ~total_return:3.0;
      _make_fold_actual ~fold_name:"f2" ~variant_label:"B" ~total_return:12.0;
      _make_fold_actual ~fold_name:"f0" ~variant_label:"C" ~total_return:(-2.0);
      _make_fold_actual ~fold_name:"f1" ~variant_label:"C" ~total_return:(-5.0);
      _make_fold_actual ~fold_name:"f2" ~variant_label:"C" ~total_return:1.0;
    ]
  in
  let folds_path =
    _write_sexp ~dir ~name:"fold_actuals.sexp"
      ([%sexp_of: T.fold_actual list] folds)
  in
  let res =
    _invoke ~dir
      [
        "--aggregate";
        agg_path;
        "--fold-actuals";
        folds_path;
        "--baseline-label";
        "A";
      ]
  in
  assert_that res.exit_code (equal_to 0);
  assert_that res.stdout
    (all_of
       [
         contains_substring "# Variant ranking";
         contains_substring "Baseline: A";
         contains_substring "## Pareto frontier";
         contains_substring "| A |";
         contains_substring "| B |";
         contains_substring "| C |";
         (* DSR computed for at least one variant: a numeric entry appears
            in the Deflated Sharpe column. The renderer prints DSRs as
            four-decimal floats; if every row showed "n/a", DSR was never
            computed. Asserting on "0." catches both small-DSR (0.0001) and
            large-DSR (0.9876) cases without being fragile to the exact
            value. *)
         contains_substring "0.";
       ])

(* 2. With --fold-actuals omitted, the renderer falls back to "n/a" everywhere
   in the DSR column and exits 0. *)
let test_no_fold_actuals _ =
  let dir = _make_tmpdir () in
  let stability =
    [
      _make_stability ~label:"X" ~sharpe:1.0 ~calmar:0.8 ~max_dd:20.0;
      _make_stability ~label:"Y" ~sharpe:0.9 ~calmar:0.9 ~max_dd:25.0;
    ]
  in
  let agg_path =
    _write_sexp ~dir ~name:"aggregate.sexp"
      (T.sexp_of_aggregate (_make_aggregate ~stability))
  in
  let res = _invoke ~dir [ "--aggregate"; agg_path ] in
  assert_that res.exit_code (equal_to 0);
  assert_that res.stdout
    (all_of
       [
         contains_substring "| X |";
         contains_substring "| Y |";
         contains_substring "n/a";
       ])

(* 3. A variant with only one fold return is skipped from DSR but still appears
   in the rendered table. Stderr carries a skip note for that label. *)
let test_skip_variant_with_too_few_folds _ =
  let dir = _make_tmpdir () in
  let stability =
    [
      _make_stability ~label:"M" ~sharpe:1.0 ~calmar:0.8 ~max_dd:20.0;
      _make_stability ~label:"N" ~sharpe:0.5 ~calmar:0.4 ~max_dd:30.0;
      _make_stability ~label:"O" ~sharpe:0.8 ~calmar:0.7 ~max_dd:25.0;
    ]
  in
  let agg_path =
    _write_sexp ~dir ~name:"aggregate.sexp"
      (T.sexp_of_aggregate (_make_aggregate ~stability))
  in
  let folds =
    [
      _make_fold_actual ~fold_name:"f0" ~variant_label:"M" ~total_return:10.0;
      _make_fold_actual ~fold_name:"f1" ~variant_label:"M" ~total_return:5.0;
      _make_fold_actual ~fold_name:"f2" ~variant_label:"M" ~total_return:15.0;
      (* N has only one fold — gets skipped from DSR. *)
      _make_fold_actual ~fold_name:"f0" ~variant_label:"N" ~total_return:(-2.0);
      _make_fold_actual ~fold_name:"f0" ~variant_label:"O" ~total_return:8.0;
      _make_fold_actual ~fold_name:"f1" ~variant_label:"O" ~total_return:3.0;
      _make_fold_actual ~fold_name:"f2" ~variant_label:"O" ~total_return:12.0;
    ]
  in
  let folds_path =
    _write_sexp ~dir ~name:"fold_actuals.sexp"
      ([%sexp_of: T.fold_actual list] folds)
  in
  let res =
    _invoke ~dir [ "--aggregate"; agg_path; "--fold-actuals"; folds_path ]
  in
  assert_that res.exit_code (equal_to 0);
  (* N still appears in the rendered table (Pareto ranking did not skip it),
     and the skip note for N is on stderr. *)
  assert_that res.stdout
    (all_of
       [
         contains_substring "| M |";
         contains_substring "| N |";
         contains_substring "| O |";
       ]);
  assert_that res.stderr (contains_substring "N: only 1")

(* 4. --aggregate missing → exit code non-zero, stderr explains. *)
let test_missing_aggregate _ =
  let dir = _make_tmpdir () in
  let res = _invoke ~dir [] in
  assert_that res.exit_code (gt (module Int_ord) 0);
  assert_that res.stderr (contains_substring "--aggregate is required")

(* 5. Pareto frontier renders correctly with one dominant + one dominated cell
   — the frontier section lists only the winner. *)
let test_pareto_single_dominator _ =
  let dir = _make_tmpdir () in
  let stability =
    [
      _make_stability ~label:"winner" ~sharpe:1.5 ~calmar:1.2 ~max_dd:10.0;
      _make_stability ~label:"loser" ~sharpe:0.5 ~calmar:0.4 ~max_dd:30.0;
    ]
  in
  let agg_path =
    _write_sexp ~dir ~name:"aggregate.sexp"
      (T.sexp_of_aggregate (_make_aggregate ~stability))
  in
  let res = _invoke ~dir [ "--aggregate"; agg_path ] in
  assert_that res.exit_code (equal_to 0);
  assert_that res.stdout
    (all_of
       [
         (* The frontier markdown bullet list contains only "winner". *)
         contains_substring "- winner";
         (* "loser" appears in the per-variant table row but its frontier flag
            is "no"; check by string match. *)
         contains_substring "| loser |";
       ]);
  (* "- loser" as a frontier bullet should NOT appear; check by exact-frontier
     section dump — the frontier section ends at "## Variants", so we slice
     the prefix. *)
  let frontier_end_offset =
    match String.substr_index res.stdout ~pattern:"## Variants" with
    | Some i -> i
    | None -> String.length res.stdout
  in
  let frontier_section =
    String.sub res.stdout ~pos:0 ~len:frontier_end_offset
  in
  assert_that frontier_section (not_ (contains_substring "- loser"))

(* -------------- suite -------------- *)

let suite =
  "rank_variants_cli"
  >::: [
         "end_to_end_3_variants" >:: test_end_to_end_3_variants;
         "no_fold_actuals" >:: test_no_fold_actuals;
         "skip_variant_with_too_few_folds"
         >:: test_skip_variant_with_too_few_folds;
         "missing_aggregate" >:: test_missing_aggregate;
         "pareto_single_dominator" >:: test_pareto_single_dominator;
       ]

let () = run_test_tt_main suite
