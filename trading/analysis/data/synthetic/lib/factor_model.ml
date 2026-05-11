open Core

(* ---------------------------------------------------------------------- *)
(* Loading distribution                                                   *)
(* ---------------------------------------------------------------------- *)

type loading_distribution = {
  mean : float;
  stddev : float;
  min_value : float;
  max_value : float;
}

let default_loading_distribution =
  { mean = 1.0; stddev = 0.4; min_value = 0.2; max_value = 2.5 }

let _check_finite name x =
  if Float.is_finite x then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "factor_model: %s must be finite (got %f)" name x)

let _check_positive name x =
  if Float.(x > 0.0) then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "factor_model: %s must be > 0 (got %.6e)" name x)

let _check_non_negative name x =
  if Float.(x >= 0.0) then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "factor_model: %s must be >= 0 (got %.6e)" name x)

let _check_range_ordered min_v max_v =
  if Float.(min_v < max_v) then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf
         "factor_model: min_value (%.4f) must be < max_value (%.4f)" min_v max_v)

let _check_mean_in_range mean min_v max_v =
  if Float.(mean >= min_v) && Float.(mean <= max_v) then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "factor_model: mean (%.4f) must be within [%.4f, %.4f]"
         mean min_v max_v)

let validate_loading_distribution d =
  Status.combine_status_list
    [
      _check_finite "mean" d.mean;
      _check_finite "stddev" d.stddev;
      _check_finite "min_value" d.min_value;
      _check_finite "max_value" d.max_value;
      _check_positive "stddev" d.stddev;
      _check_range_ordered d.min_value d.max_value;
      _check_mean_in_range d.mean d.min_value d.max_value;
    ]

(* ---------------------------------------------------------------------- *)
(* Idiosyncratic distribution                                             *)
(* ---------------------------------------------------------------------- *)

type idio_distribution = {
  omega_mean : float;
  omega_lognormal_sigma : float;
  alpha : float;
  beta : float;
}

let default_idio_distribution =
  { omega_mean = 1e-5; omega_lognormal_sigma = 0.3; alpha = 0.05; beta = 0.90 }

let _check_stationary alpha beta =
  if Float.(alpha +. beta < 1.0) then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf
         "factor_model: alpha + beta must be < 1 for stationarity (got %.6f)"
         (alpha +. beta))

let validate_idio_distribution d =
  Status.combine_status_list
    [
      _check_finite "omega_mean" d.omega_mean;
      _check_finite "omega_lognormal_sigma" d.omega_lognormal_sigma;
      _check_finite "alpha" d.alpha;
      _check_finite "beta" d.beta;
      _check_positive "omega_mean" d.omega_mean;
      _check_non_negative "omega_lognormal_sigma" d.omega_lognormal_sigma;
      _check_non_negative "alpha" d.alpha;
      _check_non_negative "beta" d.beta;
      _check_stationary d.alpha d.beta;
    ]

(* ---------------------------------------------------------------------- *)
(* Sampling primitives                                                    *)
(* ---------------------------------------------------------------------- *)

(* Box-Muller — see Garch._normal_sample. Inlined here so factor_model can
   live without depending on Garch's internal RNG plumbing. *)
let _normal_sample rng =
  let u1 = Stdlib.Random.State.float rng 1.0 in
  let u2 = Stdlib.Random.State.float rng 1.0 in
  let u1' = Float.max u1 Float.min_positive_normal_value in
  Float.sqrt (-2.0 *. Float.log u1') *. Float.cos (2.0 *. Float.pi *. u2)

(* Reject-resample a truncated Normal. Bounded retries keep us out of an
   infinite loop if the caller passes a pathologically narrow truncation
   window relative to [stddev] — though [validate_loading_distribution]
   should catch the most common shapes. *)
let _max_truncation_retries = 100

let _sample_truncated_normal ~dist ~rng =
  let rec loop tries =
    let z = _normal_sample rng in
    let x = dist.mean +. (dist.stddev *. z) in
    if Float.(x >= dist.min_value) && Float.(x <= dist.max_value) then x
    else if tries >= _max_truncation_retries then
      (* Fall back to clamping rather than recursing forever; this only
         trips for extreme truncation distributions. *)
      Float.max dist.min_value (Float.min dist.max_value x)
    else loop (tries + 1)
  in
  loop 0

(* ---------------------------------------------------------------------- *)
(* β-sampling                                                             *)
(* ---------------------------------------------------------------------- *)

let sample_betas dist ~n ~seed =
  if n <= 0 then []
  else
    match validate_loading_distribution dist with
    | Error e -> invalid_arg ("factor_model: " ^ Status.show e)
    | Ok () ->
        let rng = Stdlib.Random.State.make [| seed |] in
        List.init n ~f:(fun _ -> _sample_truncated_normal ~dist ~rng)

(* ---------------------------------------------------------------------- *)
(* Idiosyncratic parameter sampling                                       *)
(* ---------------------------------------------------------------------- *)

(* Draw [omega_i] = omega_mean * exp(σ · z), z ~ N(0,1). The log-normal
   shape keeps omega strictly positive, with median [omega_mean]. *)
let _sample_omega ~dist ~rng =
  let z = _normal_sample rng in
  dist.omega_mean *. Float.exp (dist.omega_lognormal_sigma *. z)

let _draw_idio_params ~dist ~rng : Garch.params =
  let omega = _sample_omega ~dist ~rng in
  { Garch.omega; alpha = dist.alpha; beta = dist.beta }

let _idio_params_with_rng ~dist ~n ~seed =
  let rng = Stdlib.Random.State.make [| seed |] in
  List.init n ~f:(fun _ -> _draw_idio_params ~dist ~rng)

let sample_idio_params dist ~n ~seed =
  if n <= 0 then []
  else
    match validate_idio_distribution dist with
    | Error e -> invalid_arg ("factor_model: " ^ Status.show e)
    | Ok () -> _idio_params_with_rng ~dist ~n ~seed

(* ---------------------------------------------------------------------- *)
(* Per-symbol return composition                                          *)
(* ---------------------------------------------------------------------- *)

(* Bring idio GARCH variance up from the long-run mean; the [Garch] module
   computes this for us when params are stationary. *)
let _idio_initial_variance params =
  match Garch.long_run_variance params with Some v -> v | None -> params.omega

let generate_symbol_returns ~market_returns ~beta ~idio_params ~seed =
  match market_returns with
  | [] -> []
  | _ ->
      (* Validation: raise on invalid GARCH parameters, mirroring Garch's
         own contract. *)
      (match Garch.validate idio_params with
      | Ok () -> ()
      | Error e -> invalid_arg ("factor_model: " ^ Status.show e));
      let n = List.length market_returns in
      let idio_returns =
        Garch.sample_returns idio_params ~n_steps:n ~seed
          ~initial_variance:(_idio_initial_variance idio_params)
      in
      List.map2_exn market_returns idio_returns ~f:(fun m e -> (beta *. m) +. e)
