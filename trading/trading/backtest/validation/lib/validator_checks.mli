(** The 11 invariant / expectation checks (V1-V11) + the driver.

    Each check is a pure function over parsed rows + injected lookups, so it is
    testable without files. See [dev/plans/post-run-validation-2026-07-12.md].
*)

open Validator_types

val all_check_ids : string list
(** The 11 check ids in report order: ["V1"] .. ["V11"]. *)

val run_check : id:string -> inputs -> check_result
(** [run_check ~id inputs] runs the single check [id] over [inputs], applying
    the config's severity override and capping specimens at 10. Raises if [id]
    is unknown. *)

val validate : inputs -> report
(** Run every check in {!all_check_ids} not listed in
    [inputs.config.disabled_checks]. *)
