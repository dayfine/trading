open Core

(* ---- Types ---- *)

type enriched_asset_type = Listed of Eodhd.Asset_type.t | Not_in_eodhd_listing
[@@deriving show, eq]

type entry = {
  symbol : string;
  asset_type : enriched_asset_type;
  name : string;
  exchange : string;
}
[@@deriving show, eq]

type t = {
  generated_at : Date.t;
  source_endpoints : (string * Date.t) list;
  symbols : entry list;
}
[@@deriving show, eq]

type type_count = { asset_type_label : string; count : int }
[@@deriving show, eq]

(* ---- Sexp encoding for [enriched_asset_type] ----

   We hand-roll because [Eodhd.Asset_type.t] does not derive sexp.
   The encoding pins each variant by its [to_string] / [of_eodhd_string]
   round-trip:
     Listed Common_stock       -> (Listed "Common Stock")
     Listed (Other "WeirdX")   -> (Listed (Other "WeirdX"))
     Not_in_eodhd_listing      -> Not_in_eodhd_listing
*)

let sexp_of_enriched_asset_type = function
  | Not_in_eodhd_listing -> Sexp.Atom "Not_in_eodhd_listing"
  | Listed (Eodhd.Asset_type.Other raw) ->
      Sexp.List [ Atom "Listed"; List [ Atom "Other"; Atom raw ] ]
  | Listed at ->
      Sexp.List [ Atom "Listed"; Atom (Eodhd.Asset_type.to_string at) ]

let _raise_invalid_enriched_asset_type_sexp other =
  let msg =
    "asset_type_enrichment: invalid enriched_asset_type sexp: "
    ^ Sexp.to_string other
  in
  raise (Sexp.Of_sexp_error (Failure msg, other))

let enriched_asset_type_of_sexp = function
  | Sexp.Atom "Not_in_eodhd_listing" -> Not_in_eodhd_listing
  | Sexp.List [ Atom "Listed"; List [ Atom "Other"; Atom raw ] ] ->
      Listed (Eodhd.Asset_type.Other raw)
  | Sexp.List [ Atom "Listed"; Atom s ] ->
      Listed (Eodhd.Asset_type.of_eodhd_string s)
  | other -> _raise_invalid_enriched_asset_type_sexp other

(* ---- Sexp encoding for [entry] and [t] ---- *)

let sexp_of_entry { symbol; asset_type; name; exchange } =
  Sexp.List
    [
      List [ Atom "symbol"; Atom symbol ];
      List [ Atom "asset_type"; sexp_of_enriched_asset_type asset_type ];
      List [ Atom "name"; Atom name ];
      List [ Atom "exchange"; Atom exchange ];
    ]

let _atom_of = function
  | Sexp.Atom s -> Ok s
  | other ->
      Error (Printf.sprintf "expected atom, got: %s" (Sexp.to_string other))

let _find_field fields name =
  match List.Assoc.find ~equal:String.equal fields name with
  | Some v -> Ok v
  | None -> Error (Printf.sprintf "missing field %s" name)

let _entry_field_pairs = function
  | Sexp.List [ Atom k; v ] -> Ok (k, v)
  | other ->
      Error
        (Printf.sprintf "expected (key value) pair, got: %s"
           (Sexp.to_string other))

let entry_of_sexp sexp =
  let open Result.Let_syntax in
  let parse_fields fields =
    let%bind symbol = _find_field fields "symbol" >>= _atom_of in
    let%bind asset_type_sexp = _find_field fields "asset_type" in
    let asset_type = enriched_asset_type_of_sexp asset_type_sexp in
    let%bind name = _find_field fields "name" >>= _atom_of in
    let%bind exchange = _find_field fields "exchange" >>= _atom_of in
    Ok { symbol; asset_type; name; exchange }
  in
  let result =
    match sexp with
    | Sexp.List pairs ->
        let%bind kvs = List.map pairs ~f:_entry_field_pairs |> Result.all in
        parse_fields kvs
    | other ->
        Error
          (Printf.sprintf "expected entry list, got: %s" (Sexp.to_string other))
  in
  match result with
  | Ok e -> e
  | Error msg ->
      raise (Sexp.Of_sexp_error (Failure ("entry_of_sexp: " ^ msg), sexp))

let _sexp_of_endpoint_pair (ep, d) =
  Sexp.List [ Atom ep; Atom (Date.to_string d) ]

let _endpoint_pair_of_sexp = function
  | Sexp.List [ Atom ep; Atom d ] -> (
      try Ok (ep, Date.of_string d)
      with _ -> Error ("invalid endpoint date: " ^ d))
  | other ->
      Error
        (Printf.sprintf "expected (endpoint date) pair, got: %s"
           (Sexp.to_string other))

let _generated_at_field generated_at =
  Sexp.List [ Atom "generated_at"; Atom (Date.to_string generated_at) ]

