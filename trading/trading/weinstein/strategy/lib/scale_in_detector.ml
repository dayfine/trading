(** Pure detection of the scale-in add trigger. See .mli. *)

open Core

type trigger = Pullback | Early_new_high | Either [@@deriving sexp, eq, show]

(* Default pullback-touch band: a bar's low within 3% above the breakout level
   counts as the retest of the breakout zone. *)
let default_pullback_proximity_pct = 0.03

(* Default extension gate: no add when the close sits more than 15% above the
   30-week MA (price has outrun its own trend). *)
let default_extension_max_pct = 0.15

type config = {
  initial_entry_fraction : float; [@sexp.default 1.0]
  max_adds : int; [@sexp.default 1]
  add_trigger : trigger; [@sexp.default Pullback]
  pullback_proximity_pct : float; [@sexp.default default_pullback_proximity_pct]
  extension_max_pct : float; [@sexp.default default_extension_max_pct]
  require_not_late : bool; [@sexp.default true]
}
[@@deriving sexp, eq, show]

let default_config =
  {
    initial_entry_fraction = 1.0;
    max_adds = 1;
    add_trigger = Pullback;
    pullback_proximity_pct = default_pullback_proximity_pct;
    extension_max_pct = default_extension_max_pct;
    require_not_late = true;
  }

(* Current bar + strictly-prior bars, both in chronological order collapsed to
   (current, rev_prior). [None] when fewer than two bars — a pullback or a
   continuation needs at least one full bar after the entry week. *)
let _split_current bars =
  match List.rev bars with
  | current :: (_ :: _ as rev_prior) -> Some (current, rev_prior)
  | _ -> None

(* Some prior bar's low touched the pullback zone. *)
let _touched_pullback_zone ~touch_level rev_prior =
  List.exists rev_prior ~f:(fun (b : Types.Daily_price.t) ->
      Float.( <= ) b.low_price touch_level)

(* The current bar holds the breakout level and turns back up. *)
let _held_and_turned ~entry_price ~(current : Types.Daily_price.t) ~rev_prior =
  let prev_close = (List.hd_exn rev_prior).Types.Daily_price.close_price in
  Float.( >= ) current.close_price entry_price
  && Float.( > ) current.close_price prev_close

let pullback_hold ~proximity_pct ~entry_price ~bars_since_entry =
  match _split_current bars_since_entry with
  | None -> false
  | Some (current, rev_prior) ->
      let touch_level = entry_price *. (1.0 +. proximity_pct) in
      _touched_pullback_zone ~touch_level rev_prior
      && _held_and_turned ~entry_price ~current ~rev_prior

let early_new_high ~entry_price ~bars_since_entry =
  match _split_current bars_since_entry with
  | None -> false
  | Some (current, rev_prior) ->
      let prior_max =
        List.fold rev_prior ~init:Float.neg_infinity
          ~f:(fun acc (b : Types.Daily_price.t) -> Float.max acc b.close_price)
      in
      Float.( > ) current.Types.Daily_price.close_price prior_max
      && Float.( > ) current.Types.Daily_price.close_price entry_price

let add_signal ~trigger ~proximity_pct ~entry_price ~bars_since_entry =
  match trigger with
  | Pullback -> pullback_hold ~proximity_pct ~entry_price ~bars_since_entry
  | Early_new_high -> early_new_high ~entry_price ~bars_since_entry
  | Either ->
      pullback_hold ~proximity_pct ~entry_price ~bars_since_entry
      || early_new_high ~entry_price ~bars_since_entry

let extended_above_ma ~max_pct ~close ~ma =
  Float.( > ) ma 0.0 && Float.( > ) ((close -. ma) /. ma) max_pct
