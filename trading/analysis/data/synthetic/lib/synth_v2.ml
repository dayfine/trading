open Core

type config = {
  hmm : Regime_hmm.t;
  garch_per_regime : (Regime_hmm.regime * Garch.params) list;
  drift_per_regime : (Regime_hmm.regime * float) list;
  start_price : float;
  target_length_days : int;
  start_date : Date.t;
  seed : int;
}

(* Hand-set per-regime defaults — see synth_v2.mli for rationale. *)
let default_garch_per_regime : (Regime_hmm.regime * Garch.params) list =
  [
    (Regime_hmm.Bull, { omega = 1e-6; alpha = 0.05; beta = 0.93 });
    (Regime_hmm.Bear, { omega = 1e-5; alpha = 0.10; beta = 0.85 });
    (Regime_hmm.Crisis, { omega = 5e-5; alpha = 0.20; beta = 0.75 });
  ]

let default_drift_per_regime : (Regime_hmm.regime * float) list =
  [
    (Regime_hmm.Bull, 0.0005);
    (Regime_hmm.Bear, -0.0003);
    (Regime_hmm.Crisis, -0.002);
  ]

let default_config ~start_date ~start_price ~target_length_days ~seed =
  {
    hmm = Regime_hmm.default;
    garch_per_regime = default_garch_per_regime;
    drift_per_regime = default_drift_per_regime;
    start_price;
    target_length_days;
    start_date;
    seed;
  }

(* ---------------------------------------------------------------------- *)
(* Validation                                                             *)
(* ---------------------------------------------------------------------- *)

let _all_regimes = [ Regime_hmm.Bull; Regime_hmm.Bear; Regime_hmm.Crisis ]

let _check_target_days n =
  if n <= 0 then
    Status.error_invalid_argument
      (Printf.sprintf "target_length_days must be > 0 (got %d)" n)
  else Ok ()

let _check_start_price p =
  if Float.(p <= 0.0) then
    Status.error_invalid_argument
      (Printf.sprintf "start_price must be > 0 (got %.4f)" p)
  else Ok ()

let _check_garch_assignment garch_per_regime r =
  match List.Assoc.find garch_per_regime ~equal:Regime_hmm.equal_regime r with
  | None ->
      Status.error_invalid_argument
        (Printf.sprintf "garch_per_regime missing entry for %s"
           (Regime_hmm.show_regime r))
  | Some p -> Garch.validate p

let _check_drift_assignment drift_per_regime r =
  if List.Assoc.mem drift_per_regime ~equal:Regime_hmm.equal_regime r then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "drift_per_regime missing entry for %s"
         (Regime_hmm.show_regime r))

let _validate config =
  let garch_checks =
    List.map _all_regimes ~f:(_check_garch_assignment config.garch_per_regime)
  in
  let drift_checks =
    List.map _all_regimes ~f:(_check_drift_assignment config.drift_per_regime)
  in
  Status.combine_status_list
    ([
       _check_target_days config.target_length_days;
       _check_start_price config.start_price;
       Regime_hmm.validate config.hmm;
     ]
    @ garch_checks @ drift_checks)

(* ---------------------------------------------------------------------- *)
(* Calendar (mirrors Block_bootstrap)                                     *)
(* ---------------------------------------------------------------------- *)

let _next_business_day d =
  let next = Date.add_days d 1 in
  match Date.day_of_week next with
  | Sat -> Date.add_days next 2
  | Sun -> Date.add_days next 1
  | _ -> next

let _normalise_start_date d =
  match Date.day_of_week d with
  | Sat -> Date.add_days d 2
  | Sun -> Date.add_days d 1
  | _ -> d

let _business_days ~start_date ~n =
  let normalised_start = _normalise_start_date start_date in
  let rec loop acc d remaining =
    if remaining = 0 then List.rev acc
    else loop (d :: acc) (_next_business_day d) (remaining - 1)
  in
  loop [] normalised_start n

(* ---------------------------------------------------------------------- *)
(* Bar shape                                                              *)
(* ---------------------------------------------------------------------- *)

(* Synthesise a well-formed bar from a close price + date. We don't model
   intra-day structure here; a small fixed band around the close suffices for
   downstream consumers that need OHLC. *)
let _synthetic_volume = 10_000_000

let _build_bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close *. 0.999;
    high_price = close *. 1.005;
    low_price = close *. 0.995;
    close_price = close;
    adjusted_close = close;
    volume = _synthetic_volume;
  }

