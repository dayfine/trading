(** Pure, decision-time analytics over one symbol's weekly bar series — the
    "rule-visible breakout" detector behind the [monster_scan] tool (#2490's
    capture funnel, #2489's pending feature dimensions).

    {b Rule-visible.} Every quantity in {!features} reads bars at indices
    [<= idx] only — the information set the screener holds at that week's close.
    {!forward_run} deliberately DOES look forward: it is what defines the ex-post
    monster set capture is measured against, and it never feeds {!features_at}.

    {b Classifier.} The production {!Stage.classify} is reused, not
    reimplemented, so [Stage2] means what it means to the screener and [ma30] is
    the classifier's own [ma_value] (period / MA type come from the supplied
    {!Stage.config} — the "30" is the default, not a hardcode).

    One documented reduction: [prior_stage] is [None] at every week rather than
    threaded from the previous week. Threading it would mean classifying every
    week of every symbol (quadratic per symbol — prohibitive across a top-3000
    warehouse), while the price+volume gate admits only a handful of candidate
    weeks. With [None] the classifier uses its long-term-MA-trend heuristic to
    disambiguate a FLAT MA, so a flat-MA week may be labelled differently than
    in a stateful weekly walk. Stage-2 weeks with a rising MA — the ones this
    scanner admits — are unaffected.

    {b Basis.} Callers supply bars already on the split/dividend-adjusted basis
    ({!Adjusted_basis.to_adjusted_basis}), as {!Monster_scan_reader} does.
    Volume is raw share volume on every basis, so a split inside the volume
    lookback distorts {!features.vol_ratio} there — the same limitation the
    production volume confirmation carries. *)

type params = {
  breakout_lookback_weeks : int;
      (** Trailing window, in weekly bars, for both the prior-high level and the
          average-volume denominator. *)
  min_vol_ratio : float;
      (** Minimum [volume(t) / avg trailing volume] required to confirm a
          breakout. *)
  base_band_pct : float;
      (** Half-width, in percent, of the band around the trailing median close
          that counts as "still in the base" for {!features.base_weeks}. *)
  fwd_weeks : int;
      (** Forward horizon, in weekly bars, over which {!forward_run} measures
          the run. *)
}
(** Thresholds for detection and measurement. Every one is CLI-overridable;
    nothing in this module reads a hardcoded threshold. *)

val default_params : params
(** [default_params] is [breakout_lookback_weeks = 26], [min_vol_ratio = 1.5],
    [base_band_pct = 15.0], [fwd_weeks = 52]. *)

type features = {
  prior_high : float;
      (** Max weekly high over [[idx - breakout_lookback_weeks, idx - 1]]. *)
  vol_ratio : float;
      (** [volume(idx)] divided by the mean volume over the same trailing
          window. [Float.nan] when that mean is not positive (no volume history)
          — which never compares [>=] against a threshold, so such a week is
          never admitted as a breakout. *)
  ma30 : float;
      (** The stage classifier's [ma_value] at [idx], i.e. the moving average of
          the period / type carried by the supplied {!Stage.config}. *)
  base_weeks : int;
      (** Number of consecutive weeks immediately before [idx] whose close lay
          within [±base_band_pct] of the median close over
          [[idx - breakout_lookback_weeks, idx - 1]]. A duration proxy for the
          base the breakout emerges from: the median is a single fixed reference
          computed once at [idx], and the walk back stops at the first week
          outside the band (or at the start of the series). *)
  stage : Weinstein_types.stage;  (** {!Stage.classify} at [idx]. *)
}
(** Decision-time facts about one [(symbol, week)] pair. *)

type forward_run = {
  fwd_max_close : float;
      (** Max close over [[idx + 1, idx + fwd_weeks]], clipped to the end of the
          series. [Float.nan] when no forward bar exists. *)
  fwd_run_pct : float;
      (** [(fwd_max_close /. close(idx) - 1.) * 100.]. [Float.nan] when
          [fwd_max_close] is, or when [close(idx)] is not positive. *)
  weeks_to_max : int;
      (** Number of weekly bars from [idx] to the bar achieving
          [fwd_max_close]; [0] when there is no forward bar. *)
}
(** Ex-post outcome of a week. Hindsight by construction — this is the estimand
    (#2490 measures capture of ex-post winners), never a detection input. *)

type breakout = {
  week_date : Core.Date.t;  (** Date of the breakout week's bar. *)
  close : float;  (** Close of the breakout week. *)
  features : features;  (** Decision-time facts at that week. *)
  forward : forward_run;  (** Ex-post run following that week. *)
}
(** One detected rule-visible Stage-2 breakout event. *)

val features_at :
  params:params ->
  stage_config:Stage.config ->
  bars:Types.Daily_price.t array ->
  idx:int ->
  features option
(** [features_at ~params ~stage_config ~bars ~idx] computes the decision-time
    features at weekly bar [idx] of [bars] (chronological, oldest first).

    Returns [None] when [idx] is out of range or when fewer than
    [params.breakout_lookback_weeks] bars precede it — the trailing window would
    be short, and a partially-filled window is not comparable to a full one.
    Pure function. *)

val forward_run_at :
  params:params ->
  bars:Types.Daily_price.t array ->
  idx:int ->
  forward_run
(** [forward_run_at ~params ~bars ~idx] measures the forward run following
    weekly bar [idx], over at most [params.fwd_weeks] following bars. Looks
    forward; see {!forward_run}. Pure function. *)

val scan :
  params:params ->
  stage_config:Stage.config ->
  bars:Types.Daily_price.t array ->
  breakout list

(** [scan ~params ~stage_config ~bars] returns every rule-visible Stage-2
    breakout in [bars] (chronological, oldest first), in chronological order.

    A week [idx] qualifies when all three hold:
    - [close(idx) > features.prior_high] (a new high versus the trailing
      window);
    - [features.vol_ratio >= params.min_vol_ratio] (volume confirmation);
    - [features.stage] is [Stage2] (Weinstein's spine: buy only in Stage 2).

    The cheap price and volume tests are evaluated first, so the classifier runs
    only at candidate weeks. Pure function. *)

val index_for_date :
  bars:Types.Daily_price.t array -> date:Core.Date.t -> int option
(** [index_for_date ~bars ~date] snaps [date] to the weekly bar that closes it:
    the earliest bar whose week-end date is at or after [date]. A date falling
    inside an ISO week therefore resolves to that week's close, and a date on a
    week-end resolves to that bar itself. Returns [None] when [date] is after
    the last bar — the pairs join has nothing to report at a week the warehouse
    does not cover. *)

val stage_label : Weinstein_types.stage -> string
(** [stage_label s] is the bare constructor name ["Stage1"] … ["Stage4"], for
    CSV output. Deliberately drops the payload fields, which contain commas
    under [show]. *)
