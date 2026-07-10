(** Unit + integration tests for {!Backtest.Csv_snapshot_builder} cleanup
    surface — see issue #1393 for the abnormal-exit leak this fixes.

    Three layers:

    - {b unit}: [register_for_cleanup] + [cleanup] + [registered_dirs] are pure
      ledger ops on string keys; no subprocess needed.
    - {b orphan-sweep unit}: [startup_orphan_sweep] keys on the
      [panel_runner_csv_snapshot_] prefix and an mtime threshold; verify it
      removes old entries and spares fresh ones and non-matching dirs.
    - {b abnormal-exit integration}: spawn a subprocess via the
      [csv_snapshot_builder_cleanup_subject.exe] helper that allocates a tmp
      dir, registers it, then either raises an uncaught exception or sends
      itself a SIGTERM. The parent verifies the dir is gone after the child
      exits. *)

open OUnit2
open Core
open Matchers
module Builder = Backtest.Csv_snapshot_builder

(* -------------- subject binary path -------------- *)

(* The subject binary lives next to this test exe in the _build tree (per
   the [executables] stanza in test/dune). It supports two modes via argv:
   "raise" — registers a tmp dir then raises an exception;
   "sigterm" — registers a tmp dir then kills itself with SIGTERM.
   In both cases it prints the dir path on stdout BEFORE the abnormal exit
   so the parent can verify cleanup. *)
let _subject_binary =
  Filename.concat
    (Filename.dirname Stdlib.Sys.executable_name)
    "csv_snapshot_builder_cleanup_subject.exe"

(* -------------- unit tests on the cleanup ledger -------------- *)

(* Use a sibling tmp dir under /tmp/cstest_<pid>_<seq>/ for these tests — we
   do NOT use Filename.temp_dir with the "panel_runner_csv_snapshot_" prefix
   because the unit-test process is long-lived (runs many tests) and we
   don't want the at_exit handler to fire mid-suite. The test-managed dirs
   are removed via Sys.command rm -rf at the end of each test. *)
let _seq = ref 0

let _make_tmpdir () =
  Int.incr _seq;
  let dir =
    Printf.sprintf "/tmp/cstest_%d_%d_%f"
      (Pid.to_int (Core_unix.getpid ()))
      !_seq
      (Core_unix.gettimeofday ())
  in
  Core_unix.mkdir_p dir;
  dir

let _rm_rf path =
  if Stdlib.Sys.file_exists path then
    ignore
      (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote path))
        : int)

let test_register_then_cleanup_removes_dir _ =
  let dir = _make_tmpdir () in
  Builder.register_for_cleanup dir;
  assert_that
    (List.mem (Builder.registered_dirs ()) dir ~equal:String.equal)
    (equal_to true);
  Builder.cleanup dir;
  assert_that (Stdlib.Sys.file_exists dir) (equal_to false);
  assert_that
    (List.mem (Builder.registered_dirs ()) dir ~equal:String.equal)
    (equal_to false)

let test_cleanup_is_idempotent _ =
  let dir = _make_tmpdir () in
  Builder.register_for_cleanup dir;
  Builder.cleanup dir;
  (* Second cleanup on an already-removed dir must not raise. *)
  Builder.cleanup dir;
  assert_that (Stdlib.Sys.file_exists dir) (equal_to false)

let test_cleanup_on_unregistered_dir_is_noop _ =
  let dir = _make_tmpdir () in
  (* Never registered — cleanup should still remove the dir but the ledger
     is unchanged for other entries. *)
  let dir_other = _make_tmpdir () in
  Builder.register_for_cleanup dir_other;
  Builder.cleanup dir;
  assert_that (Stdlib.Sys.file_exists dir) (equal_to false);
  assert_that
    (List.mem (Builder.registered_dirs ()) dir_other ~equal:String.equal)
    (equal_to true);
  Builder.cleanup dir_other

let test_register_is_idempotent _ =
  let dir = _make_tmpdir () in
  Builder.register_for_cleanup dir;
  Builder.register_for_cleanup dir;
  Builder.register_for_cleanup dir;
  let n_matching =
    Builder.registered_dirs () |> List.count ~f:(String.equal dir)
  in
  assert_that n_matching (equal_to 1);
  Builder.cleanup dir

(* -------------- orphan sweep unit tests -------------- *)

