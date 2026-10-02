(* Shared CLI surface of the snapshot builders (survivor tolerance + series-tail
   knobs) and their default constants. Extracted from [build_runner.ml], which
   re-exports every symbol here.
   Also hosts the warehouse exceptions-file loader. *)

open Core
module Series_tail = Snapshot_pipeline.Series_tail
module Series_splice = Snapshot_pipeline.Series_splice

(* The ONE on-disk shape of the warehouse exceptions file. Both sections are
   optional — a file may carry only [keep_tail], only [splice], or both — but
   the record is STRICT: no [allow_extra_fields], so a mistyped section name
   ([splcie]) is a parse error rather than a silently empty veto list. That
   strictness is what makes the fatal load path below mean anything: degrading
   to "no exceptions" would edit exactly the symbols a reviewer vetoed. *)
type exceptions_file = {
  keep_tail : string list; [@sexp.default []]
  splice : Series_splice.Exceptions.rule list; [@sexp.default []]
}
[@@deriving of_sexp]

let _empty_exceptions_file = { keep_tail = []; splice = [] }

let _parse_exceptions_file p =
  match
    Or_error.try_with (fun () -> exceptions_file_of_sexp (Sexp.load_sexp p))
  with
  | Ok t -> Ok t
  | Error e ->
      Status.error_invalid_argument
        (Printf.sprintf "warehouse exceptions load failed (%s): %s" p
           (Error.to_string_hum e))

(* Pure loader: the failure is a value, so both halves are testable. The CLI
   shells turn the [Error] into an exit via [tail_exceptions_or_exit] /
   [splice_exceptions_or_exit]. One file, ONE parse, two views — the section a
   caller does not care about still has to be well-formed. *)
let _load_exceptions_file = function
  | None -> Ok _empty_exceptions_file
  | Some p -> _parse_exceptions_file p

let load_tail_exceptions path =
  Result.map (_load_exceptions_file path) ~f:(fun f ->
      Series_tail.Exceptions.of_symbols f.keep_tail)

let load_splice_exceptions path =
  Result.map (_load_exceptions_file path) ~f:(fun f ->
      Series_splice.Exceptions.of_rules f.splice)

(* A malformed or missing exceptions file is FATAL: silently falling back to "no
   exceptions" would edit exactly the symbols a reviewer vetoed. *)
let _exceptions_or_exit = function
  | Ok t -> t
  | Error err ->
      Printf.eprintf "%s\n%!" (Status.show err);
      exit 1

let tail_exceptions_or_exit path =
  _exceptions_or_exit (load_tail_exceptions path)

let splice_exceptions_or_exit path =
  _exceptions_or_exit (load_splice_exceptions path)

(* Slack, in calendar days, between the universe's last bar and a symbol's own
   last bar before that symbol counts as delisted (#2693). The vendor lags a
   few names by a day or two — a symbol whose series stops on the Wednesday of
   the store's final week is still trading, not delisted. CLIs surface this as
   [--survivor-tolerance-days]. *)
let default_survivor_tolerance_days = 7

(* Committed veto list for {!Series_tail}. Documented, not defaulted: the flag
   stays optional so a build's behaviour never depends on the caller's cwd. *)
let default_exceptions_path = "trading/test_data/warehouse_exceptions.sexp"

(* Shared CLI surface for the survivor tolerance, so both builders expose the
   same flag and default. *)
let survivor_tolerance_param =
  let%map_open.Command days =
    flag "survivor-tolerance-days"
      (optional_with_default default_survivor_tolerance_days int)
      ~doc:
        (Printf.sprintf
           "N Calendar days a symbol's last bar may trail the universe's last \
            bar and still count as still-trading (active_through stays unset). \
            Default %d."
           default_survivor_tolerance_days)
  in
  days

(* Shared CLI surface for the tail knobs, so both builders expose exactly the
   same flags and defaults. The three gate knobs, the two edit switches and the
   prefix cut's short-tail guard are flags; the mis-scale THRESHOLD and the
   stray-gap parameters are measured constants of the defect classes, not
   per-build choices ({!Series_tail}). *)
let tail_params =
  let d = Series_tail.Config.default in
  let%map_open.Command ratio =
    flag "stub-ratio"
      (optional_with_default d.stub.ratio float)
      ~doc:"R Terminal-run close ratio below which a bar is a stub candidate"
  and max_bars =
    flag "stub-max-bars"
      (optional_with_default d.stub.max_bars int)
      ~doc:"N Longest terminal run still truncatable (longer = long low tail)"
  and max_price =
    flag "stub-max-price"
      (optional_with_default d.stub.max_price float)
      ~doc:"P The run's first close must be below this to count as a stub"
  and no_stub_truncation =
    flag "no-stub-truncation" no_arg
      ~doc:"Report terminal stub tails without truncating them"
  and no_stray_drop =
    flag "no-stray-drop" no_arg
      ~doc:"Report stray late bars without dropping them"
  and cut_prefix_misscale =
    flag "cut-prefix-misscale" no_arg
      ~doc:
        "Drop the mis-scaled prefix of a prefix_misscale series, keeping the \
         real later segment (#2732). Default off: the class is reported and \
         stored whole."
  and misscale_min_kept_bars =
    flag "misscale-min-kept-bars"
      (optional_with_default d.stub.misscale_min_kept_bars int)
      ~doc:
        "N Refuse a prefix cut leaving fewer than N bars, storing the series \
         whole"
  and exceptions_path =
    flag "tail-exceptions" (optional string)
      ~doc:
        (Printf.sprintf
           "PATH Warehouse exceptions sexp, shape ((keep_tail (SYM ...)) \
            (splice ((keep SYM) (drop SYM) (cut_at SYM DATE)))). Both sections \
            optional. Committed list: %s"
           default_exceptions_path)
  in
  ( {
      Series_tail.Config.stub =
        {
          d.stub with
          truncate = not no_stub_truncation;
          ratio;
          max_bars;
          max_price;
          misscale_cut = cut_prefix_misscale;
          misscale_min_kept_bars;
        };
      stray = { d.stray with drop = not no_stray_drop };
    },
    exceptions_path )
