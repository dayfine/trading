(** Stage-transition → trade-action mapping for the minimal per-symbol Weinstein
    stage strategy.

    The diagnostic strategy ignores every input except the stage transitions of
    a single symbol. This module is the pure mapping from
    [(from_stage, to_stage)] to one of three actions in each of the two variants
    — long-only and long-short. Used by {!Single_symbol_backtest} to drive the
    weekly walk.

    Pure functions; no I/O. *)

(** Two strategy variants. *)
type variant = Long_only | Long_short [@@deriving show, eq]

(** Trade action emitted by the signal on a given week.

    - [Enter_long]: buy 100% of cash at this week's close (transition into Stage
      2).
    - [Exit_long]: sell all long inventory at this week's close (transition into
      Stage 3).
    - [Enter_short]: short 100% of cash at this week's close (transition into
      Stage 4; long-short variant only).
    - [Exit_short]: cover short at this week's close (transition into Stage 1;
      long-short variant only).
    - [Hold]: no change. *)
type action = Enter_long | Exit_long | Enter_short | Exit_short | Hold
[@@deriving show, eq]

val action_of_transition :
  variant:variant ->
  prev_stage:Weinstein_types.stage option ->
  curr_stage:Weinstein_types.stage ->
  action
(** [action_of_transition ~variant ~prev_stage ~curr_stage] returns the action
    emitted by a stage observation.

    {2 Long-only mapping}
    - [None -> _]: [Hold] (first observation, no transition yet).
    - [Stage1 -> Stage2]: [Enter_long].
    - [Stage2 -> Stage3]: [Exit_long].
    - all other (from, to) including [Stage_n -> Stage_n]: [Hold].

    Note: a direct [Stage1 -> Stage3] transition (which the classifier can emit
    if it ever sees the corresponding pattern) maps to [Hold] in long-only — we
    only enter long on the canonical Stage1→2.

    {2 Long-short mapping}
    Same as long-only, plus:
    - [Stage3 -> Stage4]: [Enter_short].
    - [Stage4 -> Stage1]: [Exit_short].

    A [Stage2 -> Stage4] (the screener might emit this with a sharp regime
    change) does not flip directly long→short; it would map to [Hold] under this
    mapping. The expected sequence is
    [Stage2 -> Stage3 (exit) -> Stage4 (short)]. *)
