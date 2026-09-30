open Core
open Validator_types
module R = Validator_row_checks
module B = Validator_bar_checks
module S = Validator_splice_check
module F = Validator_fallback_check
module St = Validator_store_check
module A = Validator_audit_checks
module Sc = Validator_stall_check

let _specimen_cap = 10

(* A check's default severity is usually fixed; V23's depends on the run's
   config ([A.v23_severity]), so the registry stores it as a function. *)
let _inv _ = Invariant
let _exp _ = Expectation

let _registry :
    (string * (inputs -> severity) * (inputs -> Validator_step.finding)) list =
  [
    ("V1", _inv, R.check_v1);
    ("V2", _inv, R.check_v2);
    ("V3", _inv, B.check_v3);
    ("V4", _inv, B.check_v4);
    ("V5", _inv, R.check_v5);
    ("V6", _inv, R.check_v6);
    ("V7", _inv, B.check_v7);
    ("V8", _exp, R.check_v8);
    ("V9", _exp, B.check_v9);
    ("V10", _exp, B.check_v10);
    ("V11", _exp, R.check_v11);
    ("V12", _inv, R.check_v12);
    ("V13", _inv, B.check_v13);
    ("V14", _exp, B.check_v14);
    ("V15", _exp, S.check_v15);
    ("V16", _exp, F.check_v16);
    ("V17", _exp, F.check_v17);
    ("V18", _exp, St.check_v18);
    ("V19", _inv, A.check_v19);
    ("V20", _inv, A.check_v20);
    ("V21", _exp, A.check_v21);
    ("V22", _exp, Sc.check_v22);
    ("V23", A.v23_severity, A.check_v23);
  ]

let all_check_ids = List.map _registry ~f:(fun (id, _, _) -> id)
let _severity_of_string = function "INVARIANT" -> Invariant | _ -> Expectation

let _resolve_severity config ~id ~default =
  match List.Assoc.find config.severity_overrides id ~equal:String.equal with
  | Some s -> _severity_of_string s
  | None -> default

let _result_of ~id ~default_sev ~config (finding : Validator_step.finding) =
  let violations = List.rev finding.violations in
  {
    id;
    severity = _resolve_severity config ~id ~default:default_sev;
    passed = List.is_empty violations;
    n_violations = List.length violations;
    n_skipped = finding.skipped;
    skip_reason = finding.skip_reason;
    specimens = List.take violations _specimen_cap;
  }

let run_check ~id inputs =
  match List.find _registry ~f:(fun (i, _, _) -> String.equal i id) with
  | None -> failwithf "unknown check id: %s" id ()
  | Some (_, default_sev, fn) ->
      _result_of ~id ~default_sev:(default_sev inputs) ~config:inputs.config
        (fn inputs)

(* How many trades resolved to a trade_audit record. Surfaced in the report so a
   dead join (matched = 0) can't masquerade as "PASS (all skipped)". *)
let _audit_join inputs =
  let matched =
    List.count inputs.trades ~f:(fun t -> Option.is_some (inputs.audit t))
  in
  { matched; total = List.length inputs.trades }

let validate inputs =
  let disabled = inputs.config.disabled_checks in
  let ids =
    List.filter all_check_ids ~f:(fun id ->
        not (List.mem disabled id ~equal:String.equal))
  in
  {
    checks = List.map ids ~f:(fun id -> run_check ~id inputs);
    audit_join = _audit_join inputs;
  }
