open Core
open Async
open Ema
open Indicator_types

type stock_data = { symbol : string; price : float; ema : float }

let get_historical_prices ~token symbol =
  let zone = Time_float.Zone.utc in
  let params : Eodhd.Http_client.historical_price_params =
    {
      symbol;
      start_date = Some (Date.add_days (Date.today ~zone) (-365));
      end_date = Some (Date.today ~zone);
    }
  in
  Eodhd.Http_client.get_historical_price ~token ~params () >>| function
  | Ok data -> Some data
  | Error status ->
      printf "Error fetching data for %s: %s\n" symbol (Status.show status);
      None

let calculate_metrics symbol (historical_data : Types.Daily_price.t list) :
    stock_data =
  let prices =
    historical_data
    |> List.map ~f:(fun (price : Types.Daily_price.t) ->
        { date = price.date; value = price.adjusted_close })
  in
  let ema_values = calculate_ema prices 30 in
  let current_price = (List.last_exn prices).value in
  let current_ema = (List.last_exn ema_values).value in
  { symbol; price = current_price; ema = current_ema }

let above_30w_ema ~token ~symbols () =
  (* Create a throttle to limit concurrent requests *)
  let throttle =
    Throttle.create ~max_concurrent_jobs:20 ~continue_on_error:false
  in
  Deferred.List.map symbols ~how:`Parallel ~f:(fun symbol ->
      Throttle.enqueue throttle (fun () ->
          get_historical_prices ~token symbol
          >>| Option.map ~f:(calculate_metrics symbol)))
  >>| List.filter_opt
  >>| List.filter ~f:(fun stock -> Float.(stock.price > stock.ema))
  >>| List.sort ~compare:(fun a b -> String.compare a.symbol b.symbol)

let print_results results =
  printf "\nStocks Above 30-Week EMA:\n";
  printf "%-6s %-10s %-10s\n" "Symbol" "Price" "EMA";
  printf "%s\n" (String.make 80 '-');

  List.iter results ~f:(fun stock ->
      printf "%-6s %.2f %.2f\n" stock.symbol stock.price stock.ema);

  printf "\n%s\n" (String.make 80 '-');
  printf "Total stocks above 30-week EMA: %d\n" (List.length results)
