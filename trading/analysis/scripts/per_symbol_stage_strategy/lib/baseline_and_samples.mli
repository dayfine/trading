(** Helpers for the buy-and-hold baseline and the year-end equity samples.

    Extracted from {!Single_symbol_backtest} so the main orchestrator stays
    within the file-length limit. Both helpers operate on the same in-window
    weekly-bar series the strategy walked. *)

open Core

val bah_metrics :
  weekly_bars:Types.Daily_price.t list -> initial_cash:float -> float * float
(** [bah_metrics ~weekly_bars ~initial_cash] returns [(cagr, max_drawdown)] for
    a buy-and-hold strategy over [weekly_bars]. Entry is the first bar's close,
    equity at each subsequent bar is [shares * close]. Returns [(0.0, 0.0)] when
    there are fewer than 2 bars. No bid-ask cost is applied to BAH — the
    diagnostic's cost-comparison is "stage strategy net of round-trip costs" vs
    "passive hold gross". *)

val year_end_equity :
  dates:Date.t array -> equity:float array -> (int * float) list
(** [year_end_equity ~dates ~equity] returns, for each year present in [dates],
    the LAST equity sample for that year as a [(year, equity)] pair, sorted
    ascending by year. Used for Section 4 of the diagnostic report. Empty input
    returns the empty list. *)
