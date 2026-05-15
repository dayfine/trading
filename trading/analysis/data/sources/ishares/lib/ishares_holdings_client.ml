open Core

type holding = {
  ticker : string;
  name : string;
  sector : string;
  asset_class : string;
  market_value : float;
  weight_pct : float;
  notional_value : float;
  quantity : float;
  price : float;
  location : string;
  exchange : string;
  currency : string;
  fx_rate : float;
  market_currency : string;
  accrual_date : string;
}
[@@deriving show, eq]

type snapshot = { as_of : Date.t; holdings : holding list }
[@@deriving show, eq]

type parse_outcome = No_data_sentinel | Parsed of snapshot
[@@deriving show, eq]

(* Schema constants pinned from the Phase 1.4 URL probe. The 15-column header
   on line 10 and the [as_of] metadata on line 2 are byte-identical from
   2006-09-29 through 2026-05-08. *)
let _as_of_line_index = 1 (* zero-based: line 2 of the CSV *)
let _expected_columns = 15
let _sentinel_marker = "-"
let _utf8_bom = "\xEF\xBB\xBF"

let _canonical_header =
  "Ticker,Name,Sector,Asset Class,Market Value,Weight (%),Notional \
   Value,Quantity,Price,Location,Exchange,Currency,FX Rate,Market \
   Currency,Accrual Date"

(* iShares product identifiers pinned for IWV (Russell 3000); IWB / IWM
   generalisation lives in a follow-up plan. *)
let _iwv_product_id = "239714"
let _iwv_product_slug = "ishares-russell-3000-etf"
let _iwv_ajax_id = "1467271812596"
let _iwv_file_name = "IWV_holdings"

let _strip_utf8_bom s =
  if String.is_prefix s ~prefix:_utf8_bom then
    String.drop_prefix s (String.length _utf8_bom)
  else s

(* Split a CSV row that uses double-quoted fields with commas inside. iShares
   CSV double-quotes every cell, including numerics. We tokenise by a small
   state machine: in-quote vs out-of-quote, treating a doubled-quote pair as
   an escaped literal quote inside a quoted field. *)
let _split_csv_row row =
  let len = String.length row in
  let buf = Buffer.create 32 in
  let fields = ref [] in
  let in_quote = ref false in
  let i = ref 0 in
  while !i < len do
    let c = row.[!i] in
    (match c with
    | '"' when !in_quote && !i + 1 < len && Char.equal row.[!i + 1] '"' ->
        Buffer.add_char buf '"';
        incr i
    | '"' -> in_quote := not !in_quote
    | ',' when not !in_quote ->
        fields := Buffer.contents buf :: !fields;
        Buffer.clear buf
    | _ -> Buffer.add_char buf c);
    incr i
  done;
  fields := Buffer.contents buf :: !fields;
  List.rev !fields

(* The "Fund Holdings as of" line carries the date in field 2 for data
   responses, or "-" for the sentinel. *)
let _read_as_of_cell line =
  let fields = _split_csv_row line in
  match fields with
  | _ :: cell :: _ -> Ok (String.strip cell)
  | _ ->
      Status.error_invalid_argument
        (Printf.sprintf "Cannot read 'Fund Holdings as of' cell from line: %S"
           line)

let _months =
  [
    ("jan", Month.Jan);
    ("feb", Month.Feb);
    ("mar", Month.Mar);
    ("apr", Month.Apr);
    ("may", Month.May);
    ("jun", Month.Jun);
    ("jul", Month.Jul);
    ("aug", Month.Aug);
    ("sep", Month.Sep);
    ("oct", Month.Oct);
    ("nov", Month.Nov);
    ("dec", Month.Dec);
  ]

let _month_of_abbrev s =
  List.Assoc.find _months ~equal:String.equal
    (String.lowercase (String.prefix s 3))

(* Parse "May 08, 2026" / "Dec 29, 2006" — the as-of cell format. *)
let _parse_as_of_date text =
  let tokens =
    String.split text ~on:' '
    |> List.filter ~f:(fun s -> not (String.is_empty s))
  in
  let bad () =
    Status.error_invalid_argument
      (Printf.sprintf "Cannot parse iShares as-of date: %S" text)
  in
  match tokens with
  | [ ms; ds; ys ] -> (
      let ds = String.strip ~drop:(Char.equal ',') ds in
      match
        (_month_of_abbrev ms, Int.of_string_opt ds, Int.of_string_opt ys)
      with
      | Some m, Some d, Some y -> Ok (Date.create_exn ~y ~m ~d)
      | _ -> bad ())
  | _ -> bad ()

