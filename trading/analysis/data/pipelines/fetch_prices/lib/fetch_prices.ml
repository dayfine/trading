open Core
open Async
open Csv

let get_historical_prices ~token symbol :
    (Types.Daily_price.t list, Status.t) Result.t Deferred.t =
  let params : Eodhd.Http_client.historical_price_params =
    { symbol; start_date = None; end_date = None }
  in
  Eodhd.Http_client.get_historical_price ~token ~params ()

let save_prices symbol (data : Types.Daily_price.t list) :
    (unit, Status.t) Result.t =
  (* Do not let the Deferred's >>= to be shadowed here *)
  let open Result in
  Csv_storage.create symbol >>= fun storage ->
  Csv_storage.save storage ~override:true data

let fetch_and_save_prices ~token ~symbols () :
    (string * (unit, Status.t) Result.t) list Deferred.t =
  (* Create a throttle to limit concurrent requests *)
  let throttle =
    Throttle.create ~max_concurrent_jobs:20 ~continue_on_error:false
  in
  Deferred.List.map symbols ~how:`Parallel ~f:(fun symbol ->
      Throttle.enqueue throttle (fun () ->
          get_historical_prices ~token symbol >>= fun data ->
          Deferred.return
            ( symbol,
              match data with
              | Ok data -> save_prices symbol data
              | Error status -> Error status )))
  >>| List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
