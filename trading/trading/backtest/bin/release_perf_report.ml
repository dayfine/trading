(** Release perf report — compare scenario outputs from two batch directories
    and print a markdown comparison report.

    Usage: release_perf_report --current <dir> --prior <dir>
    [--threshold-rss-pct N] [--threshold-wall-pct M]

    Both [--current] and [--prior] are required. Each must point at a directory
    of the shape produced by [scenario_runner.ml] —
    {v
      <dir>/<scenario>/actual.sexp
      <dir>/<scenario>/summary.sexp
      <dir>/<scenario>/peak_rss_kb.txt    (optional)
      <dir>/<scenario>/wall_seconds.txt   (optional)
    v}

    Markdown is written to stdout. The exe never reads from a network or invokes
    the backtest runner — it only diffs already-on-disk batches. *)

open Core

type _cli_args = {
  current : string;
  prior : string;
  thresholds : Release_report.thresholds;
}

let _usage () =
  eprintf
    "Usage: release_perf_report --current <dir> --prior <dir> \
     [--threshold-rss-pct N] [--threshold-wall-pct M]\n";
  Stdlib.exit 1

let _parse_flag args =
  let rec loop args current prior thresholds =
    match args with
    | [] ->
        let current = match current with Some v -> v | None -> _usage () in
        let prior = match prior with Some v -> v | None -> _usage () in
        { current; prior; thresholds }
    | "--current" :: v :: rest -> loop rest (Some v) prior thresholds
    | "--prior" :: v :: rest -> loop rest current (Some v) thresholds
    | "--threshold-rss-pct" :: v :: rest ->
        let thresholds =
          {
            thresholds with
            Release_report.threshold_rss_pct = Float.of_string v;
          }
        in
        loop rest current prior thresholds
    | "--threshold-wall-pct" :: v :: rest ->
        let thresholds =
          {
            thresholds with
            Release_report.threshold_wall_pct = Float.of_string v;
          }
        in
        loop rest current prior thresholds
    | _ -> _usage ()
  in
  loop args None None Release_report.default_thresholds

let _parse_args () =
  let argv = Sys.get_argv () in
  _parse_flag (List.tl_exn (Array.to_list argv))

let () =
  let { current; prior; thresholds } = _parse_args () in
  let comparison = Release_report.load ~current ~prior in
  let md = Release_report.render ~thresholds comparison in
  print_string md
