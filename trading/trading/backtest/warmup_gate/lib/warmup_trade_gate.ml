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

(* Map an inner [on_market_close] result through {!filter_transitions} with
   [suppress = true], leaving [Error] untouched. Extracted to a flat top-level
   helper so [wrap_strategy]'s functor body stays shallow — the transform lives
   here rather than nested inside the [module Wrapped] closure (keeps nesting
   depth within the linter budget). *)
let _filter_result ~start_date
    (result : Strategy_interface.output Status.status_or) =
  Result.map result ~f:(fun { Strategy_interface.transitions } ->
      {
        Strategy_interface.transitions =
          filter_transitions ~suppress:true ~start_date transitions;
      })

let _filter_market_close ~start_date ~inner ~get_price ~get_indicator ~portfolio
    =
  inner ~get_price ~get_indicator ~portfolio |> _filter_result ~start_date

let wrap_strategy ~suppress ~start_date (module S : Strategy_interface.STRATEGY)
    =
  if not suppress then (module S : Strategy_interface.STRATEGY)
  else
    let module Wrapped = struct
      let name = S.name

      let on_market_close =
        _filter_market_close ~start_date ~inner:S.on_market_close
    end in
    (module Wrapped : Strategy_interface.STRATEGY)
