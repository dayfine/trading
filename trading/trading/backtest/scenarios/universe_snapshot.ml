(** Universe-snapshot consumer bridge — see [universe_snapshot.mli]. *)

open Core
module Snapshot = Universe.Snapshot

(** Project one snapshot entry to a [(symbol, sector)] pair. Returns [None] for
    synthetic entries — those carry pseudo-tickers like [SYNTH_HiTec_0042] that
    the runner has no CSV bars for. *)
let _entry_to_pair (e : Snapshot.entry) : (string * string) option =
  if e.synthetic then None else Some (e.symbol, e.sector)

let _empty_after_filter_error =
  Error
    Status.
      {
        code = Failed_precondition;
        message =
          "Universe_snapshot: snapshot has no non-synthetic entries; runner \
           has no synthetic-bar source so the resulting sector map would be \
           empty.";
      }

let _project_entries (entries : Snapshot.entry list) :
    (string * string) list Status.status_or =
  let projected = List.filter_map entries ~f:_entry_to_pair in
  if List.is_empty projected then _empty_after_filter_error else Ok projected

let load_path_as_pairs ~path =
  Result.bind (Snapshot.load ~path) ~f:(fun (snapshot : Snapshot.t) ->
      _project_entries snapshot.entries)
