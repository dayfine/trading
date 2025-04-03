open Core
open Async
open Ema
open Indicator_types

type stock_data = {
  symbol : string;
  name : string;
  sector : string;
  price : float;
  ema : float;
}

let read_sp500_symbols () =
  let csv = Csv.load "trading/analysis/data/sources/sp500_symbols.csv" in
  List.tl_exn csv
  |> List.map ~f:(fun row ->
         (List.nth_exn row 0, List.nth_exn row 1, List.nth_exn row 2))

let get_historical_prices ~token symbol =
  let zone = Time_float.Zone.utc in
  let params =
    {
      Eodhd.Http_params.symbol;
      start_date = Some (Date.add_days (Date.today ~zone) (-365));
      (* 1 year of data *)
      end_date = Some (Date.today ~zone);
    }
  in
  Eodhd.Http_client.get_historical_price ~token ~params >>| function
  | Ok data -> Some (symbol, data)
  | Error _ -> None

let parse_price_data data =
  let lines = String.split_lines data in
  List.tl_exn lines
  |>
  (* Skip header *)
  List.map ~f:(fun line ->
      match Csv_storage.Parser.parse_line line with
      | Ok price -> { date = price.date; value = price.adjusted_close }
      | Error msg -> failwith msg)

let calculate_metrics (symbol, name, sector) historical_data =
  match historical_data with
  | None -> None
  | Some (_sym, data) -> (
      try
        let prices = parse_price_data data in
        let ema_values = calculate_ema prices 30 in
        let current_price = (List.last_exn prices).value in
        let current_ema = (List.last_exn ema_values).value in
        Some { symbol; name; sector; price = current_price; ema = current_ema }
      with _ -> None)

let above_30w_ema ~token () =
  let symbols = read_sp500_symbols () in
  (* Create a throttle to limit concurrent requests *)
  let throttle =
    Throttle.create ~max_concurrent_jobs:20 ~continue_on_error:false
  in
  Deferred.List.map symbols ~how:`Parallel ~f:(fun (sym, name, sector) ->
      Throttle.enqueue throttle (fun () ->
          get_historical_prices ~token sym
          >>| calculate_metrics (sym, name, sector)))
  >>| List.filter_opt
  >>| List.filter ~f:(fun stock -> Float.(stock.price > stock.ema))
  >>| List.sort ~compare:(fun a b -> String.compare a.symbol b.symbol)

let print_results results =
  printf "\nStocks Above 30-Week EMA:\n";
  printf "%-6s %-30s %-20s %-10s %-10s\n" "Symbol" "Name" "Sector" "Price" "EMA";
  printf "%s\n" (String.make 80 '-');

  List.iter results ~f:(fun stock ->
      printf "%-6s %-30s %-20s %.2f %.2f\n" stock.symbol
        (String.sub stock.name ~pos:0 ~len:(min 30 (String.length stock.name)))
        stock.sector stock.price stock.ema);

  printf "\n%s\n" (String.make 80 '-');
  printf "Total stocks above 30-week EMA: %d\n" (List.length results)
