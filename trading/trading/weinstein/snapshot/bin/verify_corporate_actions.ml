(** [verify_corporate_actions] CLI — runs the M6.4 split/dividend replay harness
    against fixture-backed scenarios.

    Scope: AAPL 2020-08-31 4:1 split (PR-1) + TSLA 2020-08-31 5:1 split (PR-2).
    Follow-up scenarios (GOOG, NVDA, KO) are added as additional entries in the
    [scenarios] list without further code changes.

    Usage: [verify_corporate_actions <fixtures-root>]

    Exit code:
    - 0 — every scenario green
    - 1 — at least one scenario failed; failures printed to stderr *)

open Core
open Weinstein_snapshot

(* --------- Bar parsing (duplicated from test_split_replay to keep the bin
    standalone — small enough to not warrant a shared helper module). --------- *)

let _parse_bar_line line =
  match String.split line ~on:',' with
  | [ d; o; h; l; c; ac; v ] ->
      Ok
        ({
           date = Date.of_string d;
           open_price = Float.of_string o;
           high_price = Float.of_string h;
           low_price = Float.of_string l;
           close_price = Float.of_string c;
           adjusted_close = Float.of_string ac;
           volume = Int.of_string v;
         }
          : Types.Daily_price.t)
  | _ -> Error (Printf.sprintf "Malformed bar line: %s" line)

let _read_bars path =
  try
    match In_channel.read_lines path with
    | [] -> Error (Printf.sprintf "Empty bars file: %s" path)
    | _header :: rest ->
        let parsed = List.map rest ~f:_parse_bar_line in
        Result.all parsed
  with exn ->
    Error (Printf.sprintf "Failed to read bars %s: %s" path (Exn.to_string exn))

(* --------- Scenario definition --------- *)

type scenario = {
  name : string;
  symbol : string;
  fixture_dir : string;
  split_date : Date.t;
  factor : float;
  pre_lot : Round_trip_verifier.held_lot;
}

let _aapl_2020_split : scenario =
  {
    name = "aapl-2020-split";
    symbol = "AAPL";
    fixture_dir = "aapl-2020-split";
    split_date = Date.of_string "2020-08-31";
    factor = 4.0;
    pre_lot = { symbol = "AAPL"; quantity = 100.0; entry_price = 502.13 };
  }

let _tsla_2020_split : scenario =
  {
    name = "tsla-2020-split";
    symbol = "TSLA";
    fixture_dir = "tsla-2020-split";
    split_date = Date.of_string "2020-08-31";
    factor = 5.0;
    pre_lot = { symbol = "TSLA"; quantity = 50.0; entry_price = 2213.40 };
  }

let scenarios = [ _aapl_2020_split; _tsla_2020_split ]

(* --------- Runner --------- *)

let _run_scenario ~root (s : scenario) =
  let dir = Filename.concat root s.fixture_dir in
  let bars_path = Filename.concat dir "bars.csv" in
  let pre_path = Filename.concat dir "pre_split.sexp" in
  let post_path = Filename.concat dir "post_split.sexp" in
  let open Result.Let_syntax in
  let%bind bars = _read_bars bars_path in
  let%bind pre =
    Snapshot_reader.read_from_file pre_path |> Result.map_error ~f:Status.show
  in
  let%bind post =
    Snapshot_reader.read_from_file post_path |> Result.map_error ~f:Status.show
  in
  let result =
    Round_trip_verifier.verify_split_round_trip ~symbol:s.symbol
      ~split_date:s.split_date ~factor:s.factor ~bars ~pre_split_lot:s.pre_lot
      ~pick_pre_split:pre ~pick_post_split:post ()
  in
  Ok result

let _print_result ~scenario_name
    (result : Round_trip_verifier.Round_trip_result.t) =
  List.iter result.checks ~f:(fun (c : Round_trip_verifier.check) ->
      let status_str =
        match c.status with
        | Round_trip_verifier.Pass -> "PASS"
        | Round_trip_verifier.Fail -> "FAIL"
      in
      printf "[%s] %s.%s — %s\n" status_str scenario_name c.name c.detail)

let _run_all root =
  let outcomes =
    List.map scenarios ~f:(fun s ->
        match _run_scenario ~root s with
        | Ok result ->
            _print_result ~scenario_name:s.name result;
            Round_trip_verifier.Round_trip_result.all_pass result
        | Error msg ->
            eprintf "[FAIL] %s — fixture load: %s\n" s.name msg;
            false)
  in
  if List.for_all outcomes ~f:Fn.id then 0 else 1

let () =
  match Sys.get_argv () |> Array.to_list with
  | _ :: root :: _ -> exit (_run_all root)
  | _ ->
      eprintf "Usage: verify_corporate_actions <fixtures-root>\n";
      exit 2
