open Core

let dollar_adv_for ~(config : Liquidity_config.t) ~bar_reader ~current_date
    ticker =
  Liquidity_metric.dollar_adv ~aggregation:config.adv_aggregation
    ~trim_pct:config.adv_trim_pct
    ?split_divisor:(Bar_reader.split_divisor_for bar_reader ~symbol:ticker)
    ~lookback_days:config.adv_lookback_days
    (Bar_reader.daily_bars_for bar_reader ~symbol:ticker ~as_of:current_date)

let apply ~(config : Liquidity_config.t) ~bar_reader ~current_date candidates =
  Liquidity_gate.filter ~min_entry_dollar_adv:config.min_entry_dollar_adv
    ~dollar_adv_for:(dollar_adv_for ~config ~bar_reader ~current_date)
    candidates

let participation_allows ~max_participation ~position_dollars ~dollar_adv =
  match (max_participation, dollar_adv) with
  | None, _ | _, None -> true
  | Some p, Some adv -> Float.( <= ) position_dollars (p *. adv)

(* The ADV is computed only when the cap is armed, so the default ([None]) path
   reads no bars. *)
let within_participation ~(config : Liquidity_config.t) ~bar_reader
    ~current_date ~ticker ~position_dollars =
  match config.max_entry_adv_participation with
  | None -> true
  | Some _ as max_participation ->
      participation_allows ~max_participation ~position_dollars
        ~dollar_adv:(dollar_adv_for ~config ~bar_reader ~current_date ticker)

let cap_entry_attempt ~config ~bar_reader ~current_date
    (cand : Screener.scored_candidate) :
    Entry_audit_capture.entry_attempt_result ->
    Entry_audit_capture.entry_attempt_result = function
  | Entry_ok (_, meta) as ok ->
      let position_dollars =
        Float.of_int meta.shares *. meta.effective_entry_price
      in
      if
        within_participation ~config ~bar_reader ~current_date
          ~ticker:cand.ticker ~position_dollars
      then ok
      else Over_adv_participation
  | (Stop_too_wide | Sized_zero | No_structural_stop _ | Over_adv_participation)
    as other ->
      other
