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

    {2 Drop versus cut — why one splice is not like six hundred}

    The committed full scan
    ([dev/experiments/arc-rerun-2026-09-01/results/splice-scan.csv], 11,028
    flagged bars across 602 symbols of the 2000-vintage warehouse
    [snap_top3000_dedup_v5thin_adj]) splits into two shapes a single rule cannot
    treat alike:

    - {b Interleaved} — 66 symbols carry {b 20 or more} findings: SWD 1,215, AEZ
      694, ICT 589, CLE 412, MEL 98, MVL 80. A series does not legitimately jump
      out of band hundreds of times. These are two issuers' bars
      {e shuffled together}, not one series with a seam, so there is no date
      that splits them: any cut leaves both issuers on both sides. They are
      {b dropped} — the symbol is excluded from the build's symbol set, so it is
      {b absent} from the manifest rather than present with zero bars.
    - {b Reuse} — the long tail of 1-2-finding symbols is a single ticker
      recycled once. CHS is the motivating case (#2646): two findings,
      2001-12-19 and 2004-12-20, the second being the x3.9 jump a backtest
      "sold" into for +$513,550 on a three-day hold. The series is
      {b cut at the last splice, keeping the later segment} — the bars that
      describe the currently-listed issuer. The earlier issuer's bars are
      unrecoverable under this ticker, so they are dropped rather than
      re-exported under a synthetic name.

    A third shape rides on the same cut. AGR's single finding is
    [2006-07-05: 18,737.14 -> 14.41] on the adjusted series (raw
    [73,566 -> 33.94]): the {e earlier} segment is mis-scaled, not a different
    company. It is the same 10-symbol {b prefix mis-scale} class {!Series_tail}
    refuses to touch (plan §Sizing: AGR, SGY, SBER, DRL, TEK_old, GEG_old, SWD,
    LAN, HPC, MEL) — a bare tail walk-back would delete thousands of real bars,
    but a splice cut keeps exactly the real ones. The action is the same
    [Cut_at]; the class differs so the report names it and a reviewer can veto
    it.

    {2 Report first, act second}

    The detector's master switch ({!Splice_detector.Config.enabled}) stays
    [false] by default, so an unarmed build never reaches this module: every
    pre-existing warehouse and every golden is bit-identical. When the detector
    {e is} armed the actions apply, and [-no-splice-action] ({!Config.act} =
    [false]) reduces the pass to #2649's report-only behaviour — every finding
    is still classified and still written to [splice_actions.csv], with action
    {!Action.Kept} and not one bar changed.

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
            {!Class.Interleaved} and is dropped; below it the series is cut.
            Default [20] — the cut the committed scan shows, which separates 66
            hundreds-of-findings symbols from a long tail of 1-2-finding single
            reuses. *)
    misscale_close : float;
        (** At or above this, the close on the last bar {e before} the cut is
            not a real price and the earlier segment is a {b prefix mis-scale}
            rather than a different issuer. Default [1000.0] — the same constant
            {!Series_tail.Config.stub.misscale_close} uses, measured on the same
            10 symbols. *)
  }

  val default : t
  (** [act = true], [max_findings_keep = 20], [misscale_close = 1000.0]. *)
end

module Exceptions : sig
  (** A reviewer's veto of, or substitute for, the rule's decision on one
      symbol. Read from the committed
      [trading/test_data/warehouse_exceptions.sexp] (the same file
      {!Series_tail} reads, under a separate [splice] section) so a decision
      lands without a code change. *)
  type rule =
    | Keep of string  (** Store the series whole, however it classifies. *)
    | Drop of string  (** Exclude the symbol, however it classifies. *)
    | Cut_at of string * Core.Date.t
        (** Cut at this date instead of the rule's, keeping bars on or after it.
        *)
  [@@deriving sexp, equal]

  type t

  type file = { splice : rule list } [@@deriving sexp]
  (** On-disk shape of the file's [splice] section:
      [((splice ((keep SYM) (drop SYM) (cut_at SYM 2004-12-20))))]. The section
      is optional and unknown sections are ignored, so a file carrying only
      {!Series_tail}'s [keep_tail] parses as "no splice exceptions" and a file
      carrying both parses for both modules. *)

  val empty : t
  (** No exceptions — every symbol is subject to the rule. *)

  val of_file : file -> t
  (** [of_file f] is [of_rules f.splice]. *)

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
    | Reuse  (** Fewer findings: one ticker recycled, cut at the last splice. *)
    | Prefix_misscale
        (** A [Reuse]-shaped cut whose earlier segment is mis-scaled rather than
            a different issuer — the close before the cut is at or above
            [misscale_close] (AGR). *)
  [@@deriving sexp_of, compare, equal]

  val to_string : t -> string
  (** Lower-snake spelling used in [splice_actions.csv] ([interleaved], ...). *)
end

(** What the build actually did with the series. *)
module Action : sig
  type t =
    | Dropped  (** Symbol excluded from the warehouse by the rule. *)
    | Cut_at  (** Bars before the last splice dropped by the rule. *)
    | Kept
        (** Reported only — the class is [Clean], or {!Config.act} is [false].
        *)
    | Kept_by_exception  (** {!Exceptions.Keep} overrode the rule. *)
    | Dropped_by_exception  (** {!Exceptions.Drop} overrode the rule. *)
    | Cut_by_exception  (** {!Exceptions.Cut_at} overrode the rule's date. *)
  [@@deriving sexp_of, compare, equal]

  val to_string : t -> string
  (** Lower-snake spelling used in [splice_actions.csv] ([dropped], ...). *)
end

type finding = {
  symbol : string;
  klass : Class.t;
  n_findings : int;  (** Splice dates the detector reported for this symbol. *)
  cut_after : Core.Date.t option;
      (** Date of the last bar {e before} the cut — the last bar dropped. [None]
          when nothing is cut, or when the cut date precedes every bar. *)
  cut_from : Core.Date.t option;
      (** First bar {e kept} by the cut: the last splice date, or the
          exception's date. Reported even under [act = false], so the report
          says what an armed build {e would} do. *)
  n_dropped : int;
      (** Bars removed. Equal to the whole series for a dropped symbol. *)
  action : Action.t;
}
[@@deriving sexp_of, compare, equal]
(** One row of [splice_actions.csv]. *)

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

    A cut that would leave no bars behind degenerates to a drop (bars [None],
    [n_dropped] = the whole series), because a zero-bar manifest entry is
    exactly the shape the drop rule exists to avoid.

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
    {!Action.Cut_by_exception}), so a report-only run yields an empty plan. This
    is what the scanner hands the builder. *)

val dropped_symbols : finding list -> string list
(** [dropped_symbols findings] are the symbols the build must exclude
    ({!Action.Dropped} / {!Action.Dropped_by_exception}), in [findings] order.
    Empty on a report-only run. *)

val csv_header : string
(** Header line of [splice_actions.csv], without a trailing newline. *)

val to_csv : finding list -> string
(** Renders {!csv_header} plus one line per finding, newline-terminated. Column
    order matches the header:
    [symbol,class,n_findings,cut_after,n_dropped,action]. An absent date renders
    as an empty field. A list with no findings renders as the header alone —
    positive evidence that the pass ran and found nothing. *)

val summary : finding list -> string
(** One-line human summary the builder logs, e.g.
    ["series_splice: 3 findings (1 dropped, 1 cut_at, 1 kept, 0 by_exception)"].
*)
