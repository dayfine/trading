open Core

type t = {
  price_cache : Price_cache.t;
  indicator_manager : Indicator_manager.t;
}

let create ~data_dir =
  let price_cache = Price_cache.create ~data_dir in
  let indicator_manager = Indicator_manager.create ~price_cache in
  { price_cache; indicator_manager }

let get_price t ~symbol ~date =
  match Price_cache.get_prices t.price_cache ~symbol ~end_date:date () with
  | Error _ -> None
  | Ok prices ->
      List.find prices ~f:(fun (p : Types.Daily_price.t) ->
          Date.equal p.date date)

let get_indicator t ~symbol ~indicator_name ~period ~cadence ~date =
  let spec = Indicator_manager.{ name = indicator_name; period; cadence } in
  match
    Indicator_manager.get_indicator t.indicator_manager ~symbol ~spec ~date
  with
  | Error _ -> None
  | Ok value -> value

let finalize_period t ~cadence ~end_date =
  Indicator_manager.finalize_period t.indicator_manager ~cadence ~end_date
