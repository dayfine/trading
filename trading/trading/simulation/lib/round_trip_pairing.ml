(** Round-trip pairing for a simulation's trade stream. See [.mli]. *)

open Core
module Simulator_types = Trading_simulation_types.Simulator_types

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

let _make_trade_metric ~quantity:entry_basis_quantity symbol entry_date entry
    exit_date exit splits =
  let open Trading_base.Types in
  let days_held = Date.diff exit_date entry_date in
  (* Restate the entry leg onto the exit's (post-split) basis so pnl is computed
     across one consistent share/price space. Dividing the entry price by — and
     multiplying the entry quantity by — the cumulative factor leaves the
     position's dollar exposure unchanged while making it directly comparable to
     the post-split exit fill. The recorded [entry_price]/[quantity] are the
     adjusted (post-split) values, consistent with [exit_price]. With no
     straddling split the factor is [1.0] and the record is unchanged.

     [entry_basis_quantity] is the share count of [entry] this closing leg
     actually consumed, on the entry date's basis — equal to [entry.quantity] for
     a full exit, smaller for a partial one. *)
  let factor = _cumulative_split_factor ~entry_date ~exit_date splits in
  let entry_price = entry.price /. factor in
  let quantity = entry_basis_quantity *. factor in
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

(* Shares below which an open entry (or an unconsumed exit remainder) counts as
   exhausted. Matches the tolerance [_qty_matches_on_exit_basis] uses, so a leg
   that "matches exactly" never leaves a spurious sliver behind. *)
let _residual_qty_epsilon = 1e-6

type _open_entry = {
  entry_date : Date.t;
  trade : Trading_base.Types.trade;
  remaining : float;
      (** Shares of [trade] not yet consumed by a closing leg, on [entry_date]'s
          (pre-split) share basis. *)
}

let _open_entry_of ~date ~(trade : Trading_base.Types.trade) ~remaining =
  { entry_date = date; trade; remaining }

(* Index of the open entry this exit closes: the first whose (split-adjusted)
   unconsumed quantity matches [exit_qty] exactly, falling back to the oldest
   open entry (FIFO). [open_entries] is non-empty by the caller's guard. *)
let _select_entry_index ~splits ~exit_date ~exit_qty open_entries =
  let matches (e : _open_entry) =
    _qty_matches_on_exit_basis ~splits ~entry_date:e.entry_date ~exit_date
      ~entry_qty:e.remaining ~exit_qty
  in
  List.findi open_entries ~f:(fun _ e -> matches e)
  |> Option.map ~f:fst |> Option.value ~default:0

(* Replace the entry at [idx] with its post-consumption remainder, or drop it
   when exhausted. *)
let _rewrite_entry_at open_entries ~idx ~remaining =
  if Float.( > ) remaining _residual_qty_epsilon then
    List.mapi open_entries ~f:(fun i e ->
        if i = idx then { e with remaining } else e)
  else List.filteri open_entries ~f:(fun i _ -> i <> idx)

(* Consume [exit_qty] (on [exit_date]'s share basis) against [open_entries],
   emitting one metric per entry leg touched. Returns the surviving open
   entries, the metrics prepended to [acc] (newest first), and the exit quantity
   left unconsumed once every open entry is exhausted. *)
let rec _consume_exit ~symbol ~splits ~exit_date ~exit_trade ~exit_qty
    open_entries acc =
  match open_entries with
  | [] -> ([], acc, exit_qty)
  | _ when Float.( <= ) exit_qty _residual_qty_epsilon ->
      (open_entries, acc, 0.0)
  | _ ->
      let idx = _select_entry_index ~splits ~exit_date ~exit_qty open_entries in
      let e = List.nth_exn open_entries idx in
      let factor =
        _cumulative_split_factor ~entry_date:e.entry_date ~exit_date splits
      in
      (* Restate the exit's ask onto the entry's basis before comparing. *)
      let take = Float.min e.remaining (exit_qty /. factor) in
      let metric =
        _make_trade_metric ~quantity:take symbol e.entry_date e.trade exit_date
          exit_trade splits
      in
      let open_entries =
        _rewrite_entry_at open_entries ~idx ~remaining:(e.remaining -. take)
      in
      _consume_exit ~symbol ~splits ~exit_date ~exit_trade
        ~exit_qty:(exit_qty -. (take *. factor))
        open_entries (metric :: acc)

let _opposes (a : Trading_base.Types.trade) (b : Trading_base.Types.trade) =
  not (Trading_base.Types.equal_side a.side b.side)

(* One fold step over the trade stream: an opposite-side trade closes as much of
   the open entries as its quantity covers; a same-side trade (or the excess of
   an over-close, which really does flip the position's direction) joins the
   open entries. *)
let _pair_step ~symbol ~splits (open_entries, metrics) (date, trade) =
  let append_entry ~remaining entries =
    entries @ [ _open_entry_of ~date ~trade ~remaining ]
  in
  match open_entries with
  | e :: _ when _opposes e.trade trade ->
      let remaining_open, metrics, unconsumed =
        _consume_exit ~symbol ~splits ~exit_date:date ~exit_trade:trade
          ~exit_qty:trade.Trading_base.Types.quantity open_entries metrics
      in
      if Float.( > ) unconsumed _residual_qty_epsilon then
        (append_entry ~remaining:unconsumed remaining_open, metrics)
      else (remaining_open, metrics)
  | _ ->
      ( append_entry ~remaining:trade.Trading_base.Types.quantity open_entries,
        metrics )

(** Pair entry trades with close trades to form round-trips for a single symbol,
    position- and quantity-faithfully. A trade whose side opposes the open
    entries is an exit: it consumes the open entry with the matching
    (split-adjusted) quantity, or the oldest open entry when no quantity matches
    (FIFO), and keeps consuming further entries while quantity remains. A
    partial exit consumes only its own share count and leaves the
    {b residual open}; the residual pairs with the next closing trade instead of
    being dropped. A trade on the same side as the open entries opens another
    entry — sibling positions (e.g. a scale-in parent + add) interleave as Buy,
    Buy, Sell, Sell and each leg pairs with its own position's legs. For the
    alternating single-position stream this reduces to the previous consecutive
    pairing. Handles both Buy→Sell (long) and Sell→Buy (short: the entry is the
    short open, the exit the buy-to-cover). [splits] is the symbol's split
    events; each round-trip is corrected for any split straddling its hold via
    {!_make_trade_metric}.

    Residual tracking is what keeps a long-only run long-only in the report:
    with the residual dropped (the pre-#2059 behaviour), the {e next} closing
    Sell found no open entry and was re-read as a short open — see the [.mli].
*)
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
