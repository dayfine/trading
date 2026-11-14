(** What each stage of one Friday's Weinstein run saw and decided.

    Built by {!Friday_pipeline.run}, printed by {!Friday_trace_printer.render}.
    Types only: this interface has no implementation. *)

(** Why a stock did or did not reach the full per-stock analysis. *)
type pre_screen =
  | Analysed  (** Stage 2 or Stage 4, and its sector does not block it. *)
  | Not_stage_2_or_4  (** Stage 1 or 3: nothing to buy or short. *)
  | Sector_blocked
      (** Stage 2 in a [Weak] sector, or Stage 4 in a [Strong] one. *)

type ticker_row = {
  ticker : string;
  sector : string option;  (** From [ticker_sectors]; [None] if unmapped. *)
  recent_closes : float list;  (** The last few weekly closes, oldest first. *)
  volume_ratio : float option;
      (** This week's volume over the average of the prior four weeks. *)
  prior_stage : Weinstein_types.stage option;
      (** Last Friday's stage: the state the strategy carries between weeks. *)
  stage : Stage.result;  (** This Friday's classification. *)
  pre_screen : pre_screen;
}
(** Stages 1 and 2 for one stock, plus the pre-screen of stage 4. *)

type sector_row = {
  sector_name : string;
  etf : string;
  context : Screener.sector_context option;
      (** [None] when the ETF has too little history to rate. *)
}

type ranked_row = {
  ticker : string;
  side : Trading_base.Types.position_side;
  score : int;
  grade : Weinstein_types.grade;
  tiebreak_key : int option;
      (** The seeded tiebreak key, under the two seeded ranking modes. *)
  above_cut : bool;  (** Inside [max_buy_candidates] / [max_short_candidates]. *)
}

type walk_row = {
  candidate : Screener.scored_candidate;
  outcome : Weinstein_strategy.Audit_recorder.walk_outcome;
  gate : Weinstein_strategy.Entry_stop_width_order.gate_stop option;
      (** The trigger, initial stop and stop distance the width gate saw. *)
  entry : Weinstein_strategy.Audit_recorder.entry_event option;
      (** The strategy's own entry record; present exactly when placed. *)
  cash_before : float;
  cash_after : float;
}

type order = {
  symbol : string;
  side : Trading_base.Types.position_side;
  quantity : float;
  trigger : float;
  stop : float option;  (** The initial stop the walk registered. *)
}

type setup = {
  date : Core.Date.t;
  config : Weinstein_strategy.Weinstein_strategy_config.config;
  cash : float;
  portfolio_value : float;
}

type t = {
  setup : setup;
  tickers : ticker_row list;  (** Stages 1 and 2, and the pre-screen. *)
  macro : Macro.result;  (** Stage 3. *)
  sectors : sector_row list;  (** Stage 4. *)
  cascade : Weinstein_strategy.Audit_recorder.cascade_drop list;
      (** Stages 5 and 6: every analysed stock and side, and where it stopped.
      *)
  ranking : ranked_row list;  (** Stage 7: per side, best first. *)
  walk : walk_row list;  (** Stage 8, in walk order. *)
  orders : order list;  (** Stage 9. *)
}
