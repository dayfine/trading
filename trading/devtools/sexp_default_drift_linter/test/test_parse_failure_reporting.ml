(* Regression test for H-SEXP-DRIFT-SILENT-PARSE-SKIP: a file the linter
   cannot parse must be reported loudly (non-zero exit), never silently
   dropped from the scan. Pre-fix, [parse_ml]/[parse_mli] caught every
   exception and returned empty results, so this fixture's malformed file
   contributed nothing and the run still printed "OK:" and exited 0
   (verified live during development by reverting the fix).

   Builds a synthetic fixture root with enough trivial lib/*.ml files to
   clear the linter's own vacuous-scan floor (H-SEXP-DRIFT-VACUOUS-PASS,
   min_expected_lib_files = 500 in the linter), so this test exercises the
   parse-failure path specifically rather than tripping the floor check
   first. One variant of the fixture also carries a syntactically invalid
   .ml file.

   The linter binary is located relative to this test executable, same
   pattern as devtools/cc_linter/test/test_no_overwrite.ml. *)

(* Comfortably above the linter's min_expected_lib_files (500), so this
   fixture is unambiguously a "real" scan and any FAIL is attributable to
   the parse-failure check, not the floor check. *)
let fixture_file_count = 520

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

(* Populates [lib_dir] with [fixture_file_count] trivial, parseable .ml
   files, then optionally adds one file with invalid OCaml syntax. *)
let _populate_fixture lib_dir ~with_broken_file =
  for i = 1 to fixture_file_count do
    _write_file
      (Filename.concat lib_dir (Printf.sprintf "mod_%d.ml" i))
      (Printf.sprintf "let f_%d x = x + 1\n" i)
  done;
  if with_broken_file then
    _write_file
      (Filename.concat lib_dir "broken.ml")
      "let f x = (((( not valid ocaml syntax\n"

let _build_fixture_root ~with_broken_file =
  let root =
    Filename.concat
      (Filename.get_temp_dir_name ())
      (Printf.sprintf "sexp_drift_parse_test_%b" with_broken_file)
  in
  let lib_dir = Filename.concat root "lib" in
  _mkdir_if_absent root;
  _mkdir_if_absent lib_dir;
  _populate_fixture lib_dir ~with_broken_file;
  root

let _run_linter root =
  let out_path = Filename.temp_file "sexp_drift_parse_test" ".out" in
  let cmd = Printf.sprintf "%s %s > %s 2>&1" (linter_exe ()) root out_path in
  let exit_code = Sys.command cmd in
  let ic = open_in out_path in
  let out = really_input_string ic (in_channel_length ic) in
  close_in ic;
  Sys.remove out_path;
  (exit_code, out)

let () =
  let clean_root = _build_fixture_root ~with_broken_file:false in
  let clean_exit, clean_out = _run_linter clean_root in
  if clean_exit <> 0 then (
    Printf.eprintf
      "FAIL: all-parseable fixture unexpectedly failed (exit %d)\n\
      \  output: %s\n"
      clean_exit clean_out;
    exit 1);
  let broken_root = _build_fixture_root ~with_broken_file:true in
  let broken_exit, broken_out = _run_linter broken_root in
  if broken_exit = 0 then (
    Printf.eprintf
      "FAIL: fixture with an unparseable file exited 0 (should fail loudly \
       naming the file)\n\
      \  output: %s\n"
      broken_out;
    exit 1);
  if not (_contains_substring broken_out "broken.ml") then (
    Printf.eprintf
      "FAIL: unparseable-file failure output does not name broken.ml\n\
      \  output: %s\n"
      broken_out;
    exit 1);
  Printf.printf
    "OK: sexp_default_drift_linter -- reports an unparseable file loudly \
     (non-zero exit, names the file) instead of silently dropping it.\n"
