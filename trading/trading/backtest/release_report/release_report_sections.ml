open Core
open Release_report_types

(* --- Rendering helpers --- *)

let _delta_pct ~current ~prior =
  if Float.equal prior 0.0 then None
  else Some ((current -. prior) /. prior *. 100.0)

let _fmt_delta_pct = function None -> "n/a" | Some d -> sprintf "%+.1f%%" d
let _fmt_float_2 v = sprintf "%.2f" v
let _fmt_float_1 v = sprintf "%.1f" v
let _fmt_int_opt = function Some i -> Int.to_string i | None -> "n/a"
let _fmt_float_opt_1 = function Some f -> sprintf "%.1f" f | None -> "n/a"

let _delta_int_pct ~current ~prior =
  match (current, prior) with
  | Some c, Some p ->
      _delta_pct ~current:(Float.of_int c) ~prior:(Float.of_int p)
  | _ -> None

let _delta_float_pct ~current ~prior =
  match (current, prior) with
  | Some c, Some p -> _delta_pct ~current:c ~prior:p
  | _ -> None

(* --- Section renderers ---

   Each renderer returns a list of lines (no trailing newline). The top-level
   [render] joins everything with "\n" and adds a final newline. *)

let header ~title ~current ~prior =
  [
    sprintf "# %s" title;
    "";
    sprintf "- Current: `%s`" current;
    sprintf "- Prior:   `%s`" prior;
    "";
  ]

let _flag ~delta_pct ~threshold =
  match delta_pct with
  | Some d when Float.(d > threshold) -> " :rotating_light:"
  | _ -> ""

let _row_trading_metrics (cur, prior) =
  let row label fmt get =
    sprintf "| %s | %s | %s | %s |" label
      (fmt (get cur.actual))
      (fmt (get prior.actual))
      (_fmt_delta_pct
         (_delta_pct ~current:(get cur.actual) ~prior:(get prior.actual)))
  in
  let force_liq_flag a =
    if a.force_liquidations_count > 0 then " :rotating_light:" else ""
  in
  [
    sprintf "### %s" cur.name;
    "";
    sprintf "Period: %s → %s · Universe: %d · Steps: %d"
      (Date.to_string cur.summary.start_date)
      (Date.to_string cur.summary.end_date)
      cur.summary.universe_size cur.summary.n_steps;
    "";
    "| Metric | Current | Prior | Δ% |";
    "|---|---:|---:|---:|";
    row "Return %" _fmt_float_2 (fun a -> a.total_return_pct);
    row "Sharpe" _fmt_float_2 (fun a -> a.sharpe_ratio);
    row "Win rate %" _fmt_float_1 (fun a -> a.win_rate);
    row "Max DD %" _fmt_float_2 (fun a -> a.max_drawdown_pct);
    row "Trades" _fmt_float_1 (fun a -> a.total_trades);
    row "Avg hold (d)" _fmt_float_2 (fun a -> a.avg_holding_days);
    (* G4 force-liquidation count. Non-zero on either side flags a primary
       stop-machinery regression (red light glyph). *)
    sprintf "| Force-liq count | %d%s | %d%s | %s |"
      cur.actual.force_liquidations_count
      (force_liq_flag cur.actual)
      prior.actual.force_liquidations_count
      (force_liq_flag prior.actual)
      (_fmt_delta_pct
         (_delta_pct
            ~current:(Float.of_int cur.actual.force_liquidations_count)
            ~prior:(Float.of_int prior.actual.force_liquidations_count)));
    "";
  ]

let trading paired =
  if List.is_empty paired then
    [ "## Trading metrics"; ""; "_No paired scenarios._"; "" ]
  else
    let header = [ "## Trading metrics"; "" ] in
    let body = List.concat_map paired ~f:_row_trading_metrics in
    header @ body

let _row_rss ~threshold_pct (cur, prior) =
  let cur_rss = cur.peak_rss_kb in
  let prior_rss = prior.peak_rss_kb in
  let delta = _delta_int_pct ~current:cur_rss ~prior:prior_rss in
  let flag = _flag ~delta_pct:delta ~threshold:threshold_pct in
  sprintf "| %s | %s | %s | %s%s |" cur.name (_fmt_int_opt cur_rss)
    (_fmt_int_opt prior_rss) (_fmt_delta_pct delta) flag

let rss ~threshold_pct paired =
  let header =
    [
      "## Peak RSS (kB)";
      "";
      sprintf "Regression flag: Δ%% > %.0f%%" threshold_pct;
      "";
      "| Scenario | Current | Prior | Δ% |";
      "|---|---:|---:|---:|";
    ]
  in
  let body = List.map paired ~f:(_row_rss ~threshold_pct) in
  let footer = [ "" ] in
  header @ body @ footer

let _row_wall ~threshold_pct (cur, prior) =
  let cur_wall = cur.wall_seconds in
  let prior_wall = prior.wall_seconds in
  let delta = _delta_float_pct ~current:cur_wall ~prior:prior_wall in
  let flag = _flag ~delta_pct:delta ~threshold:threshold_pct in
  sprintf "| %s | %s | %s | %s%s |" cur.name
    (_fmt_float_opt_1 cur_wall)
    (_fmt_float_opt_1 prior_wall)
    (_fmt_delta_pct delta) flag

let wall ~threshold_pct paired =
  let header =
    [
      "## Wall time (s)";
      "";
      sprintf "Regression flag: Δ%% > %.0f%%" threshold_pct;
      "";
      "| Scenario | Current | Prior | Δ% |";
      "|---|---:|---:|---:|";
    ]
  in
  let body = List.map paired ~f:(_row_wall ~threshold_pct) in
  let footer = [ "" ] in
  header @ body @ footer
