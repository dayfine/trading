(** Pure compute helpers for the Summary tier — see [summary_compute.mli]. *)

open Core

type config = {
  ma_weeks : int;
  atr_days : int;
  rs_ma_period : int;
  tail_days : int;
}
[@@deriving sexp, show, eq]

let default_config =
  { ma_weeks = 30; atr_days = 14; rs_ma_period = 52; tail_days = 250 }

type summary_values = {
  ma_30w : float;
  atr_14 : float;
  rs_line : float;
  stage : Weinstein_types.stage;
  as_of : Date.t;
}
[@@deriving sexp, show, eq]

(** {1 Internal helpers} *)

(** [_weekly_bars bars] aggregates daily bars to weekly last-bar-of-week. Used
    by [ma_30w] and [stage_heuristic]. *)
let _weekly_bars (bars : Types.Daily_price.t list) : Types.Daily_price.t list =
  Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars

(** [_true_range ~prev_close bar] is the Weinstein TR component — the greatest
    of the range itself and the gap moves from the prior close. *)
let _true_range ~prev_close (bar : Types.Daily_price.t) : float =
  let range = bar.high_price -. bar.low_price in
  let gap_up = Float.abs (bar.high_price -. prev_close) in
  let gap_down = Float.abs (bar.low_price -. prev_close) in
  Float.max range (Float.max gap_up gap_down)

(** [_true_range_series bars] produces the TR series starting at the *second*
    bar (the first has no prior close). Returns an empty list if [bars] has
    fewer than 2 elements. *)
let _true_range_series (bars : Types.Daily_price.t list) : float list =
  match bars with
  | [] | [ _ ] -> []
  | first :: rest ->
      let _, trs =
        List.fold rest ~init:(first.Types.Daily_price.close_price, [])
          ~f:(fun (prev_close, acc) bar ->
            let tr = _true_range ~prev_close bar in
            (bar.Types.Daily_price.close_price, tr :: acc))
      in
      List.rev trs

(** [_average xs] is the arithmetic mean of a non-empty float list. *)
let _average xs =
  let sum = List.fold xs ~init:0.0 ~f:( +. ) in
  sum /. Float.of_int (List.length xs)

(** {1 Indicator primitives} *)

let ma_30w ~config (bars : Types.Daily_price.t list) : float option =
  let weekly = _weekly_bars bars in
  let n = List.length weekly in
  if n < config.ma_weeks then None
  else
    let last_n =
      List.sub weekly ~pos:(n - config.ma_weeks) ~len:config.ma_weeks
    in
    let closes =
      List.map last_n ~f:(fun b -> b.Types.Daily_price.adjusted_close)
    in
    Some (_average closes)

let atr_14 ~config (bars : Types.Daily_price.t list) : float option =
  if List.length bars < config.atr_days + 1 then None
  else
    let tr_series = _true_range_series bars in
    let n = List.length tr_series in
    if n < config.atr_days then None
    else
      let window =
        List.sub tr_series ~pos:(n - config.atr_days) ~len:config.atr_days
      in
      Some (_average window)

let rs_line ~(config : config) ~stock_bars ~benchmark_bars : float option =
  (* Weinstein §4.4 prescribes a weekly RS line with a long-term (52-week)
     Mansfield zero line. [Relative_strength.analyze] is documented as taking
     weekly bars, and [rs_ma_period = 52] means "52 weekly bars ≈ one year".
     Aggregate daily inputs to weekly first so [rs_ma_period] is interpreted
     in weeks — feeding daily bars directly would collapse the zero-line
     window to ~2.5 months and distort the normalization. *)
  let rs_config : Relative_strength.config =
    { rs_ma_period = config.rs_ma_period }
  in
  let stock_weekly = _weekly_bars stock_bars in
  let benchmark_weekly = _weekly_bars benchmark_bars in
  match
    Relative_strength.analyze ~config:rs_config ~stock_bars:stock_weekly
      ~benchmark_bars:benchmark_weekly
  with
  | None -> None
  | Some history -> (
      match List.last history with
      | None -> None
      | Some last -> Some last.Relative_strength.rs_normalized)

let stage_heuristic ~config (bars : Types.Daily_price.t list) :
    Weinstein_types.stage option =
  let weekly = _weekly_bars bars in
  if List.length weekly < config.ma_weeks then None
  else
    let stage_config =
      { Stage.default_config with ma_period = config.ma_weeks }
    in
    let result =
      Stage.classify ~config:stage_config ~bars:weekly ~prior_stage:None
    in
    Some result.stage

(** {1 Composition} *)

let compute_values ~config ~stock_bars ~benchmark_bars ~as_of :
    summary_values option =
  match ma_30w ~config stock_bars with
  | None -> None
  | Some ma_30w_v -> (
      match atr_14 ~config stock_bars with
      | None -> None
      | Some atr_14_v -> (
          match rs_line ~config ~stock_bars ~benchmark_bars with
          | None -> None
          | Some rs_line_v -> (
              match stage_heuristic ~config stock_bars with
              | None -> None
              | Some stage_v ->
                  Some
                    {
                      ma_30w = ma_30w_v;
                      atr_14 = atr_14_v;
                      rs_line = rs_line_v;
                      stage = stage_v;
                      as_of;
                    })))
