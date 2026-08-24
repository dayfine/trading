(** Pure, decision-time analytics over one symbol's weekly bar series — the
    "rule-visible breakout" detector behind the [monster_scan] tool (#2490's
    capture funnel, #2489's pending feature dimensions).

    {b Rule-visible.} Every quantity in {!features} reads bars at indices
    [<= idx] only — the information set the screener holds at that week's close.
    {!forward_run} deliberately DOES look forward: it is what defines the
    ex-post monster set capture is measured against, and it never feeds
    {!features_at}.

    {b A reduced, warehouse-only proxy — NOT the production admission rule.} The
    three-condition detector in {!scan} is deliberately {e wider} than the set
    of candidates the production screener admits. It exists to supply #2490's
    capture-funnel {e denominator}, which must be computable from the warehouse
    alone — independent of the runner — because "screener surfaced" is a
    separate, later stage of that same funnel; pre-applying the screener's own
    filters here would make that stage trivially ~100% and its leak row
    meaningless. Concretely this module applies none of: the macro gate, sector
    / relative-strength gating, the extension cap, the §4.2 fill-week check, or
    any portfolio sizing / cash constraint — and {!features.prior_high} is a
    trailing-window proxy for, not a call into, the production resistance
    mapper. Do not read {!scan} as "what the strategy would have bought".

    {b Volume basis.} [vol_lookback_weeks] defaults to [4] and [min_vol_ratio]
    to [2.0]: Weinstein's breakout volume confirmation is at least twice the
    average volume of the prior four weeks ([weinstein-book-reference.md] §4.2),
    which is also what the production volume module encodes
    ([Volume.default_config]: [lookback_bars = 4], [strong_threshold = 2.0]).
    The denominator is its own knob, separate from [breakout_lookback_weeks] and
    [base_lookback_weeks], precisely so the book-comparable ratio is producible
    without simultaneously collapsing the resistance window or the base-length
    reference. The earlier welded 26-week / 1.5x combination remains
    expressible: [-vol-lookback-weeks 26 -min-vol-ratio 1.5]. A ratio computed
    on any window other than the book's four weeks is {e not} joinable with the
    executed-trade population's volume ratio, which comes from the production
    module — do not put the two in one table without saying which window each
    used.

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
    Volume is raw share volume on every basis, so a split inside
    [vol_lookback_weeks] distorts {!features.vol_ratio} there — at the default
    four-week window this is the same limitation, over the same window, that the
    production volume confirmation carries. *)

type params = {
  breakout_lookback_weeks : int;
      (** Trailing window, in weekly bars, for the prior-high (resistance proxy)
          level only. *)
  vol_lookback_weeks : int;
      (** Trailing window, in weekly bars, for the average-volume denominator of
          {!features.vol_ratio}. Independent of [breakout_lookback_weeks]; see
          the {b Volume basis} note above for why, and for the book value. *)
  base_lookback_weeks : int;
      (** Trailing window, in weekly bars, over which the median close used as
          the {!features.base_weeks} band reference is taken. *)
  min_vol_ratio : float;
      (** Minimum [volume(t) / avg volume over vol_lookback_weeks] required to
          confirm a breakout. *)
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
(** [default_params] is [breakout_lookback_weeks = 26],
    [vol_lookback_weeks = 4], [base_lookback_weeks = 26], [min_vol_ratio = 2.0],
    [base_band_pct = 15.0], [fwd_weeks = 52]. The volume pair ([4], [2.0]) is
    the book's §4.2 confirmation rule; see the {b Volume basis} note above. *)

type features = {
  prior_high : float;
      (** Max weekly high over [[idx - breakout_lookback_weeks, idx - 1]]. *)
  vol_ratio : float;
      (** [volume(idx)] divided by the mean volume over
          [[idx - vol_lookback_weeks, idx - 1]] — a different, deliberately
          narrower window than [prior_high]'s. [Float.nan] when that mean is not
          positive (no volume history) — which never compares [>=] against a
          threshold, so such a week is never admitted as a breakout. *)
  ma30 : float;
      (** The stage classifier's [ma_value] at [idx], i.e. the moving average of
          the period / type carried by the supplied {!Stage.config}. *)
  base_weeks : int;
      (** Number of consecutive weeks immediately before [idx] whose close lay
          within [±base_band_pct] of the median close over
          [[idx - base_lookback_weeks, idx - 1]]. A duration proxy for the base
          the breakout emerges from: the median is a single fixed reference
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
      (** Number of weekly bars from [idx] to the bar achieving [fwd_max_close];
          [0] when there is no forward bar. *)
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

    Returns [None] when [idx] is out of range or when fewer bars precede it than
    the {e widest} of the three trailing windows ([breakout_lookback_weeks],
    [vol_lookback_weeks], [base_lookback_weeks]) — a partially-filled window is
    not comparable to a full one, and the three windows must all be full for one
    row's features to be mutually comparable.

    Prefix-invariant by construction: the result depends only on
    [bars.(0 .. idx)]. Two series sharing that prefix produce identical
    [features] however they diverge afterwards. Pure function. *)

val forward_run_at :
  params:params -> bars:Types.Daily_price.t array -> idx:int -> forward_run
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
    - [close(idx) > features.prior_high] (a new high versus
      [breakout_lookback_weeks]);
    - [features.vol_ratio >= params.min_vol_ratio] (volume confirmation over
      [vol_lookback_weeks]);
    - [features.stage] is [Stage2].

    These three are the {e reduced, rule-visible} definition described in the
    header — the #2490 funnel denominator, not the production screener's
    admission rule, which additionally applies the macro gate, sector / RS
    gating, the extension cap and the fill-week check.

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
