open Core

type t = {
  base_scenario : string;
  window_spec : Window_spec.t;
  variants : Walk_forward_runner.variant list;
  baseline_label : string;
  gate : Fold_gate.t;
}
[@@deriving sexp]

let load path : t = t_of_sexp (Sexp.load_sexp path)