let _source_endpoints_field source_endpoints =
  let pairs = List.map source_endpoints ~f:_sexp_of_endpoint_pair in
  Sexp.List [ Atom "source_endpoints"; List pairs ]

let _symbols_field symbols =
  let entries = List.map symbols ~f:sexp_of_entry in
  Sexp.List [ Atom "symbols"; List entries ]

let sexp_of_t { generated_at; source_endpoints; symbols } =
  Sexp.List
    [
      _generated_at_field generated_at;
      _source_endpoints_field source_endpoints;
      _symbols_field symbols;
    ]

let _parse_endpoints_field = function
  | Sexp.List pairs -> List.map pairs ~f:_endpoint_pair_of_sexp |> Result.all
  | other ->
      Error
        (Printf.sprintf "expected source_endpoints list, got: %s"
           (Sexp.to_string other))

let _parse_symbols_field = function
  | Sexp.List entries -> Ok (List.map entries ~f:entry_of_sexp)
  | other ->
      Error
        (Printf.sprintf "expected symbols list, got: %s" (Sexp.to_string other))

let _parse_generated_at fields =
  let open Result.Let_syntax in
  let%bind atom = _find_field fields "generated_at" >>= _atom_of in
  try Ok (Date.of_string atom)
  with _ -> Error ("invalid generated_at date: " ^ atom)

let _parse_t_fields fields =
  let open Result.Let_syntax in
  let%bind generated_at = _parse_generated_at fields in
  let%bind endpoints_sexp = _find_field fields "source_endpoints" in
  let%bind source_endpoints = _parse_endpoints_field endpoints_sexp in
  let%bind symbols_sexp = _find_field fields "symbols" in
  let%bind symbols = _parse_symbols_field symbols_sexp in
  Ok { generated_at; source_endpoints; symbols }

let _t_of_sexp_routing sexp =
  let open Result.Let_syntax in
  match sexp with
  | Sexp.List pairs ->
      let%bind kvs = List.map pairs ~f:_entry_field_pairs |> Result.all in
      _parse_t_fields kvs
  | other ->
      Error
        (Printf.sprintf "expected top-level list, got: %s"
           (Sexp.to_string other))

let t_of_sexp sexp =
  match _t_of_sexp_routing sexp with
  | Ok x -> x
  | Error msg ->
      raise (Sexp.Of_sexp_error (Failure ("t_of_sexp: " ^ msg), sexp))

(* ---- Pure join ---- *)

let _build_lookup eodhd_listings =
  let tbl = Hashtbl.create (module String) in
  List.iter eodhd_listings ~f:(fun m ->
      (* First occurrence wins, matching the .mli contract. *)
      let _ : [ `Duplicate | `Ok ] =
        Hashtbl.add tbl ~key:m.Eodhd.Http_client.code ~data:m
      in
      ());
  tbl

let _entry_of_inventory_symbol lookup symbol =
  match Hashtbl.find lookup symbol with
  | Some m ->
      {
        symbol;
        asset_type = Listed m.Eodhd.Http_client.asset_type;
        name = m.name;
        exchange = m.exchange;
      }
  | None ->
      { symbol; asset_type = Not_in_eodhd_listing; name = ""; exchange = "" }

let join ~inventory_symbols ~eodhd_listings ~generated_at ~source_endpoints =
  let lookup = _build_lookup eodhd_listings in
  let symbols =
    List.map inventory_symbols ~f:(_entry_of_inventory_symbol lookup)
  in
  { generated_at; source_endpoints; symbols }

(* ---- I/O — uses [File_sexp.Sexp.save/load] via a Sexpable module ---- *)

let _sexpable () =
  (module struct
    type nonrec t = t

    let sexp_of_t = sexp_of_t
    let t_of_sexp = t_of_sexp
  end : Base.Sexpable.S
    with type t = t)

let save t ~path = File_sexp.Sexp.save (_sexpable ()) t ~path
let load ~path = File_sexp.Sexp.load (_sexpable ()) ~path

(* ---- Summary ---- *)

let _label_of_enriched_asset_type = function
  | Not_in_eodhd_listing -> "Not_in_eodhd_listing"
  | Listed (Eodhd.Asset_type.Other raw) -> "Other:" ^ raw
  | Listed at -> Eodhd.Asset_type.to_string at

let per_type_counts t =
  let tbl = Hashtbl.create (module String) in
  List.iter t.symbols ~f:(fun e ->
      let key = _label_of_enriched_asset_type e.asset_type in
      Hashtbl.update tbl key ~f:(function None -> 1 | Some n -> n + 1));
  Hashtbl.to_alist tbl
  |> List.map ~f:(fun (asset_type_label, count) -> { asset_type_label; count })
  |> List.sort ~compare:(fun a b ->
      match Int.compare b.count a.count with
      | 0 -> String.compare a.asset_type_label b.asset_type_label
      | c -> c)
