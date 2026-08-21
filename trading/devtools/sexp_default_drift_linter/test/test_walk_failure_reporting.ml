(* Regression test for the CP4 finding raised in behavioral QC review of
   H-SEXP-DRIFT-VACUOUS-PASS / H-SEXP-DRIFT-SILENT-PARSE-SKIP (PR #2462,
   review 4993747068): [collect_lib_files]'s inner [walk] used to swallow
   any [Sys.readdir] failure on a subdirectory with [| exception _ -> ()],
   so a subtree lost to a permission error vanished from the scan with no
   signal as long as the surviving total still cleared
   [min_expected_lib_files] -- reproduced live in review with an 820-file
   fixture (520 readable + 300 behind a permission-denied directory) that
   still printed "OK: ... (scanned 520 files)" and exited 0.

   [walk] no longer swallows the exception: [collect_lib_files] now returns
   the failed directories alongside the collected files, and
   [_check_walk_failures] reports each one by name and exits 1 regardless
   of how many files were lost under it. This test pins that: a fixture
   with a readable [lib/] comfortably above the floor plus one directory
   that cannot be read must still fail loudly and name the directory.

   Root bypasses directory permission bits entirely (DAC override), so
   `chmod 000` alone is a no-op when the test runner is root -- confirmed
   live in the review that reproduced this defect. To make the permission
   check actually apply, the linter is invoked as the unprivileged "nobody"
   account (uid/gid 65534) via `setpriv` whenever the test process itself
   is root; when the test process is already unprivileged, the plain
   `chmod 000` is sufficient on its own and `setpriv` is skipped.

   The linter binary is located relative to this test executable, same
   pattern as devtools/cc_linter/test/test_no_overwrite.ml. *)

(* Comfortably above the linter's min_expected_lib_files (500), so a FAIL
   here is attributable to the walk-failure check, not the vacuous-scan
   floor -- the unreadable directory contributes nothing to this count. *)
let fixture_file_count = 501

let linter_exe () =
  Filename.concat
    (Filename.dirname Sys.executable_name)
    "../sexp_default_drift_linter.exe"

let _contains_substring s sub =
  let n = String.length s and m = String.length sub in
  if m > n then false
  else
    let found = ref false in
    let i = ref 0 in
    while (not !found) && !i + m <= n do
      if String.sub s !i m = sub then found := true;
      incr i
    done;
    !found

let _write_file path content =
  let oc = open_out path in
  output_string oc content;
  close_out oc

let _mkdir_if_absent path =
  try Unix.mkdir path 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ()

(* Builds <root>/lib/mod_<i>.ml x fixture_file_count (trivial, parseable),
   plus <root>/unreadable, chmod'd to 000 so any account other than root
   gets EACCES on [Sys.readdir root/unreadable]. [root] itself and [lib]
   stay 0755 so a non-root "nobody" invocation can still traverse down to
   the point of failure. *)
let _build_fixture_root () =
  let root =
    Filename.concat (Filename.get_temp_dir_name ()) "sexp_drift_walk_test_root"
  in
  let lib_dir = Filename.concat root "lib" in
  let unreadable_dir = Filename.concat root "unreadable" in
  (* Reset the unreadable dir's mode first -- if a prior run left it 000
     and this run is non-root, [Unix.mkdir]/writes below would themselves
     fail on stale state. *)
  (try Unix.chmod unreadable_dir 0o755
   with Unix.Unix_error (Unix.ENOENT, _, _) -> ());
  _mkdir_if_absent root;
  _mkdir_if_absent lib_dir;
  _mkdir_if_absent unreadable_dir;
  for i = 1 to fixture_file_count do
    _write_file
      (Filename.concat lib_dir (Printf.sprintf "mod_%d.ml" i))
      (Printf.sprintf "let f_%d x = x + 1\n" i)
  done;
  Unix.chmod unreadable_dir 0o000;
  root

let _run_linter root =
  let out_path = Filename.temp_file "sexp_drift_walk_test" ".out" in
  let base_cmd = Printf.sprintf "%s %s" (linter_exe ()) root in
  (* Root bypasses the chmod 000 above entirely, so the fixture only
     exercises the failure path if invoked as a non-root account. Drop to
     "nobody" (65534) via setpriv when the test process itself is root;
     otherwise the ambient non-root identity already makes chmod 000
     effective and setpriv would only fail (no CAP_SETUID to become an
     arbitrary uid). *)
  let cmd =
    if Unix.geteuid () = 0 then
      Printf.sprintf
        "setpriv --reuid 65534 --regid 65534 --clear-groups %s > %s 2>&1"
        base_cmd out_path
    else Printf.sprintf "%s > %s 2>&1" base_cmd out_path
  in
  let exit_code = Sys.command cmd in
  let ic = open_in out_path in
  let out = really_input_string ic (in_channel_length ic) in
  close_in ic;
  Sys.remove out_path;
  (exit_code, out)

let () =
  let root = _build_fixture_root () in
  let exit_code, out = _run_linter root in
  if exit_code = 0 then (
    Printf.eprintf
      "FAIL: fixture with an unreadable directory exited 0 (should fail loudly \
       naming the directory)\n\
      \  output: %s\n"
      out;
    exit 1);
  if not (_contains_substring out "unreadable") then (
    Printf.eprintf
      "FAIL: walk-failure output does not name the unreadable directory\n\
      \  output: %s\n"
      out;
    exit 1);
  Printf.printf
    "OK: sexp_default_drift_linter -- reports a directory that failed to read \
     mid-walk loudly (non-zero exit, names the directory) instead of silently \
     dropping whatever was under it.\n"
