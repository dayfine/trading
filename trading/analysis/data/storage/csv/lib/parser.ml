open Core

let parse_date (str : string) : Date.t =
  try Date.of_string str
  with _ ->
    raise (Invalid_argument "Invalid date format, expected YYYY-MM-DD")

let _parse_optional_date_field (str : string) : Date.t option =
  let trimmed = String.strip str in
  if String.is_empty trimmed then None else Some (parse_date trimmed)

let _build_price ?(active_through = None) date_str open_str high_str low_str
    close_str adj_close_str volume_str : Types.Daily_price.t =
  {
    date = parse_date date_str;
    open_price = float_of_string open_str;
    high_price = float_of_string high_str;
    low_price = float_of_string low_str;
    close_price = float_of_string close_str;
    adjusted_close = float_of_string adj_close_str;
    volume = int_of_string volume_str;
    active_through;
  }

let _build_price_result ?(active_through = None) date_str open_str high_str
    low_str close_str adj_close_str volume_str line =
  try
    Ok
      (_build_price ~active_through date_str open_str high_str low_str close_str
         adj_close_str volume_str)
  with
  | Invalid_argument msg -> Error msg
  | Failure _ -> Error ("Invalid number in line: " ^ line)

let parse_line (line : string) : (Types.Daily_price.t, string) Result.t =
  let parts = String.split_on_chars ~on:[ ',' ] line in
  match parts with
  | [
   date_str; open_str; high_str; low_str; close_str; adj_close_str; volume_str;
  ] ->
      (* Legacy 7-column rows: active_through defaults to None. *)
      _build_price_result date_str open_str high_str low_str close_str
        adj_close_str volume_str line
  | [
   date_str;
   open_str;
   high_str;
   low_str;
   close_str;
   adj_close_str;
   volume_str;
   active_through_str;
  ] -> (
      try
        let active_through = _parse_optional_date_field active_through_str in
        _build_price_result ~active_through date_str open_str high_str low_str
          close_str adj_close_str volume_str line
      with Invalid_argument msg -> Error msg)
  | _ -> Error ("Expected 7 or 8 columns, line: " ^ line)

let parse_lines (lines : string list) :
    Types.Daily_price.t list Status.status_or =
  if List.is_empty lines then Status.error_invalid_argument "Empty file"
  else
    (* Skip header *)
    List.tl_exn lines
    |> List.map ~f:(fun line ->
        match parse_line line with
        | Ok price -> Ok price
        | Error msg -> Status.error_invalid_argument msg)
    |> Result.all
