open Core

type config = {
  capture_weight : float;
  risk_reward_weight : float;
  pain_weight : float;
  conformance_weight : float;
  r_scale : float;
  loss_credit : float;
}
[@@deriving sexp]

let default_config =
  {
    capture_weight = 0.30;
    risk_reward_weight = 0.30;
    pain_weight = 0.15;
    conformance_weight = 0.25;
    r_scale = 2.0;
    loss_credit = 0.25;
  }

type t = {
  score : float;
  grade : string;
  capture : float;
  risk_reward : float;
  pain : float;
  conformance : float;
}
[@@deriving sexp]

(* Grade thresholds on the 0-100 composite. *)
let _grade_cuts =
  [ (85.0, "A+"); (70.0, "A"); (55.0, "B"); (40.0, "C"); (25.0, "D") ]

let grade_of_score score =
  List.find_map _grade_cuts ~f:(fun (cut, g) ->
      if Float.( >= ) score cut then Some g else None)
  |> Option.value ~default:"F"

let _clamp01 x = Float.max 0.0 (Float.min 1.0 x)

(* Realized gain as a fraction of the best excursion. Zero for losers (their
   quality is judged by risk_reward + pain, not capture) and for trades that
   never went favourable. *)
let _capture ~(rating : Trade_audit_ratings.rating) ~pnl_percent =
  let mfe = rating.mfe_pct in
  if Float.( <= ) pnl_percent 0.0 || Float.( <= ) mfe 0.0 || Float.is_nan mfe
  then 0.0
  else _clamp01 (pnl_percent /. 100.0 /. mfe)

(* R-multiple squashed to [0,1]: winners saturate via r/(r + r_scale); losers
   earn a small discipline credit that shrinks toward 0 at a full 1R loss. *)
let _risk_reward ~config ~(rating : Trade_audit_ratings.rating) =
  let r = rating.r_multiple in
  if Float.is_nan r then 0.5
  else if Float.( >= ) r 0.0 then _clamp01 (r /. (r +. config.r_scale))
  else config.loss_credit *. _clamp01 (1.0 -. Float.min 1.0 (Float.abs r))

(* How much of the initial risk budget the trade burned at its worst point.
   MAE is a fraction of entry price; initial risk in the same units is
   |mae| / |r_multiple-denominated risk| — but the rating exposes MAE and the
   R-multiple, so we reconstruct risk_pct = pnl_pct / r when both are sane and
   otherwise fall back to a neutral 0.5. *)
let _pain ~(rating : Trade_audit_ratings.rating) ~pnl_percent =
  let r = rating.r_multiple in
  let mae = Float.abs rating.mae_pct in
  if Float.is_nan r || Float.( = ) r 0.0 || Float.is_nan mae then 0.5
  else
    let risk_pct = Float.abs (pnl_percent /. 100.0 /. r) in
    if Float.( <= ) risk_pct 0.0 then 0.5
    else _clamp01 (1.0 -. Float.min 1.0 (mae /. risk_pct))

let compute ?(config = default_config) ~(rating : Trade_audit_ratings.rating)
    ~pnl_percent () =
  let capture = _capture ~rating ~pnl_percent in
  let risk_reward = _risk_reward ~config ~rating in
  let pain = _pain ~rating ~pnl_percent in
  let conformance = rating.weinstein_score in
  let components =
    [
      (capture, config.capture_weight);
      (risk_reward, config.risk_reward_weight);
      (pain, config.pain_weight);
      (conformance, config.conformance_weight);
    ]
    |> List.filter ~f:(fun (v, _) -> not (Float.is_nan v))
  in
  let wsum = List.fold components ~init:0.0 ~f:(fun a (_, w) -> a +. w) in
  let score =
    if Float.( <= ) wsum 0.0 then 0.0
    else
      List.fold components ~init:0.0 ~f:(fun a (v, w) -> a +. (v *. w))
      /. wsum *. 100.0
  in
  {
    score;
    grade = grade_of_score score;
    capture;
    risk_reward;
    pain;
    conformance;
  }
