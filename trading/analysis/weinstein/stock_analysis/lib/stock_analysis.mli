open Types

(** Combined per-stock analysis result for the Weinstein screening pipeline.

    Aggregates the outputs of Stage, RS, Volume, and Resistance analysis into a
    single value per ticker. This is what the Screener consumes.

    Pure function: given the same bars and benchmark, always returns the same
    result. *)

type config = {
  stage : Stage.config;
  rs : Rs.config;
  volume : Volume.config;
  resistance : Resistance.config;
}
(** Configuration bundling all sub-module configs. *)

val default_config : config
(** [default_config] assembles sub-module defaults. *)

type t = {
  ticker : string;
  stage : Stage.result;
  rs : Rs.result option;  (** None if insufficient bar history to compute RS. *)
  volume : Volume.result option;
      (** None if there is no identifiable breakout bar in the recent window. *)
  resistance : Resistance.result option;
      (** None if no breakout price can be determined from the bars. *)
  breakout_price : float option;
      (** Detected breakout price (top of prior base / resistance zone). Used by
          the screener to set suggested entry. *)
  prior_stage : Weinstein_types.stage option;
      (** Stage from the previous week, passed forward for transition tracking.
      *)
  as_of_date : Core.Date.t;  (** The date this analysis was computed. *)
}
(** The full per-stock analysis. *)

val analyze :
  config:config ->
  ticker:string ->
  bars:Daily_price.t list ->
  benchmark_bars:Daily_price.t list ->
  prior_stage:Weinstein_types.stage option ->
  as_of_date:Core.Date.t ->
  t
(** [analyze ~config ~ticker ~bars ~benchmark_bars ~prior_stage ~as_of_date]
    runs all sub-analyses for one stock.

    @param bars Weekly bars for the stock (chronological, oldest first).
    @param benchmark_bars Weekly bars for the benchmark index (e.g., SPX).
    @param prior_stage Previous week's stage result for this ticker.
    @param as_of_date The analysis date.

    Pure function. *)

val is_breakout_candidate : t -> bool
(** [is_breakout_candidate analysis] returns true if the stock shows a potential
    Stage 2 breakout: transitioning from Stage 1, with rising MA and strong
    volume.

    Uses the sub-analysis results directly — no additional I/O. *)

val is_breakdown_candidate : t -> bool
(** [is_breakdown_candidate analysis] returns true if the stock shows a
    potential Stage 4 breakdown: transitioning from Stage 3 into Stage 4. Used
    for identifying short candidates. *)
