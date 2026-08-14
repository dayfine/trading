(** Reader-side column addressing for [trades.csv]. See [.mli] for the contract.
*)

open Core

let position_id_column_name = "position_id"

(* Only [position_id] is resolved today; the record shape leaves room for
   further name-addressed columns without changing any caller's plumbing. *)
type t = { position_id_column : int option }

let legacy = { position_id_column = None }

let of_header_line header =
  let names = String.split header ~on:',' |> List.map ~f:String.strip in
  let position_id_column =
    List.findi names ~f:(fun _ name ->
        String.equal name position_id_column_name)
    |> Option.map ~f:fst
  in
  { position_id_column }

(* A row shorter than the header (e.g. one written before the trailing context
   columns existed) has no cell at the index; that is a missing value, not an
   error. *)
let _cell_at cells index =
  match List.nth cells index with
  | None -> None
  | Some cell ->
      let value = String.strip cell in
      if String.is_empty value then None else Some value

let position_id_of_cells t cells =
  Option.bind t.position_id_column ~f:(_cell_at cells)
