(** Per-run collector of force-liquidation events. See
    [force_liquidation_log.mli]. *)

open Core
open Portfolio_risk

type t = { mutable rev_events : Force_liquidation.event list }

let create () = { rev_events = [] }
let record t event = t.rev_events <- event :: t.rev_events

let _compare_event (a : Force_liquidation.event) (b : Force_liquidation.event) =
  match Date.compare a.date b.date with
  | 0 -> String.compare a.position_id b.position_id
  | n -> n

let events t = List.rev t.rev_events |> List.sort ~compare:_compare_event
let count t = List.length t.rev_events

type artefact = { events : Force_liquidation.event list } [@@deriving sexp]

let save_sexp ~path t =
  match events t with
  | [] -> ()
  | evs ->
      let blob : artefact = { events = evs } in
      Sexp.save_hum path (sexp_of_artefact blob)

let load_sexp path =
  let sexp = Sexp.load_sexp path in
  let blob = artefact_of_sexp sexp in
  blob.events
