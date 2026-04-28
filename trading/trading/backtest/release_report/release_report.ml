open Core

type actual = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  unrealized_pnl : float option; [@sexp.option]
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type summary_meta = {
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  n_steps : int;
  initial_cash : float;
  final_portfolio_value : float;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type scenario_run = {
  name : string;
  actual : actual;
  summary : summary_meta;
  peak_rss_kb : int option;
  wall_seconds : float option;
}
[@@deriving sexp]

type t = {
  current_label : string;
  prior_label : string;
  paired : (scenario_run * scenario_run) list;
  current_only : string list;
  prior_only : string list;
}
[@@deriving sexp]

type thresholds = { threshold_rss_pct : float; threshold_wall_pct : float }
[@@deriving sexp]

let default_thresholds = { threshold_rss_pct = 10.0; threshold_wall_pct = 25.0 }

(* --- File helpers --- *)

let _read_first_line path =
  try
    let ic = In_channel.create path in
    let line = In_channel.input_line ic in
    In_channel.close ic;
    Option.bind line ~f:(fun s ->
        let s = String.strip s in
        if String.is_empty s then None else Some s)
  with _ -> None

let _read_optional_int path =
  Option.bind (_read_first_line path) ~f:(fun s ->
      try Some (Int.of_string s) with _ -> None)

let _read_optional_float path =
  Option.bind (_read_first_line path) ~f:(fun s ->
      try Some (Float.of_string s) with _ -> None)

let load_scenario_run ~dir =
  let name = Filename.basename dir in
  let actual_path = Filename.concat dir "actual.sexp" in
  let summary_path = Filename.concat dir "summary.sexp" in
  if not (Sys_unix.file_exists_exn actual_path) then
    failwithf "Missing actual.sexp in %s" dir ();
  if not (Sys_unix.file_exists_exn summary_path) then
    failwithf "Missing summary.sexp in %s" dir ();
  let actual = actual_of_sexp (Sexp.load_sexp actual_path) in
  let summary = summary_meta_of_sexp (Sexp.load_sexp summary_path) in
  let peak_rss_kb =
    _read_optional_int (Filename.concat dir "peak_rss_kb.txt")
  in
  let wall_seconds =
    _read_optional_float (Filename.concat dir "wall_seconds.txt")
  in
  { name; actual; summary; peak_rss_kb; wall_seconds }

let _list_scenario_subdirs root =
  if not (Sys_unix.is_directory_exn root) then
    failwithf "Batch dir is not a directory: %s" root ();
  Sys_unix.ls_dir root
  |> List.sort ~compare:String.compare
  |> List.filter_map ~f:(fun entry ->
      let path = Filename.concat root entry in
      if
        Sys_unix.is_directory_exn path
        && Sys_unix.file_exists_exn (Filename.concat path "actual.sexp")
      then Some entry
      else None)

let _label_of_dir dir =
  match Filename.basename dir with "" -> dir | name -> name

let _pair_scenarios ~current_runs ~prior_runs =
  let by_name runs =
    List.map runs ~f:(fun (r : scenario_run) -> (r.name, r))
    |> Map.of_alist_exn (module String)
  in
  let current_map = by_name current_runs in
  let prior_map = by_name prior_runs in
  let names_current = Map.key_set current_map in
  let names_prior = Map.key_set prior_map in
  let common = Set.inter names_current names_prior |> Set.to_list in
  let only_current = Set.diff names_current names_prior |> Set.to_list in
  let only_prior = Set.diff names_prior names_current |> Set.to_list in
  let paired =
    List.map common ~f:(fun name ->
        (Map.find_exn current_map name, Map.find_exn prior_map name))
  in
  (paired, only_current, only_prior)

let load ~current ~prior =
  let load_batch root =
    let subdirs = _list_scenario_subdirs root in
    List.map subdirs ~f:(fun name ->
        load_scenario_run ~dir:(Filename.concat root name))
  in
  let current_runs = load_batch current in
  let prior_runs = load_batch prior in
  let paired, current_only, prior_only =
    _pair_scenarios ~current_runs ~prior_runs
  in
  {
    current_label = _label_of_dir current;
    prior_label = _label_of_dir prior;
    paired;
    current_only;
    prior_only;
  }

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

let _section_header ~title ~current ~prior =
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
    "";
  ]

let _trading_section paired =
  if List.is_empty paired then
    [ "## Trading metrics"; ""; "_No paired scenarios._"; "" ]
  else
    let header = [ "## Trading metrics"; "" ] in
    let body = List.concat_map paired ~f:_row_trading_metrics in
    header @ body

let _row_rss ~thresholds (cur, prior) =
  let cur_rss = cur.peak_rss_kb in
  let prior_rss = prior.peak_rss_kb in
  let delta = _delta_int_pct ~current:cur_rss ~prior:prior_rss in
  let flag = _flag ~delta_pct:delta ~threshold:thresholds.threshold_rss_pct in
  sprintf "| %s | %s | %s | %s%s |" cur.name (_fmt_int_opt cur_rss)
    (_fmt_int_opt prior_rss) (_fmt_delta_pct delta) flag

let _rss_section ~thresholds paired =
  let header =
    [
      "## Peak RSS (kB)";
      "";
      sprintf "Regression flag: Δ%% > %.0f%%" thresholds.threshold_rss_pct;
      "";
      "| Scenario | Current | Prior | Δ% |";
      "|---|---:|---:|---:|";
    ]
  in
  let body = List.map paired ~f:(_row_rss ~thresholds) in
  let footer = [ "" ] in
  header @ body @ footer

let _row_wall ~thresholds (cur, prior) =
  let cur_wall = cur.wall_seconds in
  let prior_wall = prior.wall_seconds in
  let delta = _delta_float_pct ~current:cur_wall ~prior:prior_wall in
  let flag = _flag ~delta_pct:delta ~threshold:thresholds.threshold_wall_pct in
  sprintf "| %s | %s | %s | %s%s |" cur.name
    (_fmt_float_opt_1 cur_wall)
    (_fmt_float_opt_1 prior_wall)
    (_fmt_delta_pct delta) flag

let _wall_section ~thresholds paired =
  let header =
    [
      "## Wall time (s)";
      "";
      sprintf "Regression flag: Δ%% > %.0f%%" thresholds.threshold_wall_pct;
      "";
      "| Scenario | Current | Prior | Δ% |";
      "|---|---:|---:|---:|";
    ]
  in
  let body = List.map paired ~f:(_row_wall ~thresholds) in
  let footer = [ "" ] in
  header @ body @ footer

let _one_sided_section ~title names =
  if List.is_empty names then []
  else
    let header = [ sprintf "## %s" title; "" ] in
    let body = List.map names ~f:(fun n -> sprintf "- `%s`" n) in
    header @ body @ [ "" ]

let render ?(thresholds = default_thresholds) (t : t) =
  let lines =
    _section_header ~title:"Release perf report" ~current:t.current_label
      ~prior:t.prior_label
    @ _trading_section t.paired
    @ _rss_section ~thresholds t.paired
    @ _wall_section ~thresholds t.paired
    @ _one_sided_section ~title:"Current-only scenarios" t.current_only
    @ _one_sided_section ~title:"Prior-only scenarios" t.prior_only
  in
  String.concat ~sep:"\n" lines ^ "\n"
