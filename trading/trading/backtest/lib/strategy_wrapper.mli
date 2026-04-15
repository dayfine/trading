(** Wraps a [STRATEGY] module to intercept transitions for stop logging.

    The wrapper delegates all calls to the underlying strategy. After each
    [on_market_close] call, it feeds the resulting transitions to a
    {!Stop_log.t} collector. The transitions are passed through unmodified —
    this wrapper is purely observational. *)

open Trading_strategy

val wrap :
  stop_log:Stop_log.t ->
  (module Strategy_interface.STRATEGY) ->
  (module Strategy_interface.STRATEGY)
(** [wrap ~stop_log strategy] returns a new strategy module that behaves
    identically to [strategy] but records every transition batch in [stop_log].
*)
