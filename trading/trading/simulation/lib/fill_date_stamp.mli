(** Re-stamp a backtest fill's timestamp with the simulated date.

    The trading engine stamps every fill with wall-clock [Time_ns_unix.now ()] —
    correct for live trading, but in a backtest it makes the portfolio's per-lot
    [acquisition_date] the {b run} date rather than the {b simulated} date. That
    in turn corrupts [open_positions.csv]'s [entry_date] column (derived from
    the held lots' [acquisition_date]) — the G1 bug, where every open-position
    row showed the run date. The simulator applies {!restamp} at the single
    point backtest fills enter the portfolio, so the lot dates are the simulated
    dates without touching the shared engine / portfolio modules. *)

val restamp :
  date:Core.Date.t -> Trading_base.Types.trade -> Trading_base.Types.trade
(** [restamp ~date trade] returns [trade] with its [timestamp] set to [date] at
    UTC start-of-day. All other fields are unchanged. Round-trip extraction is
    unaffected: it keys trades off the per-step [step.date], not
    [trade.timestamp], so only the portfolio lot [acquisition_date] (and the
    [open_positions.csv] [entry_date] it feeds) changes. *)
