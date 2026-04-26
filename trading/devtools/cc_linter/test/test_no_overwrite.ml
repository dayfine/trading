(* Smoke test: cc_linter must never overwrite its input .ml files.
   Regression for the 2026-04-25 incident where invoking
   `cc_linter.exe a.ml b.ml` clobbered b.ml with the JSON report.

   Steps:
   1. Write two trivial OCaml files to a tmpdir.
   2. Record their MD5 digests before running the linter.
   3. Run cc_linter with both files as positional arguments (the bug pattern).
   4. Assert each file has byte-identical content afterwards. *)

let () = Random.self_init ()

let write_file path content =
  let oc = open_out path in
  output_string oc content;
  close_out oc

let read_file path =
  let ic = open_in path in
  let n = in_channel_length ic in
  let s = Bytes.create n in
  really_input ic s 0 n;
  close_in ic;
  Bytes.to_string s

let digest path = Digest.to_hex (Digest.file path)

let () =
  let tmpdir =
    Filename.concat (Filename.get_temp_dir_name ()) "cc_linter_test"
  in
  (try Unix.mkdir tmpdir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  let file_a = Filename.concat tmpdir "module_a.ml" in
  let file_b = Filename.concat tmpdir "module_b.ml" in
  write_file file_a "let f x = x + 1\n";
  write_file file_b "let g x = x * 2\n";
  let digest_a_before = digest file_a in
  let digest_b_before = digest file_b in
  (* Locate the cc_linter binary relative to the test executable.
     Under dune runtest the binary is in the same _build tree. *)
  let linter =
    Filename.concat (Filename.dirname Sys.executable_name) "../cc_linter.exe"
  in
  (* Use tmpdir as trading_root (so scanner finds the two .ml files in lib/)
     and also pass the two .ml paths as extra positional args to replicate
     the bug pattern. The linter must NOT write to file_b even though it is
     the second positional argument. *)
  let cmd =
    Printf.sprintf "%s %s %s %s > /dev/null 2>&1" linter tmpdir file_a file_b
  in
  let _exit_code = Sys.command cmd in
  (* Assert byte-identity: neither file was overwritten *)
  let digest_a_after = digest file_a in
  let digest_b_after = digest file_b in
  let content_b_after = read_file file_b in
  if digest_a_before <> digest_a_after then (
    Printf.eprintf
      "FAIL: cc_linter overwrote module_a.ml (first positional arg / \
       trading_root)\n";
    exit 1);
  if digest_b_before <> digest_b_after then (
    Printf.eprintf
      "FAIL: cc_linter overwrote module_b.ml (extra positional arg)\n\
      \  Expected: let g x = x * 2\\n\n\
      \  Got:      %s\n"
      content_b_after;
    exit 1);
  Printf.printf "OK: cc_linter — no input files were overwritten.\n"
