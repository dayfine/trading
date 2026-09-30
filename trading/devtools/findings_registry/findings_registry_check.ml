(* Findings-registry check (issue #3001). See lib/findings_registry_lib.mli
   and .claude/rules/findings-registry.md.

   Usage: findings_registry_check.exe REPO_ROOT REGISTRY_FILE VALIDATOR_SOURCE
   Prints one "FAIL:" line per violation and exits 1; exit 2 on unreadable
   input; prints OK and exits 0 otherwise. *)

open Findings_registry_lib

let _read path =
  try
    let ic = open_in_bin path in
    let s = really_input_string ic (in_channel_length ic) in
    close_in ic;
    Some s
  with Sys_error _ -> None

let _die msg =
  prerr_endline ("ERROR: " ^ msg);
  exit 2

let _load_rows registry =
  match Sexplib.Sexp.load_sexps registry with
  | sexps -> parse sexps
  | exception e ->
      _die (Printf.sprintf "cannot read %s: %s" registry (Printexc.to_string e))

let _run repo_root registry validator_source =
  let rows, parse_errors = _load_rows registry in
  let validators =
    match _read validator_source with
    | Some s -> registered_validators s
    | None -> _die ("cannot read " ^ validator_source)
  in
  if validators = [] then _die ("no validator ids found in " ^ validator_source);
  let read_file rel = _read (Filename.concat repo_root rel) in
  let errors = parse_errors @ check_rows ~validators ~read_file rows in
  List.iter (fun e -> Printf.printf "FAIL: findings registry: %s\n" e) errors;
  if errors <> [] then exit 1;
  Printf.printf "OK: findings registry -- %d rows, all guards present.\n"
    (List.length rows)

let () =
  match Sys.argv with
  | [| _; root; registry; source |] -> _run root registry source
  | _ ->
      _die "usage: findings_registry_check REPO_ROOT REGISTRY VALIDATOR_SOURCE"
