open Types

let parse_date str =
  try
    Scanf.sscanf str "%d-%d-%d" (fun year month day ->
        let t = Unix.localtime (Unix.time ()) in
        { t with tm_year = year - 1900; tm_mon = month - 1; tm_mday = day })
  with _ ->
    raise (Invalid_argument "Invalid date format, expected YYYY-MM-DD")

let parse_line line =
  let parts = String.split_on_char ',' line in
  match parts with
  | [
   date_str; open_str; high_str; low_str; close_str; adj_close_str; volume_str;
  ] -> (
      try
        let date = parse_date date_str in
        let open_ = float_of_string open_str in
        let high = float_of_string high_str in
        let low = float_of_string low_str in
        let close = float_of_string close_str in
        let adjusted_close = float_of_string adj_close_str in
        let volume = int_of_string volume_str in
        Ok { date; open_; high; low; close; adjusted_close; volume }
      with
      | Invalid_argument msg -> Error (Invalid_date msg)
      | Failure _ -> Error (Invalid_number line))
  | _ -> Error (Invalid_csv_format ("Expected 7 columns, line: " ^ line))

let to_string data =
  Printf.sprintf "%04d-%02d-%02d,%.2f,%.2f,%.2f,%.2f,%.2f,%d"
    (data.date.tm_year + 1900) (data.date.tm_mon + 1) data.date.tm_mday
    data.open_ data.high data.low data.close data.adjusted_close data.volume
