(** Unit tests for {!Walk_forward.Fold_gate}. Pure scoring checks — no backtest
    invocation. *)

open OUnit2
open Core
open Matchers
module FG = Walk_forward.Fold_gate

(* ---------- Helpers ---------- *)

let _fr ~name ~variant ~baseline : FG.fold_result =
  { fold_name = name; variant_score = variant; baseline_score = baseline }

let _gate ?(metric = FG.Sharpe) ?(m = 3) ?(n = 5) ?(worst_delta = 0.10) () :
    FG.t =
  { metric; m; n; worst_delta }

(* ---------- higher_is_better ---------- *)

let test_higher_is_better _ =
  assert_that (FG.higher_is_better Sharpe) (equal_to true);
  assert_that (FG.higher_is_better Calmar) (equal_to true);
  assert_that (FG.higher_is_better TotalReturnPct) (equal_to true);
  assert_that (FG.higher_is_better MaxDrawdownPct) (equal_to false)

(* ---------- Validation ---------- *)

let test_n_zero_raises _ =
  let gate = _gate ~n:0 ~m:0 () in
  assert_raises (Failure "Fold_gate.evaluate: n must be >= 1, got 0") (fun () ->
      FG.evaluate gate [])

let test_m_out_of_range_raises _ =
  let gate = _gate ~m:6 ~n:5 () in
  assert_raises (Failure "Fold_gate.evaluate: m must be in [0, n=5], got 6")
    (fun () ->
      let folds =
        List.init 5 ~f:(fun i ->
            _fr ~name:(sprintf "fold-%03d" i) ~variant:1.0 ~baseline:0.5)
      in
      FG.evaluate gate folds)

let test_negative_delta_raises _ =
  let gate = _gate ~worst_delta:(-0.1) () in
  assert_raises
    (Failure "Fold_gate.evaluate: worst_delta must be >= 0.0, got -0.100000")
    (fun () -> FG.evaluate gate [])

let test_fold_count_mismatch_raises _ =
  let gate = _gate ~n:5 ~m:3 () in
  let folds =
    List.init 3 ~f:(fun i ->
        _fr ~name:(sprintf "fold-%03d" i) ~variant:1.0 ~baseline:0.5)
  in
  assert_raises
    (Failure
       "Fold_gate.evaluate: fold count mismatch — gate.n=5 but got 3 folds")
    (fun () -> FG.evaluate gate folds)

(* ---------- Full pass ---------- *)

let test_full_pass_5_of_5 _ =
  let gate = _gate ~metric:Sharpe ~m:3 ~n:5 ~worst_delta:0.5 () in
  let folds =
    List.init 5 ~f:(fun i ->
        _fr ~name:(sprintf "fold-%03d" i) ~variant:1.0 ~baseline:0.5)
  in
  (* Inline-record variants can't be projected via [function FG.Pass p -> Some
     p] without the type escaping. Destructure inline and assert on the bare
     fields. *)
  let verdict = FG.evaluate gate folds in
  match verdict with
  | FG.Pass { wins; n } ->
      assert_that wins (equal_to 5);
      assert_that n (equal_to 5)
  | FG.Fail _ -> assert_failure "Expected Pass, got Fail"

(* ---------- M-threshold miss ---------- *)

let test_m_threshold_miss _ =
  (* Variant wins 2 of 5; gate requires 4. *)
  let gate = _gate ~metric:Sharpe ~m:4 ~n:5 ~worst_delta:1.0 () in
  let folds =
    [
      _fr ~name:"fold-000" ~variant:1.0 ~baseline:0.5;
      _fr ~name:"fold-001" ~variant:1.0 ~baseline:0.5;
      _fr ~name:"fold-002" ~variant:0.3 ~baseline:0.5;
      _fr ~name:"fold-003" ~variant:0.4 ~baseline:0.5;
      _fr ~name:"fold-004" ~variant:0.4 ~baseline:0.5;
    ]
  in
  let verdict = FG.evaluate gate folds in
  match verdict with
  | FG.Fail { wins; n; reason; _ } ->
      assert_that wins (equal_to 2);
      assert_that n (equal_to 5);
      assert_that
        (String.is_substring reason ~substring:"M-threshold")
        (equal_to true)
  | FG.Pass _ -> assert_failure "Expected Fail (M-threshold)"

(* ---------- Δ-threshold miss ---------- *)

let test_delta_threshold_miss _ =
  (* Variant wins 4 of 5 (passes M) but one fold has a 0.5 shortfall > delta=0.1. *)
  let gate = _gate ~metric:Sharpe ~m:3 ~n:5 ~worst_delta:0.1 () in
  let folds =
    [
      _fr ~name:"fold-000" ~variant:1.0 ~baseline:0.5;
      _fr ~name:"fold-001" ~variant:1.0 ~baseline:0.5;
      _fr ~name:"fold-002" ~variant:1.0 ~baseline:0.5;
      _fr ~name:"fold-003" ~variant:1.0 ~baseline:0.5;
      _fr ~name:"fold-004" ~variant:0.0 ~baseline:0.5;
    ]
  in
  let verdict = FG.evaluate gate folds in
  match verdict with
  | FG.Fail { wins; worst_fold; worst_gap; reason; _ } ->
      assert_that wins (equal_to 4);
      assert_that worst_fold (equal_to "fold-004");
      assert_that worst_gap (float_equal 0.5);
      assert_that
        (String.is_substring reason ~substring:"Δ-threshold")
        (equal_to true)
  | FG.Pass _ -> assert_failure "Expected Fail (Δ-threshold)"

