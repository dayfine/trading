open Core
module Mat = Owl.Mat
module Linalg = Owl.Linalg.D

(** Deterministic seed for the default RNG so results are reproducible when no
    external seed is supplied. Any fixed value works; 42 is conventional. *)
let _default_rng_seed = 42

(** Minimum sigma below which expected-improvement is treated as zero, avoiding
    division by a near-zero standard deviation. *)
let _sigma_epsilon = 1e-12

(** {1 Types} *)

type observation = { parameters : (string * float) list; metric : float }
type acquisition = [ `Expected_improvement | `Upper_confidence_bound of float ]
type early_stop_config = { window : int; epsilon : float }

type config = {
  bounds : (string * (float * float)) list;
  acquisition : acquisition;
  initial_random : int;
  total_budget : int;
  rng : Stdlib.Random.State.t;
  length_scales : float array option;
  early_stop_config : early_stop_config option;
}

let create_config ~bounds ?(acquisition = `Expected_improvement)
    ?(initial_random = 5) ?(total_budget = 50)
    ?(rng = Stdlib.Random.State.make [| _default_rng_seed |]) ?length_scales
    ?early_stop_config () =
  {
    bounds;
    acquisition;
    initial_random;
    total_budget;
    rng;
    length_scales;
    early_stop_config;
  }

type t = { config : config; observations : observation list (* newest first *) }

(** {1 Validation} *)

let _early_stop_pair_of_opt = function
  | None -> None
  | Some { window; epsilon } -> Some (window, epsilon)

let create config =
  Bayesian_opt_validate.config ~bounds:config.bounds
    ~initial_random:config.initial_random ~total_budget:config.total_budget
    ~length_scales:config.length_scales
    ~early_stop:(_early_stop_pair_of_opt config.early_stop_config);
  { config; observations = [] }

(** {1 Observation accessors} *)

let observe t obs = { t with observations = obs :: t.observations }
let all_observations t = List.rev t.observations

(** Return whichever of [acc] and [obs] has the higher metric, or [Some obs]
    when [acc] is [None]. Ties go to [acc] (first-observation-wins). *)
let _pick_better acc obs =
  match acc with
  | None -> Some obs
  | Some b -> if Float.( > ) obs.metric b.metric then Some obs else acc

(** Iterate over observations in eval order (oldest first); the first
    observation reaching the max metric wins ties. *)
let best t = List.fold (all_observations t) ~init:None ~f:_pick_better

(** {1 Input scaling: raw <-> [0, 1]} *)

let _scale_to_unit ~bounds raw =
  Array.mapi raw ~f:(fun i v ->
      let _, (lo, hi) = List.nth_exn bounds i in
      if Float.equal lo hi then 0.5 else (v -. lo) /. (hi -. lo))

let _scale_from_unit ~bounds normalised =
  Array.mapi normalised ~f:(fun i v ->
      let _, (lo, hi) = List.nth_exn bounds i in
      if Float.equal lo hi then lo else lo +. (v *. (hi -. lo)))

let _params_of_array bounds arr =
  List.mapi bounds ~f:(fun i (k, _) -> (k, arr.(i)))

let _array_of_params bounds params =
  let lookup key =
    match List.Assoc.find params ~equal:String.equal key with
    | Some v -> v
    | None ->
        failwithf "Bayesian_opt: parameter %s missing from observation" key ()
  in
  Array.of_list (List.map bounds ~f:(fun (k, _) -> lookup k))

(** {1 RBF kernel} *)

let rbf_kernel ~length_scales ~signal_variance x y =
  if Array.length x <> Array.length y then
    invalid_arg "Bayesian_opt.rbf_kernel: dimension mismatch";
  if Array.length x <> Array.length length_scales then
    invalid_arg "Bayesian_opt.rbf_kernel: length_scales dimension mismatch";
  let s =
    Array.foldi x ~init:0.0 ~f:(fun i acc xi ->
        let diff = (xi -. y.(i)) /. length_scales.(i) in
        acc +. (diff *. diff))
  in
  signal_variance *. Float.exp (-0.5 *. s)

(** {1 GP fit and posterior} *)

type gp_posterior = {
  mean : float array -> float;
  variance : float array -> float;
}

let _kernel_matrix xs ~length_scales ~signal_variance =
  let n = Array.length xs in
  Mat.init_2d n n (fun i j ->
      rbf_kernel ~length_scales ~signal_variance xs.(i) xs.(j))

let _solve_lower_triangular l b = Linalg.triangular_solve ~upper:false l b
let _solve_upper_triangular u b = Linalg.triangular_solve ~upper:true u b

(** Validate GP-fit inputs. *)
let _validate_gp_inputs ~length_scales ~observations_x ~observations_y =
  let n = Array.length observations_x in
  if n = 0 then invalid_arg "Bayesian_opt.fit_gp: no observations";
  if Array.length observations_y <> n then
    invalid_arg "Bayesian_opt.fit_gp: y length disagrees with x";
  Array.iter observations_x ~f:(fun row ->
      if Array.length row <> Array.length length_scales then
        invalid_arg
          "Bayesian_opt.fit_gp: observation dim disagrees with length_scales");
  n

(** Compute the kernel-vector at a test point against the training rows. *)
let _kernel_vector ~length_scales ~signal_variance observations_x x_star =
  let n = Array.length observations_x in
  Mat.init_2d n 1 (fun i _ ->
      rbf_kernel ~length_scales ~signal_variance observations_x.(i) x_star)

let fit_gp ~length_scales ~signal_variance ~noise_variance ~observations_x
    ~observations_y =
  let n = _validate_gp_inputs ~length_scales ~observations_x ~observations_y in
  let y_mean =
    Array.fold observations_y ~init:0.0 ~f:( +. ) /. Float.of_int n
  in
  let y_centered = Array.map observations_y ~f:(fun y -> y -. y_mean) in
  let k = _kernel_matrix observations_x ~length_scales ~signal_variance in
  for i = 0 to n - 1 do
    Mat.set k i i (Mat.get k i i +. noise_variance)
  done;
  let l =
    Bayesian_opt_cholesky.chol_with_nugget_escalation k ~n ~noise_variance
      ~signal_variance
  in
  let l_t = Mat.transpose l in
  (* Solve L L^T α = y_centered  →  L z = y_centered, then L^T α = z. *)
  let y_col = Mat.of_array y_centered n 1 in
  let z = _solve_lower_triangular l y_col in
  let alpha = _solve_upper_triangular l_t z in
  let mean x_star =
    let k_star =
      _kernel_vector ~length_scales ~signal_variance observations_x x_star
    in
    let dot = Mat.dot (Mat.transpose k_star) alpha in
    y_mean +. Mat.get dot 0 0
  in
  let variance x_star =
    let k_star =
      _kernel_vector ~length_scales ~signal_variance observations_x x_star
    in
    let v = _solve_lower_triangular l k_star in
    let v_t_v = Mat.dot (Mat.transpose v) v in
    let var_self = rbf_kernel ~length_scales ~signal_variance x_star x_star in
    Float.max (var_self -. Mat.get v_t_v 0 0) 0.0
  in
  { mean; variance }

(** {1 Acquisition functions} *)

let _standard_normal_pdf z =
  Float.exp (-0.5 *. z *. z) /. Float.sqrt (2.0 *. Float.pi)

let _standard_normal_cdf z = 0.5 *. (1.0 +. Owl.Maths.erf (z /. Float.sqrt 2.0))

let expected_improvement ~posterior ~f_best x =
  let mu = posterior.mean x in
  let sigma = Float.sqrt (posterior.variance x) in
  if Float.( <= ) sigma _sigma_epsilon then 0.0
  else
    let improvement = mu -. f_best in
    let z = improvement /. sigma in
    (improvement *. _standard_normal_cdf z) +. (sigma *. _standard_normal_pdf z)

let upper_confidence_bound ~posterior ~beta x =
  posterior.mean x +. (beta *. Float.sqrt (posterior.variance x))

(** {1 Suggest_next} *)

(** Default length scale per dimension. In normalised [0,1] space, the kernel
    needs wider effective bandwidth as dimensionality grows to keep the
    posterior from under-fitting (plan §5.2). Scales as [sqrt(d) * 0.25]: at d =
    1 the value is [0.25] (matches the legacy 4-D-era default); at d = 16 it is
    [1.0]. Configs may override via [config.length_scales]. *)
let _default_length_scales bounds =
  let d = List.length bounds in
  let value = Float.sqrt (Float.of_int d) *. 0.25 in
  Array.of_list (List.map bounds ~f:(fun _ -> value))

let _length_scales_for_config config =
  match config.length_scales with
  | Some scales -> scales
  | None -> _default_length_scales config.bounds

let _signal_variance = 1.0
let _noise_variance = 1e-6

let _sample_uniform_unit_point ~rng ~dim =
  Array.init dim ~f:(fun _ -> Stdlib.Random.State.float rng 1.0)

let _sample_uniform_raw_point ~rng ~bounds =
  Array.of_list
    (List.map bounds ~f:(fun (_, (lo, hi)) ->
         if Float.equal lo hi then lo
         else lo +. Stdlib.Random.State.float rng (hi -. lo)))

let _build_posterior_for_state t =
  let observations = all_observations t in
  let xs =
    Array.of_list
      (List.map observations ~f:(fun obs ->
           let raw = _array_of_params t.config.bounds obs.parameters in
           _scale_to_unit ~bounds:t.config.bounds raw))
  in
  let ys = Array.of_list (List.map observations ~f:(fun obs -> obs.metric)) in
  let length_scales = _length_scales_for_config t.config in
  fit_gp ~length_scales ~signal_variance:_signal_variance
    ~noise_variance:_noise_variance ~observations_x:xs ~observations_y:ys

let _evaluate_acquisition acquisition ~posterior ~f_best x =
  match acquisition with
  | `Expected_improvement -> expected_improvement ~posterior ~f_best x
  | `Upper_confidence_bound beta -> upper_confidence_bound ~posterior ~beta x

let _argmax_candidate ~rng ~dim ~n_candidates ~score =
  let best_unit = ref (_sample_uniform_unit_point ~rng ~dim) in
  let best_score = ref (score !best_unit) in
  for _ = 1 to n_candidates - 1 do
    let candidate = _sample_uniform_unit_point ~rng ~dim in
    let s = score candidate in
    if Float.( > ) s !best_score then begin
      best_unit := candidate;
      best_score := s
    end
  done;
  !best_unit

let _suggest_random t =
  let raw =
    _sample_uniform_raw_point ~rng:t.config.rng ~bounds:t.config.bounds
  in
  _params_of_array t.config.bounds raw

let _suggest_via_gp t ~n_candidates =
  let posterior = _build_posterior_for_state t in
  let f_best =
    match best t with Some o -> o.metric | None -> Float.neg_infinity
  in
  let score x =
    _evaluate_acquisition t.config.acquisition ~posterior ~f_best x
  in
  let dim = List.length t.config.bounds in
  let best_unit =
    _argmax_candidate ~rng:t.config.rng ~dim ~n_candidates ~score
  in
  let raw = _scale_from_unit ~bounds:t.config.bounds best_unit in
  _params_of_array t.config.bounds raw

let _default_n_candidates = 1000

let suggest_next_with_candidates t ~n_candidates =
  if n_candidates < 1 then
    invalid_arg
      "Bayesian_opt.suggest_next_with_candidates: n_candidates must be >= 1";
  if List.length t.observations < t.config.initial_random then _suggest_random t
  else _suggest_via_gp t ~n_candidates

let suggest_next t =
  suggest_next_with_candidates t ~n_candidates:_default_n_candidates

let should_early_stop cfg ~initial_random ~running_best =
  Bayesian_opt_early_stop.should_stop ~window:cfg.window ~epsilon:cfg.epsilon
    ~initial_random ~running_best
