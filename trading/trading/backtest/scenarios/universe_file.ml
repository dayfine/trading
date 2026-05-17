open Core

type pinned_entry = { symbol : string; sector : string } [@@deriving sexp]
type t = Pinned of pinned_entry list | Full_sector_map [@@deriving sexp]

(** Try the legacy [Universe_file.t] sexp decoder. Returns [None] when the sexp
    is not in the legacy [Pinned/Full_sector_map] shape (e.g. a custom-universe
    [Universe.Snapshot.t] sexp, which starts with [(date ...)] instead of the
    variant constructor atom). *)
let _try_decode_legacy sexp : t option =
  try Some (t_of_sexp sexp) with _ -> None

(** Fallback path: the sexp didn't decode as a [Universe_file.t]; assume it's a
    [Universe.Snapshot.t] sexp written by the custom-universe pipeline and
    project its non-synthetic entries to [Pinned]. Synthetic entries are dropped
    — backtests against synthetic universes need a separate synthetic-bar source
    not yet wired (Q2-B decomposition goldens are surfaced via
    [Universe_snapshot] but cannot be run end-to-end yet). *)
let _load_via_snapshot_path path : t =
  match Universe_snapshot.load_path_as_pairs ~path with
  | Ok pairs ->
      Pinned (List.map pairs ~f:(fun (symbol, sector) -> { symbol; sector }))
  | Error err ->
      failwith
        (Printf.sprintf
           "Universe_file.load: %s is neither a Universe_file.t nor a \
            decodable Universe.Snapshot.t: %s"
           path (Status.show err))

let load path =
  let sexp = Sexp.load_sexp path in
  match _try_decode_legacy sexp with
  | Some t -> t
  | None -> _load_via_snapshot_path path

let symbol_count = function
  | Pinned entries -> Some (List.length entries)
  | Full_sector_map -> None

let to_sector_map_override = function
  | Full_sector_map -> None
  | Pinned entries ->
      let tbl = Hashtbl.create (module String) in
      List.iter entries ~f:(fun e ->
          Hashtbl.set tbl ~key:e.symbol ~data:e.sector);
      Some tbl
