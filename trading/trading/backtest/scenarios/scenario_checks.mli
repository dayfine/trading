(** Actual-metrics record, range checks and result-row formatting for
    [scenario_runner]. *)

type actual = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  open_positions_value : float; [@sexp.default Float.nan]
  unrealized_pnl : float;
  sortino_ratio_annualized : float; [@sexp.default Float.nan]
  calmar_ratio : float; [@sexp.default Float.nan]
  ulcer_index : float; [@sexp.default Float.nan]
  force_liquidations_count : int; [@sexp.default 0]
  crashed : bool; [@sexp.default false]
  crash_message : string; [@sexp.default ""]
}
[@@deriving sexp]
(** Metrics extracted from one run, serialized to [actual.sexp] so the parent
    process can read back each child's result. Optional fields default on read
    so older [actual.sexp] files still parse. *)

type check = { name : string; value : float; range : Scenario.range; ok : bool }

val actual_of_result : Backtest.Runner.result -> actual
(** Extract the [actual] metrics from a finished backtest. *)

val crashed_actual : msg:string -> actual
(** Sentinel [actual] for a crashed run: out-of-range numerics so range checks
    fail explicitly, with [crashed = true] and [crash_message = msg]. *)

val print_header : unit -> unit
(** Print the results-table header. *)

val process_result : output_root:string -> Scenario.t -> bool
(** Parent side: read back the child's [actual.sexp], run the checks and print
    the row; prints a crashed row and returns [false] when unreadable. *)
