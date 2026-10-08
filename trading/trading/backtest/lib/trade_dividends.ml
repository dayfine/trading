open Core

type t = {
  load : string -> Corporate_actions.dividend list Status.status_or;
  start_date : Date.t;
  cache : Corporate_actions.dividend list String.Table.t;
}

let create ~load ~start_date =
  { load; start_date; cache = String.Table.create () }

let _dividends_for t symbol =
  Hashtbl.find_or_add t.cache symbol ~default:(fun () ->
      match t.load symbol with Ok divs -> divs | Error _ -> [])

let _held_through (trade : Trading_simulation.Metrics.trade_metrics) ~start_date
    (div : Corporate_actions.dividend) =
  Date.( > ) div.ex_date trade.entry_date
  && Date.( <= ) div.ex_date trade.exit_date
  && Date.( >= ) div.ex_date start_date

let received t (trade : Trading_simulation.Metrics.trade_metrics) =
  let per_share =
    _dividends_for t trade.symbol
    |> List.filter ~f:(_held_through trade ~start_date:t.start_date)
    |> List.sum
         (module Float)
         ~f:(fun (d : Corporate_actions.dividend) ->
           Option.value d.unadjusted_amount ~default:0.0)
  in
  let sign =
    match trade.side with Trading_base.Types.Buy -> 1.0 | Sell -> -1.0
  in
  sign *. per_share *. trade.quantity
