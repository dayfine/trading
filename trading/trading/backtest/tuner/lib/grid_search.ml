open Core
module Metric_types = Trading_simulation_types.Metric_types

(** {1 Parameter spec} *)

type param_values = float list
type param_spec = (string * param_values) list
type cell = (string * float) list

(** {1 Objectives} *)

type objective =
  | Sharpe
  | Calmar
  | TotalReturn
  | Concavity_coef
  | Composite of (Metric_types.metric_type * float) list

let objective_label = function
  | Sharpe -> "sharpe"
  | Calmar -> "calmar"
  | TotalReturn -> "total_return"
  | Concavity_coef -> "concavity_coef"
  | Composite _ -> "composite"

let objective_metric_type = function
  | Sharpe -> Some Metric_types.SharpeRatio
  | Calmar -> Some Metric_types.CalmarRatio
  | TotalReturn -> Some Metric_types.TotalReturnPct
  | Concavity_coef -> Some Metric_types.ConcavityCoef
  | Composite _ -> None

let _lookup_metric metrics mt =
  Option.value (Map.find metrics mt) ~default:0.0

let evaluate_objective objective metrics =
  match objective with
  | Composite weights ->
      List.fold weights ~init:0.0 ~f:(fun acc (mt, w) ->
          acc +. (w *. _lookup_metric metrics mt))
  | _ ->
      let mt = Option.value_exn (objective_metric_type objective) in
      _lookup_metric metrics mt

(** {1 Cells — Cartesian product} *)

(** Build the Cartesian product. The recursion expands the head's value list,
    pairs each value with the recursive product of the tail, and concatenates.
    Lexicographic order: the LAST entry varies fastest, the FIRST entry varies
    slowest — matches the standard nested-loop order. *)
let rec _cartesian = function
  | [] -> [ [] ]
  | (key, values) :: rest ->
      let tail_cells = _cartesian rest in
      List.concat_map values ~f:(fun v ->
          List.map tail_cells ~f:(fun tail -> (key, v) :: tail))

let cells_of_spec spec =
  if List.exists spec ~f:(fun (_, vs) -> List.is_empty vs) then []
  else _cartesian spec

let cell_to_overrides cell =
  List.map cell ~f:(fun (key, value) ->
      let key_eq_value = sprintf "%s=%.17g" key value in
      match Backtest.Config_override.parse_to_sexp key_eq_value with
      | Ok sexp -> sexp
      | Error err ->
          failwithf "cell_to_overrides: failed to parse %s: %s" key_eq_value
            (Status.show err) ())

(** {1 Evaluation} *)

type evaluator = cell -> scenario:string -> Metric_types.metric_set

type row = {
  cell : cell;
  scenario : string;
  metrics : Metric_types.metric_set;
  objective_value : float;
}

type result = { rows : row list; best_cell : cell; best_score : float }

(** Build [(cell, [row; row; ...])] groups in cell-enumeration order. We build
    this twice — once for [rows] (flattened) and once for [best_cell]
    (per-cell mean) — but the same upstream evaluator call is reused via
    [Hashtbl] keyed by cell index. *)
let _evaluate_grid spec ~scenarios ~objective ~evaluator =
  let cells = cells_of_spec spec in
  List.concat_map cells ~f:(fun cell ->
      List.map scenarios ~f:(fun scenario ->
          let metrics = evaluator cell ~scenario in
          let objective_value = evaluate_objective objective metrics in
          { cell; scenario; metrics; objective_value }))

let _mean = function
  | [] -> Float.neg_infinity
  | values ->
      List.fold values ~init:0.0 ~f:( +. ) /. Float.of_int (List.length values)

let _group_rows_by_cell rows =
  (* Preserve cell-enumeration order via assoc list. Cells from [_evaluate_grid]
     are emitted in the same order as [cells_of_spec]; consecutive [row.cell]s
     belonging to the same cell are contiguous because we enumerate scenarios
     inside each cell. *)
  let cell_equal a b =
    List.equal
      (fun (k1, v1) (k2, v2) -> String.equal k1 k2 && Float.equal v1 v2)
      a b
  in
  List.fold rows ~init:[] ~f:(fun acc row ->
      match acc with
      | (last_cell, last_rows) :: rest when cell_equal last_cell row.cell ->
          (last_cell, row :: last_rows) :: rest
      | _ -> (row.cell, [ row ]) :: acc)
  |> List.rev_map ~f:(fun (c, rs) -> (c, List.rev rs))

let _argmax_by_cell rows =
  let groups = _group_rows_by_cell rows in
  let scored =
    List.map groups ~f:(fun (cell, rs) ->
        let scores = List.map rs ~f:(fun r -> r.objective_value) in
        (cell, _mean scores))
  in
  match scored with
  | [] -> ([], Float.neg_infinity)
  | (first_cell, first_score) :: rest ->
      List.fold rest ~init:(first_cell, first_score)
        ~f:(fun (best_c, best_s) (c, s) ->
          if Float.( > ) s best_s then (c, s) else (best_c, best_s))

