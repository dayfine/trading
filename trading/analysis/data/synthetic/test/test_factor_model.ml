open OUnit2
open Core
open Matchers
open Synthetic

(* ------------------------------------------------------------------ *)
(* loading_distribution validation                                      *)
(* ------------------------------------------------------------------ *)

let test_default_loading_distribution_validates _ =
  assert_that
    (Factor_model.validate_loading_distribution
       Factor_model.default_loading_distribution)
    is_ok

let test_loading_distribution_rejects_zero_stddev _ =
  let bad =
    { Factor_model.default_loading_distribution with stddev = 0.0 }
  in
  assert_that
    (Factor_model.validate_loading_distribution bad)
    (is_error_with Status.Invalid_argument)

let test_loading_distribution_rejects_inverted_range _ =
  let bad =
    { Factor_model.default_loading_distribution with min_value = 2.5; max_value = 0.2 }
  in
  assert_that
    (Factor_model.validate_loading_distribution bad)
    (is_error_with Status.Invalid_argument)

let test_loading_distribution_rejects_out_of_range_mean _ =
  let bad =
    { Factor_model.default_loading_distribution with mean = 5.0 }
  in
  assert_that
    (Factor_model.validate_loading_distribution bad)
    (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* idio_distribution validation                                         *)
(* ------------------------------------------------------------------ *)

let test_default_idio_distribution_validates _ =
  assert_that
    (Factor_model.validate_idio_distribution
       Factor_model.default_idio_distribution)
    is_ok

let test_idio_distribution_rejects_non_stationary _ =
  let bad =
    {
      Factor_model.default_idio_distribution with
      alpha = 0.6;
      beta = 0.5;
    }
  in
  assert_that
    (Factor_model.validate_idio_distribution bad)
    (is_error_with Status.Invalid_argument)

let test_idio_distribution_rejects_zero_omega _ =
  let bad =
    { Factor_model.default_idio_distribution with omega_mean = 0.0 }
  in
  assert_that
    (Factor_model.validate_idio_distribution bad)
    (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* sample_betas — output shape, range, determinism                      *)
(* ------------------------------------------------------------------ *)

let test_sample_betas_length _ =
  let betas =
    Factor_model.sample_betas Factor_model.default_loading_distribution
      ~n:50 ~seed:7
  in
  assert_that betas (size_is 50)

let test_sample_betas_in_range _ =
  let dist = Factor_model.default_loading_distribution in
  let betas = Factor_model.sample_betas dist ~n:200 ~seed:23 in
  let in_range =
    List.for_all betas ~f:(fun b ->
        Float.(b >= dist.min_value) && Float.(b <= dist.max_value))
  in
  assert_that in_range (equal_to true)

let test_sample_betas_zero_n _ =
  let betas =
    Factor_model.sample_betas Factor_model.default_loading_distribution
      ~n:0 ~seed:1
  in
  assert_that betas (size_is 0)

let test_sample_betas_deterministic _ =
  let dist = Factor_model.default_loading_distribution in
  let a = Factor_model.sample_betas dist ~n:100 ~seed:11 in
  let b = Factor_model.sample_betas dist ~n:100 ~seed:11 in
  assert_that (List.equal Float.equal a b) (equal_to true)

let test_sample_betas_different_seeds_differ _ =
  let dist = Factor_model.default_loading_distribution in
  let a = Factor_model.sample_betas dist ~n:100 ~seed:11 in
  let b = Factor_model.sample_betas dist ~n:100 ~seed:13 in
  assert_that (List.equal Float.equal a b) (equal_to false)

let test_sample_betas_empirical_mean_near_target _ =
  let dist =
    {
      Factor_model.mean = 1.0;
      stddev = 0.4;
      min_value = 0.2;
      max_value = 2.5;
    }
  in
  let n = 10_000 in
  let betas = Factor_model.sample_betas dist ~n ~seed:101 in
  let mean = List.sum (module Float) betas ~f:Fn.id /. Float.of_int n in
  (* Wide tolerance: truncation biases the mean slightly. The configured
     center is 1.0 and the truncation [0.2, 2.5] is roughly symmetric around
     it, so the empirical mean should land within ±0.1 of 1.0. *)
  assert_that mean
    (is_between (module Float_ord) ~low:0.9 ~high:1.1)

(* ------------------------------------------------------------------ *)
(* sample_idio_params — output shape, stationarity, determinism         *)
(* ------------------------------------------------------------------ *)

