open Core

(* Percent scale factor for the underwater fraction → percent conversion. Named
   so the magic-number linter does not trip on the literal. *)
let _pct_scale = 100.0

(* Tail cut percentiles for the tail-ratio (plan §1.4: |p95| / |p5|). Named so
   the linter does not trip and the contract is self-documenting. *)
let _tail_hi_p = 95.0
let _tail_lo_p = 5.0

let time_underwater_pct equity_curve =
  match equity_curve with
  | [] | [ _ ] -> 0.0
  | first :: rest ->
      let n = 1 + List.length rest in
      let _peak, n_underwater =
        List.fold rest ~init:(first, 0) ~f:(fun (peak, count) v ->
            let peak' = Float.max peak v in
            let count' = if Float.( < ) v peak then count + 1 else count in
            (peak', count'))
      in
      Float.of_int n_underwater /. Float.of_int n *. _pct_scale

let tail_ratio returns =
  match returns with
  | [] -> 0.0
  | _ ->
      let hi = Dispersion_stats.percentile returns ~p:_tail_hi_p in
      let lo = Dispersion_stats.percentile returns ~p:_tail_lo_p in
      let lo_mag = Float.abs lo in
      if Float.( <= ) lo_mag 0.0 then
        if Float.( > ) (Float.abs hi) 0.0 then Float.infinity else 0.0
      else Float.abs hi /. lo_mag

let _mean = function
  | [] -> 0.0
  | xs -> List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int (List.length xs)

(* Population variance (divides by N) — matches the simulation-layer [Skewness]
   metric's convention so the two stay numerically consistent. *)
let _variance ~mean returns =
  match returns with
  | [] | [ _ ] -> 0.0
  | _ ->
      let sum_sq =
        List.fold returns ~init:0.0 ~f:(fun acc r ->
            let d = r -. mean in
            acc +. (d *. d))
      in
      sum_sq /. Float.of_int (List.length returns)

let _third_central_moment ~mean returns =
  let sum_cube =
    List.fold returns ~init:0.0 ~f:(fun acc r ->
        let d = r -. mean in
        acc +. (d *. d *. d))
  in
  sum_cube /. Float.of_int (List.length returns)

let return_skew returns =
  match returns with
  | [] | [ _ ] -> 0.0
  | _ ->
      let mean = _mean returns in
      let var = _variance ~mean returns in
      if Float.( <= ) var 0.0 then 0.0
      else
        let m3 = _third_central_moment ~mean returns in
        let sigma = Float.sqrt var in
        m3 /. (sigma *. sigma *. sigma)
