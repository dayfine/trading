(** Pure helpers backing [fetch_iwv_history.exe].

    Companion plan: [dev/plans/iwv-scraper-2026-05-16.md] §PR-C. The backfill
    CLI must (a) enumerate the asOfDates to request given a [from..until] window
    and a cadence policy, (b) skip dates already materialised in the on-disk
    cache (resume-safe), and (c) record a one-byte sentinel marker when iShares
    returns the no-data template so subsequent runs do not re-fetch known-empty
    dates.

    All file-system reads and writes live in this module; the CLI
    ([fetch_iwv_history.ml]) wires HTTP I/O. Tests exercise this lib directly
    against pinned tmpdir layouts — no network. *)

open Core

(** Cadence policy for asOfDate enumeration. The [Auto] policy mirrors the
    empirically-verified iShares cadence from
    [dev/notes/phase1.4-iwv-url-probe-2026-05-16.md]:

    - 2006-09-29 .. 2008-12-31: quarter-ends only.
    - 2009-01-01 .. 2012-04-29: month-ends only.
    - 2012-04-30 onward: every weekday.

    The non-auto variants override the policy uniformly across the full window —
    primarily useful for backfills targeting a single era. *)
type cadence = Auto | Daily | Monthly | Quarterly [@@deriving show, eq]

val cadence_of_string : string -> cadence Status.status_or
(** [cadence_of_string s] parses a CLI flag value. Accepts ["auto"], ["daily"],
    ["monthly"], ["quarterly"] case-insensitively. *)

val enumerate_dates : from:Date.t -> until:Date.t -> cadence -> Date.t list
(** [enumerate_dates ~from ~until policy] returns the inclusive list of
    asOfDates to query, in ascending order. Behaviour by policy:

    - [Auto]: quarter-ends through 2008-12-31, month-ends through 2012-04-29,
      every weekday from 2012-04-30 onward. Era boundaries are inclusive on the
      left.
    - [Daily]: every weekday in [from..until]. Saturdays / Sundays are skipped
      (iShares auto-sentinels weekends anyway, so we save the round-trip).
    - [Monthly]: the last day of each month that falls in [from..until].
    - [Quarterly]: 03-31 / 06-30 / 09-30 / 12-31 dates inside the window.

    Returns an empty list if [until < from]. *)

(** A planned action for a single asOfDate. The [plan] function below classifies
    each enumerated date into one of these. *)
type action =
  | Skip_cached  (** A non-sentinel CSV body is already on disk. *)
  | Skip_sentinel  (** A [.sentinel] marker is on disk from a prior run. *)
  | Fetch  (** Date has neither a cached body nor a sentinel marker. *)
[@@deriving show, eq]

type planned_step = { as_of : Date.t; action : action } [@@deriving show, eq]

val csv_path : cache_dir:string -> as_of:Date.t -> string
(** [csv_path ~cache_dir ~as_of] returns the on-disk filename for the CSV body:
    [<cache_dir>/YYYY-MM-DD.csv]. *)

val sentinel_path : cache_dir:string -> as_of:Date.t -> string
(** [sentinel_path ~cache_dir ~as_of] returns the on-disk filename for the
    sentinel marker: [<cache_dir>/YYYY-MM-DD.sentinel]. The marker is a one-byte
    file — its presence alone signals "this date returned the iShares no-data
    template; do not refetch". *)

val plan : cache_dir:string -> resume:bool -> Date.t list -> planned_step list
(** [plan ~cache_dir ~resume dates] classifies each date.

    When [resume] is [true]: a date is [Skip_cached] if its CSV body exists and
    is non-empty, [Skip_sentinel] if its sentinel marker exists, and [Fetch]
    otherwise.

    When [resume] is [false]: every date is [Fetch] (callers must still clean
    the cache directory themselves if they want a true refetch; [plan] does not
    delete). *)

val format_plan_summary : planned_step list -> string
(** [format_plan_summary steps] renders a multi-line human-readable summary
    suitable for [--dry-run] output:

    {v
    Plan: 5 dates, 2 to fetch, 2 cached, 1 sentinel.
      2012-04-30 fetch
      2012-05-01 cached
      2012-05-02 sentinel
      ...
    v} *)

val ensure_cache_dir : string -> unit Status.status_or
(** [ensure_cache_dir path] creates the directory (recursively) if missing.
    Returns [Ok ()] on success or if it already exists. *)

val write_csv_body :
  cache_dir:string -> as_of:Date.t -> body:string -> unit Status.status_or
(** [write_csv_body] atomically writes [body] to [csv_path]. Writes to a sibling
    [.tmp] file then renames so a crashed mid-write does not leave a half-cached
    CSV on disk that the next [plan] would mistake for a cache hit. *)

val write_sentinel_marker :
  cache_dir:string -> as_of:Date.t -> unit Status.status_or
(** [write_sentinel_marker] creates a one-byte marker file at [sentinel_path].
*)
