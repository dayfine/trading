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
  (* Direct date-indexed lookup. The previous implementation went through
     [get_prices ~end_date:date] which allocates a fresh [List.filter]'d copy
     of the full price history per call, then walks it again with [List.find].
     For a per-tick simulation loop (many [get_price] calls per (symbol, day)
     cell at universe-scale per memtrace), that compounded into billions of
     cons-cell allocations per run. [Price_cache.get_price_on_date] is O(1)
     after first symbol load, with no per-call allocation. *)
  Price_cache.get_price_on_date t.price_cache ~symbol ~date

let get_indicator t ~symbol ~indicator_name ~period ~cadence ~date =
  let spec = Indicator_manager.{ name = indicator_name; period; cadence } in
  match
    Indicator_manager.get_indicator t.indicator_manager ~symbol ~spec ~date
  with
  | Error _ -> None
  | Ok value -> value

let finalize_period t ~cadence ~end_date =
  Indicator_manager.finalize_period t.indicator_manager ~cadence ~end_date
