(** Build-time series-tail hygiene: end a delisted symbol's series at its last
    real print (issue #2672).

    A vendor series does not stop when the company does. After a cash takeover
    or a bankruptcy the feed often carries an administrative {b stub tail} — a
    short run of sub-cent prints no counterparty could ever have filled — and
    sometimes a single {b stray bar} dated years after the real last trade.
    Those bars are phantom data: a held long's stop sits far above them, so the
    simulator sells into a price that never existed.

    This module is the {b pure core} of the build-time fix. It looks at one
    symbol's daily bars, classifies the terminal run of implausibly low closes,
    and returns the bars the warehouse should actually store. The warehouse
    builder ({!Build_runner}) applies it before {!Pipeline.build_for_symbol}, so
    the [.snap] file never contains a stub bar and no runtime guard is needed.

    {2 Why not a bare ratio}

    The obvious rule — "walk back while [close < ratio * previous close]" — keys
    on price shape alone, and it is {b wrong at build time}. (It is the rule the
    retired #2672 runtime guard applied at read time; this module supersedes it
    precisely because a bare ratio is not enough.) Measured over all 2,908
    symbols of the 2000-vintage warehouse [snap_top3000_dedup_v5thin_adj] at
    [ratio = 0.05], the terminal run splits into four populations a single ratio
    cannot separate:

    - {b stub tail} (13 symbols) — the defect. STMP: real to 2021-10-04 at
      [$329.61], then 18 bars of [$0.045 / $0.04 / $0.03]. WDR: 29 bars at
      [$0.27] after a [$24.98] cash deal. HIBB 7 bars at [$0.00], PFSW 9,
      BULL_old 4, TVSFF 1, NCF 1, plus six already-sub-cent micro-caps (RDRTQ,
      UPSL, AWEB, IMBI, SDNA, LMSC).
    - {b prefix mis-scale} (10 symbols: AGR, SGY, SBER, DRL, TEK_old, GEG_old,
      SWD, LAN, HPC, MEL) — the {e early} bars are mis-scaled, so the "run" is
      the real series. AGR's last "real" close is [$73,566] and the run below it
      is {b 4,653 genuine bars}; a bare ratio walk-back would delete all of
      them. Recognised by [last_real_close >= misscale_close] (default 1,000).
      This class is not merely reported since #2732: see
      {b Cutting the prefix mis-scale} below.
    - {b long low tail} (23 symbols) — hundreds to thousands of penny bars
      (ticker reuse, or a genuine multi-month collapse). Recognised by
      [n_stub > max_bars] (default 60).
    - {b high-priced tail} (1 symbol: ANCR) — a terminal run below [ratio] whose
      own prints are still real money. ANCR is real to [$66.68] and then prints
      a single bar at [$2.07]: that run is {e kept} here, and the stray pass
      drops the bar separately (see {b Ordering and composition}). Recognised by
      [first_stub_close >= max_price] (default [$1.00]). MEL ([$8,900] then 21
      bars at [$11.72]) clears this gate too, but the mis-scale rule outranks it
      and claims MEL first — so MEL illustrates the {e ordering}, not this
      class. The gate is what keeps a [$100 -> $2] terminal collapse out of the
      stub class.

    Raising the ratio does not help: at [0.20] the terminal-run count is 116 and
    at [0.50] it is 109. The ratio is not the lever —
    {b the run-length cap and the absolute-price floor} are what isolate the
    stub class. So the truncation rule is
    [ratio AND n_stub <= max_bars AND first_stub_close < max_price]; the
    mis-scale class gets its own {e opposite} edit (below), and the remaining
    two classes are reported untouched for a human to read once per vintage.

    {2 Cutting the prefix mis-scale (#2732)}

    Reporting the mis-scale class and storing it whole was the {e first} half of
    the fix. The class is not benign: the mis-scaled prefix is a price no
    counterparty could trade, so a backtest that touches it buys one "share" of
    AGR at [$73,566] and is force-liquidated on the first real bar. MEL — the
    same shape, [$8,900] then [$11.72] — is why the 2026-09-08 dedup rebuild
    quarantined a symbol by hand ([rebuild4.sh] grep-drops [(symbol MEL)]),
    which is not a fix. The committed scan of the [_v10] vintages
    ([dev/experiments/warehouse-dedup-2026-09-08/results/terminal_runs_*_v10.csv])
    lists {b 12 such rows on the 2000 vintage, 12 on 2009, 6 on 2019}, every one
    of them [action = kept]: AGR, AKR, BKNG, DRL, GEG_old, HPC, LAN, PEGX, SBER,
    SGY, SWD, TEK_old. BKNG and PEGX carry a [999999.9999] sentinel rather than
    a merely-large price.

    The right edit is the {b opposite} of the stub one. A tail walk-back is
    refused for this class because walking back from the end would delete the
    4,653 genuine bars {e below} AGR's fake close; a {b prefix cut} — drop every
    bar up to and including [cut_after], keep the series from [first_stub_date]
    — deletes exactly the artefact and keeps exactly the company. The two edits
    read the same run from opposite ends, which is why they share this module
    and this report.

    The cut is behind {!Config.stub.misscale_cut}, {b default [false]}: an
    un-armed build (every existing warehouse, every committed golden) still
    reports the class and stores it whole, bit-identically. When armed, an
    eligible row's action becomes {!Action.Cut_prefix} and the sidecar keeps its
    [n_stub] / [first_stub_date] columns, so the depth of a cut is readable from
    the CSV whether or not it happened.

    {b Short-tail guard.} {!Config.stub.misscale_min_kept_bars} (default 250,
    one trading year) refuses any cut whose kept segment would be shorter,
    reporting {!Action.Cut_refused_short_tail} and storing the series whole.
    This is the same constant and the same rationale as
    {!Series_splice.Config.min_kept_bars}, and PEGX is the live case it catches:
    210 real bars behind a sentinel is too little to derive a 30-week MA or a
    stage from, so it is reported for a human rather than cut. The kept segment
    is never {e empty} — the run always starts at or before the last bar — so a
    cut can never degenerate into a drop.

    {2 Precedence versus {!Series_splice}}

    Both modules classify a [Prefix_misscale] and both keep the {e later}
    segment, so an armed build cannot get two different answers. They cannot
    both edit either: {!Build_runner} applies the splice cut {b first} and this
    module {b second} (see [Build_runner._build_one_symbol]), so if the splice
    pass already removed the mis-scaled prefix, the terminal-run scan reads the
    later segment alone and finds no run to classify. The splice detector's
    master switch is [false] by default and the [_v10] rebuild did not arm it,
    which is why the 30 rows above were never acted on from that side. The two
    guards agree by construction: same [misscale_close] (1,000.0), same minimum
    kept length (250).

    {2 Stray late bars}

    Separately, 14 symbols carry a trailing bar dated years after the previous
    one (ANCR: 2000-08-01, then a single bar on 2016-01-27). Up to
    [Config.stray.max_bars] such bars are dropped when the gap to the preceding
    bar is at least [Config.stray.gap_days].

    {2 Ordering and composition}

    {!apply} runs the terminal-run pass first — truncating a stub tail, or
    cutting a mis-scaled prefix when that edit is armed — then looks for a stray
    suffix in whatever bars that pass returned. A symbol can therefore produce
    {b two} findings (ANCR's terminal run is kept as high-priced, then its 2016
    bar is dropped as stray) — which is why findings come back as a list rather
    than an option. NCF's single 2016 bar is both shapes at once; it is
    truncated as a stub and the series ends at 2004-09-30 either way.

    {2 Basis}

    Classification reads {b raw} [close_price], matching the runtime guard's
    basis and the scan that produced the class lists above. A NaN close is
    treated as non-stub in {b both} positions a close can occupy: a run never
    {e spans} one (the suffix maximum is unbounded, so the run test fails), and
    a run never {e starts after} one (a non-finite reference disqualifies the
    candidate). The second half matters because the reference close is what a
    finding reports as [last_real_close] — without it, a NaN followed by a
    handful of sub-$1 bars would truncate and write [nan] into the report.

    Pure: no I/O, no clock, no global state. Same bars + config always give the
    same bars + findings. *)

module Config : sig
  type stub = {
    truncate : bool;
        (** Edit the bars when the run classifies as a stub tail. [false]
            reports without changing anything (the [-no-stub-truncation] CLI
            flag). Detection and reporting run either way. *)
    ratio : float;
        (** A bar is a stub relative to reference close [r] when
            [close < ratio *. r]. Default [0.05]. [<= 0.0] disables detection
            entirely. *)
    max_bars : int;
        (** Longest terminal run still eligible for truncation. Default [60] —
            above it the run is a {b long low tail}, kept. *)
    max_price : float;
        (** The run's first close must be strictly below this to be a stub.
            Default [1.0] — at or above it the run is a {b high-priced tail},
            kept. *)
    misscale_close : float;
        (** At or above this, the close preceding the run is not a real price
            and the "run" is the real series: a {b prefix mis-scale}. Default
            [1000.0]. Whether that class is then cut or kept is [misscale_cut].
        *)
    misscale_cut : bool;
        (** Drop the mis-scaled prefix when the run classifies as
            {!Class.Prefix_misscale}, keeping the run itself (the
            [-cut-prefix-misscale] CLI flag). {b Default [false]} — an un-armed
            build reports the class and stores the series whole, exactly as
            before #2732, so every existing warehouse and golden is
            bit-identical. Detection and reporting run either way. *)
    misscale_min_kept_bars : int;
        (** Refuse a prefix cut that would leave fewer than this many bars,
            reporting {!Action.Cut_refused_short_tail} and storing the series
            whole. Default [250]: one trading year, the shortest segment a
            30-week MA and a stage classification can still be derived from, and
            the same constant {!Series_splice.Config.min_kept_bars} uses. PEGX
            (210 bars behind a [999999.9999] sentinel) is the row this refuses
            at the default. [0] disables the guard; the kept segment is never
            empty, so even then a cut cannot degenerate into a drop. *)
  }

  type stray = {
    drop : bool;
        (** Drop the stray suffix. [false] reports only (the [-no-stray-drop]
            CLI flag). *)
    gap_days : int;
        (** Minimum calendar-day gap between the suffix's first bar and its
            predecessor. Default [365]. *)
    max_bars : int;
        (** Longest suffix droppable as stray. Default [5] — a longer run after
            a gap is a resumed listing, not a stray print. *)
  }

  type t = { stub : stub; stray : stray }

  val default : t
  (** [ratio = 0.05], [max_bars = 60], [max_price = 1.0],
      [misscale_close = 1000.0], [gap_days = 365], [stray max_bars = 5], stub
      truncation and stray drop on, [misscale_cut = false] with
      [misscale_min_kept_bars = 250]. These are the values measured to truncate
      exactly the 13-symbol stub class of the 2000 vintage and leave the other
      33 flagged symbols alone; the prefix cut is opt-in (#2732) so the default
      config still reproduces every warehouse built before it existed. *)
end

module Exceptions : sig
  type t
  (** Symbols whose tail is never edited, however it classifies. Built from the
      [keep_tail] section of the committed warehouse exceptions file
      ([trading/test_data/warehouse_exceptions.sexp], shape
      [((keep_tail (SYM ...)) (splice (...)))]) so a reviewer can veto a
      truncation without a code change.

      This module does {e not} parse that file. {!Build_runner} reads it once,
      into a single strict record whose two sections are both optional, and
      hands each module its own section as a view — see
      {!Build_runner.load_tail_exceptions}. Strict means a mistyped section name
      is a parse error rather than a silently empty veto list. *)

  val empty : t
  (** No exceptions — every symbol is subject to the rule. *)

  val of_symbols : string list -> t
  (** [of_symbols syms] never edits any of [syms]'s tails. *)

  val mem : t -> symbol:string -> bool
  (** [mem t ~symbol] is [true] when [symbol]'s tail must be left alone. *)
end

(** How a symbol's terminal run was classified. {!Class.Stub_tail} is eligible
    for truncation and {!Class.Prefix_misscale} for a prefix cut (each behind
    its own flag); the rest are reported so a human reads them once per vintage.
*)
module Class : sig
  type t =
    | Stub_tail  (** Passed every gate — the defect this module removes. *)
    | Prefix_misscale
        (** [last_real_close >= misscale_close]: the early bars are mis-scaled
            and the run is the real series (AGR, MEL). Cut away by
            {!Action.Cut_prefix} when [misscale_cut] is armed. *)
    | Long_low_tail
        (** [n_stub > max_bars]: ticker reuse or a genuine multi-month collapse.
        *)
    | High_price_tail
        (** [first_stub_close >= max_price]: the run's own prints are real
            money. *)
    | Stray_bar
        (** A short suffix dated [>= gap_days] after its predecessor. *)
  [@@deriving sexp_of, compare, equal]

  val to_string : t -> string
  (** Lower-snake spelling used in [terminal_runs.csv] ([stub_tail], ...). *)
end

(** What the build actually did with the run. *)
module Action : sig
  type t =
    | Truncated  (** Stub bars dropped from the stored series. *)
    | Stray_dropped  (** Stray suffix dropped from the stored series. *)
    | Cut_prefix
        (** Mis-scaled prefix dropped: the stored series starts at
            {!field-first_stub_date} (#2732). *)
    | Cut_refused_short_tail
        (** The prefix cut was eligible but would have left fewer than
            [misscale_min_kept_bars]; the series is stored whole. *)
    | Kept  (** Reported only — class ineligible, or the edit is disabled. *)
    | Kept_by_exception  (** Eligible, but the symbol is in {!Exceptions}. *)
  [@@deriving sexp_of, compare, equal]

  val to_string : t -> string
  (** Lower-snake spelling used in [terminal_runs.csv] ([truncated],
      [cut_prefix], [cut_refused_short_tail], ...). *)
end

type finding = {
  symbol : string;
  klass : Class.t;
  cut_after : Core.Date.t;
      (** Date of the last bar {e before} the run — the series' new end when the
          run is dropped, and the last bar removed when the {e prefix} is cut
          instead. *)
  last_real_close : float;  (** Close on [cut_after], the run's reference. *)
  n_stub : int;
      (** Bars in the run — the bars dropped by a truncation, and the bars
          {e kept} by a prefix cut (the number the [misscale_min_kept_bars]
          guard is tested against). Reported either way, so the depth of a cut
          that did not happen is readable from the sidecar. *)
  first_stub_date : Core.Date.t;
      (** First bar of the run, and the stored series' new start after a
          {!Action.Cut_prefix}. *)
  first_stub_close : float;
  last_date : Core.Date.t;  (** Last bar of the run (the series' old end). *)
  last_close : float;
  action : Action.t;
}
[@@deriving sexp_of, compare, equal]
(** One row of the review report: a terminal run below [ratio] {e regardless} of
    the length / price gates, or a stray suffix. *)

val apply :
  Config.t ->
  exceptions:Exceptions.t ->
  symbol:string ->
  Types.Daily_price.t list ->
  Types.Daily_price.t list * finding list
(** [apply config ~exceptions ~symbol bars] returns the bars the warehouse
    should store, plus every finding for the review report.

    The terminal-run pass runs first — truncating a {!Class.Stub_tail} or, when
    [misscale_cut] is armed, cutting a {!Class.Prefix_misscale}'s prefix — then
    the stray check runs on whatever bars that pass returned, so at most two
    findings come back (see {b Ordering and composition} above). Bars must be in
    chronological order; fewer than two bars are returned unchanged with no
    findings. A symbol in [exceptions] is returned unchanged with its findings'
    action set to [Kept_by_exception], which outranks a refusal. *)

val classify :
  Config.t -> symbol:string -> Types.Daily_price.t list -> finding list
(** [classify config ~symbol bars] is {!apply} with no exceptions, discarding
    the edited bars — the report-only view. *)

val csv_header : string
(** Header line of [terminal_runs.csv], without a trailing newline. *)

val to_csv : finding list -> string
(** Renders {!csv_header} plus one line per finding, newline-terminated. Column
    order matches the header:
    [symbol,class,cut_after,last_real_close,n_stub,first_stub_date,first_stub_close,last_date,last_close,action].
*)

val summary : finding list -> string
(** One-line human summary the builder logs at the end of a build, e.g.
    ["series_tail: 46 findings (13 truncated, 14 stray_dropped, 19 kept, 0
     kept_by_exception, 0 cut_prefix, 0 cut_refused_short_tail)"]. The two #2732
    counts are appended rather than interleaved so an un-armed build's line
    still reads exactly as it did before. *)

val prefix_cut_from : finding list -> Core.Date.t option
(** [prefix_cut_from findings] is the date the stored series now starts at when
    one of [findings] actually cut a mis-scaled prefix ({!Action.Cut_prefix}),
    and [None] otherwise — a refused cut, a disabled edit and an excepted symbol
    all yield [None], exactly as they leave the bars alone.

    Exposed for the same reason {!Series_splice.cut_plan} is: {!apply} edits the
    build-window bars, but {!Build_runner} also carries a {e deep-history}
    prefix that feeds only the weekly side-table, and that prefix must be cut to
    the same date. Feed the result to {!Series_splice.keep_from} so the two cuts
    cannot drift apart. *)
