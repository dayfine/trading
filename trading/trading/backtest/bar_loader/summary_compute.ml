(** Pure compute helpers for the Summary tier — see [summary_compute.mli]. *)

open Core

type config = {
  ma_weeks : int;
  atr_days : int;
  rs_ma_period : int;
  tail_days : int;
}
[@@deriving sexp, show, eq]

(** [default_config.tail_days] must cover the longest indicator window after
    daily→weekly aggregation. The Mansfield RS line uses [rs_ma_period = 52]
    WEEKLY bars, which requires ~52 × 7 = 364 calendar days of daily input at a
    minimum; we pad to 420 (~60 weekly bars) so market-holiday gaps and the
    aggregation's partial-week edge don't trip the [n < rs_ma_period] threshold
    inside [Relative_strength.analyze]. Below that threshold [rs_line] returns
    [None] and [compute_values] returns [None] via its Option monadic chain,
    which silently leaves callers at the prior tier — the F2 regression the
    parity test was quietly masking before the bump. *)
let default_config =
  { ma_weeks = 30; atr_days = 14; rs_ma_period = 52; tail_days = 420 }

type summary_values = {
  ma_30w : float;
  atr_14 : float;
  rs_line : float;
  stage : Weinstein_types.stage;
  as_of : Date.t;
}
[@@deriving sexp, show, eq]

let _average xs =
  let sum = List.fold xs ~init:0.0 ~f:( +. ) in
  sum /. Float.of_int (List.length xs)

(** {1 Indicator primitives} *)

let ma_30w ~config (bars : Types.Daily_price.t list) : float option =
  let weekly =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars
  in
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
  Atr.atr ~period:config.atr_days bars

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
  let stock_weekly =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:true stock_bars
  in
  let benchmark_weekly =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:true
      benchmark_bars
  in
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
  let weekly =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars
  in
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
  let open Option.Let_syntax in
  let%bind ma_30w = ma_30w ~config stock_bars in
  let%bind atr_14 = atr_14 ~config stock_bars in
  let%bind rs_line = rs_line ~config ~stock_bars ~benchmark_bars in
  let%map stage = stage_heuristic ~config stock_bars in
  { ma_30w; atr_14; rs_line; stage; as_of }
