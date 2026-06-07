open Core

type per_start = {
  start_date : Date.t;
  cagr_pct : float;
  max_underwater_vs_initial_pct : float;
  max_drawdown_pct : float;
}
[@@deriving sexp, equal]

type report = {
  end_date : Date.t;
  starts : per_start list;
  cagr : Dispersion_stats.summary;
  max_underwater_vs_initial : Dispersion_stats.summary;
  max_drawdown : Dispersion_stats.summary;
}
[@@deriving sexp, equal]

let build ~end_date starts =
  let sorted =
    List.sort starts ~compare:(fun a b ->
        Date.compare a.start_date b.start_date)
  in
  {
    end_date;
    starts = sorted;
    cagr = Dispersion_stats.summarize (List.map sorted ~f:(fun s -> s.cagr_pct));
    max_underwater_vs_initial =
      Dispersion_stats.summarize
        (List.map sorted ~f:(fun s -> s.max_underwater_vs_initial_pct));
    max_drawdown =
      Dispersion_stats.summarize
        (List.map sorted ~f:(fun s -> s.max_drawdown_pct));
  }

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
    ]

(** One per-start detail row. *)
let _start_row (s : per_start) =
  _row
    [
      Date.to_string s.start_date;
      _f2 s.cagr_pct;
      _f2 s.max_underwater_vs_initial_pct;
      _f2 s.max_drawdown_pct;
    ]

(** The per-start detail table (one row per start date). *)
let _starts_table report =
  let header =
    [
      _row [ "start"; "CAGR %"; "MaxUnderwaterVsInitial %"; "MaxDrawdown %" ];
      _row [ "---"; "---"; "---"; "---" ];
    ]
  in
  String.concat ~sep:"\n" (header @ List.map report.starts ~f:_start_row)

(** Full report body (non-empty case): header + dispersion table + per-start
    detail, trailing newline. *)
let _render_full report ~header =
  String.concat ~sep:"\n\n"
    [
      header;
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
