(** CLI flag parsing for [bayesian_runner.exe]. Extracted from the executable's
    entry module; the flags, messages and exit codes are unchanged. *)

val usage_msg : string
(** Usage text printed on [--help] and appended to every CLI error. *)

(** Selector for {!Bayesian_runner_successive_halving} mode. [Single] preserves
    the legacy single-tier behaviour bit-for-bit; [Successive_halving] enables
    M1 T1.2's multi-fidelity promotion loop. *)
type fidelity_strategy = Single | Successive_halving

type cli_args = {
  spec_path : string;
  out_dir : string;
  fixtures_root : string option;
  walk_forward_spec_path : string option;
  baseline_aggregate_path : string option;
  parallel : int;
  fidelity_strategy : fidelity_strategy;
}

val parse_args : string list -> cli_args
(** Parse argv (without the program name). Prints usage / an error and exits the
    process on [--help] (0) or any invalid input (1). *)
