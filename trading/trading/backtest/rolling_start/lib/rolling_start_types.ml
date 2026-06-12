open Core

type per_start = {
  start_date : Date.t;
  cagr_pct : float;
  max_underwater_vs_initial_pct : float;
  max_drawdown_pct : float;
  benchmark_cagr_pct : float;
  edge_pct : float;
  sharpe : float;
  time_underwater_pct : float;
  realized_return_pct : float;
}
[@@deriving sexp, equal]

type report = {
  end_date : Date.t;
  min_window_days : int;
  starts : per_start list;
  cagr : Dispersion_stats.summary;
  max_underwater_vs_initial : Dispersion_stats.summary;
  max_drawdown : Dispersion_stats.summary;
  edge : Dispersion_stats.summary;
}
[@@deriving sexp, equal]

(* Inclusive calendar-day count of [start_date .. end_date] — the window length
   matching the runner's [_inclusive_days] / CAGR-annualisation convention. *)
let _inclusive_window_days ~end_date (s : per_start) =
  Date.diff end_date s.start_date + 1

let is_short_window ~min_window_days ~end_date (s : per_start) =
  min_window_days > 0 && _inclusive_window_days ~end_date s < min_window_days

(* Edge can legitimately be nan (a start with no benchmark); the dispersion
   summary is computed over only the defined edges so nan rows neither poison
   the stats nor inflate n. *)
let _defined_edges starts =
  List.filter_map starts ~f:(fun s ->
      if Float.is_nan s.edge_pct then None else Some s.edge_pct)

let build ?(min_window_days = 0) ~end_date starts =
  if min_window_days < 0 then
    invalid_arg
      (sprintf "build: min_window_days must be non-negative, got %d"
         min_window_days);
  let sorted =
    List.sort starts ~compare:(fun a b ->
        Date.compare a.start_date b.start_date)
  in
  (* The detail table renders every start; the summaries are computed over only
     the long-enough subset so a short-window start's absurd annualised CAGR
     cannot poison the aggregate. With [min_window_days = 0] this keeps every
     start (predicate is always false), so the summaries are bit-identical. *)
  let eligible =
    List.filter sorted ~f:(fun s ->
        not (is_short_window ~min_window_days ~end_date s))
  in
  {
    end_date;
    min_window_days;
    starts = sorted;
    cagr =
      Dispersion_stats.summarize (List.map eligible ~f:(fun s -> s.cagr_pct));
    max_underwater_vs_initial =
      Dispersion_stats.summarize
        (List.map eligible ~f:(fun s -> s.max_underwater_vs_initial_pct));
    max_drawdown =
      Dispersion_stats.summarize
        (List.map eligible ~f:(fun s -> s.max_drawdown_pct));
    edge = Dispersion_stats.summarize (_defined_edges eligible);
  }

let pct_beating_benchmark report =
  let eligible =
    List.filter report.starts ~f:(fun s ->
        not
          (is_short_window ~min_window_days:report.min_window_days
             ~end_date:report.end_date s))
  in
  let defined = _defined_edges eligible in
  match defined with
  | [] -> Float.nan
  | _ ->
      let beats = List.count defined ~f:(fun e -> Float.( > ) e 0.0) in
      Float.of_int beats /. Float.of_int (List.length defined) *. 100.0

(** A markdown table row: pipe-joined cells with leading/trailing pipes. *)
let _row cells = "| " ^ String.concat ~sep:" | " cells ^ " |"

let _f2 x = Printf.sprintf "%.2f" x

(** One dispersion-summary line in the per-metric table. *)
let _summary_row ~label (s : Dispersion_stats.summary) =
  _row
    [
      label;
      _f2 s.median;
      _f2 s.p10;
      _f2 s.iqr;
      _f2 s.min;
      _f2 s.max;
      Int.to_string s.n;
    ]

(** The per-metric dispersion table (median / 10th-pct / IQR / min / max / n).
*)
let _dispersion_table report =
  String.concat ~sep:"\n"
    [
      _row [ "metric"; "median"; "p10"; "IQR"; "min"; "max"; "n" ];
      _row [ "---"; "---"; "---"; "---"; "---"; "---"; "---" ];
      _summary_row ~label:"CAGR %" report.cagr;
      _summary_row ~label:"MaxUnderwaterVsInitial %"
        report.max_underwater_vs_initial;
      _summary_row ~label:"MaxDrawdown %" report.max_drawdown;
      _summary_row ~label:"Edge vs benchmark %" report.edge;
    ]

(** The headline robustness summary: how often, and by how much, the strategy
    beat the benchmark across start dates. *)
let _robustness_summary report =
  String.concat ~sep:"\n"
    [
      Printf.sprintf "- Median edge vs benchmark: %s %%"
        (_f2 report.edge.median);
      Printf.sprintf "- Worst-start edge: %s %%" (_f2 report.edge.min);
      Printf.sprintf "- Starts beating benchmark: %s %% (of %d benchmarked)"
        (_f2 (pct_beating_benchmark report))
        report.edge.n;
    ]

(** One per-start detail row — the matrix row: start x
    [strategy CAGR, benchmark CAGR, edge, Sharpe, capital-DD, time-underwater,
     realized basis], plus a [note] cell flagging short-window starts that are
    excluded from the summaries. *)
let _start_row ~min_window_days ~end_date (s : per_start) =
  let note =
    if is_short_window ~min_window_days ~end_date s then
      "short window, excluded"
    else ""
  in
  _row
    [
      Date.to_string s.start_date;
      _f2 s.cagr_pct;
      _f2 s.benchmark_cagr_pct;
      _f2 s.edge_pct;
      _f2 s.sharpe;
      _f2 s.max_underwater_vs_initial_pct;
      _f2 s.time_underwater_pct;
      _f2 s.max_drawdown_pct;
      _f2 s.realized_return_pct;
      note;
    ]

(* Column titles of the per-start detail table, in {!_start_row} order. *)
let _starts_header_cells =
  [
    "start";
    "CAGR %";
    "Benchmark CAGR %";
    "Edge %";
    "Sharpe";
    "MaxUnderwaterVsInitial %";
    "TimeUnderwater %";
    "MaxDrawdown %";
    "Realized return %";
    "note";
  ]

(** The per-start detail table (one row per start date). *)
let _starts_table report =
  let separator = List.map _starts_header_cells ~f:(fun _ -> "---") in
  let header = [ _row _starts_header_cells; _row separator ] in
  let rows =
    List.map report.starts
      ~f:
        (_start_row ~min_window_days:report.min_window_days
           ~end_date:report.end_date)
  in
  String.concat ~sep:"\n" (header @ rows)

(** Full report body (non-empty case): header + dispersion table + per-start
    detail, trailing newline. *)
let _render_full report ~header =
  String.concat ~sep:"\n\n"
    [
      header;
      "## Edge-vs-benchmark robustness";
      _robustness_summary report;
      "## Dispersion across starts";
      _dispersion_table report;
      "## Per-start detail";
      _starts_table report;
    ]
  ^ "\n"

let to_markdown report =
  let header =
    Printf.sprintf "# Rolling-start dispersion (end %s, %d starts)"
      (Date.to_string report.end_date)
      (List.length report.starts)
  in
  match report.starts with
  | [] -> header ^ "\n\n_No starts._\n"
  | _ -> _render_full report ~header
