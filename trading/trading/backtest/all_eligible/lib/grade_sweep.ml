(** Grade-sweep + per-cell-emission helpers for the all-eligible runner.

    See [grade_sweep.mli] for the API contract. *)

open Core

(* ---------------------------------------------------------------- *)
(* Cell directory naming                                              *)
(* ---------------------------------------------------------------- *)

let grade_dir_name (g : Weinstein_types.grade) : string =
  let s = Weinstein_types.grade_to_string g in
  match s with "A+" -> "grade-A_plus" | other -> "grade-" ^ other

let sweep_grades : Weinstein_types.grade list = [ F; D; C; B; A; A_plus ]

(* ---------------------------------------------------------------- *)
(* Cell construction                                                  *)
(* ---------------------------------------------------------------- *)

let build_cell ~(base_config : All_eligible.config)
    ~(scored : Backtest_optimal.Optimal_types.scored_candidate list)
    ~(min_grade : Weinstein_types.grade) :
    All_eligible.config * All_eligible.result =
  let filtered = All_eligible.filter_by_min_grade ~min_grade scored in
  let deduped = All_eligible.dedup_first_admission filtered in
  let cfg = { base_config with All_eligible.min_grade } in
  let result = All_eligible.grade ~config:cfg ~scored:deduped in
  (cfg, result)

(* ---------------------------------------------------------------- *)
(* Cross-cell summary rendering                                       *)
(* ---------------------------------------------------------------- *)

let _sweep_row ~(min_grade : Weinstein_types.grade)
    ~(result : All_eligible.result) : string =
  let agg = result.aggregate in
  Printf.sprintf "| %s | %d | %d | %d | %.4f | %.6f | %.2f |"
    (Weinstein_types.grade_to_string min_grade)
    agg.trade_count agg.winners agg.losers agg.win_rate_pct agg.mean_return_pct
    agg.total_pnl_dollars

let format_sweep_summary_md ~scenario_name ~start_date ~end_date
    ~(cells : (Weinstein_types.grade * All_eligible.result) list) : string =
  let header_lines =
    [
      Printf.sprintf
        "# All-eligible diagnostic — opportunity-cost grade sweep — %s"
        scenario_name;
      "";
      Printf.sprintf "Period: %s to %s"
        (Date.to_string start_date)
        (Date.to_string end_date);
      "";
      "## Grade sweep";
      "";
      "| min_grade | trade_count | winners | losers | win_rate_pct | \
       mean_return_pct | total_pnl_dollars |";
      "|---|---:|---:|---:|---:|---:|---:|";
    ]
  in
  let row_lines =
    List.map cells ~f:(fun (g, r) -> _sweep_row ~min_grade:g ~result:r)
  in
  String.concat ~sep:"\n"
    (header_lines @ row_lines
    @ [ ""; "Per-grade artefacts: see `grade-<G>/` subdirs."; "" ])

(* ---------------------------------------------------------------- *)
(* Per-cell artefact emission                                         *)
(* ---------------------------------------------------------------- *)

type cell_inputs = {
  base_config : All_eligible.config;
  scored : Backtest_optimal.Optimal_types.scored_candidate list;
  scenario : Scenario_lib.Scenario.t;
  out_dir : string;
  write_trades_csv : path:string -> All_eligible.result -> unit;
  format_summary_md :
    scenario_name:string ->
    start_date:Date.t ->
    end_date:Date.t ->
    result:All_eligible.result ->
    string;
}

let _write_config_sexp ~path (config : All_eligible.config) : unit =
  Sexp.save_hum path (All_eligible.sexp_of_config config)

(** Write the three per-cell artefacts to [cell_dir]. *)
let _emit_cell ~cell_dir ~(inputs : cell_inputs) ~(config : All_eligible.config)
    ~(result : All_eligible.result) : unit =
  let trades_path = Filename.concat cell_dir "trades.csv" in
  let summary_path = Filename.concat cell_dir "summary.md" in
  let config_path = Filename.concat cell_dir "config.sexp" in
  inputs.write_trades_csv ~path:trades_path result;
  let md =
    inputs.format_summary_md
      ~scenario_name:inputs.scenario.Scenario_lib.Scenario.name
      ~start_date:inputs.scenario.period.start_date
      ~end_date:inputs.scenario.period.end_date ~result
  in
  Out_channel.write_all summary_path ~data:md;
  _write_config_sexp ~path:config_path config;
  eprintf "all_eligible: wrote %s, %s, %s\n%!" trades_path summary_path
    config_path

(** Materialise the cell directory + emit one cell. Common between single and
    sweep modes. *)
let _materialise_and_emit ~(inputs : cell_inputs)
    ~(min_grade : Weinstein_types.grade) :
    Weinstein_types.grade * All_eligible.result =
  let cell_dir = Filename.concat inputs.out_dir (grade_dir_name min_grade) in
  Core_unix.mkdir_p cell_dir;
  let cfg, result =
    build_cell ~base_config:inputs.base_config ~scored:inputs.scored ~min_grade
  in
  eprintf "all_eligible: min_grade=%s → %d trades\n%!"
    (Weinstein_types.grade_to_string min_grade)
    result.aggregate.trade_count;
  _emit_cell ~cell_dir ~inputs ~config:cfg ~result;
  (min_grade, result)

let emit_single_cell ~(inputs : cell_inputs) : unit =
  let _ =
    _materialise_and_emit ~inputs ~min_grade:inputs.base_config.min_grade
  in
  ()

let emit_grade_sweep ~(inputs : cell_inputs) : unit =
  let cells =
    List.map sweep_grades ~f:(fun g ->
        _materialise_and_emit ~inputs ~min_grade:g)
  in
  let md =
    format_sweep_summary_md
      ~scenario_name:inputs.scenario.Scenario_lib.Scenario.name
      ~start_date:inputs.scenario.period.start_date
      ~end_date:inputs.scenario.period.end_date ~cells
  in
  let summary_path = Filename.concat inputs.out_dir "summary.md" in
  Out_channel.write_all summary_path ~data:md;
  eprintf "all_eligible: wrote cross-grade %s\n%!" summary_path
