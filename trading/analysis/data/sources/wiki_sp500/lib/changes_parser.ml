open Core

type ticker_id = { symbol : string; security_name : string }
[@@deriving show, eq]

type change_event = {
  effective_date : Date.t;
  added : ticker_id option;
  removed : ticker_id option;
  reason_text : string;
}
[@@deriving show, eq]

(* Schema constants for [<table id="changes">]: 6 [<td>] cells per data row,
   2 leading [<tr>] rows that are column headers (outer + inner sub-header). *)
let _expected_cell_count = 6
let _header_row_count = 2

let _sup_re =
  Re.compile (Re.Pcre.re ~flags:[ `CASELESS; `DOTALL ] "<sup\\b[^>]*>.*?</sup>")

let _tag_re = Re.compile (Re.Pcre.re "<[^>]+>")
let _whitespace_re = Re.compile (Re.Pcre.re "\\s+")

(* Decode the HTML entities actually observed in the changes table: named
   ([&amp;], [&apos;], [&quot;], [&nbsp;], [&lt;], [&gt;]) plus numeric
   character references for any decimal codepoint < 256. Anything else is
   passed through unchanged. *)
let _named_entities =
  [
    ("&amp;", "&");
    ("&apos;", "'");
    ("&quot;", "\"");
    ("&nbsp;", " ");
    ("&lt;", "<");
    ("&gt;", ">");
  ]

let _numeric_entity_re = Re.compile (Re.Pcre.re "&#([0-9]+);")

let _decode_entities s =
  let s =
    List.fold _named_entities ~init:s ~f:(fun acc (entity, replacement) ->
        String.substr_replace_all acc ~pattern:entity ~with_:replacement)
  in
  Re.replace _numeric_entity_re s ~f:(fun groups ->
      let code = Int.of_string (Re.Group.get groups 1) in
      if code < 256 then String.make 1 (Char.of_int_exn code)
      else Re.Group.get groups 0)

(* Drop [<sup>...</sup>] blocks (footnote markers), strip remaining tags,
   decode entities, collapse whitespace runs to a single space, and trim. *)
let _normalize_text raw =
  let no_sup = Re.replace_string _sup_re ~by:"" raw in
  let no_tags = Re.replace_string _tag_re ~by:"" no_sup in
  let decoded = _decode_entities no_tags in
  let collapsed = Re.replace_string _whitespace_re ~by:" " decoded in
  String.strip collapsed

let _td_re =
  Re.compile (Re.Pcre.re ~flags:[ `CASELESS; `DOTALL ] "<td\\b[^>]*>(.*?)</td>")

let _extract_td_cells row_html =
  Re.all _td_re row_html |> List.map ~f:(fun groups -> Re.Group.get groups 1)

(* Split table HTML into [<tr>...</tr>] blocks. Wikipedia sometimes omits
   the closing [</tr>], so we split on [<tr>] opens and recover each block
   as "from this open up to the next [<tr>] open (or end of table)". *)
let _tr_open_re = Re.compile (Re.Pcre.re ~flags:[ `CASELESS ] "<tr\\b[^>]*>")

let _split_into_rows table_html =
  let positions =
    Re.all _tr_open_re table_html
    |> List.map ~f:(fun groups ->
        let _, stop = Re.Group.offset groups 0 in
        stop)
  in
  let table_len = String.length table_html in
  let ends = (List.tl positions |> Option.value ~default:[]) @ [ table_len ] in
  List.map2_exn positions ends ~f:(fun start stop ->
      String.sub table_html ~pos:start ~len:(stop - start))

(* "Effective Date" cells render as e.g. "March 23, 2026" or "July 1, 1976";
   we accept any full month name, optional comma, and a 4-digit year. *)
let _date_re =
  Re.compile
    (Re.Pcre.re ~flags:[ `CASELESS ]
       "([A-Za-z]+)\\s+([0-9]{1,2}),?\\s+([0-9]{4})")

let _months =
  [
    ("january", Month.Jan);
    ("february", Month.Feb);
    ("march", Month.Mar);
    ("april", Month.Apr);
    ("may", Month.May);
    ("june", Month.Jun);
    ("july", Month.Jul);
    ("august", Month.Aug);
    ("september", Month.Sep);
    ("october", Month.Oct);
    ("november", Month.Nov);
    ("december", Month.Dec);
  ]

let _month_of_string month =
  List.Assoc.find _months ~equal:String.equal (String.lowercase month)

let _parse_date text =
  match Re.exec_opt _date_re text with
  | None ->
      Status.error_invalid_argument
        (Printf.sprintf "Cannot parse effective date: %S" text)
  | Some groups -> (
      let month_str = Re.Group.get groups 1 in
      let day = Int.of_string (Re.Group.get groups 2) in
      let year = Int.of_string (Re.Group.get groups 3) in
      match _month_of_string month_str with
      | None ->
          Status.error_invalid_argument
            (Printf.sprintf "Unknown month %S in date %S" month_str text)
      | Some m -> Ok (Date.create_exn ~y:year ~m ~d:day))

(* Empty ticker cell → [None] for the whole pair. The security cell may
   carry an [<a>] link or plain text; [_normalize_text] handles both. *)
let _build_ticker_id ~ticker_cell ~security_cell =
  let symbol = _normalize_text ticker_cell in
  if String.is_empty symbol then None
  else
    let security_name = _normalize_text security_cell in
    Some { symbol; security_name }

let _parse_row row_html =
  let cells = _extract_td_cells row_html in
  if List.length cells <> _expected_cell_count then
    Status.error_invalid_argument
      (Printf.sprintf "Expected %d <td> cells, got %d in row"
         _expected_cell_count (List.length cells))
  else
    let cell i = List.nth_exn cells i in
    let date_text = _normalize_text (cell 0) in
    let added =
      _build_ticker_id ~ticker_cell:(cell 1) ~security_cell:(cell 2)
    in
    let removed =
      _build_ticker_id ~ticker_cell:(cell 3) ~security_cell:(cell 4)
    in
    let reason_text = _normalize_text (cell 5) in
    let%map.Result effective_date = _parse_date date_text in
    { effective_date; added; removed; reason_text }

let _table_re =
  Re.compile
    (Re.Pcre.re ~flags:[ `CASELESS; `DOTALL ]
       "<table\\b[^>]*id=\"changes\"[^>]*>(.*?)</table>")

let _extract_changes_table html =
  match Re.exec_opt _table_re html with
  | Some groups -> Ok (Re.Group.get groups 1)
  | None ->
      Status.error_invalid_argument
        "Could not locate <table id=\"changes\"> in input HTML"

let parse html =
  let%bind.Result table_html = _extract_changes_table html in
  let rows = _split_into_rows table_html in
  let data_rows = List.drop rows _header_row_count in
  let parsed_rows = List.map data_rows ~f:(fun row -> _parse_row row) in
  Result.all parsed_rows
