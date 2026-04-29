(** Force-liquidation policy. See [force_liquidation.mli] for the contract. *)

open Core

type config = {
  max_unrealized_loss_fraction : float;
  min_portfolio_value_fraction_of_peak : float;
}
[@@deriving show, eq, sexp]

let default_config =
  {
    max_unrealized_loss_fraction = 0.5;
    min_portfolio_value_fraction_of_peak = 0.4;
  }

type reason = Per_position | Portfolio_floor [@@deriving show, eq, sexp]

(* The position_side type from [Trading_base] doesn't derive [sexp] in this
   project; re-expose it locally as a sexpable variant for the [event] /
   [position_input] types. *)
type _side = Long | Short [@@deriving show, eq, sexp]

let _of_side : Trading_base.Types.position_side -> _side = function
  | Trading_base.Types.Long -> Long
  | Trading_base.Types.Short -> Short

let _to_side : _side -> Trading_base.Types.position_side = function
  | Long -> Trading_base.Types.Long
  | Short -> Trading_base.Types.Short

type _event_serial = {
  symbol : string;
  position_id : string;
  date : Date.t;
  side : _side;
  entry_price : float;
  current_price : float;
  quantity : float;
  cost_basis : float;
  unrealized_pnl : float;
  unrealized_pnl_pct : float;
  reason : reason;
}
[@@deriving show, eq, sexp]

type event = {
  symbol : string;
  position_id : string;
  date : Date.t;
  side : Trading_base.Types.position_side;
  entry_price : float;
  current_price : float;
  quantity : float;
  cost_basis : float;
  unrealized_pnl : float;
  unrealized_pnl_pct : float;
  reason : reason;
}

let _to_serial (e : event) : _event_serial =
  {
    symbol = e.symbol;
    position_id = e.position_id;
    date = e.date;
    side = _of_side e.side;
    entry_price = e.entry_price;
    current_price = e.current_price;
    quantity = e.quantity;
    cost_basis = e.cost_basis;
    unrealized_pnl = e.unrealized_pnl;
    unrealized_pnl_pct = e.unrealized_pnl_pct;
    reason = e.reason;
  }

let _of_serial (s : _event_serial) : event =
  {
    symbol = s.symbol;
    position_id = s.position_id;
    date = s.date;
    side = _to_side s.side;
    entry_price = s.entry_price;
    current_price = s.current_price;
    quantity = s.quantity;
    cost_basis = s.cost_basis;
    unrealized_pnl = s.unrealized_pnl;
    unrealized_pnl_pct = s.unrealized_pnl_pct;
    reason = s.reason;
  }

let sexp_of_event e = sexp_of__event_serial (_to_serial e)
let event_of_sexp s = _of_serial (_event_serial_of_sexp s)
let pp_event fmt e = pp__event_serial fmt (_to_serial e)
let show_event e = show__event_serial (_to_serial e)
let equal_event a b = equal__event_serial (_to_serial a) (_to_serial b)

(* ---- Per-position math ---- *)

let unrealized_pnl ~(side : Trading_base.Types.position_side) ~entry_price
    ~current_price ~quantity =
  match side with
  | Trading_base.Types.Long -> (current_price -. entry_price) *. quantity
  | Trading_base.Types.Short -> (entry_price -. current_price) *. quantity

(* ---- Peak tracker ---- *)

type halt_state = Active | Halted [@@deriving show, eq, sexp]

module Peak_tracker = struct
  type t = { mutable peak : float; mutable halt : halt_state }

  let create () = { peak = 0.0; halt = Active }
  let peak t = t.peak
  let halt_state t = t.halt

  let observe t ~portfolio_value =
    if Float.( > ) portfolio_value t.peak then t.peak <- portfolio_value

  let mark_halted t = t.halt <- Halted
  let reset t = t.halt <- Active
end

(* ---- Position_input ---- *)

type _position_input_serial = {
  symbol : string;
  position_id : string;
  side : _side;
  entry_price : float;
  current_price : float;
  quantity : float;
}
[@@deriving show, eq, sexp]

type position_input = {
  symbol : string;
  position_id : string;
  side : Trading_base.Types.position_side;
  entry_price : float;
  current_price : float;
  quantity : float;
}

let _pi_to_serial (p : position_input) : _position_input_serial =
  {
    symbol = p.symbol;
    position_id = p.position_id;
    side = _of_side p.side;
    entry_price = p.entry_price;
    current_price = p.current_price;
    quantity = p.quantity;
  }

let _pi_of_serial (s : _position_input_serial) : position_input =
  {
    symbol = s.symbol;
    position_id = s.position_id;
    side = _to_side s.side;
    entry_price = s.entry_price;
    current_price = s.current_price;
    quantity = s.quantity;
  }

let sexp_of_position_input p = sexp_of__position_input_serial (_pi_to_serial p)
let position_input_of_sexp s = _pi_of_serial (_position_input_serial_of_sexp s)
let pp_position_input fmt p = pp__position_input_serial fmt (_pi_to_serial p)
let show_position_input p = show__position_input_serial (_pi_to_serial p)

let equal_position_input a b =
  equal__position_input_serial (_pi_to_serial a) (_pi_to_serial b)

(* ---- Check ---- *)

let _event_of_input ~date ~reason (p : position_input) : event =
  let pnl =
    unrealized_pnl ~side:p.side ~entry_price:p.entry_price
      ~current_price:p.current_price ~quantity:p.quantity
  in
  let cost_basis = p.entry_price *. p.quantity in
  let pnl_pct =
    if Float.( <= ) cost_basis 0.0 then 0.0 else pnl /. cost_basis
  in
  {
    symbol = p.symbol;
    position_id = p.position_id;
    date;
    side = p.side;
    entry_price = p.entry_price;
    current_price = p.current_price;
    quantity = p.quantity;
    cost_basis;
    unrealized_pnl = pnl;
    unrealized_pnl_pct = pnl_pct;
    reason;
  }

(* Per-position trigger: a position fires when its unrealized loss exceeds
   [config.max_unrealized_loss_fraction] of cost basis. Cost basis must be
   strictly positive — degenerate inputs (zero-cost basis) are not flagged. *)
let _check_per_position ~config ~date (p : position_input) : event option =
  let cost_basis = p.entry_price *. p.quantity in
  if Float.( <= ) cost_basis 0.0 then None
  else
    let pnl =
      unrealized_pnl ~side:p.side ~entry_price:p.entry_price
        ~current_price:p.current_price ~quantity:p.quantity
    in
    let loss_fraction = -.pnl /. cost_basis in
    if Float.( > ) loss_fraction config.max_unrealized_loss_fraction then
      Some (_event_of_input ~date ~reason:Per_position p)
    else None

(* Portfolio-floor trigger fires when [portfolio_value < peak * fraction] AND
   the peak has actually been observed (peak > 0). The peak-zero case happens
   on the first observation; we never fire on bar 1. *)
let _portfolio_floor_breached ~config ~peak ~portfolio_value =
  Float.( > ) peak 0.0
  && Float.( < ) portfolio_value
       (peak *. config.min_portfolio_value_fraction_of_peak)

let check ~config ~date ~positions ~portfolio_value
    ~(peak_tracker : Peak_tracker.t) =
  Peak_tracker.observe peak_tracker ~portfolio_value;
  let peak = Peak_tracker.peak peak_tracker in
  if _portfolio_floor_breached ~config ~peak ~portfolio_value then (
    Peak_tracker.mark_halted peak_tracker;
    List.map positions ~f:(_event_of_input ~date ~reason:Portfolio_floor))
  else List.filter_map positions ~f:(_check_per_position ~config ~date)
