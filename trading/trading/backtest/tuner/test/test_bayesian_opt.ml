(** Unit tests for {!Tuner.Bayesian_opt}. The objective is a synthetic function
    so no real backtest is required. Determinism is pinned by feeding fixed
    [Random.State.t] seeds. *)

open OUnit2
open Core
open Matchers
module BO = Tuner.Bayesian_opt

(* ---------- Test fixtures ---------- *)

let _make_rng seed = Stdlib.Random.State.make [| seed |]

(** 1D parabola peaked at [x = 3.0]: [f(x) = -(x - 3)²]. Maximum is [0.0] at
    [x = 3]. *)
let _parabola_1d params =
  let x = List.Assoc.find_exn params ~equal:String.equal "x" in
  -.((x -. 3.0) *. (x -. 3.0))

(** Branin function — a classic 2D BO benchmark. We negate it because the lib
    maximises. Minimum value of the original Branin is ~0.398 at three points;
    the negated maximum is ~ -0.398. *)
let _neg_branin params =
  let x = List.Assoc.find_exn params ~equal:String.equal "x" in
  let y = List.Assoc.find_exn params ~equal:String.equal "y" in
  let a = 1.0 in
  let b = 5.1 /. (4.0 *. Float.pi *. Float.pi) in
  let c = 5.0 /. Float.pi in
  let r = 6.0 in
  let s = 10.0 in
  let t = 1.0 /. (8.0 *. Float.pi) in
  let term1 = a *. Float.( ** ) (y -. (b *. x *. x) +. (c *. x) -. r) 2.0 in
  let term2 = s *. (1.0 -. t) *. Float.cos x in
  -.(term1 +. term2 +. s)

(** Run the BO loop for [budget] iterations with the given objective. *)
let _run_bo bo objective ~budget =
  let state = ref bo in
  for _ = 1 to budget do
    let params = BO.suggest_next !state in
    let metric = objective params in
    state := BO.observe !state { BO.parameters = params; metric }
  done;
  !state

(* ---------- Construction / validation ---------- *)

let test_create_with_empty_bounds_raises _ =
  let f () =
    let _ = BO.create (BO.create_config ~bounds:[] ()) in
    ()
  in
  assert_raises
    (Invalid_argument "Bayesian_opt.create: bounds must be non-empty") f

let test_create_with_inverted_bounds_raises _ =
  let f () =
    let _ = BO.create (BO.create_config ~bounds:[ ("x", (1.0, 0.0)) ] ()) in
    ()
  in
  assert_raises
    (Invalid_argument "Bayesian_opt.create: bound for x has min > max (1 > 0)")
    f

let test_create_with_negative_initial_random_raises _ =
  let f () =
    let _ =
      BO.create
        (BO.create_config ~bounds:[ ("x", (0.0, 1.0)) ] ~initial_random:(-1) ())
    in
    ()
  in
  assert_raises
    (Invalid_argument "Bayesian_opt.create: initial_random must be >= 0") f

let test_create_with_negative_total_budget_raises _ =
  let f () =
    let _ =
      BO.create
        (BO.create_config ~bounds:[ ("x", (0.0, 1.0)) ] ~total_budget:(-1) ())
    in
    ()
  in
  assert_raises
    (Invalid_argument "Bayesian_opt.create: total_budget must be >= 0") f

(* ---------- Empty-state behaviour ---------- *)

let test_best_is_none_when_no_observations _ =
  let bo = BO.create (BO.create_config ~bounds:[ ("x", (0.0, 1.0)) ] ()) in
  assert_that (BO.best bo) is_none

let test_all_observations_empty_for_fresh_state _ =
  let bo = BO.create (BO.create_config ~bounds:[ ("x", (0.0, 1.0)) ] ()) in
  assert_that (BO.all_observations bo) is_empty

