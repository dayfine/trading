(** hold_period_per_stage_analysis — Probe P4 from
    [dev/plans/hold-period-deep-dive-2026-05-19.md].

    Decomposes a backtest [trades.csv] by [entry_stage] (and optionally by
    [screener_score_at_entry] quartile, since the cell-E run has uniform Stage 2
    entries) and emits a Markdown table:

    - count, P50 / P75 / P95 hold-days
    - mean P&L %, win rate
    - exit-trigger breakdown within each bucket

    Pure analysis — no backtest reruns. Reads the CSV produced by
    [Trading.Backtest.Result_writer]. Columns 1-based, schema is
    [symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,
     quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger,
     entry_stage,entry_volume_ratio,stop_initial_distance_pct,
     stop_trigger_kind,days_to_first_stop_trigger,screener_score_at_entry]. *)

open Core

type trade = {
  days_held : int;
  pnl_percent : float;
  exit_trigger : string;
  entry_stage : string; (* empty string when missing *)
  screener_score : float option;
}

(* CSV column indices (0-based) for the fields we care about. The schema is
   pinned by Trading.Backtest.Result_writer; if it changes, update here. *)
let _col_days_held = 4
let _col_pnl_percent = 9
let _col_exit_trigger = 12
let _col_entry_stage = 13
let _col_screener_score = 18

let _parse_row (fields : string array) : trade option =
  if Array.length fields < 19 then None
  else
    let days_held =
      try Some (Int.of_string fields.(_col_days_held)) with _ -> None
    in
    let pnl_percent =
      try Some (Float.of_string fields.(_col_pnl_percent)) with _ -> None
    in
    match (days_held, pnl_percent) with
    | Some d, Some p ->
        let screener_score =
          let raw = fields.(_col_screener_score) in
          if String.is_empty raw then None
          else try Some (Float.of_string raw) with _ -> None
        in
        Some
          {
            days_held = d;
            pnl_percent = p;
            exit_trigger = fields.(_col_exit_trigger);
            entry_stage = fields.(_col_entry_stage);
            screener_score;
          }
    | _ -> None

let _load_trades ~path =
  let lines = In_channel.read_lines path in
  match lines with
  | [] | [ _ ] -> []
  | _header :: rows ->
      List.filter_map rows ~f:(fun row ->
          _parse_row (Array.of_list (String.split row ~on:',')))

let _percentile (sorted : float array) ~p =
  if Array.is_empty sorted then Float.nan
  else
    let n = Array.length sorted in
    let idx = Float.iround_down_exn (p *. Float.of_int (n - 1)) in
    sorted.(idx)

type bucket_stats = {
  n : int;
  p50_hold : float;
  p75_hold : float;
  p95_hold : float;
  mean_hold : float;
  mean_pnl_pct : float;
  win_rate : float;
  by_trigger : (string * int) list;
}

let _stats_of_bucket (ts : trade list) : bucket_stats =
  let n = List.length ts in
  if n = 0 then
    {
      n;
      p50_hold = Float.nan;
      p75_hold = Float.nan;
      p95_hold = Float.nan;
      mean_hold = Float.nan;
      mean_pnl_pct = Float.nan;
      win_rate = Float.nan;
      by_trigger = [];
    }
  else
    let holds =
      Array.of_list (List.map ts ~f:(fun t -> Float.of_int t.days_held))
    in
    Array.sort holds ~compare:Float.compare;
    let pnls = List.map ts ~f:(fun t -> t.pnl_percent) in
    let mean_pnl_pct = List.fold pnls ~init:0.0 ~f:( +. ) /. Float.of_int n in
    let mean_hold = Array.fold holds ~init:0.0 ~f:( +. ) /. Float.of_int n in
    let wins = List.count ts ~f:(fun t -> Float.( > ) t.pnl_percent 0.0) in
    let by_trigger =
      List.map ts ~f:(fun t -> t.exit_trigger)
      |> List.sort ~compare:String.compare
      |> List.group ~break:String.( <> )
      |> List.map ~f:(fun group -> (List.hd_exn group, List.length group))
      |> List.sort ~compare:(fun (_, a) (_, b) -> Int.compare b a)
    in
    {
      n;
      p50_hold = _percentile holds ~p:0.50;
      p75_hold = _percentile holds ~p:0.75;
      p95_hold = _percentile holds ~p:0.95;
      mean_hold;
      mean_pnl_pct;
      win_rate = Float.of_int wins /. Float.of_int n *. 100.0;
      by_trigger;
    }

