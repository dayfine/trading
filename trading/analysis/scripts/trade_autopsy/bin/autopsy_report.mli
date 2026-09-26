(** Markdown rendering for the trade-autopsy report.

    Pure string formatting only — no I/O. Turns the per-symbol breakdowns, the
    aggregate mode-summary, and the flat list of classified trade autopsies that
    {!autopsy_runner} assembles into the Markdown report it prints to stdout
    (caller redirects to [dev/notes/trade-autopsy-<date>.md]). *)

open Core
module Autopsy = Trade_autopsy_lib.Trade_autopsy

val render :
  start_date:Date.t ->
  end_date:Date.t ->
  breakdowns:Autopsy.per_symbol_breakdown list ->
  aggregate_summary:Autopsy.mode_summary list ->
  autopsies:Autopsy.trade_autopsy list ->
  string
(** [render ~start_date ~end_date ~breakdowns ~aggregate_summary ~autopsies]
    renders the full report: a per-symbol failure-mode breakdown table, the
    aggregate missed-gain ranking table, and an exit-reason histogram sanity
    check. *)