let test_suggest_next_with_empty_observations_returns_random _ =
  (* With initial_random > 0 and no obs, must return a random point in
     bounds — never crashes (no GP to fit). *)
  let bo =
    BO.create
      (BO.create_config
         ~bounds:[ ("x", (0.0, 1.0)) ]
         ~initial_random:5 ~rng:(_make_rng 1) ())
  in
  let params = BO.suggest_next bo in
  let x = List.Assoc.find_exn params ~equal:String.equal "x" in
  assert_that x (is_between (module Float_ord) ~low:0.0 ~high:1.0)

(* ---------- Observe / best ---------- *)

let test_observe_appends_in_order _ =
  let bo = BO.create (BO.create_config ~bounds:[ ("x", (0.0, 1.0)) ] ()) in
  let bo = BO.observe bo { parameters = [ ("x", 0.1) ]; metric = 1.0 } in
  let bo = BO.observe bo { parameters = [ ("x", 0.2) ]; metric = 2.0 } in
  let bo = BO.observe bo { parameters = [ ("x", 0.3) ]; metric = 3.0 } in
  assert_that (BO.all_observations bo)
    (elements_are
       [
         field (fun (o : BO.observation) -> o.metric) (float_equal 1.0);
         field (fun (o : BO.observation) -> o.metric) (float_equal 2.0);
         field (fun (o : BO.observation) -> o.metric) (float_equal 3.0);
       ])

let test_best_picks_max_metric _ =
  let bo = BO.create (BO.create_config ~bounds:[ ("x", (0.0, 1.0)) ] ()) in
  let bo = BO.observe bo { parameters = [ ("x", 0.1) ]; metric = 1.0 } in
  let bo = BO.observe bo { parameters = [ ("x", 0.2) ]; metric = 5.0 } in
  let bo = BO.observe bo { parameters = [ ("x", 0.3) ]; metric = 3.0 } in
  assert_that (BO.best bo)
    (is_some_and
       (field (fun (o : BO.observation) -> o.metric) (float_equal 5.0)))

let test_best_tie_break_first_observation_wins _ =
  (* All three observations have metric 5.0 — first by eval order wins. *)
  let bo = BO.create (BO.create_config ~bounds:[ ("x", (0.0, 1.0)) ] ()) in
  let bo = BO.observe bo { parameters = [ ("x", 0.1) ]; metric = 5.0 } in
  let bo = BO.observe bo { parameters = [ ("x", 0.2) ]; metric = 5.0 } in
  let bo = BO.observe bo { parameters = [ ("x", 0.3) ]; metric = 5.0 } in
  assert_that (BO.best bo)
    (is_some_and
       (field
          (fun (o : BO.observation) ->
            List.Assoc.find_exn o.parameters ~equal:String.equal "x")
          (float_equal 0.1)))

(* ---------- Bounds enforcement ---------- *)

let test_suggest_next_random_phase_respects_bounds _ =
  (* 100 random suggestions in initial-random phase, all within bounds. *)
  let bo =
    BO.create
      (BO.create_config
         ~bounds:[ ("x", (10.0, 20.0)); ("y", (-5.0, -1.0)) ]
         ~initial_random:200 ~rng:(_make_rng 7) ())
  in
  let state = ref bo in
  for _ = 1 to 100 do
    let params = BO.suggest_next !state in
    let x = List.Assoc.find_exn params ~equal:String.equal "x" in
    let y = List.Assoc.find_exn params ~equal:String.equal "y" in
    assert_that x (is_between (module Float_ord) ~low:10.0 ~high:20.0);
    assert_that y (is_between (module Float_ord) ~low:(-5.0) ~high:(-1.0));
    state := BO.observe !state { parameters = params; metric = 0.0 }
  done

let test_suggest_next_gp_phase_respects_bounds _ =
  (* After observations, the GP-driven suggestions must still respect bounds. *)
  let bo =
    BO.create
      (BO.create_config
         ~bounds:[ ("x", (10.0, 20.0)) ]
         ~initial_random:3 ~rng:(_make_rng 9) ())
  in
  let bo = BO.observe bo { parameters = [ ("x", 12.0) ]; metric = -1.0 } in
  let bo = BO.observe bo { parameters = [ ("x", 15.0) ]; metric = 0.0 } in
  let bo = BO.observe bo { parameters = [ ("x", 18.0) ]; metric = -1.0 } in
  let state = ref bo in
  for _ = 1 to 50 do
    let params = BO.suggest_next !state in
    let x = List.Assoc.find_exn params ~equal:String.equal "x" in
    assert_that x (is_between (module Float_ord) ~low:10.0 ~high:20.0);
    state := BO.observe !state { parameters = params; metric = 0.0 }
  done

