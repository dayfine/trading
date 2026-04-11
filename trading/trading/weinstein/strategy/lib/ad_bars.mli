(** NYSE advance/decline breadth data loader.

    The domain type is {!Macro.ad_bar}: [(date, advancing, declining)] triples
    used by the macro analyzer's breadth indicators. This module is format-
    agnostic at the top level — it returns [Macro.ad_bar list] regardless of
    which upstream source provided the data.

    {1 Sources}

    Source-specific parsers live in nested submodules. The {!load} façade
    currently delegates to {!Unicorn} only — when additional sources (Phase B
    for live coverage 2020-02-11 onwards) are added, the façade will merge them.

    - {!Unicorn} — historical NYSE breadth from unicorn.us.com. Two CSV files
      ([YYYYMMDD,count] format), coverage 1965-03-01 to 2020-02-10.

    {1 Graceful degradation}

    Missing files return [[]] so that callers can treat breadth data as an
    optional macro input (see {!Macro.analyze}'s [~ad_bars] argument). *)

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

val load : data_dir:string -> Macro.ad_bar list
(** [load ~data_dir] returns the best available breadth data from the caller's
    data directory. Currently delegates to {!Unicorn.load} — coverage is
    therefore limited to 1965-03-01 → 2020-02-10. Future phases will merge a
    live-coverage source for 2020-02-11 → present. *)
