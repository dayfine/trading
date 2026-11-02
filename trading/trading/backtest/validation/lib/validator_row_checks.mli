(** Checks computable from the parsed rows + audit lookup alone (no bars): V1
    (stage), V2 (macro), V5 (trigger consistency), V8 (declining MA), V11
    (stop-distance bounds). V6 (twin positions) reads the share-class map too
    and lives in {!Validator_twin_check}. *)

open Validator_types

val check_v1 : inputs -> Validator_step.finding
(** V1 (INV): every LONG entry's audit stage is Stage2. *)

val check_v2 : inputs -> Validator_step.finding
(** V2 (INV): no LONG entry under a Bearish macro trend. *)

val check_v5 : inputs -> Validator_step.finding
(** V5 (INV): [exit_trigger] and [stop_trigger_kind] are mutually consistent. *)

val check_v8 : inputs -> Validator_step.finding
(** V8 (EXP): no LONG entry with a Declining MA at entry. *)

val check_v12 : inputs -> Validator_step.finding
(** V12 (INV): every filled entry's installed stop sits within
    [config.gate_max_stop_distance_pct] of at least one base the gate could have
    measured from: the screener's [E] (the gate's [effective_entry] on runs that
    arm [sim_entry_trigger_at_suggested]) or the decision-bar close (its
    [effective_entry] by default). V12 fails only when the stop is wider than
    the gate from {b every} available base, so neither mode raises a false row.
    The fill is not used: it sits on the split-restated basis of [trades.csv]
    and may land up to 2 % above [E] (#3420); only a legacy audit with neither
    base falls back to it. I.e. the [Stop_too_wide] gate that should have
    rejected a wider stop actually fired. Skips rows with no audit join or no
    captured [installed_stop]. *)

val check_v11 : inputs -> Validator_step.finding
(** V11 (EXP): [stop_initial_distance_pct] within the configured bounds. *)
