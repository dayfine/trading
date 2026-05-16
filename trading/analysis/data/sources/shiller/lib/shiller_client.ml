open Core

type monthly_observation = {
  period : Date.t;
  sp_price : float;
  dividend : float option;
  earnings : float option;
  cpi : float option;
  long_rate : float option;
}
[@@deriving show, eq]

type series = { observations : monthly_observation list } [@@deriving show, eq]

(* The canonical [datasets/s-and-p-500] mirror, served as raw text from
   GitHub. The mirror's [data/data.csv] is regenerated from Shiller's
   [ie_data] spreadsheet on every monthly update (see the repo README at
   https://github.com/datasets/s-and-p-500). We pin the [master] branch
   because the mirror has not had a release tag in years. *)
let _source_uri_str =
  "https://raw.githubusercontent.com/datasets/s-and-p-500/master/data/data.csv"

let source_uri = Uri.of_string _source_uri_str

(* The 10-column header as it appears in the mirror CSV. Pinned verbatim:
   any drift indicates upstream schema change and is a load-bearing failure
   ({!parse} returns [Error _]). *)
let _expected_header =
  "Date,SP500,Dividend,Earnings,Consumer Price Index,Long Interest Rate,Real \
   Price,Real Dividend,Real Earnings,PE10"

let _expected_column_count = 10
let _sentinel_zero = 0.0

(* Mirror dates are YYYY-MM-DD, anchored on the 1st of the month. We accept
   any DD because we don't strip the value before forwarding to Date — but
   we never observed anything other than 01 in 155 years of data. *)
let _parse_date raw =
  match Date.of_string raw with
  | d -> Ok d
  | exception _ ->
      Status.error_invalid_argument
        (Printf.sprintf "shiller_client: unparseable date %S" raw)

let _parse_float ~column raw =
  match Float.of_string raw with
  | f -> Ok f
  | exception _ ->
      Status.error_invalid_argument
        (Printf.sprintf "shiller_client: unparseable %s value %S" column raw)

(* The mirror emits [0.0] as a sentinel for "not yet released" in the four
   fundamental columns. Map that to [None] so callers cannot accidentally
   treat a not-yet-published month as a zero-dividend / zero-CPI month. The
   price column never carries a zero in the mirror and gets the raw float. *)
let _optional_of_sentinel f =
  if Float.equal f _sentinel_zero then None else Some f

let _parse_observation ~date_s ~price_s ~div_s ~earn_s ~cpi_s ~rate_s :
    monthly_observation Status.status_or =
  let open Result.Let_syntax in
  let%bind period = _parse_date date_s in
  let%bind sp_price = _parse_float ~column:"SP500" price_s in
  let%bind dividend = _parse_float ~column:"Dividend" div_s in
  let%bind earnings = _parse_float ~column:"Earnings" earn_s in
  let%bind cpi = _parse_float ~column:"Consumer Price Index" cpi_s in
  let%bind long_rate = _parse_float ~column:"Long Interest Rate" rate_s in
  Ok
    {
      period;
      sp_price;
      dividend = _optional_of_sentinel dividend;
      earnings = _optional_of_sentinel earnings;
      cpi = _optional_of_sentinel cpi;
      long_rate = _optional_of_sentinel long_rate;
    }

let _column_count_error line_num raw_line n =
  Status.error_invalid_argument
    (Printf.sprintf "shiller_client: line %d has %d columns (expected %d): %S"
       line_num n _expected_column_count raw_line)

(* Defensive branch: [List.length = _expected_column_count] above implies the
   destructuring is total, but the compiler can't prove that statically. *)
let _unreachable_destructure_error line_num =
  Status.error_internal
    (Printf.sprintf "shiller_client: unreachable destructure on line %d"
       line_num)

let _parse_row line_num raw_line : monthly_observation Status.status_or =
  let fields = String.split raw_line ~on:',' in
  let n = List.length fields in
  if n <> _expected_column_count then _column_count_error line_num raw_line n
  else
    match fields with
    | [
     date_s;
     price_s;
     div_s;
     earn_s;
     cpi_s;
     rate_s;
     _real_p;
     _real_d;
     _real_e;
     _pe10;
    ] ->
        _parse_observation ~date_s ~price_s ~div_s ~earn_s ~cpi_s ~rate_s
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
      (Printf.sprintf "shiller_client: header drift — expected %S, got %S"
         _expected_header stripped)

let parse body : series Status.status_or =
  let lines = _split_nonempty_lines body in
  match lines with
  | [] -> Status.error_invalid_argument "shiller_client: empty body"
  | header :: data_lines ->
      let open Result.Let_syntax in
      let%bind () = _validate_header header in
      let%bind observations =
        List.mapi data_lines ~f:(fun i line -> _parse_row (i + 2) line)
        |> Result.all
      in
      Ok { observations }