let test_degenerate_dimension_min_equals_max _ =
  (* When min == max, the lib should still function — the param is fixed. *)
  let bo =
    BO.create
      (BO.create_config
         ~bounds:[ ("fixed", (3.0, 3.0)); ("free", (0.0, 1.0)) ]
         ~initial_random:5 ~rng:(_make_rng 11) ())
  in
  let params = BO.suggest_next bo in
  let fixed = List.Assoc.find_exn params ~equal:String.equal "fixed" in
  assert_that fixed (float_equal 3.0)

(* ---------- Determinism ---------- *)

let test_determinism_same_seed_same_sequence _ =
  (* Two BO states with the same seed produce identical suggestion sequences. *)
  let bo1 =
    BO.create
      (BO.create_config
         ~bounds:[ ("x", (0.0, 1.0)); ("y", (0.0, 1.0)) ]
         ~initial_random:3 ~rng:(_make_rng 17) ())
  in
  let bo2 =
    BO.create
      (BO.create_config
         ~bounds:[ ("x", (0.0, 1.0)); ("y", (0.0, 1.0)) ]
         ~initial_random:3 ~rng:(_make_rng 17) ())
  in
  let suggest_chain bo =
    let state = ref bo in
    let xs = ref [] in
    for _ = 1 to 10 do
      let params = BO.suggest_next !state in
      xs := params :: !xs;
      state := BO.observe !state { parameters = params; metric = 0.0 }
    done;
    List.rev !xs
  in
  let seq1 = suggest_chain bo1 in
  let seq2 = suggest_chain bo2 in
  let pairs = List.zip_exn seq1 seq2 in
  List.iter pairs ~f:(fun (a, b) ->
      let xa = List.Assoc.find_exn a ~equal:String.equal "x" in
      let xb = List.Assoc.find_exn b ~equal:String.equal "x" in
      assert_that xa (float_equal xb))

(* ---------- Acquisition ---------- *)

let test_ei_and_ucb_produce_different_sequences _ =
  let bounds = [ ("x", (0.0, 6.0)) ] in
  let make acq seed =
    BO.create
      (BO.create_config ~bounds ~acquisition:acq ~initial_random:3
         ~rng:(_make_rng seed) ())
  in
  let bo_ei = make `Expected_improvement 5 in
  let bo_ucb = make (`Upper_confidence_bound 2.0) 5 in
  (* Seed both with the same observations — sigh, the random phase will differ
     because the RNG is consumed inside the lib; so we hand-seed observations
     and then take a single GP-phase suggestion for each. *)
  let seed_observations bo =
    let bo = BO.observe bo { parameters = [ ("x", 1.0) ]; metric = -4.0 } in
    let bo = BO.observe bo { parameters = [ ("x", 3.0) ]; metric = 0.0 } in
    let bo = BO.observe bo { parameters = [ ("x", 5.0) ]; metric = -4.0 } in
    bo
  in
  let bo_ei = seed_observations bo_ei in
  let bo_ucb = seed_observations bo_ucb in
  let next_ei = BO.suggest_next bo_ei in
  let next_ucb = BO.suggest_next bo_ucb in
  let xe = List.Assoc.find_exn next_ei ~equal:String.equal "x" in
  let xu = List.Assoc.find_exn next_ucb ~equal:String.equal "x" in
  (* They might happen to match if the RNG hits the same candidate, but with
     two acquisition functions of different shape over a non-trivial GP this is
     vanishingly unlikely on a well-separated seed. *)
  assert_that (Float.abs (xe -. xu)) (gt (module Float_ord) 1e-6)

