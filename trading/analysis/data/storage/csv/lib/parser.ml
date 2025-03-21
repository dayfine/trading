open Core

let parse_date str =
  try
    Scanf.sscanf str "%d-%d-%d" (fun year month day ->
        Date.create_exn ~y:year ~m:(Month.of_int_exn month) ~d:day)
  with _ ->
    raise (Invalid_argument "Invalid date format, expected YYYY-MM-DD")

let parse_line line =
  let parts = String.split_on_chars ~on:[ ';' ] line in
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
