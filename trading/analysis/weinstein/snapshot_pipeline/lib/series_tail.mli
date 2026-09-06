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

    The obvious rule — "walk back while [close < ratio * previous close]" — is
    the one the runtime guard [Snapshot_runtime.Stub_tail] implements, and it is
    {b wrong at build time}. Measured over all 2,908 symbols of the 2000-vintage
    warehouse [snap_top3000_dedup_v5thin_adj] at [ratio = 0.05], the terminal
    run splits into four populations a single ratio cannot separate:

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
    stub class. So the rule is
    [ratio AND n_stub <= max_bars AND first_stub_close < max_price], and
    everything else is reported untouched for a human to read once per vintage.

    {2 Stray late bars}

    Separately, 14 symbols carry a trailing bar dated years after the previous
    one (ANCR: 2000-08-01, then a single bar on 2016-01-27). Up to
    [Config.stray.max_bars] such bars are dropped when the gap to the preceding
    bar is at least [Config.stray.gap_days].

    {2 Ordering and composition}

    {!apply} truncates the stub tail first, then looks for a stray suffix in
    what remains. A symbol can therefore produce {b two} findings (ANCR's
    terminal run is kept as high-priced, then its 2016 bar is dropped as stray)
    — which is why findings come back as a list rather than an option. NCF's
    single 2016 bar is both shapes at once; it is truncated as a stub and the
    series ends at 2004-09-30 either way.

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
            and the "run" is the real series: a {b prefix mis-scale}, kept.
            Default [1000.0]. *)
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
      [misscale_close = 1000.0], [gap_days = 365], [stray max_bars = 5], both
      edits on. These are the values measured to truncate exactly the 13-symbol
      stub class of the 2000 vintage and leave the other 33 flagged symbols
      alone. *)
end

module Exceptions : sig
  type t
  (** Symbols whose tail is never edited, however it classifies. Read from a
      committed sexp file (default
      [trading/test_data/warehouse_exceptions.sexp], shape
      [((keep_tail (SYM ...)))]) so a reviewer can veto a truncation without a
      code change. *)

  type file = { keep_tail : string list } [@@deriving sexp]
  (** On-disk shape. The builder parses the file and calls {!of_file}. *)

  val empty : t
  (** No exceptions — every symbol is subject to the rule. *)

  val of_file : file -> t
  (** [of_file f] is [of_symbols f.keep_tail]. *)

  val of_symbols : string list -> t
  (** [of_symbols syms] never edits any of [syms]'s tails. *)

  val mem : t -> symbol:string -> bool
  (** [mem t ~symbol] is [true] when [symbol]'s tail must be left alone. *)
end

(** How a symbol's terminal run was classified. Only {!Class.Stub_tail} is
    eligible for truncation; the rest are reported so a human reads them once
    per vintage. *)
module Class : sig
  type t =
    | Stub_tail  (** Passed every gate — the defect this module removes. *)
    | Prefix_misscale
        (** [last_real_close >= misscale_close]: the early bars are mis-scaled
            and the run is the real series (AGR, MEL). *)
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
    | Kept  (** Reported only — class ineligible, or the edit is disabled. *)
    | Kept_by_exception  (** Eligible, but the symbol is in {!Exceptions}. *)
  [@@deriving sexp_of, compare, equal]

  val to_string : t -> string
  (** Lower-snake spelling used in [terminal_runs.csv] ([truncated], ...). *)
end

type finding = {
  symbol : string;
  klass : Class.t;
  cut_after : Core.Date.t;
      (** Date of the last bar {e before} the run — the series' new end when the
          run is dropped. *)
  last_real_close : float;  (** Close on [cut_after], the run's reference. *)
  n_stub : int;  (** Bars in the run. *)
  first_stub_date : Core.Date.t;
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

    Stub truncation runs first, then the stray check runs on what remains, so at
    most two findings come back (see {b Ordering and composition} above). Bars
    must be in chronological order; fewer than two bars are returned unchanged
    with no findings. A symbol in [exceptions] is returned unchanged with its
    findings' action set to [Kept_by_exception]. *)

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
     kept_by_exception)"]. *)
