(** Checks computable from the parsed rows + audit lookup alone (no bars): V1
    (stage), V2 (macro), V5 (trigger consistency), V6 (rename twins), V8
    (declining MA), V11 (stop-distance bounds). *)

open Validator_types

val check_v1 : inputs -> Validator_step.finding
(** V1 (INV): every LONG entry's audit stage is Stage2. *)

val check_v2 : inputs -> Validator_step.finding
(** V2 (INV): no LONG entry under a Bearish macro trend. *)

val check_v5 : inputs -> Validator_step.finding
(** V5 (INV): [exit_trigger] and [stop_trigger_kind] are mutually consistent. *)

val check_v6 : inputs -> Validator_step.finding
(** V6 (INV): no two symbols share identical entry/exit dates + prices (a
    rename-twin duplicate position). *)

val check_v8 : inputs -> Validator_step.finding
(** V8 (EXP): no LONG entry with a Declining MA at entry. *)

val check_v11 : inputs -> Validator_step.finding
(** V11 (EXP): [stop_initial_distance_pct] within the configured bounds. *)
