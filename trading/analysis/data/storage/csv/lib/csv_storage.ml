open Core
open Result.Let_syntax
open Bos

let _not_sorted_error =
  Status.invalid_argument_error
    "Prices must be sorted by date in ascending order and contain no duplicates"

let rec _check_sorted_and_unique prev = function
  | [] -> Ok ()
  | price :: rest ->
      let curr = price.Types.Daily_price.date in
      if Date.compare curr prev <= 0 then Error _not_sorted_error
      else _check_sorted_and_unique curr rest

let _validate_prices prices =
  match prices with
  | [] -> Ok ()
  | first :: rest -> _check_sorted_and_unique first.Types.Daily_price.date rest

let _write_price oc price =
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

let _default_data_dir = Fpath.v (Sys_unix.getcwd () ^ "/data")

let _create_symbol_dirs data_dir symbol =
  if String.is_empty symbol then
    Status.error_invalid_argument "Symbol cannot be empty"
  else
    let first_char = String.get symbol 0 in
    let last_char = String.get symbol (String.length symbol - 1) in
    let dir_path =
      Fpath.(
        data_dir / String.make 1 first_char / String.make 1 last_char / symbol)
    in
    match OS.Dir.exists dir_path with
    | Ok true -> Ok dir_path
    | Ok false -> (
        match OS.Dir.create ~path:true dir_path with
        | Ok _ -> Ok dir_path
        | Error (`Msg msg) -> Status.error_internal msg)
    | Error (`Msg msg) -> Status.error_internal msg

let _write_prices_to_file path prices =
  let oc = Stdlib.open_out path in
  Exn.protect
    ~f:(fun () ->
      Out_channel.output_string oc
        "date,open,high,low,close,adjusted_close,volume\n";
      List.iter ~f:(_write_price oc) prices;
      Ok ())
    ~finally:(fun () -> Out_channel.close oc)
  |> Result.map_error ~f:(fun e ->
      Status.internal_error
        (sprintf "Failed to write file: %s" (Exn.to_string e)))

let _append_prices_to_file path prices =
  let oc = Stdlib.open_out_gen [ Open_append ] 0o666 path in
  Exn.protect
    ~f:(fun () ->
      List.iter ~f:(_write_price oc) prices;
      Ok ())
    ~finally:(fun () -> Out_channel.close oc)
  |> Result.map_error ~f:(fun e ->
      Status.internal_error
        (sprintf "Failed to write file: %s" (Exn.to_string e)))

let _price_map_of_list prices =
  List.fold prices ~init:Date.Map.empty ~f:(fun acc p ->
      Map.set acc ~key:p.Types.Daily_price.date ~data:p)

let _merge_price_into_map ~override_old_price map p =
  match Map.find map p.Types.Daily_price.date with
  | Some old_price when not (Poly.equal old_price p) ->
      if override_old_price then
        Ok (Map.set map ~key:p.Types.Daily_price.date ~data:p)
      else
        Status.error_invalid_argument
          "Cannot save data with overlapping dates and different values"
  | Some _ -> Ok map
  | None -> Ok (Map.set map ~key:p.Types.Daily_price.date ~data:p)

let _fold_merge_prices ~override_old_price price_map new_prices =
  List.fold new_prices ~init:(Ok price_map) ~f:(fun acc p ->
      match acc with
      | Error _ as e -> e
      | Ok map -> _merge_price_into_map ~override_old_price map p)

let _merge_prices ~override_old_price old_prices new_prices =
  let price_map = _price_map_of_list old_prices in
  let%bind updated_map =
    _fold_merge_prices ~override_old_price price_map new_prices
  in
  Ok
    (List.sort
       ~compare:(fun a b ->
         Date.compare a.Types.Daily_price.date b.Types.Daily_price.date)
       (Map.data updated_map))

(* Compare date ranges of two sorted price lists.
   Returns:
   - `Before` if new prices are before old prices
   - `After` if new prices are after old prices
   - `Overlapping` if there is any overlap
   - `Empty` if either list is empty *)
type date_range = Before | After | Overlapping | Empty

let _date_of p = p.Types.Daily_price.date

let _compare_date_ranges old_prices new_prices =
  match (old_prices, new_prices) with
  | [], _ | _, [] -> Empty
  | _ ->
      let old_first = _date_of (List.hd_exn old_prices) in
      let old_last = _date_of (List.last_exn old_prices) in
      let new_first = _date_of (List.hd_exn new_prices) in
      let new_last = _date_of (List.last_exn new_prices) in
      if Date.compare new_last old_first < 0 then Before
      else if Date.compare old_last new_first < 0 then After
      else Overlapping

let _handle_existing_and_new_prices path ~override existing_prices new_prices =
  if override || List.is_empty existing_prices then
    let%bind merged =
      _merge_prices ~override_old_price:true existing_prices new_prices
    in
    _write_prices_to_file path merged
  else
    match _compare_date_ranges existing_prices new_prices with
    | Empty | After -> _append_prices_to_file path new_prices
    | Before ->
        Status.error_invalid_argument
          "Cannot save data with dates before existing data"
    | Overlapping ->
        let%bind merged =
          _merge_prices ~override_old_price:false existing_prices new_prices
        in
        _write_prices_to_file path merged

type t = { path : string }

let create ?(data_dir = _default_data_dir) symbol =
  let%bind symbol_dir = _create_symbol_dirs data_dir symbol in
  let path = Fpath.(symbol_dir / "data.csv") in
  Ok { path = Fpath.to_string path }

let _in_date_range ~start_date ~end_date (price : Types.Daily_price.t) =
  let date = price.date in
  let after_start =
    match start_date with None -> true | Some s -> Date.compare date s >= 0
  in
  let before_end =
    match end_date with None -> true | Some e -> Date.compare date e <= 0
  in
  after_start && before_end

let get t ?start_date ?end_date () =
  let open Result.Let_syntax in
  (* Check if file exists before trying to read *)
  let%bind lines =
    match Sys_unix.file_exists t.path with
    | `Yes -> (
        try Ok (In_channel.read_lines t.path)
        with Sys_error msg -> Status.error_not_found msg)
    | `No | `Unknown ->
        Status.error_not_found (Printf.sprintf "Data file not found: %s" t.path)
  in
  let%bind prices = Parser.parse_lines lines in
  match (start_date, end_date) with
  | Some start, Some end_ when Date.compare start end_ > 0 ->
      Status.error_invalid_argument
        "start_date must be before or equal to end_date"
  | _ -> Ok (List.filter prices ~f:(_in_date_range ~start_date ~end_date))

let save t ?(override = false) prices =
  let open Result.Let_syntax in
  let%bind () = _validate_prices prices in
  let exists = Sys_unix.file_exists t.path in
  if phys_equal exists `Yes then
    let%bind existing_prices = get t () in
    _handle_existing_and_new_prices t.path ~override existing_prices prices
  else _write_prices_to_file t.path prices
