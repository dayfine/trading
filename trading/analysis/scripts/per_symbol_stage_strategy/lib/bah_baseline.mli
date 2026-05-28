(** Buy-and-hold baseline helpers extracted from the diagnostic backtest. *)

val metrics :
  weekly_bars:Types.Daily_price.t list -> initial_cash:float -> float * float
(** [metrics ~weekly_bars ~initial_cash] returns the BAH (CAGR, MaxDD) pair for
    buying at the first bar's close and holding through the last bar. No bid-ask
    cost. *)

val year_end_equity :
  dates:Core.Date.t array -> equity:float array -> (int * float) list
(** [year_end_equity ~dates ~equity] returns per-year (year, equity) pairs
    picking the last equity value on or before Dec 31 of each year. *)
