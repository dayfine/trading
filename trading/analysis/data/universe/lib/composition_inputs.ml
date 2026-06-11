open Core

type inventory_entry = {
  symbol : string;
  data_start_date : Date.t;
  data_end_date : Date.t;
}
[@@deriving sexp]

type inventory = { generated_at : Date.t; symbols : inventory_entry list }
[@@deriving sexp]

let load_inventory path : inventory Status.status_or =
  try Ok (inventory_of_sexp (Sexp.load_sexp path)) with
  | Sys_error msg | Failure msg ->
      Status.error_internal ("composition_inputs: inventory load: " ^ msg)
  | Sexp.Of_sexp_error (exn, _) ->
      Status.error_internal
        ("composition_inputs: inventory decode: " ^ Exn.to_string exn)

(* ------------------------------------------------------------------ *)
(* symbol_types.sexp loader                                            *)
(* Walks the sexp form directly:                                       *)
(*   [Listed "Common Stock"] / [Listed (Other Warrant)] / [Not_in_eodhd_listing] *)
(* We do not depend on [asset_type_enrichment_lib] (separate dune-project,*)
(* no public_name).                                                    *)
(* ------------------------------------------------------------------ *)

let _asset_type_of_sexp sexp : Eodhd.Asset_type.t option =
  match (sexp : Sexp.t) with
  | Atom "Not_in_eodhd_listing" -> None
  | List [ Atom "Listed"; List [ Atom "Other"; Atom raw ] ] ->
      Some (Eodhd.Asset_type.Other raw)
  | List [ Atom "Listed"; Atom s ] -> Some (Eodhd.Asset_type.of_eodhd_string s)
  | _ -> None

let _find_field sexp_pairs name =
  List.find_map sexp_pairs ~f:(function
    | Sexp.List [ Atom k; v ] when String.equal k name -> Some v
    | _ -> None)

let _is_equity_like_sexp at_sexp =
  match _asset_type_of_sexp at_sexp with
  | Some at -> Eodhd.Asset_type.is_equity_like at
  | None -> false

let _equity_like_from_field_pairs pairs : (string * bool) option =
  match (_find_field pairs "symbol", _find_field pairs "asset_type") with
  | Some (Atom sym), Some at_sexp -> Some (sym, _is_equity_like_sexp at_sexp)
  | _ -> None

let _equity_like_from_entry_sexp sexp : (string * bool) option =
  match (sexp : Sexp.t) with
  | List pairs -> _equity_like_from_field_pairs pairs
  | _ -> None

let _symbol_entries_from_sexp sexp : Sexp.t list =
  match (sexp : Sexp.t) with
  | List top_pairs -> (
      match _find_field top_pairs "symbols" with
      | Some (List entries) -> entries
      | _ -> [])
  | _ -> []

let _insert_equity_like tbl entry =
  match _equity_like_from_entry_sexp entry with
  | Some (sym, is_eq) ->
      let _ : [ `Duplicate | `Ok ] = Hashtbl.add tbl ~key:sym ~data:is_eq in
      ()
  | None -> ()

let _build_equity_like_lookup sexp : (string, bool) Hashtbl.t =
  let tbl = Hashtbl.create (module String) in
  List.iter (_symbol_entries_from_sexp sexp) ~f:(_insert_equity_like tbl);
  tbl

let load_equity_like_lookup path : (string, bool) Hashtbl.t Status.status_or =
  try Ok (_build_equity_like_lookup (Sexp.load_sexp path)) with
  | Sys_error msg | Failure msg ->
      Status.error_internal ("composition_inputs: symbol_types load: " ^ msg)
  | Sexp.Of_sexp_error (exn, _) ->
      Status.error_internal
        ("composition_inputs: symbol_types decode: " ^ Exn.to_string exn)

let _asset_type_from_field_pairs pairs : (string * Eodhd.Asset_type.t) option =
  match (_find_field pairs "symbol", _find_field pairs "asset_type") with
  | Some (Atom sym), Some at_sexp -> (
      match _asset_type_of_sexp at_sexp with
      | Some at -> Some (sym, at)
      | None -> None)
  | _ -> None

let _asset_type_from_entry_sexp sexp : (string * Eodhd.Asset_type.t) option =
  match (sexp : Sexp.t) with
  | List pairs -> _asset_type_from_field_pairs pairs
  | _ -> None

let _insert_asset_type tbl entry =
  match _asset_type_from_entry_sexp entry with
  | Some (sym, at) ->
      let _ : [ `Duplicate | `Ok ] = Hashtbl.add tbl ~key:sym ~data:at in
      ()
  | None -> ()

let _build_asset_type_lookup sexp : (string, Eodhd.Asset_type.t) Hashtbl.t =
  let tbl = Hashtbl.create (module String) in
  List.iter (_symbol_entries_from_sexp sexp) ~f:(_insert_asset_type tbl);
  tbl

let load_asset_type_lookup path :
    (string, Eodhd.Asset_type.t) Hashtbl.t Status.status_or =
  try Ok (_build_asset_type_lookup (Sexp.load_sexp path)) with
  | Sys_error msg | Failure msg ->
      Status.error_internal ("composition_inputs: symbol_types load: " ^ msg)
  | Sexp.Of_sexp_error (exn, _) ->
      Status.error_internal
        ("composition_inputs: symbol_types decode: " ^ Exn.to_string exn)

(* ------------------------------------------------------------------ *)
(* Sector CSV loader                                                   *)
(* ------------------------------------------------------------------ *)

let _split_nonempty_lines body =
  String.split_lines body
  |> List.filter ~f:(fun line -> not (String.is_empty (String.strip line)))

let _parse_sector_line line =
  match String.split line ~on:',' with
  | [ sym; sector ] -> Some (sym, sector)
  | _ -> None

let _insert_sector tbl line =
  match _parse_sector_line line with
  | Some (sym, sector) ->
      let _ : [ `Duplicate | `Ok ] = Hashtbl.add tbl ~key:sym ~data:sector in
      ()
  | None -> ()

let _populate_sector_table tbl body =
  match _split_nonempty_lines body with
  | [] | [ _ ] -> ()
  | _header :: rows -> List.iter rows ~f:(_insert_sector tbl)

let load_sectors path : (string, string) Hashtbl.t Status.status_or =
  match In_channel.read_all path with
  | exception Sys_error msg ->
      Status.error_internal ("composition_inputs: sectors load: " ^ msg)
  | body ->
      let tbl = Hashtbl.create (module String) in
      _populate_sector_table tbl body;
      Ok tbl
