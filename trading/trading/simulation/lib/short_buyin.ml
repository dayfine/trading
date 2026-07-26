open Core
module Margin_config = Trading_portfolio.Margin_config
module Position = Trading_strategy.Position

type short_holding = { position_id : string; symbol : string; mark : float }

let select_buyins ~(margin_config : Margin_config.t) ~holdings =
  List.filter holdings ~f:(fun h ->
      Margin_config.is_buyin_htb margin_config ~price:h.mark)

(* Project a priced held short into a [short_holding]. Skips non-short,
   non-Holding, and symbols with no mark today (unmarkable / unfillable this
   tick — mirrors the M2 long-maintenance projection). *)
let _holding_of_position ~price_map (id, pos) =
  match (pos.Position.side, Position.get_state pos) with
  | Trading_base.Types.Short, Position.Holding _ ->
      let%map.Option mark = Map.find price_map pos.Position.symbol in
      { position_id = id; symbol = pos.Position.symbol; mark }
  | _ -> None

let _priced_short_holdings ~price_map positions =
  Map.to_alist positions |> List.filter_map ~f:(_holding_of_position ~price_map)

let _buyin_detail h = Printf.sprintf "mark=%.6f" h.mark

let _buyin_transition ~date h =
  let exit_reason =
    Position.StrategySignal
      { label = "buyin_stress"; detail = Some (_buyin_detail h) }
  in
  {
    Position.position_id = h.position_id;
    date;
    kind = Position.TriggerExit { exit_reason; exit_price = h.mark };
  }

let _is_friday date = Date.day_of_week date |> Day_of_week.equal Day_of_week.Fri

let buyin_stress_transitions ~(margin_config : Margin_config.t) ~positions
    ~prices ~date =
  let armed = margin_config.Margin_config.short_buyin_stress_mode in
  if (not (_is_friday date)) || not armed then []
  else
    let price_map = Map.of_alist_exn (module String) prices in
    let holdings = _priced_short_holdings ~price_map positions in
    select_buyins ~margin_config ~holdings
    |> List.map ~f:(_buyin_transition ~date)
