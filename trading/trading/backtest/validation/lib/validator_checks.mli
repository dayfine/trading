(** The 22 invariant / expectation checks (V1-V21, V23) + the driver.

    Each check is a pure function over parsed rows + injected lookups, so it is
    testable without files. See [dev/plans/post-run-validation-2026-07-12.md],
    [dev/plans/delisting-data-fix-2026-09-06.md] for V16/V17, issue #2732 for
    V18, and issue #3002 for V19-V23 (V22 is not built yet). *)

open Validator_types

val all_check_ids : string list
(** The 22 check ids in report order: ["V1"] .. ["V21"], then ["V23"]. *)

val run_check : id:string -> inputs -> check_result
(** [run_check ~id inputs] runs the single check [id] over [inputs] and caps
    specimens at 10. The severity is the check's default — fixed for every check
    except V23, whose default is read off [inputs]
    ({!Validator_audit_checks.v23_severity}) — unless
    [inputs.config.severity_overrides] names [id], which always wins. Raises if
    [id] is unknown. *)

val validate : inputs -> report
(** Run every check in {!all_check_ids} not listed in
    [inputs.config.disabled_checks]. *)