let run spec ~scenarios ~objective ~evaluator =
  if List.is_empty scenarios then
    invalid_arg "Grid_search.run: scenarios must be non-empty";
  let rows = _evaluate_grid spec ~scenarios ~objective ~evaluator in
  let best_cell, best_score = _argmax_by_cell rows in
  { rows; best_cell; best_score }

(** {1 Sensitivity analysis} *)

type sensitivity_row = {
  param : string;
  varied_values : (float * float) list;
}

(** Find rows whose cell matches [best_cell] except possibly on [focus_param].
    Group by the focal param's value, average objectives across scenarios. *)
let _sensitivity_for_param ~focus_param ~best_cell rows =
  let matches_except_focus row_cell =
    List.for_all2_exn best_cell row_cell ~f:(fun (bk, bv) (rk, rv) ->
        if String.equal bk rk && String.equal bk focus_param then true
        else String.equal bk rk && Float.equal bv rv)
  in
  let filtered =
    List.filter rows ~f:(fun r -> matches_except_focus r.cell)
  in
  let value_of_focus row =
    List.find_map_exn row.cell ~f:(fun (k, v) ->
        if String.equal k focus_param then Some v else None)
  in
  let by_value = Hashtbl.create (module Float) in
  List.iter filtered ~f:(fun r ->
      let v = value_of_focus r in
      Hashtbl.update by_value v ~f:(function
        | None -> [ r.objective_value ]
        | Some xs -> r.objective_value :: xs));
  Hashtbl.to_alist by_value
  |> List.map ~f:(fun (v, scores) -> (v, _mean scores))
  |> List.sort ~compare:(fun (a, _) (b, _) -> Float.compare a b)

let compute_sensitivity spec result =
  if List.is_empty spec || List.is_empty result.rows then []
  else
    List.map spec ~f:(fun (param, _) ->
        let varied_values =
          _sensitivity_for_param ~focus_param:param
            ~best_cell:result.best_cell result.rows
        in
        { param; varied_values })

(** {1 Output} *)

let _all_metric_types = Backtest.Comparison.all_metric_types

let _csv_header_for_cell cell ~objective =
  let param_keys = List.map cell ~f:fst in
  let metric_labels = List.map _all_metric_types ~f:Backtest.Comparison.metric_label in
  let objective_col = "objective_" ^ objective_label objective in
  param_keys @ [ "scenario" ] @ metric_labels @ [ objective_col ]

let _csv_row row ~objective:_ =
  let param_values = List.map row.cell ~f:(fun (_, v) -> sprintf "%.17g" v) in
  let metric_values =
    List.map _all_metric_types ~f:(fun mt ->
        match Map.find row.metrics mt with
        | Some v -> sprintf "%.6f" v
        | None -> "")
  in
  param_values @ [ row.scenario ] @ metric_values
  @ [ sprintf "%.6f" row.objective_value ]

let _quote_csv_field s =
  if String.exists s ~f:(fun c -> Char.equal c ',' || Char.equal c '"' || Char.equal c '\n')
  then "\"" ^ String.substr_replace_all s ~pattern:"\"" ~with_:"\"\"" ^ "\""
  else s

let _csv_line fields =
  String.concat ~sep:","
    (List.map fields ~f:_quote_csv_field)
  ^ "\n"

let write_csv ~output_path ~objective result =
  Out_channel.with_file output_path ~f:(fun oc ->
      let header_cell =
        match result.rows with
        | [] -> []
        | r :: _ -> r.cell
      in
      let header = _csv_header_for_cell header_cell ~objective in
      Out_channel.output_string oc (_csv_line header);
      List.iter result.rows ~f:(fun r ->
          Out_channel.output_string oc (_csv_line (_csv_row r ~objective))))

let write_best_sexp ~output_path result =
  let sexps = cell_to_overrides result.best_cell in
  let combined = Sexp.List sexps in
  Out_channel.with_file output_path ~f:(fun oc ->
      Out_channel.output_string oc (Sexp.to_string_hum combined);
      Out_channel.output_string oc "\n")

let _format_sensitivity_section row =
  let header =
    sprintf "## Param: `%s`\n\n| Value | Mean objective |\n|---|---|\n" row.param
  in
  let body =
    List.map row.varied_values ~f:(fun (v, score) ->
        sprintf "| %.6g | %.6f |" v score)
    |> String.concat ~sep:"\n"
  in
  header ^ body ^ "\n"

let write_sensitivity_md ~output_path ~objective rows =
  let title =
    sprintf "# Sensitivity report (objective: `%s`)\n\nMean objective across \
             scenarios as each param varies, with other params held at their \
             best-cell value.\n\n"
      (objective_label objective)
  in
  let sections = List.map rows ~f:_format_sensitivity_section in
  Out_channel.with_file output_path ~f:(fun oc ->
      Out_channel.output_string oc title;
      List.iter sections ~f:(Out_channel.output_string oc))
