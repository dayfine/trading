open Core
open Validator_types
module R = Validator_row_checks
module B = Validator_bar_checks

let _specimen_cap = 10

let _registry : (string * severity * (inputs -> Validator_step.finding)) list =
  [
    ("V1", Invariant, R.check_v1);
    ("V2", Invariant, R.check_v2);
    ("V3", Invariant, B.check_v3);
    ("V4", Invariant, B.check_v4);
    ("V5", Invariant, R.check_v5);
    ("V6", Invariant, R.check_v6);
    ("V7", Invariant, B.check_v7);
    ("V8", Expectation, R.check_v8);
    ("V9", Expectation, B.check_v9);
    ("V10", Expectation, B.check_v10);
    ("V11", Expectation, R.check_v11);
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
    specimens = List.take violations _specimen_cap;
  }

let run_check ~id inputs =
  match List.find _registry ~f:(fun (i, _, _) -> String.equal i id) with
  | None -> failwithf "unknown check id: %s" id ()
  | Some (_, default_sev, fn) ->
      _result_of ~id ~default_sev ~config:inputs.config (fn inputs)

let validate inputs =
  let disabled = inputs.config.disabled_checks in
  let ids =
    List.filter all_check_ids ~f:(fun id ->
        not (List.mem disabled id ~equal:String.equal))
  in
  { checks = List.map ids ~f:(fun id -> run_check ~id inputs) }
