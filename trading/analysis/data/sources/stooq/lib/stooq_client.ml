open Core

type daily_observation = {
  date : Date.t;
  open_ : float;
  high : float;
  low : float;
  close : float;
  volume : int;
}
[@@deriving show, eq]

type series = { observations : daily_observation list } [@@deriving show, eq]

(* Canonical Stooq CSV endpoint per
   [memory/reference_deep_history_data_sources.md] §Stooq. The [.us] suffix
   selects US-listed symbols; the [&i=d] cadence flag selects daily bars.
   Verified 2026-05-17 (probe documented in the .mli docstring). *)
let _base_url = "https://stooq.com/q/d/l/"
let _us_suffix = ".us"
let _expected_header = "Date,Open,High,Low,Close,Volume"
let _expected_column_count = 6
let _apikey_error_prefix = "Get your apikey:"
let _apikey_error_marker = "get_apikey"

let _parse_date raw =
  match Date.of_string raw with
  | d -> Ok d
  | exception _ ->
      Status.error_invalid_argument
        (Printf.sprintf "stooq_client: unparseable date %S" raw)

let _parse_float ~column raw =
  match Float.of_string raw with
  | f -> Ok f
  | exception _ ->
      Status.error_invalid_argument
        (Printf.sprintf "stooq_client: unparseable %s value %S" column raw)

let _parse_int ~column raw =
  match Int.of_string raw with
  | n -> Ok n
  | exception _ ->
      Status.error_invalid_argument
        (Printf.sprintf "stooq_client: unparseable %s value %S" column raw)

let _parse_observation ~date_s ~open_s ~high_s ~low_s ~close_s ~volume_s :
    daily_observation Status.status_or =
  let open Result.Let_syntax in
  let%bind date = _parse_date date_s in
  let%bind open_ = _parse_float ~column:"Open" open_s in
  let%bind high = _parse_float ~column:"High" high_s in
  let%bind low = _parse_float ~column:"Low" low_s in
  let%bind close = _parse_float ~column:"Close" close_s in
  let%bind volume = _parse_int ~column:"Volume" volume_s in
  Ok { date; open_; high; low; close; volume }

let _column_count_error line_num raw_line n =
  Status.error_invalid_argument
    (Printf.sprintf "stooq_client: line %d has %d columns (expected %d): %S"
       line_num n _expected_column_count raw_line)

(* Defensive branch: the [List.length = _expected_column_count] check above
   implies the destructuring is total, but the compiler can't prove it. *)
let _unreachable_destructure_error line_num =
  Status.error_internal
    (Printf.sprintf "stooq_client: unreachable destructure on line %d" line_num)

let _parse_row line_num raw_line : daily_observation Status.status_or =
  let fields = String.split raw_line ~on:',' in
  let n = List.length fields in
  if n <> _expected_column_count then _column_count_error line_num raw_line n
  else
    match fields with
    | [ date_s; open_s; high_s; low_s; close_s; volume_s ] ->
        _parse_observation ~date_s ~open_s ~high_s ~low_s ~close_s ~volume_s
    | _ -> _unreachable_destructure_error line_num

let _strip_bom s =
  let bom = "\xEF\xBB\xBF" in
  if String.is_prefix s ~prefix:bom then
    String.drop_prefix s (String.length bom)
  else s

let _split_nonempty_lines body =
  String.split_lines body
  |> List.filter ~f:(fun line -> not (String.is_empty (String.strip line)))

let _validate_header line =
  let stripped = _strip_bom line in
  if String.equal stripped _expected_header then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "stooq_client: header drift — expected %S, got %S"
         _expected_header stripped)

let parse body : series Status.status_or =
  let lines = _split_nonempty_lines body in
  match lines with
  | [] -> Status.error_invalid_argument "stooq_client: empty body"
  | header :: data_lines ->
      let open Result.Let_syntax in
      let%bind () = _validate_header header in
      let%bind observations =
        List.mapi data_lines ~f:(fun i line -> _parse_row (i + 2) line)
        |> Result.all
      in
      Ok { observations }

let build_uri ?apikey ~symbol () =
  let stooq_symbol = String.lowercase symbol ^ _us_suffix in
  let base_query = [ ("s", [ stooq_symbol ]); ("i", [ "d" ]) ] in
  let query =
    match apikey with
    | None -> base_query
    | Some key -> base_query @ [ ("apikey", [ key ]) ]
  in
  Uri.of_string _base_url |> fun u -> Uri.with_query u query

let is_apikey_error_body body =
  let stripped = String.strip (_strip_bom body) in
  String.is_prefix stripped ~prefix:_apikey_error_prefix
  && String.is_substring stripped ~substring:_apikey_error_marker