let _validate_header line =
  let normalised = String.strip line in
  if String.equal normalised _canonical_header then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "iShares CSV header mismatch.\nExpected: %s\nGot:      %s"
         _canonical_header normalised)

(* Numeric cells are thousand-separated; "-" or "" map to the semantic 0.0. *)
let _parse_float_cell raw =
  let s = String.strip raw in
  if String.is_empty s || String.equal s _sentinel_marker then 0.0
  else
    let cleaned = String.filter s ~f:(fun c -> not (Char.equal c ',')) in
    Float.of_string cleaned

let _build_holding ~cell =
  {
    ticker = cell 0;
    name = cell 1;
    sector = cell 2;
    asset_class = cell 3;
    market_value = _parse_float_cell (cell 4);
    weight_pct = _parse_float_cell (cell 5);
    notional_value = _parse_float_cell (cell 6);
    quantity = _parse_float_cell (cell 7);
    price = _parse_float_cell (cell 8);
    location = cell 9;
    exchange = cell 10;
    currency = cell 11;
    fx_rate = _parse_float_cell (cell 12);
    market_currency = cell 13;
    accrual_date = cell 14;
  }

let _holding_of_fields fields =
  if List.length fields <> _expected_columns then
    Status.error_invalid_argument
      (Printf.sprintf "Expected %d CSV columns, got %d" _expected_columns
         (List.length fields))
  else
    let cell i = String.strip (List.nth_exn fields i) in
    Ok (_build_holding ~cell)

let _is_data_row_terminator line = String.is_empty (String.strip line)
let _parse_one_row line = _holding_of_fields (_split_csv_row line)

(* Data rows are post-header lines with [_expected_columns] comma-separated
   fields. The legalese footer is separated by a blank line: we stop there. *)
let rec _parse_data_rows_loop acc = function
  | [] -> Ok (List.rev acc)
  | line :: _ when _is_data_row_terminator line -> Ok (List.rev acc)
  | line :: rest ->
      let%bind.Result h = _parse_one_row line in
      _parse_data_rows_loop (h :: acc) rest

let _parse_data_rows lines = _parse_data_rows_loop [] lines

let _header_not_found_error =
  Status.error_invalid_argument
    "iShares CSV header row not found in response body"

(* The 9-line preamble layout above the header isn't load-bearing: we need
   only line 2 (sentinel + as-of) and the first row matching the canonical
   header. Anything starting with "Ticker," but not matching exactly is a
   drift signal — fail loudly. *)
let rec _locate_header_loop = function
  | [] -> _header_not_found_error
  | line :: rest ->
      let normalised = String.strip line in
      if String.equal normalised _canonical_header then Ok rest
      else if String.is_prefix normalised ~prefix:"Ticker," then
        _validate_header normalised |> Result.map ~f:(fun () -> rest)
      else _locate_header_loop rest

let _locate_header lines = _locate_header_loop lines

let parse body =
  let stripped = _strip_utf8_bom body in
  let lines = String.split_lines stripped in
  if List.length lines <= _as_of_line_index then
    Status.error_invalid_argument
      "iShares CSV response too short to contain metadata row"
  else
    let%bind.Result as_of_cell =
      _read_as_of_cell (List.nth_exn lines _as_of_line_index)
    in
    if String.equal as_of_cell _sentinel_marker then Ok No_data_sentinel
    else
      let%bind.Result as_of = _parse_as_of_date as_of_cell in
      let%bind.Result data_lines = _locate_header lines in
      let%map.Result holdings = _parse_data_rows data_lines in
      Parsed { as_of; holdings }

let build_uri ~as_of =
  let yyyymmdd =
    Printf.sprintf "%04d%02d%02d" (Date.year as_of)
      (Month.to_int (Date.month as_of))
      (Date.day as_of)
  in
  let path =
    Printf.sprintf "/us/products/%s/%s/%s.ajax" _iwv_product_id
      _iwv_product_slug _iwv_ajax_id
  in
  Uri.make ~scheme:"https" ~host:"www.ishares.com" ~path
    ~query:
      [
        ("fileType", [ "csv" ]);
        ("fileName", [ _iwv_file_name ]);
        ("dataType", [ "fund" ]);
        ("asOfDate", [ yyyymmdd ]);
      ]
    ()
