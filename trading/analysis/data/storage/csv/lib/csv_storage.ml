open Core

let validate_prices prices =
  let rec check_sorted_and_unique prev = function
    | [] -> Ok ()
    | price :: rest ->
        let curr = price.Types.Daily_price.date in
        if Date.compare curr prev <= 0 then
          Error
            (Status.invalid_argument_error
               "Prices must be sorted by date in ascending order and contain \
                no duplicates")
        else check_sorted_and_unique curr rest
  in
  match prices with
  | [] -> Ok ()
  | first :: rest -> check_sorted_and_unique first.Types.Daily_price.date rest

type t = { path : string }

let write_price oc price =
  let open Types.Daily_price in
  let date = Date.to_string price.date in
  let open_price = Float.to_string price.open_price in
  let high_price = Float.to_string price.high_price in
  let low_price = Float.to_string price.low_price in
  let close_price = Float.to_string price.close_price in
  let adjusted_close = Float.to_string price.adjusted_close in
  let volume = Int.to_string price.volume in
  Out_channel.output_string oc
    (String.concat ~sep:","
       [
         date;
         open_price;
         high_price;
         low_price;
         close_price;
         adjusted_close;
         volume;
       ]);
  Out_channel.newline oc

let default_data_dir = Fpath.v "data"

let create ?(data_dir = default_data_dir) symbol =
  let path = Fpath.(data_dir / symbol |> add_ext "csv") in
  Ok { path = Fpath.to_string path }

let save t ~override prices =
  let open Result.Let_syntax in
  let%bind () = validate_prices prices in
  let exists = Sys_unix.file_exists t.path in
  if phys_equal exists `Yes && not override then
    Error
      (Status.invalid_argument_error "File already exists and override is false")
  else
    let oc = Out_channel.create t.path in
    Exn.protect
      ~f:(fun () ->
        Out_channel.output_string oc
          "date,open,high,low,close,adjusted_close,volume\n";
        List.iter ~f:(write_price oc) prices;
        Ok ())
      ~finally:(fun () -> Out_channel.close oc)
    |> Result.map_error ~f:(fun e ->
           Status.permission_denied_error
             (sprintf "Failed to write file: %s" (Exn.to_string e)))

let get t ?start_date ?end_date () =
  let open Result.Let_syntax in
  let%bind prices =
    In_channel.read_lines t.path |> Parser.parse_lines |> Result.all
  in
  match (start_date, end_date) with
  | Some start, Some end_ when Date.compare start end_ > 0 ->
      Error
        (Status.invalid_argument_error
           "start_date must be before or equal to end_date")
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
      Ok filtered_prices
