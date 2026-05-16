open! Core

type drift_row = {
  date : Date.t;
  stooq_close : float;
  eodhd_adj_close : float;
  rel_diff : float;
}
[@@deriving show, eq]

type stats = {
  n_compared : int;
  n_flagged : int;
  mean_abs_rel_diff : float;
  max_abs_rel_diff : float;
}
[@@deriving show, eq]

type report = {
  symbol : string;
  threshold : float;
  overlap_first : Date.t option;
  overlap_last : Date.t option;
  stooq_only_count : int;
  eodhd_only_count : int;
  stats : stats;
  flagged_rows : drift_row list;
}
[@@deriving show, eq]

let _flagged_top_n_for_report = 10

let _empty_stats =
  {
    n_compared = 0;
    n_flagged = 0;
    mean_abs_rel_diff = 0.0;
    max_abs_rel_diff = 0.0;
  }

(* Join two ascending-by-date series on [date]. Stooq dates may include
   weekends? No — Stooq's daily-cadence CSV is trading-day cadence. Both
   inputs are trading-day series; we still walk them with a generic merge
   so any gap (holidays / single-source delisting tail) is handled.

   Returns (matched_pairs, stooq_only_count, eodhd_only_count). *)
let _merge_by_date stooq eodhd =
  let rec loop stooq_xs eodhd_xs acc s_only e_only =
    match (stooq_xs, eodhd_xs) with
    | [], [] -> (List.rev acc, s_only, e_only)
    | [], _ :: rest -> loop [] rest acc s_only (e_only + 1)
    | _ :: rest, [] -> loop rest [] acc (s_only + 1) e_only
    | s :: s_rest, e :: e_rest ->
        let s_date = s.Stooq.Stooq_client.date in
        let e_date = e.Types.Daily_price.date in
        let cmp = Date.compare s_date e_date in
        if cmp = 0 then loop s_rest e_rest ((s, e) :: acc) s_only e_only
        else if cmp < 0 then loop s_rest eodhd_xs acc (s_only + 1) e_only
        else loop stooq_xs e_rest acc s_only (e_only + 1)
  in
  loop stooq eodhd [] 0 0

let _rel_diff ~stooq_close ~eodhd_adj_close =
  if Float.equal stooq_close 0.0 then 0.0
  else (eodhd_adj_close -. stooq_close) /. stooq_close

let _pair_to_row (s, (e : Types.Daily_price.t)) : drift_row =
  let stooq_close = s.Stooq.Stooq_client.close in
  let eodhd_adj_close = e.adjusted_close in
  let rel_diff = _rel_diff ~stooq_close ~eodhd_adj_close in
  { date = s.date; stooq_close; eodhd_adj_close; rel_diff }

let build_drift_rows ~stooq ~eodhd : drift_row list =
  let pairs, _s_only, _e_only = _merge_by_date stooq eodhd in
  List.map pairs ~f:_pair_to_row

let _abs_rel_diff row = Float.abs row.rel_diff

let compute_stats ~threshold rows =
  let n_compared = List.length rows in
  if n_compared = 0 then _empty_stats
  else
    let abs_diffs = List.map rows ~f:_abs_rel_diff in
    let sum = List.fold abs_diffs ~init:0.0 ~f:Float.( + ) in
    let max_v =
      List.fold abs_diffs ~init:0.0 ~f:(fun acc v -> Float.max acc v)
    in
    let n_flagged =
      List.count rows ~f:(fun r -> Float.( > ) (_abs_rel_diff r) threshold)
    in
    {
      n_compared;
      n_flagged;
      mean_abs_rel_diff = sum /. Float.of_int n_compared;
      max_abs_rel_diff = max_v;
    }

let _overlap_endpoints rows =
  match rows with
  | [] -> (None, None)
  | first :: _ ->
      let last = List.last_exn rows in
      (Some first.date, Some last.date)

let _top_flagged ~threshold rows =
  rows
  |> List.filter ~f:(fun r -> Float.( > ) (_abs_rel_diff r) threshold)
  |> List.sort ~compare:(fun a b ->
      Float.compare (_abs_rel_diff b) (_abs_rel_diff a))
  |> fun sorted -> List.take sorted _flagged_top_n_for_report

let build_report ~symbol ~stooq ~eodhd ~threshold =
  let pairs, stooq_only_count, eodhd_only_count = _merge_by_date stooq eodhd in
  let rows = List.map pairs ~f:_pair_to_row in
  let stats = compute_stats ~threshold rows in
  let overlap_first, overlap_last = _overlap_endpoints rows in
  {
    symbol = String.uppercase symbol;
    threshold;
    overlap_first;
    overlap_last;
    stooq_only_count;
    eodhd_only_count;
    stats;
    flagged_rows = _top_flagged ~threshold rows;
  }

let _format_date_or_na = function None -> "n/a" | Some d -> Date.to_string d

let _format_summary_lines (r : report) =
  [
    Printf.sprintf "Stooq drift check: %s" r.symbol;
    Printf.sprintf "  threshold:     |rel_diff| > %.4f (%.2f%%)" r.threshold
      (r.threshold *. 100.0);
    Printf.sprintf "  overlap range: %s → %s"
      (_format_date_or_na r.overlap_first)
      (_format_date_or_na r.overlap_last);
    Printf.sprintf "  days compared: %d" r.stats.n_compared;
    Printf.sprintf "  days flagged:  %d" r.stats.n_flagged;
    Printf.sprintf "  mean |rel_diff|: %.4f%%"
      (r.stats.mean_abs_rel_diff *. 100.0);
    Printf.sprintf "  max  |rel_diff|: %.4f%%"
      (r.stats.max_abs_rel_diff *. 100.0);
    Printf.sprintf "  stooq-only days: %d (informational)" r.stooq_only_count;
    Printf.sprintf "  eodhd-only days: %d (informational)" r.eodhd_only_count;
  ]

let _format_row_line (r : drift_row) =
  Printf.sprintf "    %s  stooq=%.4f  eodhd_adj=%.4f  rel_diff=%+.4f%%"
    (Date.to_string r.date) r.stooq_close r.eodhd_adj_close (r.rel_diff *. 100.0)

let _format_flagged_section (r : report) =
  match r.flagged_rows with
  | [] -> [ "  no flagged days." ]
  | rows ->
      Printf.sprintf "  top %d flagged days (by |rel_diff|, descending):"
        (List.length rows)
      :: List.map rows ~f:_format_row_line

let format_text_report (r : report) =
  let lines = _format_summary_lines r @ _format_flagged_section r in
  String.concat ~sep:"\n" lines ^ "\n"
