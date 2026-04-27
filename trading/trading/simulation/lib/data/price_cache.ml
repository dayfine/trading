(** Multi-symbol price cache implementation *)

open Core

type t = {
  data_dir : Fpath.t;
  cache : (string, Types.Daily_price.t list) Hashtbl.t;
  (* Date-indexed lookup table per symbol, built lazily on first
     [get_price_on_date] call. Lets the per-tick hot path (one
     [get_price] per (symbol, day)) avoid the [List.filter] +
     [List.find] scan that allocates a fresh list per call. *)
  by_date : (string, (Date.t, Types.Daily_price.t) Hashtbl.t) Hashtbl.t;
}

let create ~data_dir =
  {
    data_dir;
    cache = Hashtbl.create (module String);
    by_date = Hashtbl.create (module String);
  }

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
        match end_date with
        | None -> true
        | Some end_ -> Date.(price.date <= end_)
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

(* Build (or fetch) the per-symbol date-indexed table. Returns [None] if
   the symbol's CSV failed to load (collapses the [Result] error path —
   callers that need the error use [get_prices] directly). *)
let _by_date_table t symbol : (Date.t, Types.Daily_price.t) Hashtbl.t option =
  match Hashtbl.find t.by_date symbol with
  | Some tbl -> Some tbl
  | None -> (
      let prices_result =
        match Hashtbl.find t.cache symbol with
        | Some cached -> Ok cached
        | None -> _load_symbol t symbol
      in
      match prices_result with
      | Error _ -> None
      | Ok prices ->
          let tbl = Hashtbl.create (module Date) in
          List.iter prices ~f:(fun (p : Types.Daily_price.t) ->
              Hashtbl.set tbl ~key:p.date ~data:p);
          Hashtbl.set t.by_date ~key:symbol ~data:tbl;
          Some tbl)

let get_price_on_date t ~symbol ~date =
  match _by_date_table t symbol with
  | None -> None
  | Some tbl -> Hashtbl.find tbl date

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

let clear_cache t =
  Hashtbl.clear t.cache;
  Hashtbl.clear t.by_date

let get_cached_symbols t = Hashtbl.keys t.cache
