(** [verify_corporate_actions] CLI — runs the M6.4 split/dividend replay harness
    against fixture-backed scenarios.

    Scope: AAPL 2020-08-31 4:1 split (PR-1), TSLA 2020-08-31 5:1 split (PR-2),
    GOOG 2022-07-18 20:1 split (PR-3), NVDA 2024-06-10 10:1 split + KO 2024
    quarterly cash dividend (PR-4 — wraps M6.4).

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

(* --------- Scenario definition ---------

   Each scenario fans out into one of two corporate-action kinds. The runner
   dispatches on [kind] and passes the right inputs to the matching verifier
   in [Round_trip_verifier]. *)

type split_params = { split_date : Date.t; factor : float }

type dividend_params = {
  ex_date : Date.t;
  amount_per_share : float;
  cash_pre : float;
  cash_post : float;
}

type kind = Split of split_params | Dividend of dividend_params

type scenario = {
  name : string;
  symbol : string;
  fixture_dir : string;
  pre_lot : Round_trip_verifier.held_lot;
  kind : kind;
}

let _aapl_2020_split : scenario =
  {
    name = "aapl-2020-split";
    symbol = "AAPL";
    fixture_dir = "aapl-2020-split";
    pre_lot = { symbol = "AAPL"; quantity = 100.0; entry_price = 502.13 };
    kind = Split { split_date = Date.of_string "2020-08-31"; factor = 4.0 };
  }

let _tsla_2020_split : scenario =
  {
    name = "tsla-2020-split";
    symbol = "TSLA";
    fixture_dir = "tsla-2020-split";
    pre_lot = { symbol = "TSLA"; quantity = 50.0; entry_price = 2213.40 };
    kind = Split { split_date = Date.of_string "2020-08-31"; factor = 5.0 };
  }

let _goog_2022_split : scenario =
  {
    name = "goog-2022-split";
    symbol = "GOOG";
    fixture_dir = "goog-2022-split";
    pre_lot = { symbol = "GOOG"; quantity = 10.0; entry_price = 2255.00 };
    kind = Split { split_date = Date.of_string "2022-07-18"; factor = 20.0 };
  }

let _nvda_2024_split : scenario =
  {
    name = "nvda-2024-split";
    symbol = "NVDA";
    fixture_dir = "nvda-2024-split";
    pre_lot = { symbol = "NVDA"; quantity = 10.0; entry_price = 1208.00 };
    kind = Split { split_date = Date.of_string "2024-06-10"; factor = 10.0 };
  }

let _ko_2024_dividend : scenario =
  {
    name = "ko-2024-divs";
    symbol = "KO";
    fixture_dir = "ko-2024-divs";
    pre_lot = { symbol = "KO"; quantity = 200.0; entry_price = 60.00 };
    kind =
      Dividend
        {
          ex_date = Date.of_string "2024-06-14";
          amount_per_share = 0.485;
          cash_pre = 50000.00;
          cash_post = 50097.00;
        };
  }

let scenarios =
  [
    _aapl_2020_split;
    _tsla_2020_split;
    _goog_2022_split;
    _nvda_2024_split;
    _ko_2024_dividend;
  ]

(* --------- Runner --------- *)

let _run_split ~dir ~symbol ~pre_lot (p : split_params) =
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
  Ok
    (Round_trip_verifier.verify_split_round_trip ~symbol
       ~split_date:p.split_date ~factor:p.factor ~bars ~pre_split_lot:pre_lot
       ~pick_pre_split:pre ~pick_post_split:post ())

let _run_dividend ~dir ~symbol ~pre_lot (p : dividend_params) =
  let pre_path = Filename.concat dir "pre_dividend.sexp" in
  let post_path = Filename.concat dir "post_dividend.sexp" in
  let open Result.Let_syntax in
  let%bind pre =
    Snapshot_reader.read_from_file pre_path |> Result.map_error ~f:Status.show
  in
  let%bind post =
    Snapshot_reader.read_from_file post_path |> Result.map_error ~f:Status.show
  in
  Ok
    (Round_trip_verifier.verify_dividend_round_trip ~symbol ~ex_date:p.ex_date
       ~amount_per_share:p.amount_per_share ~pre_lot ~pick_pre:pre
       ~pick_post:post ~cash_pre:p.cash_pre ~cash_post:p.cash_post ())

let _run_scenario ~root (s : scenario) =
  let dir = Filename.concat root s.fixture_dir in
  match s.kind with
  | Split p -> _run_split ~dir ~symbol:s.symbol ~pre_lot:s.pre_lot p
  | Dividend p -> _run_dividend ~dir ~symbol:s.symbol ~pre_lot:s.pre_lot p

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
