(** Warmup-trading gate — see [warmup_trade_gate.mli]. *)

open Core
open Trading_strategy

(* A transition creates a NEW position iff its kind is [CreateEntering]. That is
   the only entry the strategy emits (both long and short — it carries [side]).
   Everything else (exits, partial exits, risk-param updates, fills) manages an
   already-existing position and must never be suppressed. *)
let _is_warmup_entry ~start_date (transition : Position.transition) =
  match transition.kind with
  | Position.CreateEntering _ -> Date.( < ) transition.date start_date
  | _ -> false

let filter_transitions ~suppress ~start_date transitions =
  if not suppress then transitions
  else
    List.filter transitions ~f:(fun t -> not (_is_warmup_entry ~start_date t))

let wrap_strategy ~suppress ~start_date (module S : Strategy_interface.STRATEGY)
    =
  if not suppress then (module S : Strategy_interface.STRATEGY)
  else
    let module Wrapped = struct
      let name = S.name

      let on_market_close ~get_price ~get_indicator ~portfolio =
        match S.on_market_close ~get_price ~get_indicator ~portfolio with
        | Ok { transitions } ->
            Ok
              {
                Strategy_interface.transitions =
                  filter_transitions ~suppress ~start_date transitions;
              }
        | Error _ as e -> e
    end in
    (module Wrapped : Strategy_interface.STRATEGY)
