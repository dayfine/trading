(** Backtest runner CLI — thin wrapper around the {!Backtest} library.

    Usage: backtest_runner <start_date> [end_date] [--override '<sexp>']

    - start_date: required (e.g. 2018-01-02)
    - end_date: optional, defaults to today
    - --override: partial config sexp, deep-merged into the default. Can repeat.

    Example:
    {[
      backtest_runner 2019-01-02 2020-06-30 \
        --override '((initial_stop_buffer 1.08))' \
        --override '((stage_config ((ma_period 40))))'
    ]}

    Writes params.sexp, summary.sexp, trades.csv, equity_curve.csv to a
    timestamped directory under dev/backtest/ and prints the summary sexp to
    stdout. *)

open Core

(** Split argv (excluding argv[0]) into positional args and override sexps. *)
let _extract_overrides argv =
  let rec loop args positional overrides =
    match args with
    | [] -> (List.rev positional, List.rev overrides)
    | "--override" :: sexp_str :: rest ->
        loop rest positional (Sexp.of_string sexp_str :: overrides)
    | "--override" :: [] ->
        eprintf "Error: --override requires a sexp argument\n";
        Stdlib.exit 1
    | arg :: rest -> loop rest (arg :: positional) overrides
  in
  loop (Array.to_list argv |> List.tl_exn) [] []

let _parse_args () =
  let argv = Sys.get_argv () in
  if Array.length argv < 2 then (
    eprintf
      "Usage: backtest_runner <start_date> [end_date] [--override '<sexp>']\n";
    Stdlib.exit 1);
  let positional, overrides = _extract_overrides argv in
  let start_str, end_str =
    match positional with
    | [] ->
        eprintf "Error: start_date is required\n";
        Stdlib.exit 1
    | [ s ] -> (s, None)
    | [ s; e ] -> (s, Some e)
    | _ ->
        eprintf "Error: too many positional arguments\n";
        Stdlib.exit 1
  in
  let start_date = Date.of_string start_str in
  let end_date =
    match end_str with
    | Some s -> Date.of_string s
    | None -> Date.today ~zone:Time_float.Zone.utc
  in
  (start_date, end_date, overrides)

let _make_output_dir () =
  let data_dir_fpath = Data_path.default_data_dir () in
  let repo_root = Fpath.parent data_dir_fpath |> Fpath.to_string in
  let now = Core_unix.gettimeofday () in
  let tm = Core_unix.localtime now in
  let dirname =
    sprintf "%04d-%02d-%02d-%02d%02d%02d" (tm.tm_year + 1900) (tm.tm_mon + 1)
      tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  let path = repo_root ^ "dev/backtest/" ^ dirname in
  Core_unix.mkdir_p path;
  path

let () =
  let start_date, end_date, overrides = _parse_args () in
  let result =
    Backtest.Runner.run_backtest ~start_date ~end_date ~overrides ()
  in
  let output_dir = _make_output_dir () in
  eprintf "Writing output to %s/\n%!" output_dir;
  Backtest.Result_writer.write ~output_dir result;
  eprintf "Output written to: %s/\n%!" output_dir;
  Out_channel.output_string stdout
    (Sexp.to_string_hum (Backtest.Summary.sexp_of_t result.summary));
  Out_channel.newline stdout
