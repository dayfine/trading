open Core

let periods_per_year = 52.0

let _cagr_main ~returns ~n =
  let cum =
    Array.fold returns ~init:1.0 ~f:(fun acc r -> acc *. (1.0 +. r))
  in
  let years = Float.of_int n /. periods_per_year in
  if Float.(years <= 0.0) || Float.(cum <= 0.0) then 0.0
  else Float.((cum ** (1.0 / years)) - 1.0)

let cagr_from_returns ~returns =
  let n = Array.length returns in
  if n = 0 then 0.0 else _cagr_main ~returns ~n

let _sharpe_main ~returns ~n =
  let mean = Array.fold returns ~init:0.0 ~f:( +. ) /. Float.of_int n in
  let var =
    Array.fold returns ~init:0.0 ~f:(fun acc r ->
        acc +. ((r -. mean) ** 2.0))
    /. Float.of_int (n - 1)
  in
  if Float.(var <= 0.0) then 0.0
  else mean /. Float.sqrt var *. Float.sqrt periods_per_year

let sharpe_from_returns ~returns =
  let n = Array.length returns in
  if n < 2 then 0.0 else _sharpe_main ~returns ~n

let max_drawdown_from_equity ~equity =
  let peak = ref Float.neg_infinity in
  let max_dd = ref 0.0 in
  Array.iter equity ~f:(fun e ->
      peak := Float.max !peak e;
      if Float.(!peak > 0.0) then
        let dd = (e /. !peak) -. 1.0 in
        max_dd := Float.min !max_dd dd);
  !max_dd

let returns_from_equity ~equity =
  let n = Array.length equity in
  if n < 2 then [||]
  else
    Array.init (n - 1) ~f:(fun i ->
        let prev = equity.(i) in
        let curr = equity.(i + 1) in
        if Float.(prev = 0.0) then 0.0 else (curr -. prev) /. prev)
