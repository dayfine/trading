open Core

type t = { path : string }

let create_with_path path = Ok { path }

let validate_prices prices =
  let rec check_sorted_and_unique prev = function
    | [] -> Ok ()
    | price :: rest ->
        if Date.compare price.Types.Daily_price.date prev <= 0 then
          Error
            { Status.code = Status.Invalid_argument;
              message =
                "Prices must be sorted by date in ascending order and contain \
                 no duplicates" }
        else check_sorted_and_unique price.Types.Daily_price.date rest
  in
  match prices with
  | [] -> Ok ()
  | first :: rest -> check_sorted_and_unique first.Types.Daily_price.date rest

let write_price oc price =
  let date = Date.to_string price.Types.Daily_price.date in
  let open_price = Float.to_string price.Types.Daily_price.open_price in
  let high_price = Float.to_string price.Types.Daily_price.high_price in
  let low_price = Float.to_string price.Types.Daily_price.low_price in
  let close_price = Float.to_string price.Types.Daily_price.close_price in
  let adjusted_close = Float.to_string price.Types.Daily_price.adjusted_close in
  let volume = Int.to_string price.Types.Daily_price.volume in
  Out_channel.output_string oc
    (String.concat ~sep:","
       [ date; open_price; high_price; low_price; close_price; adjusted_close; volume ]);
  Out_channel.newline oc

let create symbol =
  let path = Filename.concat "data" (symbol ^ ".csv") in
  Ok { path }

let save t ~override prices =
  match validate_prices prices with
  | Error status -> Error status
  | Ok () ->
      let exists = Sys_unix.file_exists t.path in
      if (phys_equal exists `Yes) && not override then
        Error
          { Status.code = Status.Invalid_argument;
            message = "File already exists and override is false" }
      else
        try
          let oc = Out_channel.create t.path in
          try
            (* Write header *)
            Out_channel.output_string oc
              "date,open,high,low,close,adjusted_close,volume\n";
            (* Write prices *)
            List.iter ~f:(write_price oc) prices;
            Out_channel.close oc;
            Ok ()
          with e ->
            Out_channel.close oc;
            Error
              { Status.code = Status.Internal;
                message = sprintf "Failed to write file: %s" (Exn.to_string e) }
        with e ->
          Error
            { Status.code = Status.Permission_denied;
              message = sprintf "Failed to create file: %s" (Exn.to_string e) }

let get_prices t ?start_date ?end_date () =
  match Parser.read_file t.path with
  | Error msg ->
      Error
        { Status.code = Status.NotFound;
          message = sprintf "Failed to read file: %s" msg }
  | Ok prices -> (
      match (start_date, end_date) with
      | Some start, Some end_ when Date.compare start end_ > 0 ->
          Error
            { Status.code = Status.Invalid_argument;
              message = "start_date must be before or equal to end_date" }
      | _ ->
          let filtered_prices =
            List.filter prices ~f:(fun price ->
                let date = price.Types.Daily_price.date in
                let after_start =
                  match start_date with
                  | None -> true
                  | Some start -> Date.compare date start >= 0
                in
                let before_end =
                  match end_date with
                  | None -> true
                  | Some end_ -> Date.compare date end_ <= 0
                in
                after_start && before_end)
          in
          Ok filtered_prices)

