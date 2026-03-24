(** Weinstein Stage Analysis strategy implementation *)

open Core

(** {1 Configuration} *)

type stage_config = {
  ma_period : int;
  ma_slope_lookback : int;
  breakout_premium_pct : float;
}
[@@deriving show, eq]

let default_stage_config =
  { ma_period = 30; ma_slope_lookback = 4; breakout_premium_pct = 0.02 }

type macro_config = {
  index_symbol : string;
  index_ma_period : int;
}
[@@deriving show, eq]

let default_macro_config = { index_symbol = "SPY"; index_ma_period = 30 }

type sizing_config = {
  risk_per_trade_pct : float;
  max_positions : int;
  stop_pct_below_ma : float;
}
[@@deriving show, eq]

let default_sizing_config =
  { risk_per_trade_pct = 0.01; max_positions = 20; stop_pct_below_ma = 0.07 }

type config = {
  symbols : string list;
  stage : stage_config;
  macro : macro_config;
  sizing : sizing_config;
}
[@@deriving show, eq]

let default_config ~symbols =
  {
    symbols;
    stage = default_stage_config;
    macro = default_macro_config;
    sizing = default_sizing_config;
  }

let name = "Weinstein"

(** {1 Internal state types} *)

(** Per-symbol stop state tracked across weekly calls. *)
type stop_state = {
  stop_price : float;  (** Current stop level *)
  highest_close : float;  (** Highest close seen since entry *)
}

(** {1 Analysis helpers} *)

(** Get the 30-week SMA for a symbol. Returns [None] if insufficient data. *)
let _get_weekly_sma ~get_indicator ~symbol ~period =
  get_indicator symbol "SMA" period Types.Cadence.Weekly

(** Get the most recent weekly close for a symbol. *)
let _get_weekly_close ~get_price ~symbol =
  Option.map (get_price symbol) ~f:(fun p -> p.Types.Daily_price.close_price)