(* ---------- Baseline tie counts as baseline win ---------- *)

let test_tie_counts_as_baseline_win _ =
  let gate = _gate ~metric:Sharpe ~m:1 ~n:3 ~worst_delta:1.0 () in
  let folds =
    [
      _fr ~name:"fold-000" ~variant:0.5 ~baseline:0.5;
      _fr ~name:"fold-001" ~variant:0.5 ~baseline:0.5;
      _fr ~name:"fold-002" ~variant:0.5 ~baseline:0.5;
    ]
  in
  let verdict = FG.evaluate gate folds in
  match verdict with
  | FG.Fail { wins; _ } -> assert_that wins (equal_to 0)
  | FG.Pass _ -> assert_failure "Expected Fail on all-tie"

(* ---------- MaxDrawdownPct inverts direction ---------- *)

let test_drawdown_inverted_direction _ =
  (* Lower DD is better. Variant has 10% DD vs baseline 20%; variant wins. *)
  let gate = _gate ~metric:MaxDrawdownPct ~m:3 ~n:3 ~worst_delta:5.0 () in
  let folds =
    [
      _fr ~name:"fold-000" ~variant:10.0 ~baseline:20.0;
      _fr ~name:"fold-001" ~variant:8.0 ~baseline:15.0;
      _fr ~name:"fold-002" ~variant:12.0 ~baseline:13.0;
    ]
  in
  let verdict = FG.evaluate gate folds in
  match verdict with
  | FG.Pass { wins; _ } -> assert_that wins (equal_to 3)
  | FG.Fail _ -> assert_failure "Expected Pass on inverted DD"

let test_drawdown_inverted_delta_miss _ =
  let gate = _gate ~metric:MaxDrawdownPct ~m:0 ~n:3 ~worst_delta:2.0 () in
  let folds =
    [
      _fr ~name:"fold-000" ~variant:10.0 ~baseline:11.0;
      _fr ~name:"fold-001" ~variant:8.0 ~baseline:9.0;
      _fr ~name:"fold-002" ~variant:25.0 ~baseline:15.0;
      (* variant_dd 25 > baseline_dd 15 + delta 2 = 17 → fail *)
    ]
  in
  let verdict = FG.evaluate gate folds in
  match verdict with
  | FG.Fail { worst_fold; worst_gap; _ } ->
      assert_that worst_fold (equal_to "fold-002");
      assert_that worst_gap (float_equal 10.0)
  | FG.Pass _ -> assert_failure "Expected Fail on inverted-DD Δ miss"

(* ---------- Boundary: variant_score - baseline = worst_delta exactly (Pass) ---------- *)

let test_exact_delta_boundary_passes _ =
  (* worst_delta=0.5 and a fold trails by exactly 0.5 — must Pass per ">". *)
  let gate = _gate ~metric:Sharpe ~m:0 ~n:2 ~worst_delta:0.5 () in
  let folds =
    [
      _fr ~name:"fold-000" ~variant:1.0 ~baseline:0.5;
      _fr ~name:"fold-001" ~variant:0.0 ~baseline:0.5;
      (* trails by 0.5 = delta, not > *)
    ]
  in
  let verdict = FG.evaluate gate folds in
  match verdict with
  | FG.Pass _ -> ()
  | FG.Fail _ -> assert_failure "Expected Pass at exact-delta boundary"

(* ---------- Sexp round-trip on gate ---------- *)

let test_gate_sexp_round_trip _ =
  let gate = _gate ~metric:Calmar ~m:18 ~n:25 ~worst_delta:0.20 () in
  let parsed = FG.t_of_sexp (FG.sexp_of_t gate) in
  assert_that parsed
    (all_of
       [
         field (fun (g : FG.t) -> g.metric) (equal_to FG.Calmar);
         field (fun (g : FG.t) -> g.m) (equal_to 18);
         field (fun (g : FG.t) -> g.n) (equal_to 25);
         field (fun (g : FG.t) -> g.worst_delta) (float_equal 0.20);
       ])

let suite =
  "Fold_gate"
  >::: [
         "higher_is_better" >:: test_higher_is_better;
         "n=0 raises" >:: test_n_zero_raises;
         "m out of range raises" >:: test_m_out_of_range_raises;
         "negative delta raises" >:: test_negative_delta_raises;
         "fold count mismatch raises" >:: test_fold_count_mismatch_raises;
         "full pass 5/5" >:: test_full_pass_5_of_5;
         "M-threshold miss" >:: test_m_threshold_miss;
         "Δ-threshold miss" >:: test_delta_threshold_miss;
         "tie counts as baseline win" >:: test_tie_counts_as_baseline_win;
         "drawdown inverted direction pass" >:: test_drawdown_inverted_direction;
         "drawdown inverted Δ miss" >:: test_drawdown_inverted_delta_miss;
         "exact-delta boundary passes" >:: test_exact_delta_boundary_passes;
         "gate sexp round-trip" >:: test_gate_sexp_round_trip;
       ]

let () = run_test_tt_main suite
