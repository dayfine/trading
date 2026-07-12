(** Checks that need the per-symbol bar store: V3 (dollar-ADV floor), V4 (stale
    open position), V7 (virgin-territory vs history), V9 (overhead supply), V10
    (entry-week spike). *)

open Validator_types

val check_v3 : inputs -> Validator_step.finding
(** V3 (INV): entry-week dollar-ADV at or above [min_entry_dollar_adv]. No-op
    when the gate is unarmed ([min_entry_dollar_adv = None]). *)

val check_v4 : inputs -> Validator_step.finding
(** V4 (INV): no open position whose last bar is older than
    [stale_exit_after_days] before run end. No-op when unarmed. *)

val check_v7 : inputs -> Validator_step.finding
(** V7 (INV): a [Virgin_territory] label is backed by at least
    [virgin_lookback_bars] weekly bars of history. *)

val check_v9 : inputs -> Validator_step.finding
(** V9 (EXP): no LONG entry sitting beneath a prior top within [overhead_pct]
    above the entry. *)

val check_v10 : inputs -> Validator_step.finding
(** V10 (EXP): no LONG entry whose entry-week close is more than [spike_pct]
    above the [spike_lookback_weeks]-ago close. *)
