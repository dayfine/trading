(** Scale-in add runner — wires {!Scale_in_detector} into the Weinstein strategy
    (explore/exploit scale-in v1,
    [dev/plans/capital-management-scale-in-2026-07-02.md] §3).

    {1 What it emits}

    On Friday ticks with [config.enable_scale_in = true], for each symbol whose
    {b only} position is a Long in [Holding] (a sibling already Entering or
    Exiting disarms the symbol) and whose add budget
    ([scale_in_config.max_adds]) is unused: when the revealed-strength signal
    fires ({!Scale_in_detector.add_signal} over the weekly bars strictly after
    the entry week) and every gate passes, emits a {b sibling} [CreateEntering]
    — its own position id ({!Entry_audit_capture.gen_position_id}), its own
    lifecycle, the same symbol. The add {b does not touch} [stop_states]: both
    sibling units ride the ticker's existing trailing stop (one stop discipline
    governs the combined position; the stops runner advances the shared machine
    once per tick and emits per-position transitions for both — see
    {!Stops_runner}).

    {1 Gates (all must pass)}

    - macro admits longs (Bearish always blocks; Neutral per
      [config.neutral_blocks_longs]) — the buy gate applies to adds too;
    - halt state inactive; Friday (screening day) only;
    - stage: [Stage2 { late = false }] when [scale_in_config.require_not_late]
      (any recorded Stage 2 otherwise); no recorded stage → no add;
    - extension: current close within [scale_in_config.extension_max_pct] of the
      30-week MA ({!Scale_in_detector.extended_above_ma}); no MA reading → no
      add;
    - a live stop below the current close (no defined risk → no add);
    - sizing: the add is the remaining risk fraction
      ([1 - initial_entry_fraction]) of a full unit, aggregate symbol notional
      capped at [portfolio_config.max_position_pct_long] (the reallocation never
      exceeds the existing per-name envelope), share count > 0;
    - cash: full cost fits in the remaining cash budget (no partial adds).

    {1 Arbitration}

    The caller runs this BEFORE the fresh-entry walk and passes the entry walk a
    cash budget reduced by the consumed amount — a revealed-strength add
    outranks an unproven fresh entry for scarce cash (plan §3.3). The
    explore/exploit split thus emerges from the signal rate; no explicit regime
    input.

    {1 Bookkeeping}

    [scale_in_added] (symbol → adds emitted) is strategy-closure state, marked
    at {b emit} time — conservative: an add order that is later cancelled or
    never fills still consumes the symbol's budget (fails toward fewer adds,
    never more). A residual edge is documented in the plan: an unfilled add
    whose sibling stops out may still fill once; the ticker's (triggered) stop
    state exits it on a subsequent tick. *)

open Core
open Trading_strategy

val add_reasoning_description : string
(** [entry_reasoning] description marking scale-in adds in audit output. *)

val run :
  config:Weinstein_strategy_config.config ->
  positions:Position.t String.Map.t ->
  portfolio:Portfolio_view.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  bar_reader:Bar_reader.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  prior_stage_ma_values:float Hashtbl.M(String).t ->
  stop_states:Weinstein_stops.stop_state String.Map.t ref ->
  scale_in_added:int Hashtbl.M(String).t ->
  macro_result_opt:Macro.result option ->
  is_screening_day:bool ->
  halted:bool ->
  current_date:Date.t ->
  Position.transition list * float
(** [(add_transitions, cash_consumed)]. [([], 0.)] whenever
    [config.enable_scale_in = false] (bit-identical no-op), off-Friday, halted,
    or the macro gate blocks. Deterministic: candidates evaluated in symbol
    order. Mutates [scale_in_added] for emitted adds only. *)
