open Core

type axis = { floor_weights : float list; rebalance_weeks : int }
[@@deriving sexp, eq, show]

type cell = { label : string; config : Barbell_config.t }
[@@deriving sexp, eq, show]

type row = {
  label : string;
  floor_weight : float;
  metrics : Barbell_blend.metrics;
}
[@@deriving sexp, eq, show]

let _label_of_weight w = Printf.sprintf "floor_weight=%.2f" w

(* Validate the axis itself before expanding: non-empty, no duplicate weights,
   sane cadence. Per-cell config validity is checked in [_cell_of_weight]. *)
let _validate_axis (axis : axis) : unit =
  if List.is_empty axis.floor_weights then
    invalid_arg "Barbell_floor_sweep: floor_weights must be non-empty";
  if axis.rebalance_weeks < 1 then
    invalid_arg
      (Printf.sprintf
         "Barbell_floor_sweep: rebalance_weeks must be >= 1, got %d"
         axis.rebalance_weeks);
  let sorted = List.sort axis.floor_weights ~compare:Float.compare in
  match List.find_consecutive_duplicate sorted ~equal:Float.equal with
  | Some (w, _) ->
      invalid_arg
        (Printf.sprintf "Barbell_floor_sweep: duplicate floor_weight %.4f" w)
  | None -> ()

let _cell_of_weight ~rebalance_weeks floor_weight : cell =
  let config =
    { Barbell_config.enable = true; floor_weight; rebalance_weeks }
  in
  match Barbell_config.validate config with
  | Ok () -> { label = _label_of_weight floor_weight; config }
  | Error msg -> invalid_arg ("Barbell_floor_sweep: " ^ msg)

let cells (axis : axis) : cell list =
  _validate_axis axis;
  axis.floor_weights
  |> List.sort ~compare:Float.compare
  |> List.map ~f:(_cell_of_weight ~rebalance_weeks:axis.rebalance_weeks)

let metrics_table (axis : axis)
    ~(blend : Barbell_config.t -> Barbell_blend.metrics) : row list =
  cells axis
  |> List.map ~f:(fun (cell : cell) ->
      {
        label = cell.label;
        floor_weight = cell.config.floor_weight;
        metrics = blend cell.config;
      })
