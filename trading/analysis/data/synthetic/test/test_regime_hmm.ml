open OUnit2
open Core
open Matchers
open Synthetic

(* ------------------------------------------------------------------ *)
(* Validation                                                           *)
(* ------------------------------------------------------------------ *)

let test_default_validates _ =
  assert_that (Regime_hmm.validate Regime_hmm.default) is_ok

let test_validate_rejects_non_summing_row _ =
  let bad : Regime_hmm.t =
    {
      initial_regime = Bull;
      transitions =
        [
          (Bull, [ (Bull, 0.5); (Bear, 0.2); (Crisis, 0.1) ]);
          (Bear, [ (Bull, 0.05); (Bear, 0.93); (Crisis, 0.02) ]);
          (Crisis, [ (Bull, 0.10); (Bear, 0.25); (Crisis, 0.65) ]);
        ];
    }
  in
  assert_that (Regime_hmm.validate bad) (is_error_with Status.Invalid_argument)

let test_validate_rejects_negative_prob _ =
  let bad : Regime_hmm.t =
    {
      initial_regime = Bull;
      transitions =
        [
          (Bull, [ (Bull, 1.1); (Bear, -0.05); (Crisis, -0.05) ]);
          (Bear, [ (Bull, 0.05); (Bear, 0.93); (Crisis, 0.02) ]);
          (Crisis, [ (Bull, 0.10); (Bear, 0.25); (Crisis, 0.65) ]);
        ];
    }
  in
  assert_that (Regime_hmm.validate bad) (is_error_with Status.Invalid_argument)

let test_validate_rejects_missing_row _ =
  let bad : Regime_hmm.t =
    {
      initial_regime = Bull;
      transitions =
        [
          (Bull, [ (Bull, 1.0); (Bear, 0.0); (Crisis, 0.0) ]);
          (Bear, [ (Bull, 0.05); (Bear, 0.93); (Crisis, 0.02) ]);
          (* Crisis row missing *)
        ];
    }
  in
  assert_that (Regime_hmm.validate bad) (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* Sampling                                                             *)
(* ------------------------------------------------------------------ *)

let test_sample_path_zero_steps_is_empty _ =
  assert_that
    (Regime_hmm.sample_path Regime_hmm.default ~n_steps:0 ~seed:1)
    is_empty

let test_sample_path_first_element_is_initial _ =
  let path = Regime_hmm.sample_path Regime_hmm.default ~n_steps:10 ~seed:42 in
  assert_that (List.hd path) (is_some_and (equal_to Regime_hmm.Bull))

let test_sample_path_deterministic _ =
  let p1 = Regime_hmm.sample_path Regime_hmm.default ~n_steps:200 ~seed:7 in
  let p2 = Regime_hmm.sample_path Regime_hmm.default ~n_steps:200 ~seed:7 in
  assert_that (List.equal Regime_hmm.equal_regime p1 p2) (equal_to true)

let test_sample_path_different_seeds_differ _ =
  let p1 = Regime_hmm.sample_path Regime_hmm.default ~n_steps:200 ~seed:7 in
  let p2 = Regime_hmm.sample_path Regime_hmm.default ~n_steps:200 ~seed:8 in
  assert_that (List.equal Regime_hmm.equal_regime p1 p2) (equal_to false)

(* ------------------------------------------------------------------ *)
(* Persistence — Bull initial state with rare-crisis transitions stays  *)
(* mostly Bull over 100 steps.                                          *)
(* ------------------------------------------------------------------ *)

let test_bull_persistence_over_100_steps _ =
  let path = Regime_hmm.sample_path Regime_hmm.default ~n_steps:100 ~seed:13 in
  let bull_count =
    List.count path ~f:(fun r -> Regime_hmm.equal_regime r Bull)
  in
  (* With P(Bull|Bull) = 0.97, expected Bull count is well above 50 even
     with multiple regime switches. We pin a generous floor (60/100) so
     the test isn't brittle but still catches the catastrophic case where
     the chain leaves Bull immediately. *)
  assert_that bull_count (gt (module Int_ord) 60)

(* ------------------------------------------------------------------ *)
(* Persistence — over 1000 steps the average Bull-segment length is     *)
(* within ±50% of the theoretical mean ≈ 1 / (1 - 0.97) ≈ 33 steps.     *)
(* ------------------------------------------------------------------ *)

let _bull_segment_lengths path =
  let _, _, segments =
    List.fold path ~init:(None, 0, []) ~f:(fun (current, run_len, acc) r ->
        let is_bull = Regime_hmm.equal_regime r Bull in
        match current with
        | None when is_bull -> (Some Regime_hmm.Bull, 1, acc)
        | None -> (None, 0, acc)
        | Some _ when is_bull -> (Some Regime_hmm.Bull, run_len + 1, acc)
        | Some _ -> (None, 0, run_len :: acc))
  in
  segments

let test_average_bull_segment_within_band _ =
  (* Use a long path with multiple seeds aggregated; a single 1000-step
     path has high variance in segment length. Aggregating across seeds
     stabilises the empirical mean while keeping the test deterministic. *)
  let all_segments =
    List.concat_map [ 1; 2; 3; 4; 5; 6; 7; 8 ] ~f:(fun s ->
        let path =
          Regime_hmm.sample_path Regime_hmm.default ~n_steps:1000 ~seed:s
        in
        _bull_segment_lengths path)
  in
  let n = List.length all_segments in
  let mean =
    if n = 0 then 0.0
    else
      Float.of_int (List.sum (module Int) all_segments ~f:Fn.id)
      /. Float.of_int n
  in
  (* Theoretical mean = 1 / (1 - 0.97) = 33.33. Tolerance ±50% = [16.67, 50]. *)
  assert_that mean (is_between (module Float_ord) ~low:16.67 ~high:50.0)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "regime_hmm"
  >::: [
         "default validates" >:: test_default_validates;
         "validate rejects non-summing row"
         >:: test_validate_rejects_non_summing_row;
         "validate rejects negative prob"
         >:: test_validate_rejects_negative_prob;
         "validate rejects missing row" >:: test_validate_rejects_missing_row;
         "sample_path n=0 is empty" >:: test_sample_path_zero_steps_is_empty;
         "sample_path first element is initial"
         >:: test_sample_path_first_element_is_initial;
         "sample_path deterministic in seed" >:: test_sample_path_deterministic;
         "sample_path differs across seeds"
         >:: test_sample_path_different_seeds_differ;
         "bull persists over 100 steps" >:: test_bull_persistence_over_100_steps;
         "average bull-segment length within ±50% of theoretical"
         >:: test_average_bull_segment_within_band;
       ]

let () = run_test_tt_main suite
