open Core

type params = { omega : float; alpha : float; beta : float }
[@@deriving sexp, eq, show]

(* Hard cap on σ² to keep generated returns finite when callers pass
   parameters very close to the stationarity boundary. The cap corresponds
   to a daily stdev of ~1.0, well above any realistic regime; it only trips
   when [α + β] is numerically near 1. *)
let _max_variance = 1.0

let long_run_variance p =
  let denom = 1.0 -. p.alpha -. p.beta in
  if Float.(denom <= 0.0) then None else Some (p.omega /. denom)

(* ---------------------------------------------------------------------- *)
(* Validation                                                             *)
(* ---------------------------------------------------------------------- *)

let _check_finite name x =
  if Float.is_finite x then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "garch: %s must be finite (got %f)" name x)

let _check_omega_positive omega =
  if Float.(omega > 0.0) then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "garch: omega must be > 0 (got %.6e)" omega)

let _check_non_negative name x =
  if Float.(x >= 0.0) then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "garch: %s must be >= 0 (got %.6e)" name x)

let _check_stationary alpha beta =
  if Float.(alpha +. beta < 1.0) then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf
         "garch: alpha + beta must be < 1 for stationarity (got %.6f)"
         (alpha +. beta))

let validate p =
  Status.combine_status_list
    [
      _check_finite "omega" p.omega;
      _check_finite "alpha" p.alpha;
      _check_finite "beta" p.beta;
      _check_omega_positive p.omega;
      _check_non_negative "alpha" p.alpha;
      _check_non_negative "beta" p.beta;
      _check_stationary p.alpha p.beta;
    ]

(* ---------------------------------------------------------------------- *)
(* Sampling                                                               *)
(* ---------------------------------------------------------------------- *)

(* Box-Muller — two U(0,1) samples to one N(0,1) sample. We discard the
   second normal for simplicity; this is fine for fixture data. *)
let _normal_sample rng =
  let u1 = Stdlib.Random.State.float rng 1.0 in
  let u2 = Stdlib.Random.State.float rng 1.0 in
  let u1' = Float.max u1 Float.min_positive_normal_value in
  Float.sqrt (-2.0 *. Float.log u1') *. Float.cos (2.0 *. Float.pi *. u2)

let _clamp_variance v = Float.min _max_variance (Float.max 0.0 v)

let _next_variance ~params ~prev_eps ~prev_var =
  let raw =
    params.omega
    +. (params.alpha *. (prev_eps ** 2.0))
    +. (params.beta *. prev_var)
  in
  _clamp_variance raw

let _check_initial_variance v =
  if Float.is_finite v && Float.(v >= 0.0) then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "garch: initial_variance must be finite and >= 0 (got %f)"
         v)

let sample_returns params ~n_steps ~seed ~initial_variance =
  if n_steps <= 0 then []
  else
    let validation =
      Status.combine_status_list
        [ validate params; _check_initial_variance initial_variance ]
    in
    match validation with
    | Error e -> invalid_arg ("garch: " ^ Status.show e)
    | Ok () ->
        let rng = Stdlib.Random.State.make [| seed |] in
        let out = Array.create ~len:n_steps 0.0 in
        let var = ref (_clamp_variance initial_variance) in
        for k = 0 to n_steps - 1 do
          let z = _normal_sample rng in
          let sigma = Float.sqrt !var in
          let eps = sigma *. z in
          out.(k) <- eps;
          var := _next_variance ~params ~prev_eps:eps ~prev_var:!var
        done;
        Array.to_list out
