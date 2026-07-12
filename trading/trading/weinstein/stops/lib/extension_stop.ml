open Core

type config = {
  trigger_ratio : float; [@sexp.default 0.0]
  trail_pct : float; [@sexp.default 0.0]
}
[@@deriving show, eq, sexp]

let default_config = { trigger_ratio = 0.0; trail_pct = 0.0 }

let is_enabled { trigger_ratio; trail_pct } =
  Float.( > ) trigger_ratio 0.0 && Float.( > ) trail_pct 0.0

(* First week whose close/wma reaches the trigger ratio; the WMA must be filled
   (finite and > 0). Mirrors the extension screen's [_first_trigger]. *)
let _first_trigger ~closes ~wmas ~trigger_ratio =
  let n = Array.length closes in
  let rec go i =
    if i >= n then None
    else if
      Float.is_finite wmas.(i)
      && Float.( > ) wmas.(i) 0.0
      && Float.( >= ) (closes.(i) /. wmas.(i)) trigger_ratio
    then Some i
    else go (i + 1)
  in
  go 0

(* Walk forward from the trigger week; fire at the first weekly close that is
   [trail_pct] below the running peak close (peak seeded at the trigger week).
   The fire-check precedes the peak update so a new high can never fire. Mirrors
   the extension screen's [_trail_fire]. *)
let _trail_fires ~closes ~trigger ~trail_pct =
  let n = Array.length closes in
  let peak = ref closes.(trigger) in
  let rec go i =
    if i >= n then false
    else if Float.( <= ) closes.(i) (!peak *. (1.0 -. trail_pct)) then true
    else (
      peak := Float.max !peak closes.(i);
      go (i + 1))
  in
  go (trigger + 1)

let fired config ~closes ~wmas =
  if (not (is_enabled config)) || Array.length closes <> Array.length wmas then
    false
  else
    match _first_trigger ~closes ~wmas ~trigger_ratio:config.trigger_ratio with
    | None -> false
    | Some trigger -> _trail_fires ~closes ~trigger ~trail_pct:config.trail_pct
