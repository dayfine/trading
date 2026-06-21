open Core

type leg_result = { name : string; equity_curve : (Date.t * float) list }

type t = {
  config : Barbell_config.t;
  floor : leg_result;
  engine : leg_result;
  blend : Barbell_blend.t;
}

let equity_curve_of_steps steps =
  List.map steps
    ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
      (s.date, s.portfolio_value))

let run ~(config : Barbell_config.t) ~floor_leg ~engine_leg =
  (match Barbell_config.validate config with
  | Ok () -> ()
  | Error msg -> invalid_arg ("Barbell_runner.run: " ^ msg));
  let floor = floor_leg () in
  let engine = engine_leg () in
  let blend =
    Barbell_blend.blend ~config ~floor_curve:floor.equity_curve
      ~engine_curve:engine.equity_curve
  in
  { config; floor; engine; blend }

let write_equity_curve t ~output_dir =
  let path = output_dir ^ "/equity_curve.csv" in
  Out_channel.with_file path ~f:(fun oc ->
      Out_channel.output_string oc "date,portfolio_value\n";
      List.iter t.blend.nav_curve ~f:(fun (d, v) ->
          Out_channel.output_string oc
            (Printf.sprintf "%s,%.6f\n" (Date.to_string d) v)))
