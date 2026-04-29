(** Per-Friday macro-trend persistence.

    Emits [macro_trend.sexp] alongside the other run artefacts so external
    counterfactual tooling (notably {!Backtest_optimal}'s
    [optimal_strategy.exe]) can replay each Friday's [macro_trend] without
    re-running the strategy's macro pipeline.

    The per-Friday values are sourced from {!Trade_audit.cascade_summary}'s
    [date] + [macro_trend] fields — already populated by the strategy's
    [Macro.analyze_with_callbacks] call inside [_run_screen]. This module only
    projects + writes; no recompute. *)

open Core

type per_friday = { date : Date.t; trend : Weinstein_types.market_trend }
[@@deriving sexp]
(** One Friday's macro reading. [date] is the Friday on which [_run_screen]
    fired; [trend] is the [Macro.result.trend] returned by
    [Macro.analyze_with_callbacks] that Friday. *)

type t = per_friday list [@@deriving sexp]
(** The per-Friday ledger written to disk. Sorted ascending by [date]; one entry
    per Friday on which the screener actually ran. Empty when no Friday fell
    inside the run window. *)

val of_cascade_summaries : Trade_audit.cascade_summary list -> t
(** Project a list of cascade summaries down to per-Friday macro readings. Sorts
    ascending by [date]. Pure projection — no compute. *)

val write : output_dir:string -> Trade_audit.cascade_summary list -> unit
(** Write [<output_dir>/macro_trend.sexp]. The directory must already exist.

    Always writes the file (including when the input list is empty, which yields
    [()] sexp) — the artefact's presence is the contract for downstream
    consumers, distinct from [trade_audit.sexp]'s "absent on empty" rule. *)
