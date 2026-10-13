(** See .mli. *)

open Core

let _to_price_bar (symbol : string) (daily_price : Types.Daily_price.t) :
    Trading_engine.Types.price_bar =
  {
    Trading_engine.Types.symbol;
    open_price = daily_price.open_price;
    high_price = daily_price.high_price;
    low_price = daily_price.low_price;
    close_price = daily_price.close_price;
  }

let get ~adapter ~symbols ~date =
  List.filter_map symbols ~f:(fun symbol ->
      Trading_simulation_data.Market_data_adapter.get_price adapter ~symbol
        ~date
      |> Option.map ~f:(_to_price_bar symbol))
