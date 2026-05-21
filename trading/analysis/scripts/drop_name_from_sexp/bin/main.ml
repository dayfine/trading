(** One-shot transformer that drops the [name] field from sexp files used by the
    delisted-symbol agenda.

    Background: [data/symbol_types.sexp] (~6.9 MB, 230k lines) and
    [data/delisted_symbols.sexp] (~5.6 MB, 118k lines) carry a per-entry [name]
    field that no reader consults for logic — it was only emitted in a cosmetic
    log line by [fetch_delisted_bars.exe]. Dropping it shrinks the on-disk sexp
    by roughly half.

    The transformer is structural: it walks the [Sexp.t] tree and removes any
    pair of the form [(name "...")] without inspecting siblings. That handles
    both file shapes uniformly — the top-level layout differs between
    [symbol_types.sexp] and [delisted_symbols.sexp] (the former wraps each
    entry's fields with extra keys, the latter uses positional records), but
    both encode the [name] pair the same way.

    Usage:
    {v
      drop_name_from_sexp.exe --input data/symbol_types.sexp \
                              --output data/symbol_types.sexp
    v}

    Re-running is idempotent (a file already missing [name] passes through
    unchanged). *)

open Core

(** Returns true iff [sexp] is the pair [(name "...")] we want to drop. *)
let _is_name_pair = function Sexp.List [ Atom "name"; _ ] -> true | _ -> false

(** Recursively rewrite [sexp] so that every [List] has its immediate
    [(name "...")] children dropped, and the same rule applied to their
    descendants. Atoms are unchanged. *)
let rec _drop_name sexp =
  match sexp with
  | Sexp.Atom _ -> sexp
  | Sexp.List children ->
      Sexp.List
        (List.filter_map children ~f:(fun child ->
             if _is_name_pair child then None else Some (_drop_name child)))

let _run ~input_path ~output_path =
  let original = Sexp.load_sexp input_path in
  let transformed = _drop_name original in
  let tmp = output_path ^ ".tmp" in
  Out_channel.write_all tmp ~data:(Sexp.to_string_hum transformed);
  Stdlib.Sys.rename tmp output_path;
  printf "Transformed %s -> %s\n" input_path output_path

let command =
  Command.basic ~summary:"Drop the [name] field from a sexp file in place."
    (let%map_open.Command input_path =
       flag "input" (required string) ~doc:"PATH input sexp"
     and output_path =
       flag "output" (required string) ~doc:"PATH output sexp"
     in
     fun () -> _run ~input_path ~output_path)

let () = Command_unix.run command
