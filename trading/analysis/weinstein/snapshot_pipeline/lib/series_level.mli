(** Build-time store-level sanity: is a stored series' {b price level} plausible
    for a tradeable US equity at all?

    The build-time sibling of the post-run {!Validator_store_check} (V18, PR
    #2750), standing to it as {!Splice_detector} stands to V15 — same question,
    asked before the warehouse is written instead of after a run has already
    spent money on the answer.

    {2 Why a third hygiene module, when two already exist}

    {!Series_tail} and {!Series_splice} both already remove mis-scaled data, so
    this module only earns its place on what they {e cannot} see. Both key on a
    {b discontinuity}: {!Series_splice} on a day-over-day adjusted-close ratio
    outside [[0.4, 2.5]], {!Series_tail} on a {e terminal} run below
    [ratio *. reference]. Neither ever asks whether a price level is plausible
    in absolute terms — their shared [misscale_close] (1,000.0) is a
    {e reclassifier} applied to a series that has already tripped a shape rule,
    never a primary test. {!Series_tail.Class.Prefix_misscale} in particular is
    reachable only {e through} the terminal-run test.

    So the residual class is:
    {b an implausible level with no discontinuity the shape rules can act on.}
    Three sub-classes, all evidenced:

    - {b No seam inside the build window.} [Build_runner._clean_tail] applies
      {!Series_tail} to the {e windowed} bars, and the splice scan uses the same
      window. A symbol whose mis-scale seam falls {e outside} the window
      presents, inside it, as a uniformly mis-scaled series with no terminal run
      and no jump: zero findings from both modules, stored whole. The committed
      seam dates make this concrete — AGR 2006-07-03, SGY 2003-09-09, DRL
      2003-09-30, TEK_old 2007-02-26, SBER 2007-07-17, LJPC 2008-12-17, BYDDY
      2009-12-28
      ([dev/experiments/warehouse-dedup-2026-09-08/results/terminal_runs_*_v10.csv])
      — each is a symbol a window ending before its seam stores as several
      thousand bars of one number.
      {b The blindness is certain at the code level; a present-day instance is
         not:} all three committed vintages run to 2026, so every seam listed is
      {e in}-window for them and none of those seven symbols would flag on
      today's warehouse. This sub-class is an argument about what the shape
      rules structurally cannot see, evidenced by dated seams — not a prediction
      that a given build produces rows, unlike the instance-verified
      [action=kept] rows of the next sub-class. So the first armed report may
      carry {b no} {!Class.Whole_window} row at all, and an empty one is the
      expected result rather than broken wiring.
    - {b The short-tail guard refuses the cut.}
      {!Series_tail.Config.stub.misscale_min_kept_bars} (250) refuses a prefix
      cut that would leave less than a trading year and stores the series
      {e whole}, artefact included
      ({!Series_tail.Action.Cut_refused_short_tail}). Four rows of the committed
      [_v10] scans sit below that floor: PEGX 210 bars behind a [999999.9999]
      sentinel, CGE 180 behind [$4,000], TNT 44 behind [$9,820], HTV {b 21}
      behind [$14,000]. The refusal is correct on its own terms — 21 bars cannot
      carry a 30-week MA — but neither module has a {e drop} action to express
      "mostly artefact, too little real data to salvage": {!Series_tail.Action}
      has none at all, and {!Series_splice.Action.Dropped} fires only on 20+
      splice findings.
    - {b Scope.} V18 examines only the symbols a run {e traded or held}
      ([Validator_store_check._v18_subjects]). A mis-scaled series the strategy
      never bought is invisible to it forever. A build-time pass sees every
      symbol in the warehouse — 2,908 on the 2000 vintage — so it can find the
      defect that has not cost money {e yet}.

    Two things this module deliberately does {b not} do, because they are
    already covered:

    - {b MEL, the motivating defect, is not in the residual.} Its 98 splice
      findings make it {!Series_splice.Class.Interleaved} and it is dropped
      outright once the detector is armed. This module would flag it and add
      nothing.
    - {b The phantom-print half of V18 is not reimplemented.} A bar moving more
      than 90% against its predecessor has a ratio below 0.1 or above 10 — far
      outside {!Splice_detector}'s [[0.4, 2.5]] band — so the splice detector
      already reports every such bar, and carries [prev_volume] / [volume] in
      its finding for exactly the reason V18's rule gates on volume. Only the
      {b level} half was ever the residual.

    {2 The rule, and the false positive it accepts}

    A series is reported when its {b median} close is strictly above
    {!Config.median_close_max}. Median rather than mean, and the median
    {e function} is byte-identical to V18's
    ([Validator_store_check._v18_median_close]: the mean of the two central
    closes at even length). Two independent copies of one statistic drift
    silently, so their agreement is pinned by a cross-module test
    ([test_series_level_v18_median_agreement] under
    [trading/backtest/validation/test/]) that feeds one bar set to both and
    compares the medians, including at even length with differing central
    closes.

    {b That agreement is about the function, not the whole check, and the two
       halves can still diverge on one shape: a series carrying non-finite
       closes.} They feed the identical function different inputs — this module
    drops non-finite closes before any statistic is taken and counts only the
    surviving bars against {!Config.min_bars}, while V18 sorts the stored array
    raw and counts all of it. [Float.compare] orders [nan] below every real
    price, so on a NaN-carrying series the two medians differ by construction
    and V18 additionally clears a [min_bars] floor this module would not. The
    agreement therefore holds for every finite series — which is every series
    the scans above produced — and is not a claim about NaN-carrying ones.

    {b The rule is deliberately bare, and a legitimately expensive instrument
       flags.} BRK.A trades above $400k and no test on the price series alone
    separates "expensive share class" from "mis-mapped listing" — V18 pinned
    that as an accepted false positive and this module inherits the decision
    unchanged. The obvious narrowing — require a large max/min ratio, so that
    only a series carrying {e both} scales flags — was argued down in V18's own
    review on false-negative grounds, and this module is the reason that
    argument was right: a uniformly mis-scaled series has a max/min ratio near
    1.0, so the refinement would blind the check to precisely the
    {!Class.Whole_window} class that is its whole purpose. The report is
    sub-classified instead (see {!Class}), which tells a reviewer what to do
    without withholding any row.

    {b Why 10,000 and not the siblings' 1,000.} [misscale_close = 1000.0] is a
    {e single-bar} test, and it already accepts real prices as false positives:
    CMG's genuine pre-split [$3,283.04] close is a committed [prefix_misscale]
    row. As a {e median over a whole series} that constant would sweep in every
    high-priced real name — NVR, AZO, BKNG, pre-split AMZN and CMG. The default
    here is V18's [store_median_close_max] (10,000.0), which clears all of those
    and still catches every measured artefact except BRK.A: AGR [$73.5k], BYDDY
    [$78k], SBER [$107k], SWD [$136k], MEL [$172k], LJPC [$220k], HTV [$14k],
    and the [999999.9999] sentinels.

    {2 Report-only, and not yet wired}

    This module
    {b classifies and reports; it never edits a series and has no action type},
    which is why it is safe for a rule that knowingly flags BRK.A: at build time
    an automatic drop on that false positive would delete a real company.
    {!Config.enabled} defaults to [false] on top of that, mirroring
    {!Splice_detector.Config.enabled}, so arming is always explicit.

    Nothing calls it yet. That is {!Splice_detector}'s own sequence — #2649
    shipped detection that "does nothing about them" and #2708 shipped the
    action half — and it keeps the wiring (a [hygiene_opts] field, a sidecar
    file, a CLI flag on an already-729-line [build_runner.ml]) in its own
    reviewable change. Until then every warehouse and every golden is
    bit-identical by construction.

    {b Basis: raw [close_price]}, matching {!Series_tail} and the scans that
    produced the class lists above (AGR's [$73,566] is the raw close; its
    adjusted close at the same bar is [$18,737]). The question is what one share
    of the ticket costs, which is the raw number.

    Pure: no I/O, no clock, no global state. Same bars + config always give the
    same finding. *)

open Core

module Config : sig
  type t = {
    enabled : bool;
        (** Master switch. Defaults to [false] so an unarmed build gets [None]
            from {!classify} without reading a bar. Mirrors
            {!Splice_detector.Config.enabled}. *)
    median_close_max : float;
        (** A series whose median close is {e strictly} above this is reported.
            Default [10_000.0] — V18's [store_median_close_max], for the reasons
            in the header. The ceiling itself is clean. *)
    min_bars : int;
        (** Series with fewer finite closes than this are not classified at all:
            a median over a handful of bars is not evidence the series is sane.
            Default [20], V18's [store_min_bars].

            {b Clamped to a floor of 1}, as V18's own step guard is: this is a
            plain [int] with no smart constructor, so a [0] or negative value
            reaching it from a future CLI flag or sexp would otherwise let an
            empty series through to the median of an empty array. The clamp is a
            crash guard, not a policy — a floor of 1 is still far too short for
            the median to mean anything. *)
  }
  [@@deriving sexp, equal]

  val default : t
  (** [enabled = false], [median_close_max = 10_000.0], [min_bars = 20]. *)
end

(** How a reported series carries its implausible level — which decides what a
    reviewer can do about it, and whether any other module can see it. *)
module Class : sig
  type t =
    | Whole_window
        (** {e Every} bar is above the ceiling ([n_above = n_bars]). There is no
            seam inside the stored window, so neither {!Series_tail} nor
            {!Splice_detector} has anything to key on and no cut can help: there
            is no real segment in this window to keep. A reviewer's only options
            are to drop the symbol or to raise the ceiling.
            {b This is the residual class} the module exists for, and the one a
            max/min-ratio refinement would have hidden. *)
    | Mixed_scale
        (** The median is above the ceiling but at least one bar is at or below
            it: the series carries two scales and the seam is inside the window.
            The shape rules {e can} see this one — cross-reference
            [terminal_runs.csv] and [splice_actions.csv] before acting, since a
            cut that keeps the real segment is strictly better than a drop, and
            this class is where a {!Series_tail.Action.Cut_refused_short_tail}
            row (PEGX, CGE, TNT, HTV) shows up. *)
  [@@deriving sexp_of, compare, equal]

  val to_string : t -> string
  (** Lower-snake spelling used in the CSV ([whole_window], [mixed_scale]). *)
end

type finding = {
  symbol : string;
  klass : Class.t;
  n_bars : int;
      (** Bars the statistics were computed over: the series length minus any
          non-finite closes. *)
  first_date : Date.t;
  last_date : Date.t;  (** Span of those same bars. *)
  median_close : float;  (** The statistic the rule tested. *)
  min_close : float;
      (** Lowest close — the real segment's scale when there is one, and what
          distinguishes an artefact from an expensive share class to a reader.
      *)
  max_close : float;
      (** Highest close — tells a [999999.9999] sentinel apart from a merely
          mis-scaled price. *)
  n_above : int;
      (** Closes strictly above the ceiling. Equal to {!field-n_bars} exactly
          when the class is {!Class.Whole_window}, and always positive in a
          finding (a median above the ceiling puts at least half the series
          there). *)
}
[@@deriving sexp_of, compare, equal]
(** One row of the review report. Produced only for a series that failed the
    rule; a plausible series yields no row, so the report is the findings rather
    than the warehouse. *)

val classify :
  Config.t -> symbol:string -> Types.Daily_price.t list -> finding option
(** [classify config ~symbol bars] is the review row for [symbol], or [None]
    when there is nothing to report.

    [None] is returned — without editing anything, since this module never edits
    anything — when [config.enabled] is [false], when fewer than
    [config.min_bars] of [bars] carry a finite close, or when the median close
    is at or below [config.median_close_max].

    {b Non-finite closes are excluded from every field}, not merely from the
    median: a NaN has no meaningful position in an order statistic, and letting
    one through would write [nan] into the report — the same failure
    {!Series_tail} guards against on its own reference close. [n_bars],
    [first_date], [last_date] and the three price fields therefore all describe
    the finite-close bars, consistently.

    Bar order does not affect the result: the median, the extrema and the count
    are order-independent, and the reported span is the earliest and latest
    date, not the first and last element. *)

val whole_window_symbols : finding list -> string list
(** [whole_window_symbols findings] are the symbols classified
    {!Class.Whole_window}, in [findings] order — the drop candidates, the rows
    for which no cut exists. Separated out because that is the only class a
    reviewer can act on without first reading another module's report. *)

val csv_header : string
(** Header line of the report, without a trailing newline. *)

val to_csv : finding list -> string
(** Renders {!csv_header} plus one line per finding, newline-terminated. Column
    order matches the header:
    [symbol,class,n_bars,first_date,last_date,median_close,min_close,max_close,n_above].
    A list with no findings renders as the header alone — positive evidence that
    the pass ran and found nothing, as in {!Series_splice.to_csv}. *)

val summary : finding list -> string
(** One-line human summary for the builder's stderr, e.g.
    ["series_level: 3 findings (2 whole_window, 1 mixed_scale)"]. *)
