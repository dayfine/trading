(* Regression test for H-SEXP-DRIFT-VACUOUS-PASS: the linter must fail
   loudly when the scan itself finds implausibly few files, never print
   "OK:" and exit 0. Pre-fix, both scenarios below exited 0 (verified live
   during development by reverting the fix); this test pins the corrected
   behavior so a regression reddens it.

   Exercises the two masking cases named in the finding:
   1. A trading-root argument that does not exist on disk at all.
   2. A trading-root argument that exists but is empty -- the "moved
      trading/ dir" / "wrong-cwd invocation" shape, where the scan silently
      finds nothing rather than a genuinely small tree.

   The linter binary is located relative to this test executable, same
   pattern as devtools/cc_linter/test/test_no_overwrite.ml. *)

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

let _run_linter root =
  let out_path = Filename.temp_file "sexp_drift_test" ".out" in
  let cmd = Printf.sprintf "%s %s > %s 2>&1" (linter_exe ()) root out_path in
  let exit_code = Sys.command cmd in
  let ic = open_in out_path in
  let out = really_input_string ic (in_channel_length ic) in
  close_in ic;
  Sys.remove out_path;
  (exit_code, out)

let _assert_fails_loudly label root expected_substring =
  let exit_code, out = _run_linter root in
  if exit_code = 0 then (
    Printf.eprintf
      "FAIL: %s -- linter exited 0 on a vacuous scan (should fail loudly)\n\
      \  output: %s\n"
      label out;
    exit 1);
  if not (_contains_substring out expected_substring) then (
    Printf.eprintf "FAIL: %s -- output missing %S\n  output: %s\n" label
      expected_substring out;
    exit 1)

let () =
  let tmp_empty =
    Filename.concat (Filename.get_temp_dir_name ()) "sexp_drift_test_empty_root"
  in
  (try Unix.mkdir tmp_empty 0o755
   with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  _assert_fails_loudly "absent trading-root"
    "/tmp/sexp_drift_test_does_not_exist_xyz" "does not exist";
  _assert_fails_loudly "empty trading-root" tmp_empty "below the expected floor";
  Printf.printf
    "OK: sexp_default_drift_linter -- fails loudly on vacuous scans (absent \
     root, empty root).\n"
