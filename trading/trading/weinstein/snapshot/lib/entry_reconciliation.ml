open Core

type levels = {
  close : float;
  overshoot_pct : float;
  cap : float; [@sexp.default 0.0]
}
[@@deriving sexp, eq, show]

type t =
  | Not_reconciled
  | Valid_stop of levels
  | Through_entry of levels
  | Extended of levels
[@@deriving sexp, eq, show]

let _pct = 100.0

let overshoot_pct ~side ~entry ~close =
  if Float.( <= ) entry 0.0 then 0.0
  else
    let signed =
      match side with `Long -> close -. entry | `Short -> entry -. close
    in
    signed /. entry *. _pct

let cap_price ~side ~entry ~extension_max_pct =
  if Float.( <= ) extension_max_pct 0.0 || Float.( <= ) entry 0.0 then entry
  else
    let frac = extension_max_pct /. _pct in
    match side with
    | `Long -> entry *. (1.0 +. frac)
    | `Short -> entry *. (1.0 -. frac)

(* Class for an armed reconciliation. Both boundaries fall to the LOWER class:
   an overshoot exactly at the de-minimis band is still a resting stop, and one
   exactly at the cap is still tradeable at the market. *)
let _class_of ~through_band_pct ~extension_max_pct levels =
  if Float.( <= ) levels.overshoot_pct through_band_pct then Valid_stop levels
  else if Float.( <= ) levels.overshoot_pct extension_max_pct then
    Through_entry levels
  else Extended levels

let classify ~side ~entry ~close ~through_band_pct ~extension_max_pct =
  (* [extension_max_pct <= 0.0] is the arming switch (R1 no-op default); a
     non-positive entry leaves the overshoot undefined. Either way there is
     nothing honest to say about this candidate's fill. *)
  if Float.( <= ) extension_max_pct 0.0 || Float.( <= ) entry 0.0 then
    Not_reconciled
  else
    _class_of ~through_band_pct ~extension_max_pct
      {
        close;
        overshoot_pct = overshoot_pct ~side ~entry ~close;
        cap = cap_price ~side ~entry ~extension_max_pct;
      }

let label = function
  | Not_reconciled -> None
  | Valid_stop _ -> Some "valid-stop"
  | Through_entry _ -> Some "through-entry"
  | Extended _ -> Some "EXTENDED"

let levels_of = function
  | Not_reconciled -> None
  | Valid_stop l | Through_entry l | Extended l -> Some l
