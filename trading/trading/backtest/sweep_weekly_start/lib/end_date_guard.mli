(** End-date guard for the weekly-start sweep (issue #2915).

    The sweep's [end_date] floats with the run date, while the committed bars
    stop at a fixed floor. Measuring every cell to a date weeks past the last
    bar makes the simulator annualize CAGR over dead calendar days: the prices
    are unchanged but every cell's CAGR drifts down a little more each week, and
    the Mondays past the floor are dropped with a warning that used to reach
    only the workflow log.

    This module owns the guard — compare the requested end date against the
    symbol's last bar and clamp when the gap exceeds a tolerance — and the
    report fragments that make its outcome and any dropped cells visible in the
    generated markdown. {!Sweep_weekly_start_lib} re-exports the guard functions
    and calls the renderers. *)

open Core
open Sweep_types

val default_max_end_date_gap_days : int
(** Default guard tolerance, in calendar days (7): the most [end_date] may run
    past the symbol's last bar before the sweep clamps it. One calendar week
    absorbs a weekend plus a holiday-shortened week of vendor lag without ever
    clamping a run whose bars are merely a few sessions behind. *)

val resolve_coverage :
  requested_end_date:Date.t ->
  last_bar_date:Date.t ->
  tolerance_days:int ->
  coverage
(** The guard. [clamped] is [true] iff [requested_end_date] is strictly more
    than [tolerance_days] calendar days after [last_bar_date]. Pure. *)

val effective_end_date : coverage -> Date.t
(** The end date every cell is measured to: [last_bar_date] when [clamped], else
    [requested_end_date]. *)

val load_coverage :
  data_dir:Fpath.t ->
  symbol:string ->
  requested_end_date:Date.t ->
  tolerance_days:int ->
  coverage
(** Read [symbol]'s bars from the CSV store under [data_dir], take the latest
    bar date, and apply {!resolve_coverage}.

    @raise Failure
      when the store cannot be read or holds no bars for [symbol] — a sweep with
      no bars at all has nothing to measure. *)

val warn_if_clamped : string -> coverage -> unit
(** [warn_if_clamped symbol coverage] prints a one-line stderr warning naming
    both dates when [coverage.clamped], so the workflow log carries the clamp
    too. No-op otherwise. *)

val last_bar_line : sweep_result -> string
(** ["Last bar: YYYY-MM-DD\n"] for the report header when [coverage] is set;
    [""] otherwise. *)

val clamp_warning : sweep_result -> string
(** The loud [WARNING -- END DATE CLAMPED] block for the report header: names
    the requested end date, the last bar, the gap in days and the tolerance, so
    nobody reads the CAGRs as measured to the run date. [""] when the guard did
    not clamp (or never ran). *)

val dropped_block : dropped_cell list -> string
(** The report's [## Dropped cells] section: the count, then one
    ["- <start_date>: <reason>"] line per dropped cell. [""] when the list is
    empty. *)