let test_sample_idio_params_length _ =
  let params =
    Factor_model.sample_idio_params Factor_model.default_idio_distribution
      ~n:30 ~seed:5
  in
  assert_that params (size_is 30)

let test_sample_idio_params_all_stationary _ =
  let params =
    Factor_model.sample_idio_params Factor_model.default_idio_distribution
      ~n:100 ~seed:5
  in
  let all_stationary =
    List.for_all params ~f:(fun (p : Garch.params) ->
        Float.(p.omega > 0.0)
        && Float.(p.alpha >= 0.0)
        && Float.(p.beta >= 0.0)
        && Float.(p.alpha +. p.beta < 1.0))
  in
  assert_that all_stationary (equal_to true)

let test_sample_idio_params_deterministic _ =
  let a =
    Factor_model.sample_idio_params Factor_model.default_idio_distribution
      ~n:20 ~seed:99
  in
  let b =
    Factor_model.sample_idio_params Factor_model.default_idio_distribution
      ~n:20 ~seed:99
  in
  assert_that (List.equal Garch.equal_params a b) (equal_to true)

let test_sample_idio_params_omegas_vary _ =
  let params =
    Factor_model.sample_idio_params Factor_model.default_idio_distribution
      ~n:50 ~seed:5
  in
  let omegas = List.map params ~f:(fun (p : Garch.params) -> p.omega) in
  let distinct = List.dedup_and_sort omegas ~compare:Float.compare in
  (* Log-normal sampling should yield distinct omegas; collapsing to a single
     value would indicate the lognormal step is broken. *)
  assert_that (List.length distinct) (gt (module Int_ord) 40)

let test_sample_idio_params_zero_sigma_collapses _ =
  let dist =
    { Factor_model.default_idio_distribution with omega_lognormal_sigma = 0.0 }
  in
  let params = Factor_model.sample_idio_params dist ~n:10 ~seed:5 in
  let omegas = List.map params ~f:(fun (p : Garch.params) -> p.omega) in
  let all_equal =
    List.for_all omegas ~f:(fun o -> Float.(abs (o -. dist.omega_mean) < 1e-12))
  in
  assert_that all_equal (equal_to true)

(* ------------------------------------------------------------------ *)
(* generate_symbol_returns — length, sanity, determinism                *)
(* ------------------------------------------------------------------ *)

let _const_market_returns ~n value = List.init n ~f:(fun _ -> value)

let test_generate_symbol_returns_length _ =
  let market = _const_market_returns ~n:300 0.0005 in
  let returns =
    Factor_model.generate_symbol_returns ~market_returns:market ~beta:1.0
      ~idio_params:{ Garch.omega = 1e-5; alpha = 0.05; beta = 0.90 }
      ~seed:42
  in
  assert_that returns (size_is 300)

let test_generate_symbol_returns_empty_market _ =
  let returns =
    Factor_model.generate_symbol_returns ~market_returns:[] ~beta:1.0
      ~idio_params:{ Garch.omega = 1e-5; alpha = 0.05; beta = 0.90 }
      ~seed:42
  in
  assert_that returns (size_is 0)

let test_generate_symbol_returns_deterministic _ =
  let market = _const_market_returns ~n:100 0.0005 in
  let a =
    Factor_model.generate_symbol_returns ~market_returns:market ~beta:1.2
      ~idio_params:{ Garch.omega = 1e-5; alpha = 0.05; beta = 0.90 }
      ~seed:88
  in
  let b =
    Factor_model.generate_symbol_returns ~market_returns:market ~beta:1.2
      ~idio_params:{ Garch.omega = 1e-5; alpha = 0.05; beta = 0.90 }
      ~seed:88
  in
  assert_that (List.equal Float.equal a b) (equal_to true)

let test_generate_symbol_returns_beta_zero_strips_market _ =
  (* β=0 means r_i = ε_i (no market exposure). Setting omega very small keeps
     ε_i tiny too — the resulting returns should be near zero regardless of
     the market series magnitude. *)
  let market = _const_market_returns ~n:50 0.01 in
  let returns =
    Factor_model.generate_symbol_returns ~market_returns:market ~beta:0.0
      ~idio_params:{ Garch.omega = 1e-12; alpha = 0.0; beta = 0.0 }
      ~seed:42
  in
  let max_abs =
    List.fold returns ~init:0.0 ~f:(fun acc r ->
        Float.max acc (Float.abs r))
  in
  (* All returns should be very small — vol baseline is sqrt(1e-12) ≈ 1e-6. *)
  assert_that max_abs (lt (module Float_ord) 1e-4)

