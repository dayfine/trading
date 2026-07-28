(** Unit tests for {!Tuner.Bayesian_opt_cholesky}.

    All matrix arithmetic in this file is done with plain OCaml loops rather
    than [Owl.Mat.dot]. That is deliberate: these tests exist because the
    vendored BLAS was found returning wrong results on some hosts, so a test
    that verified the factorisation using the same BLAS would be able to
    validate a wrong answer against a wrong reference. See the module's [.mli]
    for the full account. *)

open OUnit2
open Core
open Matchers
module Chol = Tuner.Bayesian_opt_cholesky
module Mat = Owl.Mat

(* ---------- Fixtures and plain-OCaml matrix helpers ---------- *)

(** Sizes spanning the band in which the vendored LAPACK [dpotrf] was measured
    wrong on an [Intel Xeon 6973P-C] runner (33..63), plus one below it, one
    above, and 100 — the largest matrix order reachable in production, since
    [total_budget] bounds the observation count and the largest value in any
    committed spec is [(total_budget 100)]. The defect is discontinuous in n
    (correct at n <= 32, wrong from 33), so coverage has to reach the top of the
    reachable range rather than stop at a convenient size. A regression in the
    factorisation shows up as one of these failing while the small case still
    passes. *)
let _certified_sizes = [ 4; 32; 33; 40; 63; 64; 100 ]

(** Largest absolute deviation of [L * L^T] from [k], computed without BLAS. *)
let _reconstruction_error l ~k ~n =
  let worst = ref 0.0 in
  for i = 0 to n - 1 do
    for j = 0 to n - 1 do
      let acc = ref 0.0 in
      for p = 0 to n - 1 do
        acc := !acc +. (Mat.get l i p *. Mat.get l j p)
      done;
      let deviation = Float.abs (!acc -. Mat.get k i j) in
      if Float.( > ) deviation !worst then worst := deviation
    done
  done;
  !worst

(** Largest absolute entry strictly above the diagonal of [l]. *)
let _max_above_diagonal l ~n =
  let worst = ref 0.0 in
  for i = 0 to n - 1 do
    for j = i + 1 to n - 1 do
      let v = Float.abs (Mat.get l i j) in
      if Float.( > ) v !worst then worst := v
    done
  done;
  !worst

(** A symmetric, well-conditioned [n x n] matrix. Built entrywise from a
    deterministic formula so the fixture is identical on every host and needs no
    RNG.

    Not diagonally dominant beyond the smallest certified size: from n=32 on,
    some rows' off-diagonal sum exceeds the diagonal, which cycles through 2, 3,
    4 (worst case n=100: 61/100 rows violate it, with an off-diagonal row sum of
    ~3.5 in the middle rows against a diagonal of 2-4). Positive-definiteness is
    instead confirmed directly: a pure-OCaml (no-BLAS) power-iteration estimate
    of the smallest eigenvalue holds steady at ~1.83, comfortably bounded away
    from 0, at every size in [_certified_sizes]. *)
let _well_conditioned_spd ~n =
  Mat.init_2d n n (fun i j ->
      if i = j then 2.0 +. Float.of_int (i % 3)
      else 0.5 /. (1.0 +. Float.abs (Float.of_int (i - j))))

let _factor m ~n =
  Chol.chol_with_nugget_escalation m ~n ~noise_variance:0.0 ~signal_variance:1.0

(* ---------- Factorisation correctness ---------- *)

let test_reconstructs_input_across_sizes _ =
  (* L * L^T must reproduce the input at every order, including the band where
     the vendored LAPACK dpotrf silently returned a ~5-7% wrong factor. *)
  let errors =
    List.map _certified_sizes ~f:(fun n ->
        let k = _well_conditioned_spd ~n in
        _reconstruction_error (_factor k ~n) ~k ~n)
  in
  assert_that errors
    (each (fun e -> assert_that e (le (module Float_ord) 1e-12)))

let test_factor_is_lower_triangular _ =
  let n = 40 in
  let l = _factor (_well_conditioned_spd ~n) ~n in
  assert_that (_max_above_diagonal l ~n) (float_equal 0.0)

