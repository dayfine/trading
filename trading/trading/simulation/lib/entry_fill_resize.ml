(** G2b entry-fill resize — see [entry_fill_resize.mli]. *)

open Core
module Position = Trading_strategy.Position

type t = { enabled : bool; min_size_fraction : float }

let create ~enabled ~min_size_fraction = { enabled; min_size_fraction }
let disabled = create ~enabled:false ~min_size_fraction:0.0

let entry_trade_side :
    Trading_base.Types.position_side -> Trading_base.Types.side = function
  | Long -> Buy
  | Short -> Sell

(* The paper-loss drag [Portfolio._check_sufficient_cash] adds to the floor:
   the sum of the non-positive marks, mirroring
   [Portfolio._negative_unrealized_pnl_total]. Positive marks are clamped away
   — only losses count against spendable cash. *)
let _negative_unrealized_pnl (portfolio : Trading_portfolio.Portfolio.t) =
  List.fold portfolio.unrealized_pnl_per_position ~init:0.0
    ~f:(fun acc (_symbol, pnl) -> acc +. Float.min 0.0 pnl)

let affordable_quantity ~(portfolio : Trading_portfolio.Portfolio.t)
    ~(trade : Trading_base.Types.trade) =
  match trade.side with
  | Sell -> 0.0
  | Buy ->
      let budget =
        portfolio.current_cash
        +. _negative_unrealized_pnl portfolio
        -. trade.commission
      in
      if Float.(trade.price <= 0.0) || Float.(budget <= 0.0) then 0.0
      else Float.round_down (budget /. trade.price)

(* The designed quantity of the ticket [trade] was filling, when [pos] is that
   ticket: an [Entering] position on the trade's symbol whose entry order
   produces the trade's side. The side check is what keeps a rejected exit out
   of this path (see the .mli on #2466). *)
let _designed_quantity_of ~(trade : Trading_base.Types.trade) (pos : Position.t)
    =
  match pos.state with
  | Entering { target_quantity; _ }
    when String.equal pos.symbol trade.symbol
         && Trading_base.Types.equal_side (entry_trade_side pos.side) trade.side
    ->
      Some target_quantity
  | _ -> None

let _designed_quantity ~positions trade =
  Map.data positions |> List.find_map ~f:(_designed_quantity_of ~trade)

(* The quantity to re-offer this refused trade at, or [None] to let it die:
   [min designed affordable], refused when it is non-positive or falls below
   [min_size_fraction] of the designed size. *)
let _clamped_quantity t ~portfolio ~positions trade =
  let open Option.Let_syntax in
  let%bind designed = _designed_quantity ~positions trade in
  let quantity = Float.min designed (affordable_quantity ~portfolio ~trade) in
  if
    Float.(quantity <= 0.0)
    || Float.(quantity < t.min_size_fraction *. designed)
  then None
  else Some quantity

(* Book [trade] at [quantity]. [None] when the portfolio still refuses it — in
   which case the caller lets the original die, exactly as it does today. *)
let _book_clamped ~initial_long_margin_req ~portfolio ~quantity
    (trade : Trading_base.Types.trade) =
  let clamped = { trade with quantity } in
  match
    Trading_portfolio.Portfolio_margin.apply_single_trade_with_long_margin
      ~initial_long_margin_req portfolio clamped
  with
  | Ok portfolio -> Some (portfolio, clamped)
  | Error _ -> None

(* Fold step: claim one refused trade, or push it onto the still-rejected
   accumulator. Both accumulators are built reversed. *)
let _resize_one t ~initial_long_margin_req ~positions (portfolio, filled, dying)
    trade =
  let claimed =
    let open Option.Let_syntax in
    let%bind quantity = _clamped_quantity t ~portfolio ~positions trade in
    _book_clamped ~initial_long_margin_req ~portfolio ~quantity trade
  in
  match claimed with
  | Some (portfolio, clamped) -> (portfolio, clamped :: filled, dying)
  | None -> (portfolio, filled, trade :: dying)

let claim t ~initial_long_margin_req ~portfolio ~positions ~accepted
    ~rejected_trades =
  (* R1: disabled returns the caller's own values — no portfolio call, no
     allocation, so the fill/cancel pipeline is bit-identical to pre-G2b. *)
  if not t.enabled then (portfolio, accepted, rejected_trades)
  else
    let portfolio, filled_rev, dying_rev =
      List.fold rejected_trades ~init:(portfolio, [], [])
        ~f:(_resize_one t ~initial_long_margin_req ~positions)
    in
    (portfolio, accepted @ List.rev filled_rev, List.rev dying_rev)
