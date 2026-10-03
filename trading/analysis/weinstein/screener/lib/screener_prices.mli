(** Price helpers for screened candidates: entry, stop, swing target and the
    base-low proxy. Re-exported by {!Screener_scoring} (and so by {!Screener});
    callers keep using those names. *)

val suggested_entry : entry_buffer_pct:float -> float -> float
(** [suggested_entry ~entry_buffer_pct breakout_price] returns the suggested
    entry price: breakout price plus a small configurable buffer, rounded to the
    nearest cent. *)

val suggested_stop : initial_stop_pct:float -> float -> float
(** [suggested_stop ~initial_stop_pct entry] returns the long initial stop:
    [entry * (1 - initial_stop_pct)]. *)

val swing_target : breakout:float -> base_low_opt:float option -> float option
(** [swing_target ~breakout ~base_low_opt] estimates the Weinstein swing target:
    [breakout + (breakout - base_low)]. Returns [None] when [base_low_opt] is
    absent or [breakout <= base_low]. *)

val base_low : base_low_proxy_pct:float -> Stock_analysis.t -> float option
(** [base_low ~base_low_proxy_pct a] returns a proxy for the prior base low:
    [ma_value * (1 - base_low_proxy_pct)]. Returns [None] when [ma_value <= 0].
*)
