open Core

let parse_date str =
  try Date.of_string str
  with _ ->
    raise (Invalid_argument "Invalid date format, expected YYYY-MM-DD")

let parse_line line =
  let parts = String.split_on_chars ~on:[ ',' ] line in
  match parts with
  | [
   date_str; open_str; high_str; low_str; close_str; adj_close_str; volume_str;
  ] -> (
      try
        let date = parse_date date_str in
        let open_price = float_of_string open_str in
        let high_price = float_of_string high_str in
        let low_price = float_of_string low_str in
        let close_price = float_of_string close_str in
        let adjusted_close = float_of_string adj_close_str in
        let volume = int_of_string volume_str in
        let price : Types.Daily_price.t =
          {
            date;
            open_price;
            high_price;
            low_price;
            close_price;
            volume;
            adjusted_close;
          }
        in
        Ok price
      with
      | Invalid_argument msg -> Error msg
      | Failure _ -> Error ("Invalid number in line: " ^ line))
  | _ -> Error ("Expected 7 columns, line: " ^ line)

let read_file filename =
  try
    let lines = In_channel.read_lines filename in
    let rec parse_lines acc = function
      | [] -> Ok (List.rev acc)
      | line :: rest -> (
          match parse_line line with
          | Ok price -> parse_lines (price :: acc) rest
          | Error msg -> Error msg)
    in
    match lines with
    | [] -> Ok []
    | header :: data_lines ->
        (* Try to parse header but ignore any errors *)
        let _ = parse_line header in
        parse_lines [] data_lines
  with
  | Sys_error msg -> Error ("Failed to read file: " ^ msg)
  | e -> Error ("Unexpected error: " ^ Exn.to_string e)
