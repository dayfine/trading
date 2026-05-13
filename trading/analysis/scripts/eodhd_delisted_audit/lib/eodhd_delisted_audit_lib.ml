open Core

type removed_symbol = { symbol : string; effective_date : string }
[@@deriving sexp, equal]

type eodhd_fixture = { delisted : string list; live : string list }
[@@deriving sexp_of, equal]

type status = Matched_in_eodhd_delisted | Live_on_eodhd | Not_found
[@@deriving sexp_of, equal]

type row = { symbol : string; effective_date : string; status : status }
[@@deriving sexp_of, equal]

let parse_removed_sexp text =
  try
    let sexp = Sexp.of_string text in
    Ok (List.t_of_sexp removed_symbol_of_sexp sexp)
  with exn ->
    Status.error_invalid_argument
      ("Failed to parse removed-symbols sexp: " ^ Exn.to_string exn)

let _code_of_entry = function
  | `Assoc fields -> (
      match List.Assoc.find fields "Code" ~equal:String.equal with
      | Some (`String s) -> Some s
      | _ -> None)
  | _ -> None

let _codes_of_json_array = function
  | `List entries -> List.filter_map entries ~f:_code_of_entry
  | _ -> []

let _fixture_of_object fields =
  let lookup key =
    List.Assoc.find fields key ~equal:String.equal
    |> Option.value ~default:(`List [])
  in
  Ok
    {
      delisted = _codes_of_json_array (lookup "delisted");
      live = _codes_of_json_array (lookup "live");
    }

let parse_eodhd_fixture text =
  try
    match Yojson.Safe.from_string text with
    | `Assoc fields -> _fixture_of_object fields
    | _ ->
        Status.error_invalid_argument
          "Expected top-level JSON object with 'delisted' and 'live' keys"
  with Yojson.Json_error msg ->
    Status.error_invalid_argument ("Invalid EODHD fixture JSON: " ^ msg)

let _classify ~delisted_set ~live_set symbol =
  if Hash_set.mem delisted_set symbol then Matched_in_eodhd_delisted
  else if Hash_set.mem live_set symbol then Live_on_eodhd
  else Not_found

let cross_reference ~(removed : removed_symbol list) ~eodhd =
  let delisted_set = Hash_set.of_list (module String) eodhd.delisted in
  let live_set = Hash_set.of_list (module String) eodhd.live in
  List.map removed ~f:(fun r ->
      {
        symbol = r.symbol;
        effective_date = r.effective_date;
        status = _classify ~delisted_set ~live_set r.symbol;
      })
  |> List.sort ~compare:(fun a b -> String.compare a.symbol b.symbol)

let _status_label = function
  | Matched_in_eodhd_delisted -> "matched-in-eodhd-delisted"
  | Live_on_eodhd -> "live-on-eodhd"
  | Not_found -> "not-found"

let _status_order = function
  | Matched_in_eodhd_delisted -> 0
  | Live_on_eodhd -> 1
  | Not_found -> 2

let _count_status rows s = List.count rows ~f:(fun r -> equal_status r.status s)
let _initial_buffer_bytes = 1024

let render_markdown rows =
  let buf = Buffer.create _initial_buffer_bytes in
  Buffer.add_string buf "# EODHD Delisted-Symbol Audit\n\n";
  Printf.bprintf buf "Matched: %d / Live: %d / Not-found: %d (total: %d)\n\n"
    (_count_status rows Matched_in_eodhd_delisted)
    (_count_status rows Live_on_eodhd)
    (_count_status rows Not_found)
    (List.length rows);
  Buffer.add_string buf "| Symbol | Effective Date | Status |\n";
  Buffer.add_string buf "|--------|----------------|--------|\n";
  let sorted =
    List.sort rows ~compare:(fun a b ->
        match Int.compare (_status_order a.status) (_status_order b.status) with
        | 0 -> String.compare a.symbol b.symbol
        | c -> c)
  in
  List.iter sorted ~f:(fun r ->
      Printf.bprintf buf "| %s | %s | %s |\n" r.symbol r.effective_date
        (_status_label r.status));
  Buffer.contents buf
