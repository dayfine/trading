(** NYSE advance/decline breadth data loader.

    The domain type is {!Macro.ad_bar}: [(date, advancing, declining)] triples
    used by the macro analyzer's breadth indicators. This module is format-
    agnostic at the top level — it returns [Macro.ad_bar list] regardless of
    which upstream source provided the data.

    {1 Sources}

    Source-specific parsers live in nested submodules. The {!load} façade
    composes multiple sources to maximize coverage:

    - {!Unicorn} — historical NYSE breadth from unicorn.us.com. Two CSV files
      ([YYYYMMDD,count] format), coverage 1965-03-01 to 2020-02-10.
    - {!Synthetic} — breadth computed from the Russell 3000 universe. Two CSV
      files ([YYYYMMDD,count] format), coverage ~1973 to present.

    {1 Composition rules}

    {!load} merges Unicorn and Synthetic series: for dates covered by Unicorn,
    Unicorn data is preferred (it is exchange-official). Synthetic fills:
    - the tail, from the first date after Unicorn's last date; and
    - every interior Unicorn hole wider than the gap threshold
      ({!default_max_interior_gap_days} calendar days between consecutive
      Unicorn bars), with the Synthetic bars strictly inside the hole.

    Synthetic bars before Unicorn's first date are not used. The result is
    deduped by date and sorted chronologically. A hole that Synthetic does not
    cover either stays a hole; {!gaps} / {!gaps_in_window} report it.

    {1 Graceful degradation}

    Missing files return [[]] so that callers can treat breadth data as an
    optional macro input (see {!Macro.analyze}'s [~ad_bars] argument). If only
    one source is present, it is returned alone. *)

module Unicorn : sig
  (** Parser for the unicorn.us.com historical NYSE breadth archive.

      Reads two separate CSVs — [nyse_advn.csv] and [nyse_decln.csv] — from
      [data_dir/breadth/], both two-column [YYYYMMDD,count]. Joins on date and
      drops placeholder rows (the upstream maintainer padded the tail of the
      file with [count=0] rows when it stopped updating in Feb 2020).

      Coverage: 1965-03-01 → 2020-02-10. No live updates. *)

  val load : data_dir:string -> Macro.ad_bar list
  (** [load ~data_dir] reads [data_dir/breadth/nyse_advn.csv] and
      [data_dir/breadth/nyse_decln.csv], joins on date, filters placeholders,
      and returns records sorted by date ascending. Missing files return [[]].
      Malformed rows are silently skipped. *)
end

module Synthetic : sig
  (** Parser for synthetic breadth CSVs computed from the stock universe.

      Reads [synthetic_advn.csv] and [synthetic_decln.csv] from
      [data_dir/breadth/], same two-column [YYYYMMDD,count] format as Unicorn.
      Coverage depends on when [compute_synthetic_adl.exe] was last run. *)

  val load : data_dir:string -> Macro.ad_bar list
  (** [load ~data_dir] reads [data_dir/breadth/synthetic_advn.csv] and
      [data_dir/breadth/synthetic_decln.csv], joins on date, and returns records
      sorted by date ascending. Missing files return [[]]. Malformed rows are
      silently skipped. *)
end

(** {1 Gap detection}

    A breadth series with a hole reads to the macro analyzer as a frozen input:
    the cumulative A-D line and the A-D momentum MA stop moving, and the
    indicators keep voting off stale data. Issue #3238: the committed fixture
    once held one 1965 row and then 2017+, so every 26y run had no breadth for
    2000-2016. These helpers make such holes visible. *)

val default_max_interior_gap_days : int
(** Widest Unicorn hole, in calendar days between consecutive bars, that {!load}
    leaves unfilled (7). The longest legitimate NYSE closure in the archive
    (2001-09-10 to 2001-09-17) is exactly 7 days. *)

val gaps :
  Macro.ad_bar list -> max_gap_days:int -> (Core.Date.t * Core.Date.t) list
(** [gaps bars ~max_gap_days] returns every pair [(a, b)] of consecutive bar
    dates in the date-sorted [bars] with [b - a > max_gap_days] calendar days,
    in chronological order. [[]] for fewer than two bars. *)

val gaps_in_window :
  Macro.ad_bar list ->
  start_date:Core.Date.t ->
  end_date:Core.Date.t ->
  max_gap_days:int ->
  (Core.Date.t * Core.Date.t) list
(** [gaps_in_window bars ~start_date ~end_date ~max_gap_days] is {!gaps} over
    the bars dated in [[start_date, end_date]], with [start_date] and [end_date]
    themselves acting as boundary sentinels: a window whose first bar comes more
    than [max_gap_days] after [start_date] reports [(start_date, first_bar)],
    one whose last bar ends early reports [(last_bar, end_date)], and an empty
    series reports [[(start_date, end_date)]] when the window is wider than
    [max_gap_days]. Used at backtest setup to warn when breadth is missing
    inside the run. *)

(** {1 Composed loader} *)

val load_with :
  max_interior_gap_days:int -> data_dir:string -> Macro.ad_bar list
(** [load_with ~max_interior_gap_days ~data_dir] is {!load} with an explicit
    interior-gap threshold: Synthetic fills any Unicorn hole wider than
    [max_interior_gap_days] calendar days. *)

val load : data_dir:string -> Macro.ad_bar list
(** [load ~data_dir] returns the best available breadth data from the caller's
    data directory: {!load_with} at {!default_max_interior_gap_days}. Unicorn is
    preferred for any date it covers; Synthetic fills the tail after Unicorn's
    last date and every interior Unicorn hole wider than the threshold. If only
    one source is present, it is returned alone. Missing files degrade
    gracefully to [[]]. *)
