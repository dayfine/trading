(** Universe-file reader for the snapshot warehouse writer — see
    [universe_loader.mli]. *)

open Core
module Snapshot = Universe.Snapshot

(* The [Pinned] universe shape mirrors [scenario_lib/universe_file.mli]:
   [(Pinned ((symbol AAPL) (sector "Information Technology")) ...)]. Only the
   symbol is needed by the snapshot writer; the sector field is retained for
   sexp-shape fidelity but otherwise unused. *)
type _pinned_entry = { symbol : string; sector : string [@warning "-69"] }
[@@deriving sexp]

type _universe_kind = Pinned of _pinned_entry list | Full_sector_map
[@@deriving sexp]

let _full_sector_map_error =
  Error
    Status.
      {
        code = Unimplemented;
        message =
          "build_snapshots: Full_sector_map universes are not supported; pass \
           a Pinned universe sexp or a composition snapshot.";
      }

let _unrecognized_shape_error =
  Error
    Status.
      {
        code = Failed_precondition;
        message =
          "build_snapshots: universe sexp is neither a Pinned/Full_sector_map \
           universe nor a composition snapshot.";
      }

(* Mirrors [universe_snapshot._empty_after_filter_error]: a snapshot with no
   non-synthetic entries yields no tradeable symbols, so the writer cannot
   meaningfully consume it. *)
let _all_synthetic_error =
  Error
    Status.
      {
        code = Failed_precondition;
        message =
          "build_snapshots: composition snapshot has no non-synthetic entries; \
           the writer has no synthetic-bar source so there are no symbols to \
           build.";
      }

(* Real-ticker symbol of a snapshot entry, or [None] for synthetic entries —
   those carry pseudo-tickers like [SYNTH_HiTec_0042] that the writer has no CSV
   bars for. Mirrors [universe_snapshot._entry_to_pair]. *)
let _entry_to_symbol (e : Snapshot.entry) : string option =
  if e.synthetic then None else Some e.symbol

let _symbols_of_snapshot (snapshot : Snapshot.t) : string list Status.status_or
    =
  let symbols = List.filter_map snapshot.entries ~f:_entry_to_symbol in
  if List.is_empty symbols then _all_synthetic_error else Ok symbols

(* Try the [Universe.Snapshot.t] sexp shape. A composition snapshot is the
   expected hit here; any sexp that fails to decode as a snapshot is reported as
   an unrecognized universe shape rather than the raw decode failure. *)
let _try_composition sexp =
  match Snapshot.t_of_sexp sexp with
  | snapshot -> _symbols_of_snapshot snapshot
  | exception _ -> _unrecognized_shape_error

let symbols_of_sexp sexp =
  match _universe_kind_of_sexp sexp with
  | Pinned entries -> Ok (List.map entries ~f:(fun e -> e.symbol))
  | Full_sector_map -> _full_sector_map_error
  | exception _ -> _try_composition sexp

let symbols_of_path ~path =
  match Sexp.load_sexp path with
  | sexp -> symbols_of_sexp sexp
  | exception exn ->
      Status.error_internal
        (Printf.sprintf
           "build_snapshots: failed to read universe sexp at %s: %s" path
           (Exn.to_string exn))
