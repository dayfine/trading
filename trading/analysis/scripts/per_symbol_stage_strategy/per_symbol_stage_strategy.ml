(** per_symbol_stage_strategy — CLI driver for the diagnostic single-symbol
    Weinstein stage strategy.

    Runs both [Long_only] and [Long_short] variants over a configurable set of
    symbols and writes a Markdown report to stdout (caller redirects to
    [dev/notes/per-symbol-stage-strategy-<date>.md]).

    Per the dispatch brief (2026-05-29), the canonical run is over SPY + the 11
    SPDR sector ETFs over 1998-01-01 → 2025-12-31. *)

open Core
module Backtest = Per_symbol_stage_strategy_lib.Single_symbol_backtest
module Signal = Per_symbol_stage_strategy_lib.Stage_signal

(* The dispatch brief's canonical 12-symbol set. *)
let _default_symbols =
  [
    "SPY";
    "XLK";
    "XLF";
    "XLI";
    "XLV";
    "XLE";
    "XLP";
    "XLY";
    "XLU";
    "XLB";
    "XLRE";
    "XLC";
  ]

let _initial_cash = 1_000_000.0

(* ------------------------------------------------------------------ *)
(* Report rendering                                                    *)
(* ------------------------------------------------------------------ *)

let _fmt_pct v = sprintf "%+6.2f%%" (v *. 100.0)
let _fmt_pct_abs v = sprintf "%5.2f%%" (Float.abs v *. 100.0)
let _fmt_float v = sprintf "%6.2f" v

(* Per-variant matrix — Section 1 (long-only) and Section 2 (long-short).
   Section 2 has two extra columns (% time short, # short entries). *)
let _render_row ~(variant : Signal.variant) (r : Backtest.result) =
  let delta_cagr = r.strategy_cagr -. r.bah_cagr in
  let core =
    sprintf "| %s | %s | %s | %s | %s | %s | %d | %.0f | %.1f%% |" r.symbol
      (_fmt_pct r.strategy_cagr) (_fmt_pct r.bah_cagr) (_fmt_pct delta_cagr)
      (_fmt_pct_abs r.strategy_max_dd)
      (_fmt_pct_abs r.bah_max_dd)
      r.num_long_entries r.avg_holding_days (r.pct_time_long *. 100.0)
  in
  match variant with
  | Signal.Long_only -> core
  | Signal.Long_short ->
      (* [core] ends with " |"; append two more cells. Keep the trailing
         "|" boundary explicit so the markdown table stays well-formed. *)
      sprintf "%s %.1f%% | %d |" core
        (r.pct_time_short *. 100.0)
        r.num_short_entries

let _render_section_header variant =
  let extra =
    match variant with
    | Signal.Long_only -> ""
    | Signal.Long_short -> " % time short | # short entries |"
  in
  sprintf
    "| Symbol | Stage CAGR | BAH CAGR | Δ CAGR | Stage MaxDD | BAH MaxDD | # \
     Stage-2 entries | Avg holding days | %% time long |%s"
    extra

let _render_section_divider variant =
  match variant with
  | Signal.Long_only -> "|---|---|---|---|---|---|---|---|---|"
  | Signal.Long_short -> "|---|---|---|---|---|---|---|---|---|---|---|"

let _render_section ~(variant : Signal.variant) ~results =
  let header = _render_section_header variant in
  let divider = _render_section_divider variant in
  let rows = List.map results ~f:(_render_row ~variant) in
  String.concat ~sep:"\n" (header :: divider :: rows)

(* Aggregate verdict counters for Section 3. *)
type _agg = {
  total : int;
  beat_bah : int;
  delta_avg : float;
  delta_max : float;
  delta_min : float;
  total_long_entries : int;
}

let _aggregate (results : Backtest.result list) : _agg =
  let total = List.length results in
  let deltas = List.map results ~f:(fun r -> r.strategy_cagr -. r.bah_cagr) in
  let beat_bah = List.count deltas ~f:(fun d -> Float.( > ) d 0.0) in
  let total_long_entries =
    List.fold results ~init:0 ~f:(fun acc r -> acc + r.num_long_entries)
  in
  let delta_avg =
    match deltas with
    | [] -> 0.0
    | _ ->
        List.fold deltas ~init:0.0 ~f:( +. )
        /. Float.of_int (List.length deltas)
  in
  let delta_max = List.fold deltas ~init:Float.neg_infinity ~f:Float.max in
  let delta_min = List.fold deltas ~init:Float.infinity ~f:Float.min in
  { total; beat_bah; delta_avg; delta_max; delta_min; total_long_entries }

let _render_aggregate ~label ~(agg : _agg) =
  sprintf
    "- **%s**: %d/%d symbols beat BAH. Δ CAGR avg %+.2fpp; range [%+.2fpp, \
     %+.2fpp]. Total Stage-2 entries across panel: %d (avg %.1f per symbol)."
    label agg.beat_bah agg.total (agg.delta_avg *. 100.0)
    (agg.delta_min *. 100.0) (agg.delta_max *. 100.0) agg.total_long_entries
    (Float.of_int agg.total_long_entries /. Float.of_int agg.total)

(* Section 4 — year-end equity samples. One block per symbol, listing
   (year, long-only equity, long-short equity) so the reader can eyeball
   the trajectory without us drawing graphs. *)
let _render_year_end_block ~(lo : Backtest.result) ~(ls : Backtest.result) =
  let years =
    List.map lo.year_end_equity ~f:fst
    |> List.dedup_and_sort ~compare:Int.compare
  in
  let lo_map = Int.Map.of_alist_exn lo.year_end_equity in
  let ls_map = Int.Map.of_alist_exn ls.year_end_equity in
  let header = sprintf "**%s**" lo.symbol in
  let rows =
    List.map years ~f:(fun y ->
        let lo_v = Map.find lo_map y |> Option.value ~default:Float.nan in
        let ls_v = Map.find ls_map y |> Option.value ~default:Float.nan in
        sprintf "| %d | $%s | $%s |" y
          (_fmt_float (lo_v /. 1000.0))
          (_fmt_float (ls_v /. 1000.0)))
  in
  String.concat ~sep:"\n"
    (header :: "| Year-end | Long-only equity ($k) | Long-short equity ($k) |"
   :: "|---|---|---|" :: rows)

(* ------------------------------------------------------------------ *)
(* Main render                                                         *)
(* ------------------------------------------------------------------ *)

(* Run both variants for one symbol and return the pair. Errors are
   propagated upward; a missing symbol fails the whole report. *)
let _run_symbol ~data_dir ~start_date ~end_date symbol =
  let lo =
    Backtest.run ~data_dir ~symbol ~start_date ~end_date
      ~initial_cash:_initial_cash ~variant:Signal.Long_only ()
  in
  let ls =
    Backtest.run ~data_dir ~symbol ~start_date ~end_date
      ~initial_cash:_initial_cash ~variant:Signal.Long_short ()
  in
  match (lo, ls) with
  | Ok lo_r, Ok ls_r -> Ok (lo_r, ls_r)
  | Error e, _ | _, Error e -> Error (symbol, e)

let _render_report ~start_date ~end_date ~pairs =
  let lo_results = List.map pairs ~f:fst in
  let ls_results = List.map pairs ~f:snd in
  let section1 =
    _render_section ~variant:Signal.Long_only ~results:lo_results
  in
  let section2 =
    _render_section ~variant:Signal.Long_short ~results:ls_results
  in
  let lo_agg = _aggregate lo_results in
  let ls_agg = _aggregate ls_results in
  let agg_lo_line = _render_aggregate ~label:"Long-only vs BAH" ~agg:lo_agg in
  let agg_ls_line = _render_aggregate ~label:"Long-short vs BAH" ~agg:ls_agg in
  let year_end_blocks =
    List.map2_exn lo_results ls_results ~f:(fun lo ls ->
        _render_year_end_block ~lo ~ls)
    |> String.concat ~sep:"\n\n"
  in
  String.concat ~sep:"\n\n"
    [
      sprintf "# Per-symbol Weinstein stage strategy — %s to %s"
        (Date.to_string start_date)
        (Date.to_string end_date);
      "Diagnostic: minimal stage-transition strategy on SPY + 11 SPDR sector \
       ETFs.";
      sprintf
        "Initial cash: $%.0fk. Cost model: 0.5 bps one-sided bid-ask, no \
         commission. Stage classifier: default Weinstein config (30-week WMA, \
         slope_threshold 0.5%%)."
        (_initial_cash /. 1000.0);
      "## Section 1 — Long-only matrix";
      section1;
      "## Section 2 — Long-short matrix";
      section2;
      "## Section 3 — Aggregate verdicts";
      agg_lo_line;
      agg_ls_line;
      "## Section 4 — Per-symbol year-end equity samples";
      year_end_blocks;
    ]

(* ------------------------------------------------------------------ *)
(* CLI                                                                 *)
(* ------------------------------------------------------------------ *)

let _cmd =
  Command.basic ~summary:"Per-symbol Weinstein stage strategy diagnostic"
    (let%map_open.Command data_dir =
       flag "-data-dir" (required string)
         ~doc:
           "PATH Root of the daily-price CSV shard tree (e.g. \
            /workspaces/trading-1/data)"
     and start_date =
       flag "-start"
         (optional_with_default (Date.of_string "1998-01-01") date)
         ~doc:"DATE Inclusive run start (default 1998-01-01)"
     and end_date =
       flag "-end"
         (optional_with_default (Date.of_string "2025-12-31") date)
         ~doc:"DATE Inclusive run end (default 2025-12-31)"
     and symbols_arg =
       flag "-symbols" (optional string)
         ~doc:
           "CSV Comma-separated symbol list (default SPY + 11 SPDR sector ETFs)"
     in
     fun () ->
       let symbols =
         match symbols_arg with
         | None -> _default_symbols
         | Some s -> String.split s ~on:',' |> List.map ~f:String.strip
       in
       let data_dir_fp = Fpath.v data_dir in
       let pairs =
         List.filter_map symbols ~f:(fun sym ->
             match
               _run_symbol ~data_dir:data_dir_fp ~start_date ~end_date sym
             with
             | Ok p -> Some p
             | Error (s, e) ->
                 eprintf "skipping %s: %s\n%!" s (Status.show e);
                 None)
       in
       if List.is_empty pairs then
         failwith "No symbols completed — nothing to report."
       else print_endline (_render_report ~start_date ~end_date ~pairs))

let () = Command_unix.run _cmd
