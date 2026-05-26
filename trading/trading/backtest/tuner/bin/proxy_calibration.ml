(** Thin executable wrapper around {!Tuner_bin.Proxy_calibration_runner.main}.

    See the runner module for the substantive logic and the CLI flag
    documentation. *)

let () = Tuner_bin.Proxy_calibration_runner.main ()
