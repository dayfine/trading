(** CLI for the cross-arm validator gate.

    Loads two or more [<out>.sexp] reports written by
    [post_run_validator_cli.exe], compares their per-check violation counts, and
    turns the answer into an exit code so an experiment chain can refuse to
    quote a delta between two arms that hold different instrument sets. See
    {!Post_run_validator.Validator_diff} for the rule and issue #2730 (ask 2)
    for the specimen that motivated it. *)

open Core
module Vt = Post_run_validator.Validator_types
module Vd = Post_run_validator.Validator_diff

(* Distinct from [_exit_differ] so a chain can tell "the arms disagree" (a real
   finding) from "I could not read the reports" (an operator error). *)
let _exit_agree = 0
let _exit_differ = 1
let _exit_usage = 2

(* [Sexp.load_sexp] raises on a missing file, and [report_of_sexp] raises on a
   sexp of the wrong shape. An escaping exception exits 1 — the code that means
   "the arms differ", a real finding — so both are funnelled onto the [Error]
   path and out through [_exit_usage] like every other operator error. Pinned by
   devtools/checks/validator_diff_exit_codes_smoke.sh. *)
let _load_report ~label path =
  Or_error.try_with (fun () ->
      { Vd.label; report = Vt.report_of_sexp (Sexp.load_sexp path) })
  |> Result.map_error ~f:(fun err ->
      sprintf "could not read report %S from %S: %s" label path
        (Error.to_string_hum err))

let _parse_report_arg arg =
  match String.lsplit2 arg ~on:'=' with
  | Some (label, path)
    when (not (String.is_empty label)) && not (String.is_empty path) ->
      _load_report ~label path
  | _ -> Error (sprintf "-report expects LABEL=PATH, got %S" arg)

let _parse_severity = function
  | "invariant" -> Ok Vd.Invariant_only
  | "all" -> Ok Vd.All_checks
  | s -> Error (sprintf "-severity expects invariant|all, got %S" s)

let _compute ~report_args ~check_ids ~severity_arg =
  let open Result.Let_syntax in
  let%bind severity = _parse_severity severity_arg in
  let%bind reports = List.map report_args ~f:_parse_report_arg |> Result.all in
  Vd.compute ~check_ids ~severity reports
  |> Result.map_error ~f:(fun (st : Status.t) -> st.message)

let _run ~report_args ~check_ids ~severity_arg =
  match _compute ~report_args ~check_ids ~severity_arg with
  | Error msg ->
      prerr_endline ("validator_diff: " ^ msg);
      exit _exit_usage
  | Ok t ->
      print_endline (Vd.render t);
      if Vd.agreed t then (
        print_endline "OK: every selected check agrees across all reports";
        exit _exit_agree)
      else (
        print_endline
          "FAIL: validator invariant counts differ -- these arms hold \
           different instrument sets and their delta is not a paired read";
        exit _exit_differ)

let _report_doc =
  "LABEL=PATH a validator report sexp under a short arm name (repeatable; at \
   least two)"

let _check_doc =
  "ID compare only this check id (repeatable); overrides -severity"

let _severity_doc =
  "invariant|all which checks to compare when -check is absent (default \
   invariant)"

let command =
  Command.basic
    ~summary:"Diff post-run validator reports across arms (paired-read gate)"
    (let%map_open.Command report_args =
       flag "-report" (listed string) ~doc:_report_doc
     and check_ids = flag "-check" (listed string) ~doc:_check_doc
     and severity_arg =
       flag "-severity"
         (optional_with_default "invariant" string)
         ~doc:_severity_doc
     in
     fun () -> _run ~report_args ~check_ids ~severity_arg)

let () = Command_unix.run command
