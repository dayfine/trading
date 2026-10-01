(** Weinstein-conformance rule predicates R1-R8 (plus the R6 pre-entry-closes
    window helpers). Re-exported by [Trade_audit_ratings]; see its .mli for the
    contract. *)

open Core
open Trade_audit_ratings_types

(* Rule predicates -------------------------------------------------------- *)

let _is_long (e : Backtest.Trade_audit.entry_decision) =
  Trading_base.Types.equal_position_side e.side Long

let _is_short (e : Backtest.Trade_audit.entry_decision) =
  Trading_base.Types.equal_position_side e.side Short

let _is_stage2 = function Weinstein_types.Stage2 _ -> true | _ -> false
let _is_stage3 = function Weinstein_types.Stage3 _ -> true | _ -> false
let _is_stage4 = function Weinstein_types.Stage4 _ -> true | _ -> false

let _ma_flat_or_rising (m : Weinstein_types.ma_direction) =
  match m with
  | Weinstein_types.Rising | Weinstein_types.Flat -> true
  | Weinstein_types.Declining -> false

let _ma_flat_or_falling (m : Weinstein_types.ma_direction) =
  match m with
  | Weinstein_types.Declining | Weinstein_types.Flat -> true
  | Weinstein_types.Rising -> false

let _eval_r1 (e : Backtest.Trade_audit.entry_decision) =
  if not (_is_long e) then Not_applicable
  else if _is_stage2 e.stage && _ma_flat_or_rising e.ma_direction then Pass
  else Fail

let _eval_r2 ~config (e : Backtest.Trade_audit.entry_decision) =
  if not (_is_long e) then Not_applicable
  else
    match e.volume_quality with
    | None -> Not_applicable
    | Some (Weinstein_types.Strong ratio)
      when Float.( >= ) ratio config.volume_confirmation_min_ratio ->
        Pass
    | Some (Weinstein_types.Strong _) -> Marginal
    | Some (Weinstein_types.Adequate _) -> Marginal
    | Some (Weinstein_types.Weak _) -> Fail

let _eval_r3 (e : Backtest.Trade_audit.entry_decision) =
  if not (_is_long e) then Not_applicable
  else if _is_stage4 e.stage then Fail
  else Pass

let _eval_r4 (e : Backtest.Trade_audit.entry_decision) =
  if not (_is_short e) then Not_applicable
  else if _ma_flat_or_falling e.ma_direction then Pass
  else Fail

let _eval_r5 (e : Backtest.Trade_audit.entry_decision) =
  if not (_is_short e) then Not_applicable
  else if _is_stage4 e.stage then Pass
  else Fail

(* R6 pre-entry price context: daily closes at or before the entry, oldest
   first. Supplied by the report/bin from a bar source (the audit record itself
   carries no pre-entry bars). Empty when no bar source was wired in — R6 then
   reports [Not_applicable] rather than synthesising a verdict. *)
type pre_entry_closes = (Date.t * float) list

let _no_closes : pre_entry_closes = []

(* Restrict [closes] to the lookback window [entry_date - lookback, entry_date)
   — bars strictly before the entry, within [lookback] calendar days. *)
let _closes_in_window ~lookback ~entry_date (closes : pre_entry_closes) =
  List.filter closes ~f:(fun (d, _) ->
      let gap = Date.diff entry_date d in
      gap > 0 && gap <= lookback)

(* Deepest peak-to-trough drop in [closes] plus the trough's date. Scans oldest
   first tracking the running peak; the max drop is [(peak - close) / peak] at
   the trough. Returns [None] when there is no positive peak to measure against.
*)
let _max_drawdown (closes : pre_entry_closes) : (float * Date.t) option =
  List.fold closes ~init:(0.0, None) ~f:(fun (peak, best) (d, close) ->
      let peak = Float.max peak close in
      if Float.( <= ) peak 0.0 then (peak, best)
      else
        let drop = (peak -. close) /. peak in
        match best with
        | Some (bd, _) when Float.( >= ) bd drop -> (peak, best)
        | _ -> (peak, Some (drop, d)))
  |> snd

(** Weinstein Ch.4 plunge-buy avoidance. A long entry is flagged [Fail] when a
    drop of at least [config.recent_plunge_min_drop_pct] occurred within
    [config.recent_plunge_lookback_days] before the entry AND that drop's trough
    sits within [config.recent_plunge_proximity_days] of the entry — i.e. the
    strategy bought into a fresh plunge. Otherwise [Pass]. Reports
    [Not_applicable] when fewer than two in-window closes are available
    (insufficient pre-entry history to judge). *)
