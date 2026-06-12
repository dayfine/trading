(** Re-stamp a backtest fill's timestamp with the simulated date. See
    [fill_date_stamp.mli]. *)

open Core

let restamp ~date (trade : Trading_base.Types.trade) =
  {
    trade with
    timestamp =
      Time_ns_unix.of_date_ofday ~zone:Time_float.Zone.utc date
        Time_ns.Ofday.start_of_day;
  }
