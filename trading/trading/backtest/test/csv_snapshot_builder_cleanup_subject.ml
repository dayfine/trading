(** Test subject for [test_csv_snapshot_builder_cleanup]. Allocates a
    [/tmp/panel_runner_csv_snapshot_*] dir via
    [Csv_snapshot_builder.register_for_cleanup], prints the dir path on stdout,
    then exits abnormally per its argv:

    - "raise" — raises an OCaml exception (uncaught -> at_exit fires).
    - "sigterm" — sends itself SIGTERM (signal handler -> exit 130 -> at_exit
      fires).

    The parent test reads the dir from stdout and asserts the dir is gone after
    the subprocess exits. *)

let () =
  let dir = Filename.temp_dir "panel_runner_csv_snapshot_" "_subject" in
  Backtest.Csv_snapshot_builder.register_for_cleanup dir;
  (* Print path BEFORE the abnormal exit and flush, so the parent can read it
     even when the process dies before stdout is naturally flushed. *)
  print_endline dir;
  flush stdout;
  match Sys.argv with
  | [| _; "raise" |] -> failwith "subject: intentional abnormal exit"
  | [| _; "sigterm" |] ->
      Unix.kill (Unix.getpid ()) Sys.sigterm;
      (* Sleep a few seconds so the SIGTERM has time to actually fire the
         handler; if we exit normally before the signal lands, the test would
         not exercise the SIGTERM path. *)
      Unix.sleep 5;
      print_endline "subject: SIGTERM did not fire — handler not installed?";
      exit 99
  | _ ->
      prerr_endline
        "usage: csv_snapshot_builder_cleanup_subject.exe (raise|sigterm)";
      exit 2
