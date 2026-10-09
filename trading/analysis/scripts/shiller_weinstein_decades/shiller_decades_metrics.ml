(** MA-window units, moving average, return series, and risk metrics for the
    Shiller decade reduction. *)

open Core

(** Unit-tagged MA window length. The binary's underlying data is monthly, so
    any length expressed in days or weeks is rounded to the nearest whole month
    at the boundary between user input and the sliding-window convolution. The
    three variants exist to keep the unit explicit at every call site — the
    original M1 PR conflated [Months 30] with [Weeks 30] and silently lagged
    re-entries by 6-12 months after every crash. See [ma_window_to_months] for
    the conversion factors. *)
type ma_window = Days of int | Weeks of int | Months of int

let days_per_month = 30
let weeks_per_month = 4.333

(** Convert a unit-tagged [ma_window] to the integer number of monthly bars
    consumed by [moving_average]. Floors to 1 so the convolution always has a
    non-empty window. *)
let ma_window_to_months = function
  | Days n -> Int.max 1 ((n + (days_per_month / 2)) / days_per_month)
  | Weeks n ->
      Int.max 1
        (Float.to_int (Float.round_nearest (Float.of_int n /. weeks_per_month)))
  | Months n -> Int.max 1 n

(** Stan Weinstein's canonical 30-week MA, expressed in monthly bars (≈ 7).
    Operators override via [-ma-window]. *)
let default_ma_window = Weeks 30

(** Parse the CLI [-ma-window] argument. Accepts:
    - [N] (bare integer) → [Months N] (backward-compat with the original CLI)
    - [Nd] / [Nday] / [Ndays] → [Days N]
    - [Nw] / [Nwk] / [Nweek] / [Nweeks] → [Weeks N]
    - [Nm] / [Nmo] / [Nmonth] / [Nmonths] → [Months N] Trailing whitespace
      tolerated; case-insensitive on the unit suffix. *)
let parse_ma_window_arg s =
  let s = String.strip s |> String.lowercase in
  let parse_num n_str =
    try Int.of_string n_str
    with _ ->
      failwithf "shiller_weinstein_decades: not an integer: %S" n_str ()
  in
  let suffix_match unit_chars =
    List.find_map unit_chars ~f:(fun unit_str ->
        if String.is_suffix s ~suffix:unit_str then
          let n = String.length s - String.length unit_str in
          Some (parse_num (String.sub s ~pos:0 ~len:n))
        else None)
  in
  match suffix_match [ "days"; "day"; "d" ] with
  | Some n -> Days n
  | None -> (
      match suffix_match [ "weeks"; "week"; "wk"; "w" ] with
      | Some n -> Weeks n
      | None -> (
          match suffix_match [ "months"; "month"; "mo"; "m" ] with
          | Some n -> Months n
          | None -> Months (parse_num s)))

(** Risk-free rate proxy for Sharpe. We use a constant 0 for the cross-decade
    comparison; using the contemporaneous long-rate would bias toward
    inflationary decades. The Sharpe numbers reported are therefore "excess over
    cash" not "excess over treasury" — adequate for cross-regime rank
    comparison. *)
let risk_free_monthly = 0.0

(* ────────────────────────────────────────────────────────────
   Pure compute helpers
   ──────────────────────────────────────────────────────────── *)

(** [moving_average prices ~window] returns an array of the same length as
    [prices], with the first [window-1] entries set to [Float.nan] and the rest
    set to the trailing simple average. *)
let moving_average prices ~window =
  let n = Array.length prices in
  let out = Array.create ~len:n Float.nan in
  if n < window then out
  else begin
    let sum = ref 0.0 in
    for i = 0 to window - 1 do
      sum := !sum +. prices.(i)
    done;
    out.(window - 1) <- !sum /. Float.of_int window;
    for i = window to n - 1 do
      sum := !sum -. prices.(i - window) +. prices.(i);
      out.(i) <- !sum /. Float.of_int window
    done;
    out
  end

(** Per-month monthly return: [(p_t - p_{t-1}) / p_{t-1}]. Length = n - 1. *)
let monthly_returns prices =
  let n = Array.length prices in
  Array.init (n - 1) ~f:(fun i -> (prices.(i + 1) -. prices.(i)) /. prices.(i))