let test_generate_symbol_returns_beta_one_reproduces_market _ =
  (* β=1 with deterministically-zero idio noise (omega → 0, α = β = 0)
     should reproduce the market returns exactly (modulo tiny GARCH baseline
     vol). *)
  let market = List.init 50 ~f:(fun i -> Float.of_int i *. 0.001) in
  let returns =
    Factor_model.generate_symbol_returns ~market_returns:market ~beta:1.0
      ~idio_params:{ Garch.omega = 1e-20; alpha = 0.0; beta = 0.0 }
      ~seed:42
  in
  (* The market term dominates by ~14 orders of magnitude; check elementwise
     equality up to a loose epsilon. *)
  let close_enough =
    List.for_all2_exn market returns ~f:(fun m r ->
        Float.(abs (r -. m) < 1e-5))
  in
  assert_that close_enough (equal_to true)

(* ------------------------------------------------------------------ *)
(* Sample-betas + idio params: validation paths via Invalid_argument   *)
(* ------------------------------------------------------------------ *)

let test_sample_betas_invalid_distribution_raises _ =
  let bad =
    { Factor_model.default_loading_distribution with stddev = 0.0 }
  in
  let did_raise =
    try
      let _ = Factor_model.sample_betas bad ~n:5 ~seed:1 in
      false
    with Invalid_argument _ -> true
  in
  assert_that did_raise (equal_to true)

let test_sample_idio_params_invalid_raises _ =
  let bad =
    { Factor_model.default_idio_distribution with alpha = 0.6; beta = 0.5 }
  in
  let did_raise =
    try
      let _ = Factor_model.sample_idio_params bad ~n:5 ~seed:1 in
      false
    with Invalid_argument _ -> true
  in
  assert_that did_raise (equal_to true)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "factor_model"
  >::: [
         (* loading distribution validation *)
         "default loading distribution validates"
         >:: test_default_loading_distribution_validates;
         "loading distribution rejects zero stddev"
         >:: test_loading_distribution_rejects_zero_stddev;
         "loading distribution rejects inverted range"
         >:: test_loading_distribution_rejects_inverted_range;
         "loading distribution rejects out-of-range mean"
         >:: test_loading_distribution_rejects_out_of_range_mean;
         (* idio distribution validation *)
         "default idio distribution validates"
         >:: test_default_idio_distribution_validates;
         "idio distribution rejects non-stationary"
         >:: test_idio_distribution_rejects_non_stationary;
         "idio distribution rejects zero omega"
         >:: test_idio_distribution_rejects_zero_omega;
         (* sample_betas *)
         "sample_betas: length" >:: test_sample_betas_length;
         "sample_betas: in range" >:: test_sample_betas_in_range;
         "sample_betas: zero n" >:: test_sample_betas_zero_n;
         "sample_betas: deterministic" >:: test_sample_betas_deterministic;
         "sample_betas: different seeds differ"
         >:: test_sample_betas_different_seeds_differ;
         "sample_betas: empirical mean near target"
         >:: test_sample_betas_empirical_mean_near_target;
         "sample_betas: invalid distribution raises"
         >:: test_sample_betas_invalid_distribution_raises;
         (* sample_idio_params *)
         "sample_idio_params: length" >:: test_sample_idio_params_length;
         "sample_idio_params: all stationary"
         >:: test_sample_idio_params_all_stationary;
         "sample_idio_params: deterministic"
         >:: test_sample_idio_params_deterministic;
         "sample_idio_params: omegas vary"
         >:: test_sample_idio_params_omegas_vary;
         "sample_idio_params: zero sigma collapses"
         >:: test_sample_idio_params_zero_sigma_collapses;
         "sample_idio_params: invalid raises"
         >:: test_sample_idio_params_invalid_raises;
         (* generate_symbol_returns *)
         "generate_symbol_returns: length"
         >:: test_generate_symbol_returns_length;
         "generate_symbol_returns: empty market"
         >:: test_generate_symbol_returns_empty_market;
         "generate_symbol_returns: deterministic"
         >:: test_generate_symbol_returns_deterministic;
         "generate_symbol_returns: beta=0 strips market"
         >:: test_generate_symbol_returns_beta_zero_strips_market;
         "generate_symbol_returns: beta=1 reproduces market"
         >:: test_generate_symbol_returns_beta_one_reproduces_market;
       ]

let () = run_test_tt_main suite