let test_input_matrix_is_not_modified _ =
  (* The contract says k is left untouched; escalation runs on a copy. An
     all-ones kernel is rank 1, so the escalation path is guaranteed to fire and
     the pre-fix implementation would widen the diagonal in place.

     noise_variance is 1e-4 rather than the 0.0 the other tests use, so the
     first escalation increment is 1e-4 — five orders of magnitude above
     Matchers' default float_equal epsilon of 1e-9. With 0.0 the increment is
     exactly 1e-9 and whether this test detects the mutation would be decided by
     one ulp of rounding rather than by the contract. Every entry is checked,
     not just the first, since escalation touches the whole diagonal. *)
  let n = 3 in
  let k = Mat.init_2d n n (fun _ _ -> 1.0) in
  let before =
    Array.init (n * n) ~f:(fun idx -> Mat.get k (idx / n) (idx % n))
  in
  let _ =
    Chol.chol_with_nugget_escalation k ~n ~noise_variance:1e-4
      ~signal_variance:1.0
  in
  let after =
    Array.init (n * n) ~f:(fun idx -> Mat.get k (idx / n) (idx % n))
  in
  assert_that (Array.to_list after)
    (elements_are (List.map (Array.to_list before) ~f:(fun v -> float_equal v)))

(* ---------- Nugget escalation ---------- *)

let test_duplicate_rows_succeed_via_escalation _ =
  (* An all-ones kernel is what identical observations produce: rank 1, so the
     bare factorisation fails at pivot 2 and only the nugget rescues it. *)
  let n = 5 in
  let k = Mat.init_2d n n (fun _ _ -> 1.0) in
  let l = _factor k ~n in
  assert_that (_max_above_diagonal l ~n) (float_equal 0.0)

let test_escalation_stays_within_jitter_cap _ =
  (* Cumulative jitter is capped at 1e-2 * signal_variance per increment, so a
     rescued all-ones kernel must reconstruct to within roughly that much. *)
  let n = 5 in
  let k = Mat.init_2d n n (fun _ _ -> 1.0) in
  let error = _reconstruction_error (_factor k ~n) ~k ~n in
  assert_that error (is_between (module Float_ord) ~low:0.0 ~high:2e-2)

(* ---------- Diagnosable failures ---------- *)

let test_genuinely_indefinite_input_raises_with_pivot _ =
  (* Negative definite: no jitter within the cap can rescue it. The message must
     name the failing pivot rather than surfacing a bare LAPACK error code. *)
  let n = 4 in
  let k = Mat.init_2d n n (fun i j -> if i = j then -1.0 else 0.0) in
  let message =
    try
      let _ = _factor k ~n in
      "no exception raised"
    with Failure msg -> msg
  in
  assert_that message
    (all_of
       [
         contains_substring "not positive definite";
         contains_substring "pivot 1";
       ])

let test_non_finite_entry_raises_invalid_argument _ =
  let n = 3 in
  let k =
    Mat.init_2d n n (fun i j -> if i = 1 && j = 2 then Float.nan else 1.0)
  in
  let message =
    try
      let _ = _factor k ~n in
      "no exception raised"
    with Invalid_argument msg -> msg
  in
  assert_that message
    (all_of [ contains_substring "not finite"; contains_substring "(1, 2)" ])

let test_infinite_entry_raises_invalid_argument _ =
  let n = 3 in
  let k =
    Mat.init_2d n n (fun i j -> if i = 0 && j = 0 then Float.infinity else 1.0)
  in
  let message =
    try
      let _ = _factor k ~n in
      "no exception raised"
    with Invalid_argument msg -> msg
  in
  assert_that message (contains_substring "not finite")

let suite =
  "Tuner.Bayesian_opt_cholesky"
  >::: [
         "reconstructs input across sizes"
         >:: test_reconstructs_input_across_sizes;
         "factor is lower triangular" >:: test_factor_is_lower_triangular;
         "input matrix is not modified" >:: test_input_matrix_is_not_modified;
         "duplicate rows succeed via escalation"
         >:: test_duplicate_rows_succeed_via_escalation;
         "escalation stays within jitter cap"
         >:: test_escalation_stays_within_jitter_cap;
         "genuinely indefinite input raises with pivot"
         >:: test_genuinely_indefinite_input_raises_with_pivot;
         "non-finite entry raises Invalid_argument"
         >:: test_non_finite_entry_raises_invalid_argument;
         "infinite entry raises Invalid_argument"
         >:: test_infinite_entry_raises_invalid_argument;
       ]

let () = run_test_tt_main suite
