(** Trade metrics computation for performance analysis. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

(** {1 Trade Metrics Types} *)

type trade_metrics = {
  symbol : string;
  side : Trading_base.Types.side;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  entry_price : float;
  exit_price : float;
  quantity : float;
  pnl_dollars : float;
  pnl_percent : float;
}
[@@deriving show, eq]

type summary_stats = {
  total_pnl : float;
  avg_holding_days : float;
  win_count : int;
  loss_count : int;
  win_rate : float;
}
[@@deriving show, eq]

(** {1 Trade Metrics Functions} *)

let _side_label = function
  | Trading_base.Types.Buy -> "LONG"
  | Trading_base.Types.Sell -> "SHORT"

let show_trade_metrics m =
  Printf.sprintf
    "%s [%s]: %s -> %s (%d days), entry=%.2f exit=%.2f qty=%.0f, P&L=$%.2f \
     (%.2f%%)"
    m.symbol (_side_label m.side)
    (Date.to_string m.entry_date)
    (Date.to_string m.exit_date)
    m.days_held m.entry_price m.exit_price m.quantity m.pnl_dollars
    m.pnl_percent

let show_summary s =
  Printf.sprintf
    "Total P&L: $%.2f | Avg hold: %.1f days | Win rate: %.1f%% (%d/%d)"
    s.total_pnl s.avg_holding_days s.win_rate s.win_count
    (s.win_count + s.loss_count)

(** Compute (pnl_dollars, pnl_percent) for a closed round-trip, dispatching on
    the entry side. Long: profit when exit > entry. Short: profit when exit
    (cover) < entry. Both pnl_percent figures are expressed as a percentage of
    the entry price; the sign convention is that a positive reading always means
    profit, regardless of direction. *)
let _compute_pnl ~entry_side ~entry_price ~exit_price ~quantity =
  let dollars =
    match entry_side with
    | Trading_base.Types.Buy -> (exit_price -. entry_price) *. quantity
    | Trading_base.Types.Sell -> (entry_price -. exit_price) *. quantity
  in
  let percent =
    match entry_side with
    | Trading_base.Types.Buy ->
        (exit_price -. entry_price) /. entry_price *. 100.0
    | Trading_base.Types.Sell ->
        (entry_price -. exit_price) /. entry_price *. 100.0
  in
  (dollars, percent)

(** Cumulative split factor for events straddling a single hold — the product of
    [factor] over all splits with [entry_date < split_date <= exit_date].

    [Split_event.factor] is [new_shares /. old_shares] (2:1 → [2.0], 3:1 →
    [3.0], reverse 1:5 → [0.2]), matching [Split_handler]'s live-position
    scaling. A split on the entry date itself is excluded (the entry fill
    already prints on that day's post-split basis); a split on the exit date is
    included (the exit fill is post-split, so the entry leg must be carried
    forward through it). *)
let _cumulative_split_factor ~entry_date ~exit_date
    (splits : Trading_portfolio.Split_event.t list) =
  List.fold splits ~init:1.0
    ~f:(fun acc (s : Trading_portfolio.Split_event.t) ->
      if Date.( < ) entry_date s.date && Date.( <= ) s.date exit_date then
        acc *. s.factor
      else acc)

let _make_trade_metric symbol entry_date entry exit_date exit splits =
  let open Trading_base.Types in
  let days_held = Date.diff exit_date entry_date in
  (* Restate the entry leg onto the exit's (post-split) basis so pnl is computed
     across one consistent share/price space. Dividing the entry price by — and
     multiplying the entry quantity by — the cumulative factor leaves the
     position's dollar exposure unchanged while making it directly comparable to
     the post-split exit fill. The recorded [entry_price]/[quantity] are the
     adjusted (post-split) values, consistent with [exit_price]. With no
     straddling split the factor is [1.0] and the record is unchanged. *)
  let factor = _cumulative_split_factor ~entry_date ~exit_date splits in
  let entry_price = entry.price /. factor in
  let quantity = entry.quantity *. factor in
  let pnl_dollars, pnl_percent =
    _compute_pnl ~entry_side:entry.side ~entry_price ~exit_price:exit.price
      ~quantity
  in
  {
    symbol;
    side = entry.side;
    entry_date;
    exit_date;
    days_held;
    entry_price;
    exit_price = exit.price;
    quantity;
    pnl_dollars;
    pnl_percent;
  }

(* Whether [entry]'s quantity, restated onto the exit date's post-split basis
   (the same restatement [_make_trade_metric] applies), equals [exit_qty]. *)
let _qty_matches_on_exit_basis ~splits ~entry_date ~exit_date ~entry_qty
    ~exit_qty =
  let factor = _cumulative_split_factor ~entry_date ~exit_date splits in
  Float.(abs ((entry_qty *. factor) -. exit_qty) < 1e-6)

(* Pick the open entry this exit closes: the one whose (split-adjusted)
   quantity matches exactly, falling back to the oldest open entry (FIFO).
   Returns the chosen entry and the remaining open entries. [open_entries] is
   non-empty by the caller's guard. *)
let _pop_matching_entry ~splits ~exit_date ~exit_qty open_entries =
  let matches i =
    let entry_date, (entry : Trading_base.Types.trade) =
      List.nth_exn open_entries i
    in
    _qty_matches_on_exit_basis ~splits ~entry_date ~exit_date
      ~entry_qty:entry.quantity ~exit_qty
  in
  let idx =
    List.range 0 (List.length open_entries)
    |> List.find ~f:matches |> Option.value ~default:0
  in
  ( List.nth_exn open_entries idx,
    List.filteri open_entries ~f:(fun i _ -> i <> idx) )

let _opposes (a : Trading_base.Types.trade) (b : Trading_base.Types.trade) =
  not (Trading_base.Types.equal_side a.side b.side)

(* Close one round-trip: pop the open entry this exit matches and build its
   metric. Returns the metric and the remaining open entries. *)
let _close_round_trip ~symbol ~splits ~exit_date ~exit_trade open_entries =
  let (entry_date, entry), remaining =
    _pop_matching_entry ~splits ~exit_date
      ~exit_qty:exit_trade.Trading_base.Types.quantity open_entries
  in
  ( _make_trade_metric symbol entry_date entry exit_date exit_trade splits,
    remaining )

(* One fold step over the trade stream: an opposite-side trade closes a
   round-trip; a same-side trade joins the open entries. *)
let _pair_step ~symbol ~splits (open_entries, metrics) ((date, trade) as t) =
  match open_entries with
  | (_, head) :: _ when _opposes head trade ->
      let m, remaining =
        _close_round_trip ~symbol ~splits ~exit_date:date ~exit_trade:trade
          open_entries
      in
      (remaining, m :: metrics)
  | _ -> (open_entries @ [ t ], metrics)

(** Pair entry trades with close trades to form round-trips for a single symbol,
    position-faithfully. A trade whose side opposes the open entries is an exit:
    it closes the open entry with the matching (split-adjusted) quantity, or the
    oldest open entry when no quantity matches (FIFO). A trade on the same side
    as the open entries opens another entry — sibling positions (e.g. a scale-in
    parent + add) interleave as Buy, Buy, Sell, Sell and each leg pairs with its
    own position's legs. For the alternating single-position stream this reduces
    to the previous consecutive pairing. Handles both Buy→Sell (long) and
    Sell→Buy (short: the entry is the short open, the exit the buy-to-cover).
    [splits] is the symbol's split events; each round-trip is corrected for any
    split straddling its hold via {!_make_trade_metric}. *)
let _pair_trades_for_symbol symbol
    (trades : (Date.t * Trading_base.Types.trade) list)
    (splits : Trading_portfolio.Split_event.t list) : trade_metrics list =
  let _, metrics =
    List.fold trades ~init:([], []) ~f:(_pair_step ~symbol ~splits)
  in
  List.rev metrics

(** Group the [splits_applied] across all steps by symbol. Split events are
    detected on the split day and carried on each [step_result], so the trade
    metrics can adjust split-straddling holds without re-deriving factors. *)
let _splits_by_symbol (steps : Simulator_types.step_result list) :
    Trading_portfolio.Split_event.t list String.Map.t =
  List.concat_map steps ~f:(fun step -> step.splits_applied)
  |> List.fold
       ~init:(Map.empty (module String))
       ~f:(fun acc (s : Trading_portfolio.Split_event.t) ->
         Map.add_multi acc ~key:s.symbol ~data:s)

let extract_round_trips (steps : Simulator_types.step_result list) :
    trade_metrics list =
  let all_trades =
    List.concat_map steps ~f:(fun step ->
        List.map step.trades ~f:(fun trade -> (step.date, trade)))
  in
  let splits_by_symbol = _splits_by_symbol steps in
  let by_symbol =
    List.fold all_trades
      ~init:(Map.empty (module String))
      ~f:(fun acc (date, trade) ->
        let symbol = trade.Trading_base.Types.symbol in
        let existing = Map.find acc symbol |> Option.value ~default:[] in
        Map.set acc ~key:symbol ~data:((date, trade) :: existing))
  in
  Map.fold by_symbol ~init:[] ~f:(fun ~key:symbol ~data:trades acc ->
      let sorted =
        List.sort trades ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2)
      in
      let splits =
        Map.find splits_by_symbol symbol |> Option.value ~default:[]
      in
      _pair_trades_for_symbol symbol sorted splits @ acc)

let compute_summary (trades : trade_metrics list) : summary_stats option =
  match trades with
  | [] -> None
  | _ ->
      let total_pnl =
        List.fold trades ~init:0.0 ~f:(fun acc m -> acc +. m.pnl_dollars)
      in
      let total_days =
        List.fold trades ~init:0 ~f:(fun acc m -> acc + m.days_held)
      in
      let avg_holding_days =
        Float.of_int total_days /. Float.of_int (List.length trades)
      in
      let win_count =
        List.count trades ~f:(fun m -> Float.(m.pnl_dollars > 0.0))
      in
      let loss_count = List.length trades - win_count in
      let win_rate =
        Float.of_int win_count /. Float.of_int (List.length trades) *. 100.0
      in
      Some { total_pnl; avg_holding_days; win_count; loss_count; win_rate }

(** {1 Conversion Functions} *)

let summary_stats_to_metrics (stats : summary_stats) : Metric_types.metric_set =
  Metric_types.of_alist_exn
    [
      (TotalPnl, stats.total_pnl);
      (AvgHoldingDays, stats.avg_holding_days);
      (WinCount, Float.of_int stats.win_count);
      (LossCount, Float.of_int stats.loss_count);
      (WinRate, stats.win_rate);
    ]

let compute_profit_factor (round_trips : trade_metrics list) =
  let gross_profit =
    List.fold round_trips ~init:0.0 ~f:(fun acc (m : trade_metrics) ->
        if Float.(m.pnl_dollars > 0.0) then acc +. m.pnl_dollars else acc)
  in
  let gross_loss =
    List.fold round_trips ~init:0.0 ~f:(fun acc (m : trade_metrics) ->
        if Float.(m.pnl_dollars < 0.0) then acc +. Float.abs m.pnl_dollars
        else acc)
  in
  if Float.(gross_loss = 0.0) then
    if Float.(gross_profit > 0.0) then Float.infinity else 0.0
  else gross_profit /. gross_loss

let compute_round_trip_metric_set (round_trips : trade_metrics list) :
    Metric_types.metric_set =
  let pf = compute_profit_factor round_trips in
  let pf_metric = Metric_types.singleton ProfitFactor pf in
  match compute_summary round_trips with
  | None ->
      (* Empty round-trip list: legacy [Summary_computer] still emitted
         [ProfitFactor = 0.0] (see [compute_profit_factor] convention).
         Pin the same shape so existing callers and the no-trades test
         observe identical behaviour. *)
      pf_metric
  | Some stats ->
      let base = summary_stats_to_metrics stats in
      Metric_types.merge base pf_metric
