open Core

type daily_return = {
  date : Date.t;
  industry_returns : (string * float option) list;
}
[@@deriving show, eq]

type series = { industries : string list; observations : daily_return list }
[@@deriving show, eq]

type parsed = { value_weighted : series; equal_weighted : series }
[@@deriving show, eq]

(* Canonical ZIP URIs on the Dartmouth/Tuck server. Both datasets share the
   same two-block file shape — only the column count differs (5 vs 49) and the
   inflated size (5-Industry ~2.6 MB; 49-Industry ~20 MB). Updated monthly
   alongside the rest of Kenneth French's data library. *)
let _source_uri_5industry_str =
  "https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/ftp/5_Industry_Portfolios_daily_CSV.zip"

let _source_uri_49industry_str =
  "https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/ftp/49_Industry_Portfolios_daily_CSV.zip"

let source_uri_5industry = Uri.of_string _source_uri_5industry_str
let source_uri_49industry = Uri.of_string _source_uri_49industry_str

(* Compatibility alias for the original single-URI export. New callers should
   prefer [source_uri_5industry]; this binding stays so the existing bin layer
   keeps building unchanged. *)
let source_uri = source_uri_5industry

(* Pinned block-header strings as they appear in the source CSV. Any drift
   here indicates an upstream schema change and is a load-bearing failure
   ({!parse} returns [Error _]). The leading two spaces are part of the
   source; we match verbatim after light stripping. *)
let _vw_block_header = "Average Value Weighted Returns -- Daily"
let _ew_block_header = "Average Equal Weighted Returns -- Daily"

(* Missing-data sentinels per the file's preamble. Both observed in the
   wider French datasets even though the 5-Industry daily has none in
   practice — the parser still maps them to [None] to honor the documented
   contract. *)
let _sentinel_neg_99_99 = -99.99
let _sentinel_neg_999_99 = -999.99
let _sentinel_epsilon = 1e-9

let _is_sentinel f =
  Float.(abs (f - _sentinel_neg_99_99) < _sentinel_epsilon)
  || Float.(abs (f - _sentinel_neg_999_99) < _sentinel_epsilon)

let _optional_of_sentinel f = if _is_sentinel f then None else Some f

(* The file uses [YYYYMMDD] with no separators (e.g. [19260701]). [Date.t]
   does not auto-parse that shape, so we slice + recombine. *)
let _parse_yyyymmdd raw =
  let trimmed = String.strip raw in
  if String.length trimmed <> 8 then
    Status.error_invalid_argument
      (Printf.sprintf "kenneth_french: unparseable date %S (expected YYYYMMDD)"
         raw)
  else
    try
      let y = Int.of_string (String.sub trimmed ~pos:0 ~len:4) in
      let m = Int.of_string (String.sub trimmed ~pos:4 ~len:2) in
      let d = Int.of_string (String.sub trimmed ~pos:6 ~len:2) in
      Ok (Date.create_exn ~y ~m:(Month.of_int_exn m) ~d)
    with _ ->
      Status.error_invalid_argument
        (Printf.sprintf "kenneth_french: unparseable date %S" raw)

let _parse_float ~column raw =
  let trimmed = String.strip raw in
  match Float.of_string trimmed with
  | f -> Ok f
  | exception _ ->
      Status.error_invalid_argument
        (Printf.sprintf "kenneth_french: unparseable %s value %S" column trimmed)

let _strip_bom s =
  let bom = "\xEF\xBB\xBF" in
  if String.is_prefix s ~prefix:bom then
    String.drop_prefix s (String.length bom)
  else s

(* Some preamble / footer lines start with whitespace and contain plain
   text. Data rows always start with an 8-digit YYYYMMDD; the industry
   header always starts with a comma. We use those two patterns to
   distinguish "structural" lines from "data" lines without baking in
   row-count expectations (which drift monthly). *)
let _is_blank_line line = String.is_empty (String.strip line)
let _is_industry_header line = String.is_prefix (String.strip line) ~prefix:","

(* A "data row" is any non-blank line that carries commas and is not the
   industry header. We do not require the first 8 chars to be digits — if
   the line shape says "data row" but the date is malformed, parse_row
   will raise the unparseable-date error rather than silently terminating
   the block. *)
let _is_data_row line =
  let trimmed = String.strip line in
  (not (String.is_empty trimmed))
  && (not (_is_industry_header line))
  && String.contains trimmed ','

(* The industry header is comma-prefixed (the first column is "date" which
   the source leaves blank). We strip the leading comma and split. *)
let _parse_industry_header line =
  let stripped = String.strip line in
  match String.lsplit2 stripped ~on:',' with
  | None | Some ("", "") ->
      Status.error_invalid_argument
        (Printf.sprintf "kenneth_french: malformed industry header %S" line)
  | Some (_, rest) ->
      let names =
        String.split rest ~on:',' |> List.map ~f:String.strip
        |> List.filter ~f:(fun s -> not (String.is_empty s))
      in
      if List.is_empty names then
        Status.error_invalid_argument
          (Printf.sprintf "kenneth_french: empty industry header %S" line)
      else Ok names

let _column_count_error ~line_num ~raw_line ~got ~expected =
  Status.error_invalid_argument
    (Printf.sprintf
       "kenneth_french: line %d has %d columns (expected %d incl. date): %S"
       line_num got expected raw_line)

(* Apply [_parse_float] across the parallel-aligned ([industry], [cell])
   pairs, short-circuiting on the first parse failure. *)
let _parse_value_cells ~industries cells =
  List.map2_exn industries cells ~f:(fun col raw ->
      _parse_float ~column:col raw)
  |> Result.all

let _zip_industry_returns industries values =
  List.map2_exn industries values ~f:(fun col v ->
      (col, _optional_of_sentinel v))

(* Build an observation from the already-split row (date string + value
   cells); industry-count agreement is the caller's responsibility. *)
let _build_observation ~industries ~date_s ~value_cells :
    daily_return Status.status_or =
  let open Result.Let_syntax in
  let%bind date = _parse_yyyymmdd date_s in
  let%bind values = _parse_value_cells ~industries value_cells in
  Ok { date; industry_returns = _zip_industry_returns industries values }

let _parse_row ~industries ~line_num raw_line : daily_return Status.status_or =
  let fields = String.split raw_line ~on:',' in
  let expected = 1 + List.length industries in
  let got = List.length fields in
  if got <> expected then _column_count_error ~line_num ~raw_line ~got ~expected
  else
    match fields with
    | date_s :: value_cells ->
        _build_observation ~industries ~date_s ~value_cells
    | [] ->
        Status.error_internal
          (Printf.sprintf "kenneth_french: empty split on line %d" line_num)

(* Scan forward over the prepared (1-based-numbered) lines until we find a
   line whose stripped content equals the expected block header. Returns
   the remaining suffix (after the block header). *)
let _seek_block_header ~header lines =
  let rec aux = function
    | [] ->
        Status.error_invalid_argument
          (Printf.sprintf "kenneth_french: missing block header %S" header)
    | (_, line) :: rest ->
        if String.equal (String.strip line) header then Ok rest else aux rest
  in
  aux lines

let _industry_header_eof_error =
  Status.error_invalid_argument
    "kenneth_french: missing industry header after block header"

let _unexpected_line_error ~line_num ~line =
  Status.error_invalid_argument
    (Printf.sprintf
       "kenneth_french: expected industry header on line %d, got %S" line_num
       line)

let _parse_industry_header_and_rest line rest =
  Result.map (_parse_industry_header line) ~f:(fun industries ->
      (industries, rest))

(* After the block header, the next non-blank line should be the industry
   header. Skip blanks, validate the industry header, and return the
   industry list + the remaining (numbered) lines. *)
let _expect_industry_header lines =
  let rec aux = function
    | [] -> _industry_header_eof_error
    | (_, line) :: rest when _is_blank_line line -> aux rest
    | (_, line) :: rest when _is_industry_header line ->
        _parse_industry_header_and_rest line rest
    | (line_num, line) :: _ -> _unexpected_line_error ~line_num ~line
  in
  aux lines

(* Consume contiguous data rows (any row whose first 8 chars are digits)
   until we hit either EOF, a blank line, or a non-data line. Returns the
   parsed observations + the remaining lines (caller decides what to do
   with them — for VW we re-seek the EW header; for EW we tolerate the
   copyright footer). *)
let _consume_data_rows ~industries lines =
  let rec aux acc = function
    | [] -> Ok (List.rev acc, [])
    | (_, line) :: rest when _is_blank_line line -> Ok (List.rev acc, rest)
    | (line_num, line) :: rest when _is_data_row line -> (
        match _parse_row ~industries ~line_num line with
        | Error _ as e -> e
        | Ok obs -> aux (obs :: acc) rest)
    | (_, _) :: _ as remaining ->
        (* Non-data, non-blank line — end of block. *)
        Ok (List.rev acc, remaining)
  in
  aux [] lines

let _parse_one_block ~header lines =
  let open Result.Let_syntax in
  let%bind after_block_header = _seek_block_header ~header lines in
  let%bind industries, after_industry_header =
    _expect_industry_header after_block_header
  in
  let%bind observations, remainder =
    _consume_data_rows ~industries after_industry_header
  in
  Ok ({ industries; observations }, remainder)

let _validate_industries_agree ~vw ~ew =
  if List.equal String.equal vw.industries ew.industries then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf
         "kenneth_french: industry mismatch between VW and EW blocks (VW=[%s] \
          EW=[%s])"
         (String.concat ~sep:"," vw.industries)
         (String.concat ~sep:"," ew.industries))

let parse body : parsed Status.status_or =
  let raw = _strip_bom body in
  let lines = String.split_lines raw in
  if List.for_all lines ~f:_is_blank_line then
    Status.error_invalid_argument "kenneth_french: empty body"
  else
    let numbered = List.mapi lines ~f:(fun i l -> (i + 1, l)) in
    let open Result.Let_syntax in
    let%bind value_weighted, after_vw =
      _parse_one_block ~header:_vw_block_header numbered
    in
    let%bind equal_weighted, _ =
      _parse_one_block ~header:_ew_block_header after_vw
    in
    let%bind () =
      _validate_industries_agree ~vw:value_weighted ~ew:equal_weighted
    in
    Ok { value_weighted; equal_weighted }
