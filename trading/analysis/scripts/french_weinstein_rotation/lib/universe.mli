(** Per-industry derived views over the raw {!Loader.daily_row} series.

    For each of the 49 French industries we build:
    - A daily decimal return array (missing-data → 0.0).
    - A synthetic price level array (cumulative product of [1 + r]).
    - A trailing moving average of the price level.
    - The first day on which the industry has any non-missing data (industries
      did not all exist in 1926; Hlth and Softw start in the 1960s/80s).

    The {!stage_at} and {!relative_strengths} helpers consume these views to
    produce Weinstein stage classifications and cross-sectional RS scores. Kept
    separate from {!Rotation} so the strategy file remains under the 300-line
    file-length linter limit and the responsibility split is clean (Universe =
    derived views; Rotation = portfolio construction + walk-loop). *)

type per_industry = {
  returns : float array;  (** Decimal daily returns (0.0 for missing days). *)
  prices : float array;
      (** Synthetic price level; starts at 1.0 + returns.(0). *)
  ma : float array;
      (** Trailing simple MA of [prices], window = [ma_trading_days]. *)
  first_idx : int option;
      (** First trading day index with non-missing data. [None] = industry never
          reports across the full series. *)
}
[@@deriving show, eq]

val build :
  rows:Loader.daily_row array ->
  industries:string list ->
  ma_trading_days:int ->
  per_industry array
(** [build ~rows ~industries ~ma_trading_days] builds one {!per_industry} per
    industry-name in order. *)

val stage_at :
  industry:per_industry ->
  ma_trading_days:int ->
  slope_lookback_days:int ->
  slope_threshold_pct:float ->
  int ->
  Stage.stage
(** [stage_at ~industry ~ma_trading_days ~slope_lookback_days
     ~slope_threshold_pct t] returns the Weinstein stage classification at index
    [t]. Falls back to Stage 1 if the industry didn't exist long enough for the
    MA to be valid. *)

val relative_strengths :
  industries:per_industry array -> rs_lookback_days:int -> int -> float array
(** [relative_strengths ~industries ~rs_lookback_days t] returns the
    cross-sectional RS score for each industry at index [t]:

    [RS_i(t) = cum_return_i(t-k..t) - mean(cum_return_j(t-k..t))] over all valid
    industries [j].

    NaN-coded for industries that don't have a full RS lookback window. *)

val benchmark_return : industries:per_industry array -> int -> float
(** [benchmark_return ~industries t] is the equal-weighted-49-industry market
    return on day [t], restricted to industries whose [first_idx] ≤ [t]. *)