let test_orphan_sweep_removes_old_panel_runner_dirs _ =
  (* Create a dir that matches the prefix and backdate its mtime. The
     sweep should remove it. We use a 0.001-hour threshold (3.6 seconds)
     to avoid flakiness with the system clock. *)
  let dir =
    Stdlib.Filename.temp_dir "panel_runner_csv_snapshot_" "_test_orphan_old"
  in
  (* Backdate mtime to 1 hour ago. *)
  let one_hour_ago = Core_unix.gettimeofday () -. 3600.0 in
  Core_unix.utimes dir ~access:one_hour_ago ~modif:one_hour_ago;
  let (_ : int) = Builder.startup_orphan_sweep ~max_age_hours:0.001 () in
  (* The load-bearing postcondition is that OUR backdated dir is gone. We do
     NOT assert the returned count is >= 1: under parallel dune a concurrent
     test's sweep can legitimately remove our dir first, so this sweep sees it
     already gone and returns 0 while [file_exists dir = false] still holds
     (issue #1884). The count is unassertable across concurrent sweeps sharing
     [Filename.temp_dir_name]; the dir-absence is the contract. *)
  assert_that (Stdlib.Sys.file_exists dir) (equal_to false)

let test_orphan_sweep_spares_fresh_panel_runner_dirs _ =
  (* A freshly-created dir (mtime ~now) should be spared by a 1-hour
     threshold sweep. *)
  let dir =
    Stdlib.Filename.temp_dir "panel_runner_csv_snapshot_" "_test_orphan_fresh"
  in
  let _ = Builder.startup_orphan_sweep ~max_age_hours:1.0 () in
  assert_that (Stdlib.Sys.file_exists dir) (equal_to true);
  _rm_rf dir

let test_orphan_sweep_ignores_non_matching_dirs _ =
  let dir = _make_tmpdir () in
  (* Backdate so we'd remove if the prefix matched. *)
  let one_hour_ago = Core_unix.gettimeofday () -. 3600.0 in
  Core_unix.utimes dir ~access:one_hour_ago ~modif:one_hour_ago;
  let _ = Builder.startup_orphan_sweep ~max_age_hours:0.001 () in
  assert_that (Stdlib.Sys.file_exists dir) (equal_to true);
  _rm_rf dir

(* -------------- integration tests via subject subprocess -------------- *)

let _run_subject ~arg =
  let stdout_path = Stdlib.Filename.temp_file "cstest_stdout_" "" in
  let cmd =
    Printf.sprintf "%s %s > %s 2>&1" _subject_binary arg
      (Filename.quote stdout_path)
  in
  let exit_code = Stdlib.Sys.command cmd in
  let stdout = In_channel.read_all stdout_path in
  _rm_rf stdout_path;
  (* The subject prints the dir on its FIRST line (always), then EITHER
     raises (uncaught -> exit 2) OR sigterms itself (exit 130 via our handler
     OR raw 143 if our handler didn't install). *)
  let dir =
    match String.split_lines stdout with
    | first :: _ -> String.strip first
    | [] -> failwith "subject produced no output"
  in
  (dir, exit_code, stdout)

let test_abnormal_exit_via_uncaught_exception _ =
  let dir, _exit_code, _out = _run_subject ~arg:"raise" in
  (* The dir name must look like a panel_runner_csv_snapshot_ tmp dir so
     we know the subject ran the code path we intended. *)
  assert_that
    (String.is_substring dir ~substring:"panel_runner_csv_snapshot_")
    (equal_to true);
  (* And the dir must be gone — at_exit fires on uncaught exceptions. *)
  assert_that (Stdlib.Sys.file_exists dir) (equal_to false)

let test_abnormal_exit_via_sigterm _ =
  let dir, exit_code, _out = _run_subject ~arg:"sigterm" in
  assert_that
    (String.is_substring dir ~substring:"panel_runner_csv_snapshot_")
    (equal_to true);
  (* Exit code is 130 (our handler maps SIGTERM -> exit 130). If our
     handler weren't installed the shell would surface 143 (128 + SIGTERM=15)
     and the dir would leak. *)
  assert_that exit_code (equal_to 130);
  assert_that (Stdlib.Sys.file_exists dir) (equal_to false)

(* -------------- suite -------------- *)

let suite =
  "Csv_snapshot_builder cleanup"
  >::: [
         "register + cleanup removes dir and ledger entry"
         >:: test_register_then_cleanup_removes_dir;
         "cleanup is idempotent" >:: test_cleanup_is_idempotent;
         "cleanup on unregistered dir does not touch other entries"
         >:: test_cleanup_on_unregistered_dir_is_noop;
         "register is idempotent" >:: test_register_is_idempotent;
         "orphan sweep removes old panel_runner dirs"
         >:: test_orphan_sweep_removes_old_panel_runner_dirs;
         "orphan sweep spares fresh panel_runner dirs"
         >:: test_orphan_sweep_spares_fresh_panel_runner_dirs;
         "orphan sweep ignores non-panel_runner dirs"
         >:: test_orphan_sweep_ignores_non_matching_dirs;
         "abnormal exit (uncaught exception) cleans up dir"
         >:: test_abnormal_exit_via_uncaught_exception;
         "abnormal exit (SIGTERM) cleans up dir"
         >:: test_abnormal_exit_via_sigterm;
       ]

let () = run_test_tt_main suite
