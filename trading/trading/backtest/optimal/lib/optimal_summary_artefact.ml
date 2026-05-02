open Core

type t = {
  constrained : Optimal_types.optimal_summary;
  score_picked : Optimal_types.optimal_summary;
  relaxed_macro : Optimal_types.optimal_summary;
}
[@@deriving sexp]

let _filename = "optimal_summary.sexp"

let write ~output_dir t =
  let path = Filename.concat output_dir _filename in
  Sexp.save_hum path (sexp_of_t t);
  eprintf "optimal_strategy: wrote %s\n%!" path
