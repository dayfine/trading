open Core
module Portfolio = Trading_portfolio.Portfolio
module Portfolio_margin = Trading_portfolio.Portfolio_margin
module Position = Trading_strategy.Position

let restore_buffer_pct = 0.02

type long_holding = {
  position_id : string;
  symbol : string;
  quantity : float;
  entry_price : float;
  mark : float;
}

let _marked_value h = h.quantity *. h.mark

(* Unrealized return since entry — the weakness key. entry_price is positive by
   the position invariant, so no divide-by-zero guard is needed. *)
let _unrealized_return h = (h.mark /. h.entry_price) -. 1.0

let _total_marked_exposure holdings =
  List.sum (module Float) holdings ~f:_marked_value

(* Weakest-first: ascending unrealized return, ties broken by symbol so the
   order is deterministic. *)
let _weakest_first holdings =
  List.sort holdings ~compare:(fun a b ->
      match Float.compare (_unrealized_return a) (_unrealized_return b) with
      | 0 -> String.compare a.symbol b.symbol
      | c -> c)

(* Shed weakest holdings until the running exposure is at most [target_exposure].
   Selling at the mark leaves equity unchanged, so shrinking the denominator is
   what restores the ratio. Whole-position granularity, mirroring the short-side
   force-cover. *)
let rec _shed_until ~target_exposure ~running acc = function
  | [] -> List.rev acc
  | _ when Float.( <= ) running target_exposure -> List.rev acc
  | h :: rest ->
      let running = running -. _marked_value h in
      _shed_until ~target_exposure ~running (h :: acc) rest

let select_reductions ~equity ~maintenance_long_pct ~holdings =
  let exposure = _total_marked_exposure holdings in
  if Float.( <= ) maintenance_long_pct 0.0 || Float.( <= ) exposure 0.0 then []
  else if Float.( >= ) (equity /. exposure) maintenance_long_pct then []
  else
    (* Reduce to a target ratio slightly above the bare requirement so mark noise
       does not immediately re-breach. When equity is wiped ([<= 0]) no positive
       exposure satisfies the ratio, so the target is unreachable and every
       holding is shed. *)
    let target_exposure =
      if Float.( <= ) equity 0.0 then Float.neg_infinity
      else equity /. (maintenance_long_pct *. (1.0 +. restore_buffer_pct))
    in
    _shed_until ~target_exposure ~running:exposure [] (_weakest_first holdings)

(* Project a priced held long into a [long_holding]. Skips non-long, non-Holding,
   and symbols with no mark today (unmarkable / unfillable this tick). *)
let _holding_of_position ~price_map (id, pos) =
  match (pos.Position.side, Position.get_state pos) with
  | Trading_base.Types.Long, Position.Holding h ->
      let%map.Option mark = Map.find price_map pos.Position.symbol in
      {
        position_id = id;
        symbol = pos.Position.symbol;
        quantity = h.quantity;
        entry_price = h.entry_price;
        mark;
      }
  | _ -> None

let _priced_long_holdings ~price_map positions =
  Map.to_alist positions |> List.filter_map ~f:(_holding_of_position ~price_map)

let _reduce_detail h =
  Printf.sprintf "unrealized_return=%.6f mark=%.6f" (_unrealized_return h)
    h.mark

let _reduce_transition ~date h =
  let exit_reason =
    Position.StrategySignal
      { label = "maintenance_reduce"; detail = Some (_reduce_detail h) }
  in
  {
    Position.position_id = h.position_id;
    date;
    kind = Position.TriggerExit { exit_reason; exit_price = h.mark };
  }

let _is_friday date = Date.day_of_week date |> Day_of_week.equal Day_of_week.Fri

let maintenance_reduce_transitions ~maintenance_long_pct ~portfolio ~positions
    ~prices ~date =
  if (not (_is_friday date)) || Float.( <= ) maintenance_long_pct 0.0 then []
  else
    let price_map = Map.of_alist_exn (module String) prices in
    let holdings = _priced_long_holdings ~price_map positions in
    let equity =
      Portfolio_margin.equity_cash portfolio +. _total_marked_exposure holdings
    in
    select_reductions ~equity ~maintenance_long_pct ~holdings
    |> List.map ~f:(_reduce_transition ~date)
