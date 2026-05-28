open Core

let _bah_main ~weekly_bars ~initial_cash =
  let first = List.hd_exn weekly_bars in
  let entry_price = first.Types.Daily_price.close_price in
  let shares = initial_cash /. entry_price in
  let equity =
    List.map weekly_bars ~f:(fun b -> shares *. b.Types.Daily_price.close_price)
    |> Array.of_list
  in
  let returns = Equity_metrics.returns_from_equity ~equity in
  let cagr = Equity_metrics.cagr_from_returns ~returns in
  let dd = Equity_metrics.max_drawdown_from_equity ~equity in
  (cagr, dd)

let bah_metrics ~weekly_bars ~initial_cash =
  match weekly_bars with
  | [] | [ _ ] -> (0.0, 0.0)
  | _ -> _bah_main ~weekly_bars ~initial_cash

let year_end_equity ~dates ~equity : (int * float) list =
  if Array.is_empty dates then []
  else
    let by_year = Int.Table.create () in
    Array.iteri dates ~f:(fun i d ->
        let y = Date.year d in
        Hashtbl.set by_year ~key:y ~data:equity.(i));
    Hashtbl.to_alist by_year
    |> List.sort ~compare:(fun (a, _) (b, _) -> Int.compare a b)
