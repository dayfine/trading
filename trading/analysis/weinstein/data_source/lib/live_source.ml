open Async
open Core
open Csv

type config = {
  token : string;
  data_dir : string;
  max_concurrent_requests : int;
}
[@@deriving show, eq]

let default_config ~token =
  { token; data_dir = "./data"; max_concurrent_requests = 20 }

(* Load bars from CSV cache for the given symbol; return empty list on miss *)
let _load_cached_bars data_dir symbol ~start_date ~end_date =
  match Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error _ -> Ok []
  | Ok storage -> Csv_storage.get storage ?start_date ?end_date ()

(* Write bars to the local CSV cache *)
let _save_bars_to_cache data_dir symbol bars =
  match Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> Error e
  | Ok storage -> Csv_storage.save storage ~override:true bars

(* Check if cached data is current: last bar is today or yesterday *)
let _cache_is_current bars =
  match List.last bars with
  | None -> false
  | Some last_bar ->
      let today = Date.today ~zone:Time_float.Zone.utc in
      let yesterday = Date.add_days today (-1) in
      Date.compare last_bar.Types.Daily_price.date yesterday >= 0

(* Fetch bars from EODHD API and write to cache *)
let _fetch_and_cache ?fetch ~token ~data_dir ~period ~symbol ~start_date
    ~end_date () =
  let params : Eodhd.Http_client.historical_price_params =
    { symbol; start_date; end_date; period }
  in
  Eodhd.Http_client.get_historical_price ~token ~params ?fetch () >>= function
  | Error e -> return (Error e)
  | Ok fetched ->
      (match _save_bars_to_cache data_dir symbol fetched with
      | Ok () -> ()
      | Error e ->
          Core.eprintf "warn: cache write failed for %s: %s\n" symbol
            (Status.show e));
      return (Ok fetched)

(* Serve bars: return cached data if fresh; fetch from API if stale *)
let _get_bars ?fetch ~token ~data_dir ~throttle ~symbol ~period ~start_date
    ~end_date () =
  match _load_cached_bars data_dir symbol ~start_date ~end_date with
  | Error _ ->
      Throttle.enqueue throttle (fun () ->
          _fetch_and_cache ?fetch ~token ~data_dir ~period ~symbol ~start_date
            ~end_date ())
  | Ok cached when _cache_is_current cached ->
      let filtered =
        List.filter cached ~f:(fun bar ->
            let d = bar.Types.Daily_price.date in
            let after_start =
              match start_date with
              | None -> true
              | Some s -> Date.compare d s >= 0
            in
            let before_end =
              match end_date with
              | None -> true
              | Some e -> Date.compare d e <= 0
            in
            after_start && before_end)
      in
      return (Ok filtered)
  | Ok _stale ->
      Throttle.enqueue throttle (fun () ->
          _fetch_and_cache ?fetch ~token ~data_dir ~period ~symbol ~start_date
            ~end_date ())

let make ?fetch config =
  let token = config.token in
  let data_dir = config.data_dir in
  let throttle =
    Throttle.create ~max_concurrent_jobs:config.max_concurrent_requests
      ~continue_on_error:true
  in
  let module S = struct
    let get_bars ~(query : Data_source.bar_query) () =
      _get_bars ?fetch ~token ~data_dir ~throttle ~symbol:query.symbol
        ~period:query.period ~start_date:query.start_date
        ~end_date:query.end_date ()

    let get_universe () = return (Universe.load data_dir)
  end in
  return (module S : Data_source.DATA_SOURCE)
