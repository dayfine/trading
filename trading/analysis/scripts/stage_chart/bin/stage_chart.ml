open Core
module Plot = Owl_plplot.Plot
module Mat = Owl.Dense.Matrix.D

(* Render a symbol's weekly close coloured by its programmatic Weinstein stage,
   overlaid on the 30-week MA, so the classifier can be eyeballed against the
   chart. Usage: stage_chart <SYMBOL> <START> <END> <DATA_DIR> <OUT.png> *)

let stage_rgb = function
  | Weinstein_types.Stage1 _ -> (40, 90, 220) (* blue: basing *)
  | Weinstein_types.Stage2 _ -> (0, 170, 60) (* green: advancing *)
  | Weinstein_types.Stage3 _ -> (240, 150, 0) (* orange: topping *)
  | Weinstein_types.Stage4 _ -> (220, 30, 30)
(* red: declining *)

let stage_index = function
  | Weinstein_types.Stage1 _ -> 1
  | Stage2 _ -> 2
  | Stage3 _ -> 3
  | Stage4 _ -> 4

let stage_label = function
  | Weinstein_types.Stage1 _ -> "Stage1"
  | Stage2 _ -> "Stage2"
  | Stage3 _ -> "Stage3"
  | Stage4 _ -> "Stage4"

(* (weeks-in-stage, late-flag) for the lifecycle CSV sidecar. [late] is only
   meaningful for Stage2 (the MA-deceleration top-warning); false elsewhere. *)
let stage_detail = function
  | Weinstein_types.Stage1 { weeks_in_base } -> (weeks_in_base, false)
  | Stage2 { weeks_advancing; late } -> (weeks_advancing, late)
  | Stage3 { weeks_topping } -> (weeks_topping, false)
  | Stage4 { weeks_declining } -> (weeks_declining, false)

(* Write a per-week classification CSV alongside the PNG: lets the lifecycle
   sub-signals (weeks-in-stage, the Stage2 [late] MA-deceleration flag) be
   inspected, since the chart only colours the four discrete stages. *)
let emit_csv ~out ~arr ~stages ~mas =
  let path = out ^ ".csv" in
  let oc = Out_channel.create path in
  Out_channel.output_string oc "week,date,close,ma,stage,weeks_in_stage,late\n";
  Array.iteri arr ~f:(fun i b ->
      let stage = stages.(i) in
      let label = Option.value_map stage ~default:"-" ~f:stage_label in
      let weeks, late =
        Option.value_map stage ~default:(0, false) ~f:stage_detail
      in
      Out_channel.output_string oc
        (sprintf "%d,%s,%.2f,%.2f,%s,%d,%b\n" i
           (Date.to_string b.Types.Daily_price.date)
           b.Types.Daily_price.adjusted_close mas.(i) label weeks late));
  Out_channel.close oc;
  printf "wrote %s\n" path

let load_weekly ~data_dir ~symbol ~end_date =
  let result =
    let open Result.Let_syntax in
    let%bind storage = Csv.Csv_storage.create ~data_dir symbol in
    let%map daily = Csv.Csv_storage.get storage ~end_date () in
    Time_period.Conversion.daily_to_weekly ~include_partial_week:false daily
  in
  match result with Ok w -> w | Error e -> failwith (Status.show e)

(* Rolling stage classification: per week, classify the prefix [0..i] threading
   the prior stage. Returns (stage option array, MA-value array). *)
let classify_series arr =
  let n = Array.length arr in
  let cfg = Stage.default_config in
  let stages = Array.create ~len:n None in
  let mas = Array.create ~len:n Float.nan in
  let prior = ref None in
  for i = 0 to n - 1 do
    let bars = Array.to_list (Array.sub arr ~pos:0 ~len:(i + 1)) in
    let r = Stage.classify ~config:cfg ~bars ~prior_stage:!prior in
    stages.(i) <- Some r.stage;
    mas.(i) <- r.ma_value;
    prior := Some r.stage
  done;
  (stages, mas)

(* (x, y, stage) for the weeks whose stage maps to index [s]. *)
let points_for_stage ~x ~closes ~stages s =
  Array.to_list stages
  |> List.filter_mapi ~f:(fun i st ->
      match st with
      | Some stage when stage_index stage = s -> Some (x.(i), closes.(i), stage)
      | _ -> None)

let plot_line ~h ~rgb ~width xs ys =
  let r, g, b = rgb in
  let m = Array.length xs in
  Plot.plot ~h
    ~spec:[ Plot.RGB (r, g, b); Plot.LineWidth width ]
    (Mat.of_array xs 1 m) (Mat.of_array ys 1 m)

(* Scatter the close points of one stage in its colour. *)
let plot_stage_scatter ~h ~x ~closes ~stages s =
  match points_for_stage ~x ~closes ~stages s with
  | [] -> ()
  | (_, _, stage0) :: _ as pts ->
      let r, g, b = stage_rgb stage0 in
      let xs = Array.of_list (List.map pts ~f:(fun (a, _, _) -> a)) in
      let ys = Array.of_list (List.map pts ~f:(fun (_, c, _) -> c)) in
      let m = Array.length xs in
      Plot.scatter ~h
        ~spec:[ Plot.RGB (r, g, b); Plot.MarkerSize 3.0 ]
        (Mat.of_array xs 1 m) (Mat.of_array ys 1 m)

let () =
  let argv = Sys.get_argv () in
  let symbol = argv.(1) in
  let start_date = Date.of_string argv.(2) in
  let end_date = Date.of_string argv.(3) in
  let data_dir = Fpath.v argv.(4) in
  let out = argv.(5) in
  let weekly =
    load_weekly ~data_dir ~symbol ~end_date
    |> List.filter ~f:(fun b -> Date.( >= ) b.Types.Daily_price.date start_date)
  in
  let arr = Array.of_list weekly in
  let n = Array.length arr in
  let stages, mas = classify_series arr in
  emit_csv ~out ~arr ~stages ~mas;
  Core_unix.putenv ~key:"QT_QPA_PLATFORM" ~data:"offscreen";
  let h = Plot.create out in
  Plot.set_output h out;
  Plot.set_background_color h 255 255 255;
  Plot.set_title h
    (sprintf
       "%s weekly close by Weinstein stage (blue=S1 green=S2 orange=S3 red=S4) \
        + 30w MA"
       symbol);
  Plot.set_xlabel h "week index";
  Plot.set_ylabel h "price";
  let x = Array.init n ~f:Float.of_int in
  let closes = Array.map arr ~f:(fun b -> b.Types.Daily_price.adjusted_close) in
  plot_line ~h ~rgb:(170, 170, 170) ~width:1.0 x closes;
  let w = 30 in
  if n > w then
    plot_line ~h ~rgb:(0, 0, 0) ~width:2.0
      (Array.sub x ~pos:w ~len:(n - w))
      (Array.sub mas ~pos:w ~len:(n - w));
  List.iter [ 1; 2; 3; 4 ] ~f:(plot_stage_scatter ~h ~x ~closes ~stages);
  Plot.output h;
  printf "wrote %s (%d weeks)\n" out n