let _group_by (ts : trade list) ~(key : trade -> string) :
    (string * trade list) list =
  ts
  |> List.sort ~compare:(fun a b -> String.compare (key a) (key b))
  |> List.group ~break:(fun a b -> String.( <> ) (key a) (key b))
  |> List.map ~f:(fun group -> (key (List.hd_exn group), group))

let _bucket_label_for_stage (t : trade) =
  if String.is_empty t.entry_stage then "(missing)" else t.entry_stage

let _score_quartile (score : float option) ~(thresholds : float * float * float)
    =
  let q25, q50, q75 = thresholds in
  match score with
  | None -> "(missing)"
  | Some s ->
      if Float.( < ) s q25 then "Q1 (lowest)"
      else if Float.( < ) s q50 then "Q2"
      else if Float.( < ) s q75 then "Q3"
      else "Q4 (highest)"

let _compute_score_thresholds (ts : trade list) =
  let arr =
    List.filter_map ts ~f:(fun t -> t.screener_score) |> Array.of_list
  in
  if Array.is_empty arr then (Float.nan, Float.nan, Float.nan)
  else (
    Array.sort arr ~compare:Float.compare;
    (_percentile arr ~p:0.25, _percentile arr ~p:0.50, _percentile arr ~p:0.75))

let _print_bucket_table ~title ~(buckets : (string * bucket_stats) list) =
  printf "## %s\n\n" title;
  printf
    "| Bucket | N | P50 | P75 | P95 | Mean hold | Mean P&L %% | Win-rate %% |\n";
  printf "|---|---:|---:|---:|---:|---:|---:|---:|\n";
  List.iter buckets ~f:(fun (label, s) ->
      printf "| %s | %d | %.0f | %.0f | %.0f | %.1f | %.2f | %.1f |\n" label s.n
        s.p50_hold s.p75_hold s.p95_hold s.mean_hold s.mean_pnl_pct s.win_rate);
  printf "\n"

let _print_cross_tab ~(buckets : (string * bucket_stats) list) =
  printf "### Exit-trigger breakdown within each bucket\n\n";
  printf "| Bucket | Trigger | Count | %% of bucket |\n";
  printf "|---|---|---:|---:|\n";
  List.iter buckets ~f:(fun (label, s) ->
      List.iter s.by_trigger ~f:(fun (trig, c) ->
          let pct = Float.of_int c /. Float.of_int s.n *. 100.0 in
          let trig_label = if String.is_empty trig then "(blank)" else trig in
          printf "| %s | %s | %d | %.1f |\n" label trig_label c pct));
  printf "\n"

let _report ~trades_path =
  let ts = _load_trades ~path:trades_path in
  let total = List.length ts in
  printf "# Hold-period per-stage analysis — Probe P4\n\n";
  printf "Source: `%s` (%d trades)\n\n" trades_path total;
  let by_stage =
    _group_by ts ~key:_bucket_label_for_stage
    |> List.map ~f:(fun (k, group) -> (k, _stats_of_bucket group))
  in
  _print_bucket_table ~title:"Per-stage hold distribution" ~buckets:by_stage;
  _print_cross_tab ~buckets:by_stage;
  let thresholds = _compute_score_thresholds ts in
  let by_score =
    _group_by ts ~key:(fun t -> _score_quartile t.screener_score ~thresholds)
    |> List.map ~f:(fun (k, group) -> (k, _stats_of_bucket group))
    |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
  in
  let q25, q50, q75 = thresholds in
  printf
    "Screener-score quartile thresholds (when stage is uniform): Q25=%.1f, \
     Q50=%.1f, Q75=%.1f\n\n"
    q25 q50 q75;
  _print_bucket_table
    ~title:"Per-screener-score-quartile hold distribution (auxiliary)"
    ~buckets:by_score;
  _print_cross_tab ~buckets:by_score

let _command =
  Command.basic
    ~summary:
      "Decompose a backtest trades.csv by entry_stage (P4) and by \
       screener-score quartile, emit a Markdown report on hold-distribution \
       and exit-trigger composition per bucket."
    (let%map_open.Command trades_path =
       flag "-trades" (required string) ~doc:"PATH backtest trades.csv"
     in
     fun () -> _report ~trades_path)

let () = Command_unix.run _command
