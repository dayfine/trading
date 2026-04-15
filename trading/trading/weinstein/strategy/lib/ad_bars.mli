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
    Unicorn data is preferred (it is exchange-official). Synthetic fills the
    tail from the first date after Unicorn's last date. The result is deduped
    by date and sorted chronologically.

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
      [data_dir/breadth/synthetic_decln.csv], joins on date, and returns
      records sorted by date ascending. Missing files return [[]].
      Malformed rows are silently skipped. *)
end

val load : data_dir:string -> Macro.ad_bar list
(** [load ~data_dir] returns the best available breadth data from the caller's
    data directory. Composes Unicorn (1965-03-01 to 2020-02-10) with Synthetic
    (tail after Unicorn's last date). Unicorn is preferred for any date it
    covers. If only one source is present, it is returned alone. Missing files
    degrade gracefully to [[]]. *)
