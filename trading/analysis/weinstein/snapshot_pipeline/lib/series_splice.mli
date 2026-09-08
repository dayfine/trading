(** Build-time splice hygiene: stop a ticker-reuse series from describing two
    issuers at once (issue #2672, class ii of
    [dev/plans/delisting-data-fix-2026-09-06.md] §Design item 4).

    {!Splice_detector} finds the days on which a series jumps from one security
    to another under the same ticker — a vendor feed joining two issues, or an
    exchange recycling a delisted symbol — and, since #2649, does nothing about
    them. This module is the {b action}: given a symbol's bars plus the dates
    the detector flagged for it, it decides whether the warehouse should store
    the series whole, store only its later segment, or not store it at all. It
    is the splice-side sibling of {!Series_tail}, and deliberately mirrors that
    module's shape ({!Config}, {!Exceptions}, {!Class}, {!Action}, {!apply}, a
    CSV report).

    {2 Drop, cut, or report — why one splice is not like six hundred}

    The committed full scan
    ([dev/experiments/arc-rerun-2026-09-01/results/splice-scan.csv], 11,028
    flagged bars across 603 symbols of the 2000-vintage warehouse
    [snap_top3000_dedup_v5thin_adj]) splits into three shapes a single rule
    cannot treat alike:

    - {b Interleaved} — 66 symbols carry {b 20 or more} findings: SWD 1,215, AEZ
      694, ICT 589, CLE 412, MEL 98, MVL 80. A series does not legitimately jump
      out of band hundreds of times. These are two issuers' bars
      {e shuffled together}, not one series with a seam, so there is no date
      that splits them: any cut leaves both issuers on both sides. They are
      {b dropped} — the symbol is excluded from the build's symbol set, so it is
      {b absent} from the manifest rather than present with zero bars.
    - {b Prefix mis-scale} — AGR's single finding is
      [2006-07-05: 18,737.14 -> 14.41] on the adjusted series (raw
      [73,566 -> 33.94]): the {e earlier} segment is mis-scaled, not a different
      company. It is the same 10-symbol class {!Series_tail} refuses to touch
      (plan §Sizing: AGR, SGY, SBER, DRL, TEK_old, GEG_old, SWD, LAN, HPC, MEL)
      — a bare tail walk-back would delete thousands of real bars, but a splice
      cut keeps exactly the real ones. The earlier segment is a known artefact
      rather than a company, so this class still {b cuts by rule}, and the class
      name lets a reviewer veto it.
    - {b Reuse} — everything else: one or two findings on a series that may be a
      recycled ticker. This class is {b report-only} ({!Action.Kept}); see
      below.

    {2 Why [Reuse] no longer cuts by rule (#2711)}

    PR #2708 shipped [Reuse] as "cut at the last splice, keeping the later
    segment", on the CHS case (#2646: two findings, 2001-12-19 and 2004-12-20,
    the second an x3.9 jump a backtest "sold" into for +$513,550 on a three-day
    hold). The first armed scan of the 2000 vintage measured what that rule
    would actually have done
    ([dev/experiments/warehouse-rebuild-2026-09-06/results/splice_actions_2000_v8ctl.csv],
    591 symbols with findings: interleaved 67, prefix_misscale 6,
    {b reuse 518}). Bars dropped per reuse symbol: p10 455, {b p50 2,033}, p75
    3,269, p90 4,906, max 6,805 — {b 247 of the 518 would have lost 90% or more}
    of their series.

    The deepest cuts are not recycled tickers at all. The verified terminal
    cases keep a stub of a few dozen bars: GES 43 (cut 2026-01-22, 6,805 of
    6,848 bars — taken private), RAD 43, TUPBQ 26, BIG 9, HIBB 7, TUP 1 — and 16
    of the 20 deepest cuts leave 80 bars or fewer. A takeover premium or a
    bankruptcy collapse trips the detector's adjusted-ratio band
    {e on the security's last real day}, so "keep the later segment" keeps the
    {b administrative stub} and deletes the company. That is the exact shape
    {!Series_tail} exists to handle from the other side.

    So the default for [Reuse] is {!Action.Kept}: classified, reported with its
    would-be depth, and {b not edited}. A reuse series is cut only where a
    reviewer read the report and recorded [(cut_at SYM DATE)] (or [(drop SYM)])
    in the committed exceptions file — which is what the plan's §Design item 4
    asked for in the first place ("a symbol with a splice finding is split at
    the splice or dropped {e per a committed exceptions file}").

    {2 The short-tail guard — a safety net, {b not} the protection}

    {!Config.min_kept_bars} (default 250, one trading year) applies to {b every}
    cut, the rule's [Prefix_misscale] one and a reviewer's [cut_at] alike: if
    the later segment would be shorter than that, the cut is {b refused}
    ({!Action.Cut_refused_short_tail}), the symbol is stored whole, and the row
    records the refusal. A terminal jump followed by a short tail is a delisting
    stub, which is {!Series_tail}'s domain and never a reuse — so an exceptions
    entry written from a misread report cannot delete a company either.

    {b The guard does not, on its own, fix what #2711 found.} On the same
    control arm it would have refused only {b 259 of the 518} reuse cuts, and
    {b 18 symbols lose 90% or more} of their series while still leaving a tail
    of 250 bars or more (NKTR 289 bars, EMMS 263 — live repricings, not terminal
    events). What protects those is the report-only default above; the guard is
    the second line, covering the exception-driven cut a reviewer gets wrong.

    {2 Report first, act second}

    The detector's master switch ({!Splice_detector.Config.enabled}) stays
    [false] by default, so an unarmed build never reaches this module: every
    pre-existing warehouse and every golden is bit-identical. When the detector
    {e is} armed the actions apply, and [-no-splice-action] ({!Config.act} =
    [false]) reduces the pass to #2649's report-only behaviour — every finding
    is still classified and still written to [splice_actions.csv], with action
    {!Action.Kept} and not one bar changed. Either way every row carries
    {!field-n_dropped} / {!field-n_kept} measured off the bars, so the depth of
    a cut that did not happen is readable from the sidecar instead of re-derived
    from the bar store (#2711 item 3).

    Pure: no I/O, no clock, no global state. Same bars + splices + config always
    give the same bars + finding. The caller owns loading, the sidecar file, and
    removing dropped symbols from the build's symbol set. *)

module Config : sig
  type t = {
    act : bool;
        (** Edit the series. [false] classifies and reports without changing
            anything (the [-no-splice-action] CLI flag), which is #2649's
            behaviour. Detection and reporting run either way. *)
    max_findings_keep : int;
        (** A symbol with {e at least} this many findings is
            {!Class.Interleaved} and is dropped; below it the series is a
            [Reuse] or a [Prefix_misscale]. Default [20] — the cut the committed
            scan shows, which separates 66 hundreds-of-findings symbols from a
            long tail of 1-2-finding single reuses. *)
    misscale_close : float;
        (** At or above this, the close on the last bar {e before} the cut is
            not a real price and the earlier segment is a {b prefix mis-scale}
            rather than a different issuer. Default [1000.0] — the same constant
            {!Series_tail.Config.stub.misscale_close} uses, measured on the same
            10 symbols. *)
    min_kept_bars : int;
        (** Refuse any cut — rule-driven or exception-driven — that would leave
            fewer than this many bars in the later segment, reporting
            {!Action.Cut_refused_short_tail} and storing the series whole.
            Default [250]: one trading year, the shortest later segment from
            which a 30-week MA and a stage classification can still be derived,
            and the length below which "keep the later segment" is keeping a
            delisting stub rather than a company (#2711: GES lost 6,805 of 6,848
            bars to a 43-bar stub under the blanket rule).

            {b This is a safety net for exception-driven cuts; it does not
               replace the report-only default.} It would have refused only 259
            of the 518 blanket reuse cuts, and 18 symbols lose 90%+ of their
            series behind a tail longer than 250 bars — {!Class.Reuse}
            defaulting to {!Action.Kept} is what protects those.

            [0] disables the guard, and then a cut that leaves no bars at all
            degenerates to a drop rather than being refused. *)
  }

  val default : t
  (** [act = true], [max_findings_keep = 20], [misscale_close = 1000.0],
      [min_kept_bars = 250]. *)
end

module Exceptions : sig
  (** A reviewer's veto of, or substitute for, the rule's decision on one
      symbol. Recorded in the committed
      [trading/test_data/warehouse_exceptions.sexp] (the same file
      {!Series_tail}'s vetoes live in, under a separate [splice] section) so a
      decision lands without a code change.

      Since #2711 this is also the {e only} way a [Reuse] series is cut: the
      rule reports it and a human decides. *)
  type rule =
    | Keep of string  (** Store the series whole, however it classifies. *)
    | Drop of string  (** Exclude the symbol, however it classifies. *)
    | Cut_at of string * Core.Date.t
        (** Cut at this date instead of the rule's, keeping bars on or after it.
            Still subject to {!Config.min_kept_bars}. *)
  [@@deriving sexp, equal]

  type t
  (** The [splice] section of the committed warehouse exceptions file, indexed
      by symbol. On disk the file reads [((keep_tail (...)) (splice (...)))],
      with each splice rule spelt [(keep SYM)] / [(drop SYM)] /
      [(cut_at SYM 2004-12-20)].

      This module does {e not} parse that file. {!Build_runner} reads it once,
      into a single strict record whose two sections are both optional, and
      hands each module its own section as a view — see
      {!Build_runner.load_splice_exceptions}. Strict means a mistyped section
      name is a parse error rather than a silently empty veto list. *)

  val empty : t
  (** No exceptions — every symbol is subject to the rule. *)

  val of_rules : rule list -> t
  (** [of_rules rules] indexes [rules] by symbol. A symbol named twice keeps the
      last rule, so an operator appending a correction does not have to delete
      the line above it. *)

  val find : t -> symbol:string -> rule option
  (** [find t ~symbol] is the reviewer's rule for [symbol], if any. *)
end

(** How a symbol's splice findings classify. *)
module Class : sig
  type t =
    | Clean  (** No findings — the series has no splice to act on. *)
    | Interleaved
        (** At least [max_findings_keep] findings: two issuers shuffled
            together, with no date that separates them. *)
    | Reuse
        (** Fewer findings: one ticker possibly recycled. {b Report-only} since
            #2711 — 518 of these on the 2000 vintage, of which 247 would have
            lost 90%+ of their bars to the old blanket cut because the "splice"
            was a takeover or a bankruptcy on the security's last real day. *)
    | Prefix_misscale
        (** A [Reuse]-shaped cut whose earlier segment is mis-scaled rather than
            a different issuer — the close before the cut is at or above
            [misscale_close] (AGR). Still cut by rule. *)
  [@@deriving sexp_of, compare, equal]

  val to_string : t -> string
  (** Lower-snake spelling used in [splice_actions.csv] ([interleaved], ...). *)
end

(** What the build actually did with the series. *)
module Action : sig
  type t =
    | Dropped  (** Symbol excluded from the warehouse by the rule. *)
    | Cut_at
        (** Bars before the cut dropped by the rule ([Prefix_misscale]). *)
    | Kept
        (** Reported only — the class is [Clean] or [Reuse], or {!Config.act} is
            [false]. *)
    | Kept_by_exception  (** {!Exceptions.Keep} overrode the rule. *)
    | Dropped_by_exception  (** {!Exceptions.Drop} overrode the rule. *)
    | Cut_by_exception  (** {!Exceptions.Cut_at} overrode the rule's date. *)
    | Cut_refused_short_tail
        (** A cut was called for — by the rule or by an exception — and refused
            because the later segment is shorter than {!Config.min_kept_bars}.
            The series is stored whole; [n_kept] is the length that failed the
            guard. *)
  [@@deriving sexp_of, compare, equal]

  val to_string : t -> string
  (** Lower-snake spelling used in [splice_actions.csv] ([dropped], ...). *)
end

type finding = {
  symbol : string;
  klass : Class.t;
  n_findings : int;  (** Splice dates the detector reported for this symbol. *)
  cut_after : Core.Date.t option;
      (** Date of the last bar {e before} the cut point — the last bar an
          applied cut drops. [None] when there is no cut point, or when it
          precedes every bar. *)
  cut_from : Core.Date.t option;
      (** First bar {e kept} by the cut point: the exception's date, or the last
          splice date. Reported whether or not the build cut there — including
          for a report-only [Reuse] row — so the report says what a cut
          {e would} do. *)
  n_dropped : int;
      (** Bars strictly before {!field-cut_from}, counted off the bars rather
          than off the action: the depth an applied cut had, or the depth the
          cut that did not happen {e would} have had. Equal to the whole series
          for a dropped symbol, [0] when there is no cut point. *)
  n_kept : int;
      (** Bars on or after {!field-cut_from} — the later segment's length, and
          the number the {!Config.min_kept_bars} guard is tested against. [0]
          for a dropped symbol, the whole series when there is no cut point. *)
  action : Action.t;
}
[@@deriving sexp_of, compare, equal]
(** One row of [splice_actions.csv]. [n_dropped + n_kept] is the series length
    for every row. *)

val apply :
  Config.t ->
  exceptions:Exceptions.t ->
  symbol:string ->
  splices:Core.Date.t list ->
  Types.Daily_price.t list ->
  Types.Daily_price.t list option * finding option
(** [apply config ~exceptions ~symbol ~splices bars] classifies [splices] (the
    dates {!Splice_detector} flagged for [symbol]; order and duplicates do not
    matter) and returns the bars the warehouse should store, plus the report
    row.

    [None] bars means {b drop the symbol entirely} — the caller must remove it
    from the build's symbol set so it is absent from the manifest, not present
    with zero bars. [None] finding means there was nothing to report: no splices
    and no exception naming this symbol.

    A cut leaving fewer than [config.min_kept_bars] bars is refused and the
    whole series returned ({!Action.Cut_refused_short_tail}). With the guard
    switched off ([min_kept_bars = 0]) a cut that would leave no bars at all
    degenerates to a drop instead, because a zero-bar manifest entry is exactly
    the shape the drop rule exists to avoid.

    {b [active_through] is unaffected by a cut.} The cut keeps the {e later}
    segment, so the series' last bar — the delisting evidence
    {!Build_runner.build} derives the manifest's [active_through] from — is the
    same bar before and after. A dropped symbol has no manifest entry and
    therefore no marker at all. *)

val keep_from :
  Core.Date.t -> Types.Daily_price.t list -> Types.Daily_price.t list
(** [keep_from date bars] is the bars dated on or after [date]: the later
    segment of a cut series.

    Exposed because the {e decision} is made by the scanner, which sees every
    symbol's full-history bars, while the {e edit} is applied by
    {!Build_runner.build} to that symbol's windowed build bars. Both sides use
    this one function so the two cuts cannot drift apart. *)

val cut_plan : finding list -> Core.Date.t Core.Map.M(Core.String).t
(** [cut_plan findings] maps each symbol the build must cut to the date it keeps
    from — only the findings whose action actually cut ({!Action.Cut_at} /
    {!Action.Cut_by_exception}), so a report-only run, and a refused cut, yield
    no entry. This is what the scanner hands the builder. *)

val dropped_symbols : finding list -> string list
(** [dropped_symbols findings] are the symbols the build must exclude
    ({!Action.Dropped} / {!Action.Dropped_by_exception}), in [findings] order.
    Empty on a report-only run. *)

val csv_header : string
(** Header line of [splice_actions.csv], without a trailing newline. *)

val to_csv : finding list -> string
(** Renders {!csv_header} plus one line per finding, newline-terminated. Column
    order matches the header:
    [symbol,class,n_findings,cut_after,n_dropped,n_kept,action]. An absent date
    renders as an empty field. A list with no findings renders as the header
    alone — positive evidence that the pass ran and found nothing. *)

val summary : finding list -> string
(** One-line human summary the builder logs, e.g.
    ["series_splice: 3 findings (1 dropped, 1 cut_at, 1 kept, 0 refused, 0
     by_exception)"]. *)