let test_ucb_zero_beta_picks_max_mean _ =
  (* β = 0 reduces UCB to pure exploitation (just the GP mean). After
     observations, the next suggestion should be near the highest-metric obs. *)
  let bo =
    BO.create
      (BO.create_config
         ~bounds:[ ("x", (0.0, 6.0)) ]
         ~acquisition:(`Upper_confidence_bound 0.0) ~initial_random:0
         ~rng:(_make_rng 13) ())
  in
  let bo = BO.observe bo { parameters = [ ("x", 1.0) ]; metric = -4.0 } in
  let bo = BO.observe bo { parameters = [ ("x", 3.0) ]; metric = 0.0 } in
  let bo = BO.observe bo { parameters = [ ("x", 5.0) ]; metric = -4.0 } in
  let params = BO.suggest_next bo in
  let x = List.Assoc.find_exn params ~equal:String.equal "x" in
  (* Greedy on the mean — should pick something close to x = 3.0 where the
     mean peaks. Tolerance is generous because we only sample 1000 candidates. *)
  assert_that (Float.abs (x -. 3.0)) (lt (module Float_ord) 1.5)

(* ---------- Convergence ---------- *)

let test_bo_converges_on_1d_parabola _ =
  (* f(x) = -(x - 3)² over [0, 6]. BO should find a metric near 0.0 within
     30 evals. *)
  let bo =
    BO.create
      (BO.create_config
         ~bounds:[ ("x", (0.0, 6.0)) ]
         ~initial_random:5 ~rng:(_make_rng 23) ())
  in
  let final = _run_bo bo _parabola_1d ~budget:30 in
  let best = BO.best final in
  assert_that best
    (is_some_and
       (field
          (fun (o : BO.observation) -> o.metric)
          (gt (module Float_ord) (-0.5))))

let test_bo_converges_on_2d_branin _ =
  (* Negated Branin. Original Branin global min is ~0.398 → negated max ~-0.398.
     We ask for metric > -3.0 within 50 evals. *)
  let bo =
    BO.create
      (BO.create_config
         ~bounds:[ ("x", (-5.0, 10.0)); ("y", (0.0, 15.0)) ]
         ~initial_random:10 ~rng:(_make_rng 31) ())
  in
  let final = _run_bo bo _neg_branin ~budget:50 in
  let best = BO.best final in
  assert_that best
    (is_some_and
       (field
          (fun (o : BO.observation) -> o.metric)
          (gt (module Float_ord) (-3.0))))

(* ---------- Internal helpers ---------- *)

let test_rbf_kernel_self_equals_signal_variance _ =
  let k =
    BO.rbf_kernel ~length_scales:[| 1.0; 1.0 |] ~signal_variance:2.5
      [| 0.3; 0.7 |] [| 0.3; 0.7 |]
  in
  assert_that k (float_equal 2.5)

let test_rbf_kernel_decays_with_distance _ =
  let near =
    BO.rbf_kernel ~length_scales:[| 1.0 |] ~signal_variance:1.0 [| 0.0 |]
      [| 0.1 |]
  in
  let far =
    BO.rbf_kernel ~length_scales:[| 1.0 |] ~signal_variance:1.0 [| 0.0 |]
      [| 5.0 |]
  in
  assert_that near (gt (module Float_ord) far)

let test_rbf_kernel_dimension_mismatch_raises _ =
  let f () =
    let _ =
      BO.rbf_kernel ~length_scales:[| 1.0 |] ~signal_variance:1.0 [| 0.0 |]
        [| 0.0; 1.0 |]
    in
    ()
  in
  assert_raises (Invalid_argument "Bayesian_opt.rbf_kernel: dimension mismatch")
    f

let test_fit_gp_interpolates_observations _ =
  (* With near-zero noise, the GP mean at observed points should be very close
     to the observed values. *)
  let xs = [| [| 0.1 |]; [| 0.5 |]; [| 0.9 |] |] in
  let ys = [| 1.0; 4.0; 2.0 |] in
  let posterior =
    BO.fit_gp ~length_scales:[| 0.25 |] ~signal_variance:1.0
      ~noise_variance:1e-8 ~observations_x:xs ~observations_y:ys
  in
  let m0 = posterior.mean [| 0.1 |] in
  let m1 = posterior.mean [| 0.5 |] in
  let m2 = posterior.mean [| 0.9 |] in
  (* Tolerance loose because Cholesky jitter shifts the fit slightly. *)
  assert_that (Float.abs (m0 -. 1.0)) (lt (module Float_ord) 0.05);
  assert_that (Float.abs (m1 -. 4.0)) (lt (module Float_ord) 0.05);
  assert_that (Float.abs (m2 -. 2.0)) (lt (module Float_ord) 0.05)

let test_fit_gp_variance_at_observed_point_is_small _ =
  let xs = [| [| 0.1 |]; [| 0.5 |] |] in
  let ys = [| 1.0; 2.0 |] in
  let posterior =
    BO.fit_gp ~length_scales:[| 0.25 |] ~signal_variance:1.0
      ~noise_variance:1e-8 ~observations_x:xs ~observations_y:ys
  in
  let v = posterior.variance [| 0.1 |] in
  assert_that v (lt (module Float_ord) 1e-2)

let test_fit_gp_variance_far_from_observations_is_large _ =
  let xs = [| [| 0.5 |] |] in
  let ys = [| 0.0 |] in
  let posterior =
    BO.fit_gp ~length_scales:[| 0.1 |] ~signal_variance:1.0 ~noise_variance:1e-6
      ~observations_x:xs ~observations_y:ys
  in
  let v_far = posterior.variance [| 5.0 |] in
  let v_near = posterior.variance [| 0.5 |] in
  assert_that v_far (gt (module Float_ord) v_near)

let test_fit_gp_empty_observations_raises _ =
  let f () =
    let _ =
      BO.fit_gp ~length_scales:[| 0.25 |] ~signal_variance:1.0
        ~noise_variance:1e-6 ~observations_x:[||] ~observations_y:[||]
    in
    ()
  in
  assert_raises (Invalid_argument "Bayesian_opt.fit_gp: no observations") f

let test_fit_gp_y_length_mismatch_raises _ =
  let f () =
    let _ =
      BO.fit_gp ~length_scales:[| 0.25 |] ~signal_variance:1.0
        ~noise_variance:1e-6 ~observations_x:[| [| 0.0 |]; [| 1.0 |] |]
        ~observations_y:[| 0.0 |]
    in
    ()
  in
  assert_raises
    (Invalid_argument "Bayesian_opt.fit_gp: y length disagrees with x") f

let test_fit_gp_row_dim_mismatch_raises _ =
  let f () =
    let _ =
      (* observations_x has 2-dim rows but length_scales has 1 entry *)
      BO.fit_gp ~length_scales:[| 0.25 |] ~signal_variance:1.0
        ~noise_variance:1e-6
        ~observations_x:[| [| 0.0; 0.0 |] |]
        ~observations_y:[| 0.0 |]
    in
    ()
  in
  assert_raises
    (Invalid_argument
       "Bayesian_opt.fit_gp: observation dim disagrees with length_scales")
    f

let test_expected_improvement_zero_at_constant_posterior _ =
  (* If the posterior σ² is ~0 everywhere (i.e. the test point is essentially
     pinned by an observation), EI should be ~0. *)
  let xs = [| [| 0.5 |] |] in
  let ys = [| 1.0 |] in
  let posterior =
    BO.fit_gp ~length_scales:[| 0.25 |] ~signal_variance:1.0
      ~noise_variance:1e-10 ~observations_x:xs ~observations_y:ys
  in
  let ei = BO.expected_improvement ~posterior ~f_best:1.0 [| 0.5 |] in
  assert_that ei (lt (module Float_ord) 1e-2)

let test_ucb_increases_with_beta _ =
  let xs = [| [| 0.0 |] |] in
  let ys = [| 0.0 |] in
  let posterior =
    BO.fit_gp ~length_scales:[| 0.25 |] ~signal_variance:1.0
      ~noise_variance:1e-6 ~observations_x:xs ~observations_y:ys
  in
  let test_x = [| 0.8 |] in
  let ucb_low = BO.upper_confidence_bound ~posterior ~beta:0.5 test_x in
  let ucb_high = BO.upper_confidence_bound ~posterior ~beta:2.0 test_x in
  assert_that ucb_high (gt (module Float_ord) ucb_low)

let test_suggest_next_with_invalid_n_candidates_raises _ =
  let bo =
    BO.create
      (BO.create_config
         ~bounds:[ ("x", (0.0, 1.0)) ]
         ~initial_random:0 ~rng:(_make_rng 1) ())
  in
  let bo = BO.observe bo { parameters = [ ("x", 0.5) ]; metric = 0.0 } in
  let f () =
    let _ = BO.suggest_next_with_candidates bo ~n_candidates:0 in
    ()
  in
  assert_raises
    (Invalid_argument
       "Bayesian_opt.suggest_next_with_candidates: n_candidates must be >= 1")
    f

(* ---------- Test runner ---------- *)

let suite =
  "Tuner.Bayesian_opt"
  >::: [
         "create with empty bounds raises"
         >:: test_create_with_empty_bounds_raises;
         "create with inverted bounds raises"
         >:: test_create_with_inverted_bounds_raises;
         "create with negative initial_random raises"
         >:: test_create_with_negative_initial_random_raises;
         "create with negative total_budget raises"
         >:: test_create_with_negative_total_budget_raises;
         "best is None when no observations"
         >:: test_best_is_none_when_no_observations;
         "all_observations is empty for fresh state"
         >:: test_all_observations_empty_for_fresh_state;
         "suggest_next with empty observations returns random"
         >:: test_suggest_next_with_empty_observations_returns_random;
         "observe appends in order" >:: test_observe_appends_in_order;
         "best picks max metric" >:: test_best_picks_max_metric;
         "best tie-break: first observation wins"
         >:: test_best_tie_break_first_observation_wins;
         "suggest_next random phase respects bounds"
         >:: test_suggest_next_random_phase_respects_bounds;
         "suggest_next GP phase respects bounds"
         >:: test_suggest_next_gp_phase_respects_bounds;
         "degenerate dimension (min == max)"
         >:: test_degenerate_dimension_min_equals_max;
         "determinism: same seed -> same sequence"
         >:: test_determinism_same_seed_same_sequence;
         "EI and UCB produce different sequences"
         >:: test_ei_and_ucb_produce_different_sequences;
         "UCB with beta = 0 picks GP-mean argmax"
         >:: test_ucb_zero_beta_picks_max_mean;
         "BO converges on 1D parabola" >:: test_bo_converges_on_1d_parabola;
         "BO converges on 2D Branin" >:: test_bo_converges_on_2d_branin;
         "rbf_kernel: self equals signal_variance"
         >:: test_rbf_kernel_self_equals_signal_variance;
         "rbf_kernel: decays with distance"
         >:: test_rbf_kernel_decays_with_distance;
         "rbf_kernel: dimension mismatch raises"
         >:: test_rbf_kernel_dimension_mismatch_raises;
         "fit_gp: interpolates observations"
         >:: test_fit_gp_interpolates_observations;
         "fit_gp: variance at observed point is small"
         >:: test_fit_gp_variance_at_observed_point_is_small;
         "fit_gp: variance far from observations is large"
         >:: test_fit_gp_variance_far_from_observations_is_large;
         "fit_gp: empty observations raises"
         >:: test_fit_gp_empty_observations_raises;
         "fit_gp: y length mismatch raises"
         >:: test_fit_gp_y_length_mismatch_raises;
         "fit_gp: row dim mismatch raises"
         >:: test_fit_gp_row_dim_mismatch_raises;
         "expected_improvement: zero at constant posterior"
         >:: test_expected_improvement_zero_at_constant_posterior;
         "ucb: increases with beta" >:: test_ucb_increases_with_beta;
         "suggest_next_with_candidates: invalid n raises"
         >:: test_suggest_next_with_invalid_n_candidates_raises;
       ]

let () = run_test_tt_main suite
