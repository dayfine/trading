open Core
open Types

(* Buy-and-hold equity curve over the same weekly bars. The first bar's
   close is the entry price; subsequent equity is shares * close.

   No bid-ask cost on the BAH baseline — the comparison is "stage strategy
   net of 0.5 bps round-trip costs" vs "passive hold gross". The latter is
   how SPY BAH is commonly quoted, and the 0.5-bps difference is dwarfed by
   the strategy's many trades. *)
let metrics ~weekly_bars ~initial_cash =
  match weekly_bars with
  | [] | [ _ ] -> (0.0, 0.0)
  | first :: _ ->
      let entry_price = first.Daily_price.close_price in
      let shares = initial_cash /. entry_price in
      let equity =
        List.map weekly_bars ~f:(fun b -> shares *. b.Daily_price.close_price)
        |> Array.of_list
      in
      let returns = Equity_metrics.returns_from_equity ~equity in
      let cagr = Equity_metrics.cagr_from_returns ~returns in
      let dd = Equity_metrics.max_drawdown_from_equity ~equity in
      (cagr, dd)

(* Per-year [(year, equity)] pairs picking the last equity value falling
   on or before Dec 31 of each year present in the run window. *)
let year_end_equity ~dates ~equity : (int * float) list =
  if Array.is_empty dates then []
  else
    let by_year = Int.Table.create () in
    Array.iteri dates ~f:(fun i d ->
        let y = Date.year d in
        Hashtbl.set by_year ~key:y ~data:equity.(i));
    Hashtbl.to_alist by_year
    |> List.sort ~compare:(fun (a, _) (b, _) -> Int.compare a b)
