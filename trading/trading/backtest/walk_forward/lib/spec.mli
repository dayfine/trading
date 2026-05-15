(** On-disk spec consumed by [bin/walk_forward_runner.exe]. Hoisted out of the
    binary into the library so test fixtures can be parsed and validated without
    invoking the backtest itself (the binary's surface is otherwise not
    addressable from unit tests). *)

type t = {
  base_scenario : string;
      (** Path (relative to fixtures-root) to a base scenario sexp file. *)
  window_spec : Window_spec.t;
  variants : Walk_forward_runner.variant list;
  baseline_label : string;
  gate : Fold_gate.t;
}
[@@deriving sexp]
(** Top-level spec the binary reads via [Sexp.load_sexp] + [t_of_sexp]. *)

val load : string -> t
(** [load path] = [Sexp.load_sexp path |> t_of_sexp]. Raises [Failure] / sexp
    parse errors per the underlying functions. *)