(* ---------------------------------------------------------------------- *)
(* Generation                                                             *)
(* ---------------------------------------------------------------------- *)

let _drift_for ~drift_per_regime r =
  List.Assoc.find drift_per_regime ~equal:Regime_hmm.equal_regime r
  |> Option.value ~default:0.0

let _params_for ~garch_per_regime r =
  match List.Assoc.find garch_per_regime ~equal:Regime_hmm.equal_regime r with
  | Some p -> p
  | None ->
      invalid_arg
        (Printf.sprintf "synth_v2: missing GARCH params for regime %s"
           (Regime_hmm.show_regime r))

(* Box-Muller, same as Garch._normal_sample. Inlined here so the GARCH state
   is owned by this module — we run a single recursion that switches
   parameters when the regime switches, rather than calling Garch.sample_returns
   per-regime (which would reset variance at each regime boundary). *)
let _normal_sample rng =
  let u1 = Stdlib.Random.State.float rng 1.0 in
  let u2 = Stdlib.Random.State.float rng 1.0 in
  let u1' = Float.max u1 Float.min_positive_normal_value in
  Float.sqrt (-2.0 *. Float.log u1') *. Float.cos (2.0 *. Float.pi *. u2)

(* Same hard cap as Garch._max_variance, kept locally to avoid leaking it
   into the public Garch interface. *)
let _max_variance = 1.0
let _clamp_variance v = Float.min _max_variance (Float.max 0.0 v)

let _initial_variance ~garch_per_regime ~initial_regime =
  let p = _params_for ~garch_per_regime initial_regime in
  match Garch.long_run_variance p with
  | Some v -> v
  | None ->
      (* Stationarity is enforced by Garch.validate; this branch is a safety
         net for non-stationary parameters that somehow slipped through. *)
      p.omega

(* Compose log-returns using a regime-switching GARCH variance recursion.
   The variance carries forward across steps; only the (ω, α, β) parameters
   switch on regime change. Returns drift + ε at each step. *)
let _compose_log_returns ~regimes ~garch_per_regime ~drift_per_regime ~rng =
  let n = List.length regimes in
  let regimes_arr = Array.of_list regimes in
  let out = Array.create ~len:n 0.0 in
  let initial_regime = regimes_arr.(0) in
  let var =
    ref (_initial_variance ~garch_per_regime ~initial_regime |> _clamp_variance)
  in
  for k = 0 to n - 1 do
    let r = regimes_arr.(k) in
    let p = _params_for ~garch_per_regime r in
    let z = _normal_sample rng in
    let sigma = Float.sqrt !var in
    let eps = sigma *. z in
    let drift = _drift_for ~drift_per_regime r in
    out.(k) <- drift +. eps;
    let next_var = p.omega +. (p.alpha *. (eps ** 2.0)) +. (p.beta *. !var) in
    var := _clamp_variance next_var
  done;
  Array.to_list out

let _build_bars ~dates ~start_price ~log_returns =
  let dates_arr = Array.of_list dates in
  let returns_arr = Array.of_list log_returns in
  let n = Array.length dates_arr in
  let bars =
    Array.create ~len:n (_build_bar ~date:dates_arr.(0) ~close:start_price)
  in
  bars.(0) <- _build_bar ~date:dates_arr.(0) ~close:start_price;
  let prev_close = ref start_price in
  for k = 1 to n - 1 do
    (* Apply the (k-1)-th sampled return between bar k-1 and bar k. We have
       n returns from the regime sampler but only need n-1 transitions; the
       0-th return is implicit in the [start_price]. *)
    let close = !prev_close *. Float.exp returns_arr.(k - 1) in
    bars.(k) <- _build_bar ~date:dates_arr.(k) ~close;
    prev_close := close
  done;
  Array.to_list bars

let _generate_validated config =
  let n = config.target_length_days in
  let regimes =
    Regime_hmm.sample_path config.hmm ~n_steps:n ~seed:config.seed
  in
  (* GARCH stream uses seed + 1 so it is independent of the HMM stream
     even when seeds collide across calls. *)
  let rng = Stdlib.Random.State.make [| config.seed + 1 |] in
  let log_returns =
    _compose_log_returns ~regimes ~garch_per_regime:config.garch_per_regime
      ~drift_per_regime:config.drift_per_regime ~rng
  in
  let dates = _business_days ~start_date:config.start_date ~n in
  _build_bars ~dates ~start_price:config.start_price ~log_returns

let generate config =
  Result.bind (_validate config) ~f:(fun () -> Ok (_generate_validated config))
