(** Position-transition builders for the SPY-only Weinstein strategy — see
    [spy_only_transitions.mli]. *)

open Trading_strategy

let _entry_reasoning : Position.entry_reasoning =
  TechnicalSignal
    {
      indicator = "Stage";
      description = "SPY-only Weinstein: Stage 2 entry on rising 30-week MA";
    }

let build_entry ~(position_id : string) ~(symbol : string)
    ~(bar : Types.Daily_price.t) ~(target_quantity : float) :
    Position.transition =
  {
    Position.position_id;
    date = bar.date;
    kind =
      CreateEntering
        {
          symbol;
          side = Long;
          target_quantity;
          entry_price = bar.close_price;
          reasoning = _entry_reasoning;
        };
  }

let build_exit ~(pos : Position.t) ~(bar : Types.Daily_price.t)
    ~(label : string) : Position.transition =
  {
    Position.position_id = pos.id;
    date = bar.date;
    kind =
      TriggerExit
        {
          exit_reason = StrategySignal { label; detail = Some "side=long" };
          exit_price = bar.close_price;
        };
  }

let build_stop_exit ~(pos : Position.t) ~(bar : Types.Daily_price.t)
    ~(stop_level : float) : Position.transition =
  {
    Position.position_id = pos.id;
    date = bar.date;
    kind =
      TriggerExit
        {
          exit_reason =
            StopLoss
              {
                stop_price = stop_level;
                actual_price = bar.close_price;
                loss_percent = 0.0;
              };
          exit_price = bar.close_price;
        };
  }
