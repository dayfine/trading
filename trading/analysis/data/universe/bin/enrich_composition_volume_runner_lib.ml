open Core
module BFI = Universe.Build_from_individuals
module Snapshot = Universe.Snapshot

type entry_result = { enriched : int; no_volume : int; synthetic : int }
[@@deriving show, eq]

type file_result = { path : string; result : entry_result }
[@@deriving show, eq]

type result = { files : file_result list; composition_changed : int }
[@@deriving show, eq]

let _empty_tally = { enriched = 0; no_volume = 0; synthetic = 0 }

(* ------------------------------------------------------------------ *)
(* Per-entry enrichment                                                *)
(* ------------------------------------------------------------------ *)

let enrich_entry ~date ~config (entry : Snapshot.entry) : Snapshot.entry =
  if entry.synthetic then entry
  else
    let avg_dollar_volume =
      BFI.avg_dollar_volume_for_symbol ~date ~config entry.symbol
    in
    { entry with avg_dollar_volume }

let _tally_entry acc (entry : Snapshot.entry) =
  if entry.synthetic then { acc with synthetic = acc.synthetic + 1 }
  else
    match entry.avg_dollar_volume with
    | Some _ -> { acc with enriched = acc.enriched + 1 }
    | None -> { acc with no_volume = acc.no_volume + 1 }

let enrich_snapshot ~config (snapshot : Snapshot.t) =
  let date = snapshot.date in
  let entries = List.map snapshot.entries ~f:(enrich_entry ~date ~config) in
  let tally = List.fold entries ~init:_empty_tally ~f:_tally_entry in
  ({ snapshot with entries }, tally)

(* ------------------------------------------------------------------ *)
(* Composition-preservation invariant                                  *)
(* ------------------------------------------------------------------ *)

(* Projection that drops [avg_dollar_volume] — the only field enrichment is
   allowed to touch. Two entries are composition-equal iff they agree on every
   other field. *)
type _entry_projection = {
  symbol : string;
  weight : float;
  sector : string;
  synthetic : bool;
}
[@@deriving eq]

let _project (entry : Snapshot.entry) =
  {
    symbol = entry.symbol;
    weight = entry.weight;
    sector = entry.sector;
    synthetic = entry.synthetic;
  }

let composition_preserved (before : Snapshot.t) (after : Snapshot.t) =
  Date.equal before.date after.date
  && Snapshot.equal_method_ before.method_ after.method_
  && Int.equal before.size after.size
  && Float.equal before.aggregate_period_return after.aggregate_period_return
  && List.equal equal__entry_projection
       (List.map before.entries ~f:_project)
       (List.map after.entries ~f:_project)

(* ------------------------------------------------------------------ *)
(* File-level pipeline                                                 *)
(* ------------------------------------------------------------------ *)

let _config_for ~bars_root =
  (* Only [bars_root] / [trailing_window_days] / [min_window_bars] are read by
     [avg_dollar_volume_for_symbol]; the path fields are unused, so empty
     strings are safe and keep us on the builder's documented defaults. *)
  BFI.default_config ~size:1 ~bars_root ~symbol_types_path:""
    ~sectors_csv_path:"" ~inventory_path:""

let _enrich_one_file ~config path =
  let%bind.Result snapshot = Snapshot.load ~path in
  let enriched, tally = enrich_snapshot ~config snapshot in
  if not (composition_preserved snapshot enriched) then
    Ok ({ path; result = tally }, true)
  else
    let%bind.Result () = Snapshot.save enriched ~path in
    Ok ({ path; result = tally }, false)

let _golden_paths ~goldens_dir =
  match Sys_unix.readdir goldens_dir with
  | exception _ ->
      Status.error_internal
        (Printf.sprintf "enrich: cannot list goldens dir %s" goldens_dir)
  | names ->
      Array.to_list names
      |> List.filter ~f:(fun n -> String.is_suffix n ~suffix:".sexp")
      |> List.sort ~compare:String.compare
      |> List.map ~f:(Filename.concat goldens_dir)
      |> fun paths -> Ok paths

let _fold_file ~config acc path =
  let%bind.Result files, changed = acc in
  let%bind.Result file_result, drifted = _enrich_one_file ~config path in
  let changed = if drifted then changed + 1 else changed in
  Ok (file_result :: files, changed)

let run ~goldens_dir ~bars_root =
  let config = _config_for ~bars_root in
  let%bind.Result paths = _golden_paths ~goldens_dir in
  let%bind.Result files, composition_changed =
    List.fold paths ~init:(Ok ([], 0)) ~f:(_fold_file ~config)
  in
  Ok { files = List.rev files; composition_changed }
