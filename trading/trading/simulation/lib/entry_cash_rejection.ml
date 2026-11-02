open Core
module Position = Trading_strategy.Position

type t = {
  position_id : string;
  symbol : string;
  date : Date.t;
  required : float;
  available : float;
  budgeted : float;
}
[@@deriving show, eq]

let funded_fraction t =
  if Float.(t.required <= 0.0) then 0.0 else t.budgeted /. t.required

type pending = {
  date : Date.t;
  emit : (t -> unit) option;
  noted : (float * float * float) String.Table.t;
      (* symbol -> (required, available, budgeted) *)
}

let pending ~date ~emit = { date; emit; noted = String.Table.create () }

let _cost (trade : Trading_base.Types.trade) =
  (trade.quantity *. trade.price) +. trade.commission

let note p (trade : Trading_base.Types.trade) ~available_cash ~budgeted_cash =
  if Option.is_some p.emit then
    ignore
      (Hashtbl.add p.noted ~key:trade.symbol
         ~data:(_cost trade, available_cash, budgeted_cash)
        : [ `Ok | `Duplicate ])

let _make p ~(tr : Position.transition) ~symbol (required, available, budgeted)
    =
  {
    position_id = tr.position_id;
    symbol;
    date = p.date;
    required;
    available;
    budgeted;
  }

let _record p ~positions (tr : Position.transition) =
  match tr.kind with
  | CancelEntry _ ->
      let%bind.Option (pos : Position.t) = Map.find positions tr.position_id in
      Hashtbl.find p.noted pos.symbol
      |> Option.map ~f:(_make p ~tr ~symbol:pos.symbol)
  | _ -> None

let emit p ~positions ~cancels =
  Option.iter p.emit ~f:(fun send ->
      List.filter_map cancels ~f:(_record p ~positions) |> List.iter ~f:send)
