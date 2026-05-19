open Core

type per_industry = {
  returns : float array;
  prices : float array;
  ma : float array;
  first_idx : int option;
}
[@@deriving show, eq]

(* ────────────────────────────────────────────────────────────
   Per-industry construction
   ──────────────────────────────────────────────────────────── *)

(** Convert percent returns to decimal, missing-data → 0.0. *)
let _industry_daily_decimal_returns ~rows ~industry_idx =
  Array.map rows ~f:(fun (r : Loader.daily_row) ->
      match r.industry_returns.(industry_idx) with
      | Some pct -> pct /. 100.0
      | None -> 0.0)

let _first_data_day ~rows ~industry_idx =
  Array.findi rows ~f:(fun _ (r : Loader.daily_row) ->
      Option.is_some r.industry_returns.(industry_idx))
  |> Option.map ~f:fst

(** Synthetic price level: cumulative product of [1 + r]. Starts at 1.0. *)
let _industry_price_levels ~daily_decimal_returns =
  let n = Array.length daily_decimal_returns in
  let prices = Array.create ~len:n 1.0 in
  if n > 0 then prices.(0) <- 1.0 +. daily_decimal_returns.(0);
  for i = 1 to n - 1 do
    prices.(i) <- prices.(i - 1) *. (1.0 +. daily_decimal_returns.(i))
  done;
  prices

let build ~rows ~industries ~ma_trading_days =
  List.mapi industries ~f:(fun idx _name ->
      let returns = _industry_daily_decimal_returns ~rows ~industry_idx:idx in
      let prices = _industry_price_levels ~daily_decimal_returns:returns in
      let ma = Stage.moving_average ~prices ~window:ma_trading_days in
      let first_idx = _first_data_day ~rows ~industry_idx:idx in
      { returns; prices; ma; first_idx })
  |> Array.of_list

(* ────────────────────────────────────────────────────────────
   Stage + relative strength
   ──────────────────────────────────────────────────────────── *)

let stage_at ~(industry : per_industry) ~ma_trading_days ~slope_lookback_days
    ~slope_threshold_pct t =
  match industry.first_idx with
  | None -> Stage.Stage1
  | Some f when t - f < ma_trading_days -> Stage.Stage1
  | _ ->
      Stage.classify_at ~prices:industry.prices ~ma:industry.ma
        ~slope_lookback:slope_lookback_days ~slope_threshold_pct t

let _cum_return ~(industry : per_industry) ~k t =
  match industry.first_idx with
  | None -> Float.nan
  | Some f when t - f < k -> Float.nan
  | _ ->
      let p_now = industry.prices.(t) in
      let p_then = industry.prices.(t - k) in
      if Float.(p_then <= 0.0) then Float.nan else (p_now /. p_then) -. 1.0

let relative_strengths ~industries ~rs_lookback_days t =
  let cums =
    Array.map industries ~f:(fun ind ->
        _cum_return ~industry:ind ~k:rs_lookback_days t)
  in
  let valid = Array.filter cums ~f:(fun c -> not (Float.is_nan c)) in
  let n = Array.length valid in
  if n = 0 then Array.map cums ~f:(fun _ -> Float.nan)
  else
    let mean = Array.fold valid ~init:0.0 ~f:( +. ) /. Float.of_int n in
    Array.map cums ~f:(fun c -> if Float.is_nan c then Float.nan else c -. mean)

let benchmark_return ~industries t =
  let active =
    Array.filter industries ~f:(fun (ind : per_industry) ->
        match ind.first_idx with Some f -> f <= t | None -> false)
  in
  let n = Array.length active in
  if n = 0 then 0.0
  else
    let sum =
      Array.fold active ~init:0.0 ~f:(fun acc ind -> acc +. ind.returns.(t))
    in
    sum /. Float.of_int n