let _recent_plunge_verdict ~config ~entry_date (closes : pre_entry_closes) =
  let window =
    _closes_in_window ~lookback:config.recent_plunge_lookback_days ~entry_date
      closes
  in
  if List.length window < 2 then Not_applicable
  else
    match _max_drawdown window with
    | None -> Not_applicable
    | Some (drop, trough_date) ->
        let near_entry =
          Date.diff entry_date trough_date
          <= config.recent_plunge_proximity_days
        in
        if Float.( >= ) drop config.recent_plunge_min_drop_pct && near_entry
        then Fail
        else Pass

let _eval_r6 ~config ~closes (e : Backtest.Trade_audit.entry_decision) =
  if not (_is_long e) then Not_applicable
  else _recent_plunge_verdict ~config ~entry_date:e.entry_date closes

(* The [exit_trigger] label the drawdown breaker stamps on every
   force-liquidation exit — [Weinstein_strategy.Force_liquidation_runner
   .exit_label], carried on the transition's [StrategySignal] and mapped to
   [Stop_log.Strategy_signal] by [exit_trigger_of_reason]. Spelled literally
   rather than taken as a library dependency, for the same reason
   [Validator_types._default_fallback_exit_labels] spells it: this analysis
   layer sits below the strategy layer that owns the token. *)
let _force_liquidation_exit_label = "force_liquidation"

(* Whether an exit trigger is a drawdown-breaker (force-liquidation) exit. *)
let _is_force_liquidation (trigger : Backtest.Stop_log.exit_trigger) =
  match trigger with
  | Strategy_signal { label; _ } ->
      String.equal label _force_liquidation_exit_label
  | _ -> false

(* R7's verdict from an exit trigger plus the entry/exit stage shape. Two
   distinct failure modes, checked in this order:

   1. Force-liquidation — the drawdown breaker is the safety net, not a
      strategy signal, so its firing is by construction evidence the
      protective stop never removed the position. Unconditional [Fail]:
      unlike the held-through shape below it needs no stage comparison, so it
      also catches the breaker firing on a short, or while the classifier
      still reads Stage 2/3 (the case where the stop most clearly failed).
   2. Held through Stage3 -> Stage4 — a long entered in Stage 2/3 and exited
      in Stage 4 on anything other than [Stop_loss] / [Signal_reversal] rode
      the transition down instead of exiting on signal. *)
let _r7_of_trigger ~entered_long ~entered_stage_2_or_3 ~exited_in_stage_4
    (trigger : Backtest.Stop_log.exit_trigger) =
  if _is_force_liquidation trigger then Fail
  else if entered_long && entered_stage_2_or_3 && exited_in_stage_4 then
    match trigger with Stop_loss _ | Signal_reversal _ -> Pass | _ -> Fail
  else Pass

(** R7 reads the enriched [exit_] when the record has one. When it does not, the
    reason-only [external_exit] can still answer failure mode 1 — it carries an
    [exit_trigger] but no [stage_at_exit], and mode 1 needs none. Every other
    trigger on that path stays {!Not_applicable}, as does a still-open position.
*)
let _eval_r7 (e : Backtest.Trade_audit.entry_decision)
    (x : Backtest.Trade_audit.exit_decision option)
    (ext : Backtest.Trade_audit.external_exit_decision option) =
  match x with
  | Some exit_d ->
      _r7_of_trigger ~entered_long:(_is_long e)
        ~entered_stage_2_or_3:(_is_stage2 e.stage || _is_stage3 e.stage)
        ~exited_in_stage_4:(_is_stage4 exit_d.stage_at_exit)
        exit_d.exit_trigger
  | None -> (
      match ext with
      | Some ext_d when _is_force_liquidation ext_d.exit_trigger -> Fail
      | Some _ | None -> Not_applicable)

let _eval_r8 (e : Backtest.Trade_audit.entry_decision) =
  match (e.side, e.macro_trend) with
  | Long, Weinstein_types.Bullish -> Pass
  | Long, Weinstein_types.Neutral -> Marginal
  | Long, Weinstein_types.Bearish -> Fail
  | Short, Weinstein_types.Bearish -> Pass
  | Short, Weinstein_types.Neutral -> Marginal
  | Short, Weinstein_types.Bullish -> Fail
