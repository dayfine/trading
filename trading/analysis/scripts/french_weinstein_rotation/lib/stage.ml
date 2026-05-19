open Core

type stage = Stage1 | Stage2 | Stage3 | Stage4 [@@deriving show, eq]

let label = function
  | Stage1 -> "S1"
  | Stage2 -> "S2"
  | Stage3 -> "S3"
  | Stage4 -> "S4"

let moving_average ~prices ~window =
  let n = Array.length prices in
  let out = Array.create ~len:n Float.nan in
  if n < window || window <= 0 then out
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

(** Slope of MA at index t, normalised by current price. NaN if undefined. *)
let _ma_slope_pct ~prices ~ma ~lookback t =
  if t < lookback then Float.nan
  else if Float.is_nan ma.(t) || Float.is_nan ma.(t - lookback) then Float.nan
  else (ma.(t) -. ma.(t - lookback)) /. prices.(t)

(** Map (above-MA, rising, falling) booleans to a stage. *)
let _stage_of_signals ~above ~rising ~falling =
  match (above, rising, falling) with
  | true, true, _ -> Stage2
  | false, _, true -> Stage4
  | true, false, _ -> Stage3
  | false, _, false -> Stage1

(** Stage classification when the slope is NaN (e.g. not enough history): if
    price is above MA we treat as Stage 3 (topping), else Stage 1 (basing). *)
let _stage_no_slope ~price ~ma_value =
  if Float.(price > ma_value) then Stage3 else Stage1

type _ma_state =
  | Ma_nan
  | Ma_no_slope of float
  | Ma_with_slope of float * float

(** Resolve the MA / slope state at index [t]. Centralises the three NaN
    branches so [classify_at] is flat. *)
let _ma_state ~prices ~ma ~slope_lookback t =
  let m = ma.(t) in
  match Float.is_nan m with
  | true -> Ma_nan
  | false ->
      let slope = _ma_slope_pct ~prices ~ma ~lookback:slope_lookback t in
      if Float.is_nan slope then Ma_no_slope m else Ma_with_slope (m, slope)

let classify_at ~prices ~ma ~slope_lookback ~slope_threshold_pct t =
  let p = prices.(t) in
  match _ma_state ~prices ~ma ~slope_lookback t with
  | Ma_nan -> Stage1
  | Ma_no_slope m -> _stage_no_slope ~price:p ~ma_value:m
  | Ma_with_slope (m, slope) ->
      _stage_of_signals
        ~above:Float.(p > m)
        ~rising:Float.(slope > slope_threshold_pct)
        ~falling:Float.(slope < -.slope_threshold_pct)
