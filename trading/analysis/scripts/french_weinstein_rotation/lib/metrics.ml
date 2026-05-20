open Core

let _cagr_main ~returns ~periods_per_year =
  let n = Array.length returns in
  let cum = Array.fold returns ~init:1.0 ~f:(fun acc r -> acc *. (1.0 +. r)) in
  let years = Float.of_int n /. periods_per_year in
  if Float.(years <= 0.0) || Float.(cum <= 0.0) then 0.0
  else Float.((cum ** (1.0 / years)) - 1.0)

let cagr ~returns ~periods_per_year =
  if Array.is_empty returns then 0.0 else _cagr_main ~returns ~periods_per_year

let _sharpe_main ~returns ~periods_per_year =
  let n = Array.length returns in
  let mean = Array.fold returns ~init:0.0 ~f:( +. ) /. Float.of_int n in
  let var =
    Array.fold returns ~init:0.0 ~f:(fun acc r -> acc +. ((r -. mean) ** 2.0))
    /. Float.of_int (n - 1)
  in
  if Float.(var <= 0.0) then 0.0
  else mean /. Float.sqrt var *. Float.sqrt periods_per_year

let sharpe ~returns ~periods_per_year =
  if Array.length returns < 2 then 0.0
  else _sharpe_main ~returns ~periods_per_year

let max_drawdown ~returns =
  let cum = ref 1.0 in
  let peak = ref 1.0 in
  let max_dd = ref 0.0 in
  Array.iter returns ~f:(fun r ->
      cum := !cum *. (1.0 +. r);
      peak := Float.max !peak !cum;
      let dd = (!cum /. !peak) -. 1.0 in
      max_dd := Float.min !max_dd dd);
  !max_dd

let cumulative_return ~returns =
  Array.fold returns ~init:1.0 ~f:(fun acc r -> acc *. (1.0 +. r))

let _beta_main ~strategy ~market =
  let n = Array.length market in
  let mean_x = Array.fold market ~init:0.0 ~f:( +. ) /. Float.of_int n in
  let mean_y = Array.fold strategy ~init:0.0 ~f:( +. ) /. Float.of_int n in
  let cov = ref 0.0 in
  let var_x = ref 0.0 in
  for i = 0 to n - 1 do
    let dx = market.(i) -. mean_x in
    let dy = strategy.(i) -. mean_y in
    cov := !cov +. (dx *. dy);
    var_x := !var_x +. (dx *. dx)
  done;
  if Float.(!var_x <= 0.0) then 0.0 else !cov /. !var_x

let beta ~strategy ~market =
  let n = Array.length market in
  if n < 2 || Array.length strategy <> n then 0.0
  else _beta_main ~strategy ~market