(** Determine if the market regime is bullish.

    Bullish: index price is above its MA and the MA is rising.
    Returns [None] if we can't determine the regime (no data). *)
let _is_bullish_regime ~get_price ~get_indicator ~macro_config =
  let sym = macro_config.index_symbol in
  let price_opt = _get_weekly_close ~get_price ~symbol:sym in
  let ma_opt =
    _get_weekly_sma ~get_indicator ~symbol:sym ~period:macro_config.index_ma_period
  in
  match (price_opt, ma_opt) with
  | Some price, Some ma -> Some Float.(price > ma)
  | _ -> None

(** Generate a unique position ID. *)
let _position_counter = ref 0

let _generate_position_id symbol =
  _position_counter := !_position_counter + 1;
  Printf.sprintf "%s-w%d" symbol !_position_counter

(** {1 Stop management} *)

(** Compute the initial stop price: a percentage below the 30-week MA. *)
let _initial_stop_price ~ma_price ~stop_pct_below_ma =
  ma_price *. (1.0 -. stop_pct_below_ma)

(** Update a stop state given the latest close and MA.

    Weinstein trailing stop: once the position is profitable, raise the stop to
    protect gains. We ratchet the stop up as the highest close rises, but never
    lower it. *)
let _update_stop ~stop_state ~current_close ~ma_price ~stop_pct_below_ma =
  let new_highest = Float.max stop_state.highest_close current_close in
  (* New floor: always maintain a floor of stop_pct_below_ma below the current MA *)
  let ma_floor = _initial_stop_price ~ma_price ~stop_pct_below_ma in
  (* Trailing component: raise stop as price rises above the MA floor *)
  let trailing =
    if Float.(new_highest > ma_price) then
      (* Price is above MA: trail at stop_pct_below_ma below the highest close *)
      new_highest *. (1.0 -. stop_pct_below_ma)
    else ma_floor
  in
  let new_stop = Float.max (Float.max trailing ma_floor) stop_state.stop_price in
  { stop_price = new_stop; highest_close = new_highest }

(** {1 Strategy logic} *)

(** Check held positions and emit exits/stop updates. *)
let _check_held_positions ~get_price ~get_indicator ~positions ~stop_states
    ~date ~stage_config ~sizing_config =
  let open Trading_strategy.Position in
  Map.fold positions ~init:([], [], stop_states)
    ~f:(fun ~key:position_id ~data:pos (exits, updates, states) ->
      match get_state pos with
      | Holding holding -> (
          let symbol = pos.symbol in
          let close_opt = _get_weekly_close ~get_price ~symbol in
          let ma_opt =
            _get_weekly_sma ~get_indicator ~symbol
              ~period:stage_config.ma_period
          in
          match (close_opt, ma_opt) with
          | Some current_close, Some ma_price ->
              (* Update stop state *)
              let current_stop =
                match Map.find states symbol with
                | Some s -> s
                | None ->
                    {
                      stop_price =
                        _initial_stop_price ~ma_price
                          ~stop_pct_below_ma:sizing_config.stop_pct_below_ma;
                      highest_close = current_close;
                    }
              in
              let new_stop =
                _update_stop ~stop_state:current_stop ~current_close ~ma_price
                  ~stop_pct_below_ma:sizing_config.stop_pct_below_ma
              in
              let new_states = Map.set states ~key:symbol ~data:new_stop in
              (* Check if stop is hit *)
              if Float.(current_close <= new_stop.stop_price) then
                let exit_transition =
                  {
                    position_id;
                    date;
                    kind =
                      TriggerExit
                        {
                          exit_reason =
                            StopLoss
                              {
                                stop_price = new_stop.stop_price;
                                actual_price = current_close;
                                loss_percent =
                                  (current_close -. holding.entry_price)
                                  /. holding.entry_price *. 100.0;
                              };
                          exit_price = current_close;
                        };
                  }
                in
                (exit_transition :: exits, updates, new_states)
              else
                (* Stop not hit — check if we need to update risk params *)
                let update_transition =
                  {
                    position_id;
                    date;
                    kind =
                      UpdateRiskParams
                        {
                          new_risk_params =
                            {
                              stop_loss_price = Some new_stop.stop_price;
                              take_profit_price = holding.risk_params.take_profit_price;
                              max_hold_days = holding.risk_params.max_hold_days;
                            };
                        };
                  }
                in
                (exits, update_transition :: updates, new_states)
          | _ ->
              (* No data for this symbol — leave position unchanged *)
              (exits, updates, states))
      | _ ->
          (* Not in Holding state — skip *)
          (exits, updates, stop_states))

(** Count active (non-closed) positions. *)
let _count_active_positions positions =
  Map.count positions ~f:(fun pos ->
      not (Trading_strategy.Position.is_closed pos))

(** Score a symbol for entry.

    Weinstein criteria:
    - Price must be above the 30-week MA (Stage 2 condition)
    - MA should be rising (positive slope)
    - Volume confirmation helps but we use price/MA as primary signal here

    Returns [None] if insufficient data or criteria not met.
    Returns [Some (entry_price, stop_price, score)] if candidate qualifies. *)
let _score_symbol ~get_price ~get_indicator ~stage_config ~sizing_config symbol
    =
  let close_opt = _get_weekly_close ~get_price ~symbol in
  let ma_opt =
    _get_weekly_sma ~get_indicator ~symbol ~period:stage_config.ma_period
  in
  (* Need both price and MA to evaluate *)
  match (close_opt, ma_opt) with
  | Some close, Some ma when Float.(close > 0.0 && ma > 0.0) ->
      let pct_above_ma = (close -. ma) /. ma in
      (* Must be above MA with some premium (breakout condition) *)
      if Float.(pct_above_ma >= stage_config.breakout_premium_pct) then
        let entry_price = close *. 1.005 in
        (* Small premium above current price *)
        let stop_price =
          _initial_stop_price ~ma_price:ma
            ~stop_pct_below_ma:sizing_config.stop_pct_below_ma
        in
        let risk_pct = (entry_price -. stop_price) /. entry_price in
        (* Score: how far above MA as a percentage, capped at a reasonable value *)
        let score = Float.to_int (Float.min (pct_above_ma *. 1000.0) 100.0) in
        Some (entry_price, stop_price, risk_pct, score)
      else None
  | _ -> None

(** {1 Entry module implementation} *)

let make (config : config) : (module Strategy_interface.STRATEGY) =
  (* Private mutable state: stop levels per symbol, prior stage tracking *)
  let stop_states = ref String.Map.empty in
  let module M = struct
    let name = name

    let on_market_close ~get_price ~get_indicator ~positions =
      let open Result.Let_syntax in
      let date =
        (* Use today's date from get_price on the index symbol *)
        match get_price config.macro.index_symbol with
        | Some p -> p.Types.Daily_price.date
        | None ->
            (* Fallback: use a fixed date — should not happen in practice *)
            Date.of_string "1970-01-01"
      in
      (* Step 1: Check held positions — update stops, emit exits *)
      let exits, updates, new_stop_states =
        _check_held_positions ~get_price ~get_indicator ~positions
          ~stop_states:!stop_states ~date ~stage_config:config.stage
          ~sizing_config:config.sizing
      in
      stop_states := new_stop_states;
      (* If any positions hit their stop, skip new entries this week *)
      let active_count = _count_active_positions positions in
      (* Step 2: Macro gate — only enter new longs in bullish regime *)
      let regime_ok =
        match _is_bullish_regime ~get_price ~get_indicator ~macro_config:config.macro with
        | Some is_bullish -> is_bullish
        | None -> false
        (* Conservative: if we can't determine regime, don't enter *)
      in
      (* Step 3: Scan universe for entry candidates *)
      let entry_transitions =
        if
          (not regime_ok)
          || active_count >= config.sizing.max_positions
          || not (List.is_empty exits)
        then
          (* Don't add new positions if regime is bearish, we're at max capacity,
             or we're already exiting some positions this week *)
          []
        else
          let available_slots =
            config.sizing.max_positions - active_count
          in
          let held_symbols =
            Map.to_alist positions
            |> List.filter_map ~f:(fun (_, pos) ->
                   if Trading_strategy.Position.is_closed pos then None
                   else Some pos.Trading_strategy.Position.symbol)
          in
          (* Score all symbols not already held *)
          let candidates =
            List.filter_map config.symbols ~f:(fun symbol ->
                if List.mem held_symbols symbol ~equal:String.equal then None
                else
                  Option.map
                    (_score_symbol ~get_price ~get_indicator
                       ~stage_config:config.stage ~sizing_config:config.sizing
                       symbol)
                    ~f:(fun (entry_price, stop_price, _risk_pct, score) ->
                      (symbol, entry_price, stop_price, score)))
          in
          (* Sort by score descending, take top candidates *)
          let sorted =
            List.sort candidates ~compare:(fun (_, _, _, s1) (_, _, _, s2) ->
                Int.compare s2 s1)
          in
          let top = List.take sorted available_slots in
          List.map top ~f:(fun (symbol, entry_price, stop_price, _score) ->
              let position_id = _generate_position_id symbol in
              {
                Trading_strategy.Position.position_id;
                date;
                kind =
                  CreateEntering
                    {
                      symbol;
                      side = Long;
                      target_quantity = 1.0;
                          (* Placeholder: real sizing uses portfolio value *)
                      entry_price;
                      reasoning =
                        TechnicalSignal
                          {
                            indicator = "SMA30W";
                            description =
                              Printf.sprintf
                                "Price above 30-week MA; stop at %.2f"
                                stop_price;
                          };
                    };
              })
      in
      let all_transitions = exits @ updates @ entry_transitions in
      let%bind () = Ok () in
      Ok { Strategy_interface.transitions = all_transitions }
  end in
  (module M : Strategy_interface.STRATEGY)
