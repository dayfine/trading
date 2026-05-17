open Core

(* ---- Types ---- *)

type entry = { symbol : string; shares_outstanding : float }
[@@deriving show, eq]

type t = {
  generated_at : Date.t;
  source_endpoints : (string * Date.t) list;
  entries : entry list;
}
[@@deriving show, eq]

(* ---- Sexp encoding for [entry] ---- *)

let _kv_sexp key value = Sexp.List [ Atom key; Atom value ]
let _symbol_field s = _kv_sexp "symbol" s

let _shares_outstanding_field n =
  _kv_sexp "shares_outstanding" (Printf.sprintf "%.6f" n)

let sexp_of_entry { symbol; shares_outstanding } =
  Sexp.List
    [ _symbol_field symbol; _shares_outstanding_field shares_outstanding ]

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

let _parse_float_atom atom =
  try Ok (Float.of_string atom)
  with _ -> Error (Printf.sprintf "invalid float atom: %s" atom)

let _entry_of_fields fields =
  let open Result.Let_syntax in
  let%bind symbol = _find_field fields "symbol" >>= _atom_of in
  let%bind shares_atom = _find_field fields "shares_outstanding" >>= _atom_of in
  let%bind shares_outstanding = _parse_float_atom shares_atom in
  Ok { symbol; shares_outstanding }

let entry_of_sexp sexp =
  let result =
    let open Result.Let_syntax in
    match sexp with
    | Sexp.List pairs ->
        let%bind kvs = List.map pairs ~f:_entry_field_pairs |> Result.all in
        _entry_of_fields kvs
    | other ->
        Error
          (Printf.sprintf "expected entry list, got: %s" (Sexp.to_string other))
  in
  match result with
  | Ok e -> e
  | Error msg ->
      raise (Sexp.Of_sexp_error (Failure ("entry_of_sexp: " ^ msg), sexp))

(* ---- Sexp encoding for [t] ---- *)

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

let _entries_field entries =
  Sexp.List [ Atom "entries"; List (List.map entries ~f:sexp_of_entry) ]

let sexp_of_t { generated_at; source_endpoints; entries } =
  Sexp.List
    [
      _generated_at_field generated_at;
      _source_endpoints_field source_endpoints;
      _entries_field entries;
    ]

let _parse_endpoints_field = function
  | Sexp.List pairs -> List.map pairs ~f:_endpoint_pair_of_sexp |> Result.all
  | other ->
      Error
        (Printf.sprintf "expected source_endpoints list, got: %s"
           (Sexp.to_string other))

let _parse_entries_field = function
  | Sexp.List entries -> Ok (List.map entries ~f:entry_of_sexp)
  | other ->
      Error
        (Printf.sprintf "expected entries list, got: %s" (Sexp.to_string other))

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
  let%bind entries_sexp = _find_field fields "entries" in
  let%bind entries = _parse_entries_field entries_sexp in
  Ok { generated_at; source_endpoints; entries }

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

let _has_positive_shares (f : Eodhd.Fundamentals_endpoint.fundamentals) =
  Float.(f.shares_outstanding > 0.0)

(* Deduplicate by symbol, keeping the first occurrence. *)
let _dedupe_by_symbol fundamentals =
  let seen = Hash_set.create (module String) in
  List.filter fundamentals ~f:(fun f ->
      let symbol = f.Eodhd.Fundamentals_endpoint.symbol in
      if Hash_set.mem seen symbol then false
      else (
        Hash_set.add seen symbol;
        true))

let _entry_of_fundamentals (f : Eodhd.Fundamentals_endpoint.fundamentals) =
  { symbol = f.symbol; shares_outstanding = f.shares_outstanding }

let join ~fundamentals ~generated_at ~source_endpoints =
  let entries =
    fundamentals
    |> List.filter ~f:_has_positive_shares
    |> _dedupe_by_symbol
    |> List.map ~f:_entry_of_fundamentals
    |> List.sort ~compare:(fun a b -> String.compare a.symbol b.symbol)
  in
  { generated_at; source_endpoints; entries }

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
