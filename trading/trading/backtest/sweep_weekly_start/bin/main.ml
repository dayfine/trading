(** [sweep_weekly_start] CLI — enumerate Mondays in a trailing N-year window,
    run a Buy-and-Hold simulation from each Monday to [end_date], and emit a
    sexp golden + markdown summary.

    Usage:
    {v
      sweep_weekly_start \
        --symbol SPY \
        --init-cash 100000 \
        --years-back 3 \
        --out-sexp <path> \
        --out-markdown <path> \
        [--end-date 2026-05-17] \
        [--universe-path universes/spy-only.sexp] \
        [--fixtures-root <path>] \
        [--max-cells-in-md 30]
    v}

    Defaults: [end_date = Date.today_exn ()] in [America/New_York]; fixtures
    root is auto-resolved by walking parents looking for
    [trading/test_data/backtest_scenarios] (matches [test_bah_runner_e2e]). *)

open Core
module SWS = Sweep_weekly_start.Sweep_weekly_start_lib

type cli_args = {
  symbol : string;
  init_cash : float;
  years_back : int;
  out_sexp : string;
  out_markdown : string;
  end_date : Date.t option;
  universe_path : string;
  fixtures_root : string option;
  max_cells_in_md : int option;
}

let _usage_msg =
  "Usage: sweep_weekly_start --symbol SPY --init-cash 100000 --years-back 3 \
   --out-sexp <path> --out-markdown <path> [--end-date YYYY-MM-DD] \
   [--universe-path <path>] [--fixtures-root <path>] [--max-cells-in-md N]"

let _default_universe_path = "universes/spy-only.sexp"

(** Walk upward from cwd to find the worktree's
    [trading/test_data/backtest_scenarios] dir — same trick used by
    [test_bah_runner_e2e]. *)
let _resolve_fixtures_root () =
  let rec walk_up dir tries_left =
    if tries_left = 0 then None
    else
      let candidate =
        Filename.concat dir "trading/test_data/backtest_scenarios"
      in
      if try Stdlib.Sys.is_directory candidate with _ -> false then
        Some candidate
      else
        let parent = Filename.dirname dir in
        if String.equal parent dir then None else walk_up parent (tries_left - 1)
  in
  walk_up (Stdlib.Sys.getcwd ()) 10

let _parse_args argv =
  let rec loop symbol init_cash years_back out_sexp out_markdown end_date
      universe_path fixtures_root max_cells_in_md = function
    | [] -> (
        match (symbol, out_sexp, out_markdown) with
        | Some s, Some os, Some om ->
            {
              symbol = s;
              init_cash = Option.value init_cash ~default:100000.0;
              years_back = Option.value years_back ~default:3;
              out_sexp = os;
              out_markdown = om;
              end_date;
              universe_path =
                Option.value universe_path ~default:_default_universe_path;
              fixtures_root;
              max_cells_in_md;
            }
        | _ ->
            eprintf "%s\n" _usage_msg;
            Stdlib.exit 1)
    | "--symbol" :: v :: rest ->
        loop (Some v) init_cash years_back out_sexp out_markdown end_date
          universe_path fixtures_root max_cells_in_md rest
    | "--init-cash" :: v :: rest ->
        loop symbol
          (Some (Float.of_string v))
          years_back out_sexp out_markdown end_date universe_path fixtures_root
          max_cells_in_md rest
    | "--years-back" :: v :: rest ->
        loop symbol init_cash
          (Some (Int.of_string v))
          out_sexp out_markdown end_date universe_path fixtures_root
          max_cells_in_md rest
    | "--out-sexp" :: v :: rest ->
        loop symbol init_cash years_back (Some v) out_markdown end_date
          universe_path fixtures_root max_cells_in_md rest
    | "--out-markdown" :: v :: rest ->
        loop symbol init_cash years_back out_sexp (Some v) end_date
          universe_path fixtures_root max_cells_in_md rest
    | "--end-date" :: v :: rest ->
        loop symbol init_cash years_back out_sexp out_markdown
          (Some (Date.of_string v))
          universe_path fixtures_root max_cells_in_md rest
    | "--universe-path" :: v :: rest ->
        loop symbol init_cash years_back out_sexp out_markdown end_date (Some v)
          fixtures_root max_cells_in_md rest
    | "--fixtures-root" :: v :: rest ->
        loop symbol init_cash years_back out_sexp out_markdown end_date
          universe_path (Some v) max_cells_in_md rest
    | "--max-cells-in-md" :: v :: rest ->
        loop symbol init_cash years_back out_sexp out_markdown end_date
          universe_path fixtures_root
          (Some (Int.of_string v))
          rest
    | ("--help" | "-h") :: _ ->
        printf "%s\n" _usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown _usage_msg;
        Stdlib.exit 1
  in
  loop None None None None None None None None None argv

let _resolve_fixtures_root_or_fail (args : cli_args) =
  match args.fixtures_root with
  | Some r -> r
  | None -> (
      match _resolve_fixtures_root () with
      | Some r -> r
      | None ->
          eprintf
            "Error: --fixtures-root not provided and could not auto-resolve \
             trading/test_data/backtest_scenarios from cwd=%s\n"
            (Stdlib.Sys.getcwd ());
          Stdlib.exit 1)

let _today () = Date.today ~zone:Time_float.Zone.utc

let _main () =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let args = _parse_args argv in
  let fixtures_root = _resolve_fixtures_root_or_fail args in
  let end_date = Option.value args.end_date ~default:(_today ()) in
  let cfg : SWS.config =
    {
      symbol = args.symbol;
      initial_cash = args.init_cash;
      years_back = args.years_back;
      end_date;
      fixtures_root;
      universe_path = args.universe_path;
    }
  in
  eprintf
    "[sweep_weekly_start] symbol=%s init_cash=%.2f years_back=%d end_date=%s\n\
     %!"
    cfg.symbol cfg.initial_cash cfg.years_back
    (Date.to_string cfg.end_date);
  let result = SWS.run cfg in
  Sexp.save_hum args.out_sexp (SWS.format_sexp result);
  eprintf "[sweep_weekly_start] wrote sexp: %s (cells=%d)\n%!" args.out_sexp
    result.summary.n_cells;
  let md = SWS.format_markdown ?max_cells:args.max_cells_in_md result in
  Out_channel.write_all args.out_markdown ~data:md;
  eprintf "[sweep_weekly_start] wrote markdown: %s\n%!" args.out_markdown;
  eprintf "[sweep_weekly_start] best=%s @ %s | worst=%s @ %s | median=%s\n%!"
    (Printf.sprintf "%.2f%%" (result.summary.best_cagr *. 100.0))
    (Date.to_string result.summary.best_cell_start)
    (Printf.sprintf "%.2f%%" (result.summary.worst_cagr *. 100.0))
    (Date.to_string result.summary.worst_cell_start)
    (Printf.sprintf "%.2f%%" (result.summary.median_cagr *. 100.0))

let () = _main ()