(** Long-cash signal at the end of month t, indexed against the [prices] / [ma]
    arrays. [true] = Long for month t+1; [false] = Cash. *)
let is_long ~prices ~ma t =
  if t = 0 then false
  else
    let p = prices.(t) in
    let m = ma.(t) in
    let m_prev = ma.(t - 1) in
    if Float.is_nan m || Float.is_nan m_prev then false
    else Float.(p > m) && Float.(m > m_prev)

(** Strategy returns: for each month t (where t >= 1), participate in the full
    underlying return iff [is_long ~t:(t-1)] was true. Length = n - 1. *)
let strategy_returns ~prices ~ma =
  let n = Array.length prices in
  Array.init (n - 1) ~f:(fun i ->
      let underlying = (prices.(i + 1) -. prices.(i)) /. prices.(i) in
      if is_long ~prices ~ma i then underlying else risk_free_monthly)

(* ────────────────────────────────────────────────────────────
   Metrics
   ──────────────────────────────────────────────────────────── *)

(** [cagr_from_returns rs ~periods_per_year] = annualised compound return. *)
let cagr_from_returns rs ~periods_per_year =
  let n = Array.length rs in
  if n = 0 then 0.0
  else
    let cum = Array.fold rs ~init:1.0 ~f:(fun acc r -> acc *. (1.0 +. r)) in
    let years = Float.of_int n /. periods_per_year in
    if Float.(years <= 0.0) then 0.0 else Float.((cum ** (1.0 / years)) - 1.0)

(** [sharpe rs ~periods_per_year] = annualised Sharpe ratio (excess over
    [risk_free_monthly]). *)
let sharpe rs ~periods_per_year =
  let n = Array.length rs in
  if n < 2 then 0.0
  else
    let mean = Array.fold rs ~init:0.0 ~f:( +. ) /. Float.of_int n in
    let var =
      Array.fold rs ~init:0.0 ~f:(fun acc r -> acc +. ((r -. mean) ** 2.0))
      /. Float.of_int (n - 1)
    in
    if Float.(var <= 0.0) then 0.0
    else
      let excess = mean -. risk_free_monthly in
      let std = Float.sqrt var in
      excess /. std *. Float.sqrt periods_per_year

(** [max_drawdown rs] = maximum peak-to-trough drawdown of the cumulative return
    curve, as a negative number (or 0.0 if no drawdown). *)
let max_drawdown rs =
  let cum = ref 1.0 in
  let peak = ref 1.0 in
  let max_dd = ref 0.0 in
  Array.iter rs ~f:(fun r ->
      cum := !cum *. (1.0 +. r);
      peak := Float.max !peak !cum;
      let dd = (!cum /. !peak) -. 1.0 in
      max_dd := Float.min !max_dd dd);
  !max_dd

(** [cumulative_return rs] = end-state cumulative return as a multiplier (e.g.
    1.0 means flat, 2.0 means doubled). *)
let cumulative_return rs =
  Array.fold rs ~init:1.0 ~f:(fun acc r -> acc *. (1.0 +. r))

(** [beta strategy_rs market_rs] = OLS regression slope of strategy returns
    against market (B&H) returns. β<1 means strategy moves less than market per
    unit market move — confirms lower-vol-not-higher-return regime. *)
let beta strategy_rs market_rs =
  let n = Array.length market_rs in
  if n < 2 then 0.0
  else
    let mean_x = Array.fold market_rs ~init:0.0 ~f:( +. ) /. Float.of_int n in
    let mean_y = Array.fold strategy_rs ~init:0.0 ~f:( +. ) /. Float.of_int n in
    let cov = ref 0.0 in
    let var_x = ref 0.0 in
    for i = 0 to n - 1 do
      let dx = market_rs.(i) -. mean_x in
      let dy = strategy_rs.(i) -. mean_y in
      cov := !cov +. (dx *. dy);
      var_x := !var_x +. (dx *. dx)
    done;
    if Float.(!var_x <= 0.0) then 0.0 else !cov /. !var_x

let format_ma_window = function
  | Days n -> sprintf "%dd" n
  | Weeks n -> sprintf "%dw" n
  | Months n -> sprintf "%dmo" n
