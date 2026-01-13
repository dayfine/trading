(** Storage backend implementation *)

open Core

type t = {
  data_dir : Fpath.t;
  cache : (string, Types.Daily_price.t list) Hashtbl.t;
}

let create ~data_dir = { data_dir; cache = Hashtbl.create (module String) }

let _load_symbol t symbol =
  match Csv.Csv_storage.create ~data_dir:t.data_dir symbol with
  | Error err -> Error err
  | Ok storage -> (
      match Csv.Csv_storage.get storage () with
      | Error err -> Error err
      | Ok prices ->
          Hashtbl.set t.cache ~key:symbol ~data:prices;
          Ok prices)

let _filter_by_date_range prices ~start_date ~end_date =
  List.filter prices ~f:(fun (price : Types.Daily_price.t) ->
      let date_ok_start =
        match start_date with
        | None -> true
        | Some start -> Date.(price.date >= start)
      in
      let date_ok_end =
        match end_date with None -> true | Some end_ -> Date.(price.date <= end_)
      in
      date_ok_start && date_ok_end)

let get_prices t ~symbol ?start_date ?end_date () =
  (* Check cache first *)
  let%bind.Result prices =
    match Hashtbl.find t.cache symbol with
    | Some cached -> Ok cached
    | None -> _load_symbol t symbol
  in
  (* Filter by date range *)
  let filtered = _filter_by_date_range prices ~start_date ~end_date in
  Ok filtered

let preload_symbols t symbols =
  let results =
    List.map symbols ~f:(fun symbol ->
        match _load_symbol t symbol with
        | Ok _ -> Ok ()
        | Error err -> Error (symbol, err))
  in
  let errors =
    List.filter_map results ~f:(fun result ->
        match result with Error e -> Some e | Ok () -> None)
  in
  if List.is_empty errors then Ok ()
  else
    let error_messages =
      List.map errors ~f:(fun (symbol, err) ->
          Printf.sprintf "%s: %s" symbol err.message)
      |> String.concat ~sep:"; "
    in
    Error
      (Status.internal_error
         (Printf.sprintf "Failed to load symbols: %s" error_messages))

let clear_cache t = Hashtbl.clear t.cache

let get_cached_symbols t = Hashtbl.keys t.cache
