open Types

let parse_line line =
  try
    match String.split_on_char ',' line with
    | [date_str; open_str; high_str; low_str; close_str; adj_close_str; volume_str] ->
        Ok {
          date = Date.parse date_str;
          open_price = float_of_string open_str;
          high = float_of_string high_str;
          low = float_of_string low_str;
          close = float_of_string close_str;
          adjusted_close = float_of_string adj_close_str;
          volume = int_of_string volume_str;
        }
    | _ ->
        Error (Printf.sprintf "Invalid CSV format: expected 7 columns, line: %s" line)
  with
  | Failure msg -> Error (Printf.sprintf "Error parsing line '%s': %s" line msg)
  | e -> Error (Printf.sprintf "Unexpected error parsing line '%s': %s" line (Printexc.to_string e))

let read_file filename =
  try
    let ic = open_in filename in
    let rec read_lines acc =
      try
        let line = input_line ic in
        if String.contains line 'D' then  (* Skip header *)
          read_lines acc
        else
          match parse_line line with
          | Ok data -> read_lines (data :: acc)
          | Error msg -> failwith msg
      with End_of_file ->
        close_in ic;
        List.rev acc  (* Return in chronological order *)
    in
    read_lines []
  with
  | Sys_error msg -> failwith (Printf.sprintf "Error reading file: %s" msg)
  | e ->
      failwith (Printf.sprintf "Unexpected error reading file: %s"
        (Printexc.to_string e))
