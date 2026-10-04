(** Suspicious vendor high/low diagnostic. See [wick_check.mli]. *)

open Core

type config = { threshold_pct : float }

let _default_threshold_pct = 0.05
let default_config = { threshold_pct = _default_threshold_pct }

type field = High | Low [@@deriving sexp, equal]
type reference = Stored | Neighbour [@@deriving sexp, equal]

type wick = {
  date : Date.t;
  field : field;
  observed : float;
  reference_value : float;
  reference : reference;
  deviation_pct : float;
}
[@@deriving sexp, equal]

type basis_change = {
  date : Date.t;
  stored_close : float;
  fetched_close : float;
}
[@@deriving sexp, equal]

type report = { wicks : wick list; basis_changes : basis_change list }
[@@deriving sexp, equal]

(* Relative distance of [x] from [ref]; [None] when [ref] is not positive. *)
let _rel ~ref x =
  if Float.( <= ) ref 0.0 then None else Some (Float.abs (x -. ref) /. ref)

let _beyond ~threshold ~ref x =
  match _rel ~ref x with Some d -> Float.( > ) d threshold | None -> false

let _wick ~reference ~field ~observed ~reference_value
    (bar : Types.Daily_price.t) =
  {
    date = bar.date;
    field;
    observed;
    reference_value;
    reference;
    deviation_pct =
      Option.value (_rel ~ref:reference_value observed) ~default:0.0;
  }

(* A low below [low_ref] / a high above [high_ref] by more than [threshold]. *)
let _side_wicks ~threshold ~reference ~low_ref ~high_ref
    (bar : Types.Daily_price.t) =
  let low =
    if
      Float.( < ) bar.low_price low_ref
      && _beyond ~threshold ~ref:low_ref bar.low_price
    then
      [
        _wick ~reference ~field:Low ~observed:bar.low_price
          ~reference_value:low_ref bar;
      ]
    else []
  in
  let high =
    if
      Float.( > ) bar.high_price high_ref
      && _beyond ~threshold ~ref:high_ref bar.high_price
    then
      [
        _wick ~reference ~field:High ~observed:bar.high_price
          ~reference_value:high_ref bar;
      ]
    else []
  in
  low @ high

let _basis_change ~(stored : Types.Daily_price.t) (bar : Types.Daily_price.t) =
  {
    date = bar.date;
    stored_close = stored.close_price;
    fetched_close = bar.close_price;
  }

(* Stored reference: a re-based close is a basis change, else compare wicks. *)
let _vs_stored ~threshold ~(stored : Types.Daily_price.t)
    (bar : Types.Daily_price.t) =
  if _beyond ~threshold ~ref:stored.close_price bar.close_price then
    ([], [ _basis_change ~stored bar ])
  else
    let low_ref = stored.low_price and high_ref = stored.high_price in
    (_side_wicks ~threshold ~reference:Stored ~low_ref ~high_ref bar, [])

(* Neighbour reference: the low is judged against the lower of the bar's body
   bottom and the prior close, so it must sit below both (mirror for a high). A
   gap day, or the first bar (no prior close), is exempt. *)
let _vs_neighbour ~threshold ~prev_close (bar : Types.Daily_price.t) =
  match prev_close with
  | None -> []
  | Some prev when _beyond ~threshold ~ref:prev bar.open_price -> []
  | Some prev ->
      let low_ref = Float.min (Float.min bar.open_price bar.close_price) prev in
      let high_ref =
        Float.max (Float.max bar.open_price bar.close_price) prev
      in
      _side_wicks ~threshold ~reference:Neighbour ~low_ref ~high_ref bar

let _stored_by_date stored =
  List.fold stored ~init:Date.Map.empty ~f:(fun m (b : Types.Daily_price.t) ->
      Map.set m ~key:b.date ~data:b)

let check ?(config = default_config) ~stored fetched =
  let threshold = config.threshold_pct in
  let by_date = _stored_by_date stored in
  let sorted =
    List.sort fetched ~compare:(fun (a : Types.Daily_price.t) b ->
        Date.compare a.date b.date)
  in
  let wicks, changes, _ =
    List.fold sorted ~init:([], [], None)
      ~f:(fun (ws, cs, prev_close) (bar : Types.Daily_price.t) ->
        let w, c =
          match Map.find by_date bar.date with
          | Some s -> _vs_stored ~threshold ~stored:s bar
          | None -> (_vs_neighbour ~threshold ~prev_close bar, [])
        in
        (List.rev_append w ws, List.rev_append c cs, Some bar.close_price))
  in
  { wicks = List.rev wicks; basis_changes = List.rev changes }

let _field_label = function Low -> "low" | High -> "high"
let _reference_label = function Stored -> "stored" | Neighbour -> "neighbour"
let _pct = 100.0

let _render_wick ~symbol (w : wick) =
  Printf.sprintf
    "WICK %s %s %s observed=%.4f reference=%.4f (%s) deviation=%.2f%%" symbol
    (Date.to_string w.date) (_field_label w.field) w.observed w.reference_value
    (_reference_label w.reference)
    (_pct *. w.deviation_pct)

let _render_basis ~symbol (b : basis_change) =
  Printf.sprintf "BASIS %s %s stored_close=%.4f fetched_close=%.4f" symbol
    (Date.to_string b.date) b.stored_close b.fetched_close

let render ~symbol report =
  List.map report.wicks ~f:(_render_wick ~symbol)
  @ List.map report.basis_changes ~f:(_render_basis ~symbol)
