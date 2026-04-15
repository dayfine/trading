(** Wraps a [STRATEGY] module to intercept transitions for stop logging. *)

open Trading_strategy

let wrap ~stop_log (module S : Strategy_interface.STRATEGY) =
  let module Wrapped = struct
    let name = S.name

    let on_market_close ~get_price ~get_indicator ~portfolio =
      let result = S.on_market_close ~get_price ~get_indicator ~portfolio in
      (match result with
      | Ok { transitions } -> Stop_log.record_transitions stop_log transitions
      | Error _ -> ());
      result
  end in
  (module Wrapped : Strategy_interface.STRATEGY)
