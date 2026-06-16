(** Pure helpers for the README top-line report: the common testing period
    (intersection of per-instrument bar coverage) and the return math the four
    headline numbers are built from. No I/O — every function is a pure
    transformation of dates / floats, so the report's arithmetic is
    unit-testable without touching the CSV store or running a backtest. *)

open Core

type coverage = {
  symbol : string;
  first_bar : Date.t;  (** First trading day with a bar for [symbol]. *)
  last_bar : Date.t;  (** Last trading day with a bar for [symbol]. *)
}
[@@deriving sexp, eq]
(** One instrument's on-disk bar coverage, as read from its CSV. *)

val period_intersection : coverage list -> (Date.t * Date.t) option
(** [period_intersection coverages] is the common window every instrument can be
    priced over: [(max of the first_bar dates, min of the last_bar dates)] — the
    latest start and earliest end across the list.

    - Returns [None] for the empty list, or when the intersection is empty (the
      latest [first_bar] is strictly after the earliest [last_bar], i.e. no
      single day is covered by all instruments).
    - The bound dates are members of the input (a real instrument's first/last
      bar), not synthesised — so the pinned period is always anchored to actual
      coverage. *)

val total_return_pct : initial:float -> final:float -> float
(** [total_return_pct ~initial ~final] is [(final -. initial) /. initial *. 100]
    — the percent change of a value from [initial] to [final].

    Returns [Float.nan] when [initial <= 0.0] (cannot price a return off a
    non-positive base). *)

val bah_total_return_pct :
  start_date:Date.t ->
  end_date:Date.t ->
  close_series:(Date.t * float) list ->
  float
(** [bah_total_return_pct ~start_date ~end_date ~close_series] is the
    buy-and-hold total return percent over [start_date .. end_date], computed
    from a chronological [(date, close)] series (use {e adjusted} closes so
    dividends/splits are reflected).

    - Entry close = the first pair whose date is [>= start_date]; exit close =
      the last pair whose date is [<= end_date]. Result is
      [total_return_pct ~initial:entry ~final:exit].
    - Returns [Float.nan] when the window cannot be priced: fewer than two
      distinct bars span it (empty series, all dates outside the window, or a
      single bar where entry and exit coincide — a zero-span, unpriceable
      window), or the entry close is [<= 0.0].
    - [close_series] need not be sorted — entry/exit are selected by date
      comparison, not list position.

    This is the total-return companion to
    {!Rolling_start.Rolling_start_runner.bah_cagr_pct} (same entry/exit
    selection), so the two are consistent. *)

val inclusive_days : start_date:Date.t -> end_date:Date.t -> int
(** [inclusive_days ~start_date ~end_date] is the inclusive calendar-day span
    [end_date - start_date + 1] (so a single day is [1]). Matches the day count
    {!Walk_forward.Walk_forward_runner.cagr_pct} annualises over. Returns [0]
    when [end_date < start_date]. *)
