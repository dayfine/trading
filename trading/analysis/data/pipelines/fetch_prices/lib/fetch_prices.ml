open Core
open Async
open Eodhd.Http_client
open Csv
open Csv.Parser

let get_historical_prices ~token symbol : (string, string) Result.t Deferred.t =
  let params =
    {
      Eodhd.Http_params.symbol;
      start_date = None;
      (* 1 year of data *)
      end_date = None;
    }
  in
  get_historical_price ~token ~params

let parse_price_data data : (Types.Daily_price.t list, Status.t) Result.t =
  let lines = String.split_lines data in
  List.tl_exn lines
  |>
  (* Skip header *)
  List.map ~f:(fun line ->
      match parse_line line with Ok price -> Ok price | Error msg -> Error msg)
  |> Result.all
  |> Result.map_error ~f:(fun msg ->
         Status.invalid_argument_error
           (sprintf "Failed to parse price data: %s" msg))

let save_prices symbol (data : string) : (unit, Status.t) Result.t =
  (* Do not let the Deferred's >>= to be shadowed here *)
  let open Result in
  parse_price_data data >>= fun prices ->
  Csv_storage.create symbol >>= fun storage ->
  Csv_storage.save storage ~override:true prices

let fetch_and_save_prices ~token ~symbols () :
    (string * (unit, Status.t) Result.t) list Deferred.t =
  (* Create a throttle to limit concurrent requests *)
  let throttle =
    Throttle.create ~max_concurrent_jobs:20 ~continue_on_error:false
  in
  Deferred.List.map symbols ~how:`Parallel ~f:(fun symbol ->
      Throttle.enqueue throttle (fun () ->
          get_historical_prices ~token symbol >>= function
          | Ok (data : string) -> Deferred.return (symbol, save_prices symbol data)
          | Error msg ->
              Deferred.return (
                symbol,
                Result.Error (
                  Status.internal_error
                    (sprintf "Failed to fetch prices for %s: %s" symbol msg) ))))
  >>| List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
