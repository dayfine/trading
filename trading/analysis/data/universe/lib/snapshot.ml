open Core

type anchor = [ `Shiller_sp_composite ] [@@deriving sexp, show, eq]

type factor_skeleton = [ `French_5_industry | `French_49_industry ]
[@@deriving sexp, show, eq]

type method_ =
  | Composition_from_individuals
  | Decomposition_from_index of {
      anchor : anchor;
      factor_skeleton : factor_skeleton;
    }
[@@deriving sexp, show, eq]

type entry = {
  symbol : string;
  weight : float;
  sector : string;
  synthetic : bool;
}
[@@deriving sexp, show, eq]

type t = {
  date : Date.t;
  method_ : method_;
  size : int;
  entries : entry list;
  aggregate_period_return : float;
}
[@@deriving sexp, show, eq]

let _atomic_write_sexp ~path sexp =
  let tmp_path = path ^ ".tmp" in
  try
    Out_channel.write_all tmp_path ~data:(Sexp.to_string_hum sexp);
    Stdlib.Sys.rename tmp_path path;
    Ok ()
  with Sys_error msg | Failure msg ->
    (try Stdlib.Sys.remove tmp_path with _ -> ());
    Status.error_internal (Printf.sprintf "Snapshot.save: %s" msg)

let save t ~path = _atomic_write_sexp ~path (sexp_of_t t)

let _read_sexp_file path =
  try Ok (Sexp.load_sexp path)
  with Sys_error msg | Failure msg ->
    Status.error_internal (Printf.sprintf "Snapshot.load: %s" msg)

let _decode_sexp_failure msg =
  Error
    Status.
      {
        code = Failed_precondition;
        message = Printf.sprintf "Snapshot.load: %s" msg;
      }

let _decode_sexp sexp =
  try Ok (t_of_sexp sexp) with
  | Sexp.Of_sexp_error (exn, _) ->
      _decode_sexp_failure ("sexp decode: " ^ Exn.to_string exn)
  | Failure msg -> _decode_sexp_failure msg

let load ~path =
  match _read_sexp_file path with
  | Error _ as e -> e
  | Ok sexp -> _decode_sexp sexp

let total_weight t =
  List.fold t.entries ~init:0.0 ~f:(fun acc e -> acc +. e.weight)
