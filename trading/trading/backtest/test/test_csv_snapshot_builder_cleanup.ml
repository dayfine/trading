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

(* The subject binary lives next to this test exe in the _build tree — it is
   kept there by the (deps ...) field of the [tests] stanza in test/dune,
   without which dune is free to skip building it (issue #2565). It supports
   two modes via argv:
   "raise" — registers a tmp dir then raises an exception;
   "sigterm" — registers a tmp dir then kills itself with SIGTERM.
   In both cases it prints the dir path on stdout BEFORE the abnormal exit
   so the parent can verify cleanup. *)
let _subject_binary =
  Filename.concat
    (Filename.dirname Stdlib.Sys.executable_name)
    "csv_snapshot_builder_cleanup_subject.exe"

(* Shell exit codes meaning "could not execute the command at all": 126 =
   found but not executable, 127 = not found. These are the ONLY shapes we
   treat as a harness failure — the subject's own abnormal exits (2 for the
   uncaught exception, 130 for SIGTERM) are the behaviour under test and must
   stay observable to the callers. *)
let _exit_code_not_executable = 126
let _exit_code_not_found = 127

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

(* [startup_orphan_sweep] scans [Filename.get_temp_dir_name ()] by PREFIX AND
   MTIME ONLY — by design (it is a belt-and-suspenders sweep for orphans left
   by a SIGKILLed process, so it cannot know which live process, if any, owns
   a given dir). That means it is not safe to point at a temp root any other
   concurrently-running process might also be using: it cannot tell "old
   orphan" from "live dir that merely hasn't been touched in a while."

   Under OUnit2's default "processes" runner (confirmed here, not assumed:
   `-runner processes -shards N`, the default, forks N worker OS processes
   that run disjoint subsets of this suite's tests IN PARALLEL — see
   `-list-test`/`-verbose true` output), the three tests below and every
   other test file's panel_runner_csv_snapshot_ dir (created by any
   concurrently-running CSV-mode Panel_runner test under the SAME
   dune-invocation-shared TMPDIR) are all fair game for each other's sweeps.

   Root-caused 2026-09-02 (dev/status/cleanup.md flaky_test entry, 4th
   observation): with an artificial delay reproducing plausible
   load-induced scheduling jitter between two OUnit worker processes,
   [test_orphan_sweep_removes_old_panel_runner_dirs]'s aggressive 3.6s-old
   threshold deleted [test_orphan_sweep_spares_fresh_panel_runner_dirs]'s
   still-fresh fixture before that test's own assertion ran — a genuine,
   deterministic OUnitAssert failure, not a fluke of the sweep's own
   dir. Issue #1884's fix only protected the "removes old" test's own
   assertion (by not asserting on the returned count); it did not close
   this reverse direction.

   Fix: point [Filename.get_temp_dir_name ()] at a PRIVATE, per-test root via
   [Filename.set_temp_dir_name] for the duration of each orphan-sweep test, so
   its sweep can only ever see fixtures it created itself. This is a test-only
   change — [startup_orphan_sweep]'s production contract (scan whatever
   [get_temp_dir_name ()] currently resolves to) is unchanged. *)
let _with_private_tmp_root f =
  let saved = Stdlib.Filename.get_temp_dir_name () in
  let private_root = _make_tmpdir () in
  Stdlib.Filename.set_temp_dir_name private_root;
  Exn.protect ~f ~finally:(fun () ->
      Stdlib.Filename.set_temp_dir_name saved;
      _rm_rf private_root)

let test_orphan_sweep_removes_old_panel_runner_dirs _ =
  _with_private_tmp_root (fun () ->
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
      assert_that (Stdlib.Sys.file_exists dir) (equal_to false))

let test_orphan_sweep_spares_fresh_panel_runner_dirs _ =
  _with_private_tmp_root (fun () ->
      (* A freshly-created dir (mtime ~now) should be spared by a 1-hour
         threshold sweep. *)
      let dir =
        Stdlib.Filename.temp_dir "panel_runner_csv_snapshot_"
          "_test_orphan_fresh"
      in
      let _ = Builder.startup_orphan_sweep ~max_age_hours:1.0 () in
      assert_that (Stdlib.Sys.file_exists dir) (equal_to true))

let test_orphan_sweep_ignores_non_matching_dirs _ =
  _with_private_tmp_root (fun () ->
      (* Non-matching prefix, but created (like the matching-prefix fixtures
         above) under the swept [get_temp_dir_name ()] itself — this proves
         the sweep's prefix filter, not merely that the dir sits outside the
         scanned directory. *)
      let dir = Stdlib.Filename.temp_dir "not_a_panel_runner_dir_" "_test" in
      (* Backdate so we'd remove if the prefix matched. *)
      let one_hour_ago = Core_unix.gettimeofday () -. 3600.0 in
      Core_unix.utimes dir ~access:one_hour_ago ~modif:one_hour_ago;
      let _ = Builder.startup_orphan_sweep ~max_age_hours:0.001 () in
      assert_that (Stdlib.Sys.file_exists dir) (equal_to true))

(* [_with_private_tmp_root]'s docstring states a CONTRACT — "its sweep can only
   ever see fixtures it created itself" — and that contract is the entire fix
   for this flake. Nothing above pins it: the three tests each create their
   fixture INSIDE the private root, so they pass identically whether the root
   is private or shared. Verified by qc-behavioral on PR #2637 (CP4): replacing
   the helper body with [let _with_private_tmp_root f = f ()] — the exact shape
   of a silent future regression — left the suite at 3/3, exit 0.

   This test pins the guard directly, from the outside in: plant a backdated
   [panel_runner_csv_snapshot_*] dir in the SHARED temp root (the dune-wide
   TMPDIR every other test file also writes to), then run the most aggressive
   sweep from INSIDE the private root. The outside dir must survive — that is
   precisely the cross-worker deletion that caused the flake.

   Deterministic: no delays, no concurrency, no dependence on scheduling. *)
let test_private_tmp_root_hides_the_shared_root_from_the_sweep _ =
  let shared_root = Stdlib.Filename.get_temp_dir_name () in
  let outsider =
    Stdlib.Filename.temp_dir "panel_runner_csv_snapshot_" "_test_outsider"
  in
  (* Backdate well past any threshold used below, so survival can only be
     explained by the sweep never seeing it — not by it looking too fresh. *)
  let one_hour_ago = Core_unix.gettimeofday () -. 3600.0 in
  Core_unix.utimes outsider ~access:one_hour_ago ~modif:one_hour_ago;
  Exn.protect
    ~f:(fun () ->
      _with_private_tmp_root (fun () ->
          (* Sanity: we really are somewhere else. If this ever fails, the
             assertion below would pass vacuously (sweeping the shared root
             from the shared root, finding nothing to do). *)
          assert_that
            (String.equal (Stdlib.Filename.get_temp_dir_name ()) shared_root)
            (equal_to false);
          let (_ : int) =
            Builder.startup_orphan_sweep ~max_age_hours:0.001 ()
          in
          ());
      assert_that (Stdlib.Sys.file_exists outsider) (equal_to true))
    ~finally:(fun () -> _rm_rf outsider)

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
  if exit_code = _exit_code_not_executable || exit_code = _exit_code_not_found
  then
    assert_failure
      (Printf.sprintf
         "could not execute subject binary %s (shell exit %d): it was not \
          built. The [tests] stanza in test/dune must keep it in its (deps \
          ...). Shell output: %s"
         _subject_binary exit_code (String.strip stdout));
  (* The subject prints the dir on its FIRST line (always), then EITHER
     raises (uncaught -> exit 2) OR sigterms itself (exit 130 via our handler
     OR raw 143 if our handler didn't install). *)
  let dir =
    match String.split_lines stdout with
    | first :: _ -> String.strip first
    | [] ->
        assert_failure
          (Printf.sprintf "subject binary %s (shell exit %d) produced no output"
             _subject_binary exit_code)
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
         "private tmp root hides the shared root from the sweep"
         >:: test_private_tmp_root_hides_the_shared_root_from_the_sweep;
         "abnormal exit (uncaught exception) cleans up dir"
         >:: test_abnormal_exit_via_uncaught_exception;
         "abnormal exit (SIGTERM) cleans up dir"
         >:: test_abnormal_exit_via_sigterm;
       ]

let () = run_test_tt_main suite
