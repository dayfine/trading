open Core
module Plot = Owl_plplot.Plot
module Mat = Owl.Dense.Matrix.D

(* Render a symbol's weekly close coloured by its programmatic Weinstein stage,
   overlaid on the 30-week MA, so the classifier can be eyeballed against the
   chart. Usage:
     stage_chart <SYMBOL> <START> <END> <DATA_DIR> <OUT.png>
                 [ENTRY_DATE EXIT_DATE STOP_DISTANCE_PCT]
   When the optional trade-overlay args (6-8) are present, the chart also draws
   our actual trade: a green vertical line + dot at entry, a grey vertical line
   + dot at exit (both on the price line), and a magenta horizontal line at the
   initial stop level (entry price × (1 - STOP_DISTANCE_PCT)). STOP_DISTANCE_PCT
   is a scale-invariant ratio (e.g. 0.22), so it applies to the chart's
   adjusted-close scale regardless of the raw entry price.
   (The 30-week MA already plotted IS the trailing-stop proxy for a Stage-2
   hold — Weinstein's structural trailing stop tracks just below it, which is
   why a winner gives back to ~the MA before the stop fires.) *)

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
   the prior stage. Returns (stage option array, MA-value array, MA-direction
   array — the last two on the classifier's adjusted-close basis). *)
let classify_series ?(enable_stage2_ma_hold = false) arr =
  let n = Array.length arr in
  let cfg = { Stage.default_config with Stage.enable_stage2_ma_hold } in
  let stages = Array.create ~len:n None in
  let mas = Array.create ~len:n Float.nan in
  let ma_dirs = Array.create ~len:n Weinstein_types.Flat in
  let prior = ref None in
  for i = 0 to n - 1 do
    let bars = Array.to_list (Array.sub arr ~pos:0 ~len:(i + 1)) in
    let r = Stage.classify ~config:cfg ~bars ~prior_stage:!prior in
    stages.(i) <- Some r.stage;
    mas.(i) <- r.ma_value;
    ma_dirs.(i) <- r.ma_direction;
    prior := Some r.stage
  done;
  (stages, mas, ma_dirs)

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

(* Our actual trade, when the optional overlay args are supplied. The stop is
   given as a distance *ratio* (scale-invariant), so it applies correctly to the
   chart's adjusted-close scale even though the backtest's raw entry price is on
   a different scale. *)
type trade = {
  entry_date : Date.t;
  exit_date : Date.t;
  stop_distance_pct : float;  (** initial stop = entry × (1 - this), long side *)
}

(* Week index of the first bar on/after [d] (clamped to the last bar). Used to
   place the entry/exit overlays on the week-index x-axis. *)
let week_index_of_date arr d =
  let n = Array.length arr in
  match
    Array.findi arr ~f:(fun _ b -> Date.( >= ) b.Types.Daily_price.date d)
  with
  | Some (i, _) -> i
  | None -> n - 1

(* Build an adjusted-scale OHLC bar (scale O/H/L by adjusted_close/close) so the
   stop state machine operates on the same adjusted-close scale as the chart. *)
let adjusted_bar (b : Types.Daily_price.t) =
  let c = b.Types.Daily_price.close_price in
  let f =
    if Float.( > ) c 0.0 then b.Types.Daily_price.adjusted_close /. c else 1.0
  in
  {
    b with
    Types.Daily_price.open_price = b.Types.Daily_price.open_price *. f;
    high_price = b.Types.Daily_price.high_price *. f;
    low_price = b.Types.Daily_price.low_price *. f;
    close_price = b.Types.Daily_price.adjusted_close;
  }

(* Replay the real Weinstein trailing-stop state machine over the hold
   [ie..ix], seeded at the exact initial stop, on the adjusted-close scale.
   Returns (week-index, stop-level) points. Approximate vs the backtest (weekly
   bars, default stop config, support floor proxied by the initial level) but it
   is the true ratcheting trail, not the MA proxy. *)
let trailing_stop_path ~arr ~stages ~mas ~ma_dirs ~ie ~ix ~initial_stop =
  let state =
    ref
      (Weinstein_stops.Initial
         { stop_level = initial_stop; reference_level = initial_stop })
  in
  let xs = ref [ Float.of_int ie ] and ys = ref [ initial_stop ] in
  for i = ie + 1 to ix do
    let st, _ =
      Weinstein_stops.update ~config:Weinstein_stops.default_config
        ~side:Trading_base.Types.Long ~state:!state
        ~current_bar:(adjusted_bar arr.(i))
        ~ma_value:mas.(i) ~ma_direction:ma_dirs.(i)
        ~stage:(Option.value_exn stages.(i))
    in
    state := st;
    xs := Float.of_int i :: !xs;
    ys := Weinstein_stops.get_stop_level st :: !ys
  done;
  (Array.of_list (List.rev !xs), Array.of_list (List.rev !ys))

(* Draw our trade: entry/exit vertical lines + markers (on the price line), the
   initial-stop horizontal line (magenta), and the reconstructed trailing-stop
   path (red). *)
let plot_trade ~h ~arr ~closes ~stages ~mas ~ma_dirs t =
  let lo = Array.fold closes ~init:Float.infinity ~f:Float.min in
  let hi = Array.fold closes ~init:Float.neg_infinity ~f:Float.max in
  let ie = week_index_of_date arr t.entry_date in
  let ix = week_index_of_date arr t.exit_date in
  let we = Float.of_int ie and wx = Float.of_int ix in
  let entry_px = closes.(ie) and exit_px = closes.(ix) in
  let stop_px = entry_px *. (1.0 -. t.stop_distance_pct) in
  let vline x rgb = plot_line ~h ~rgb ~width:1.5 [| x; x |] [| lo; hi |] in
  vline we (0, 150, 0) (* entry: green *);
  vline wx (150, 150, 150) (* exit: grey *);
  (* initial stop level across the hold: magenta *)
  plot_line ~h ~rgb:(200, 0, 200) ~width:1.5 [| we; wx |] [| stop_px; stop_px |];
  (* reconstructed trailing stop: red *)
  let sx, sy =
    trailing_stop_path ~arr ~stages ~mas ~ma_dirs ~ie ~ix ~initial_stop:stop_px
  in
  if Array.length sx > 1 then plot_line ~h ~rgb:(220, 0, 0) ~width:2.0 sx sy;
  let mark x y rgb =
    let r, g, b = rgb in
    Plot.scatter ~h
      ~spec:[ Plot.RGB (r, g, b); Plot.MarkerSize 8.0 ]
      (Mat.of_array [| x |] 1 1) (Mat.of_array [| y |] 1 1)
  in
  mark we entry_px (0, 150, 0);
  mark wx exit_px (200, 0, 0)

let () =
  let argv = Sys.get_argv () in
  let symbol = argv.(1) in
  let start_date = Date.of_string argv.(2) in
  let end_date = Date.of_string argv.(3) in
  let data_dir = Fpath.v argv.(4) in
  let out = argv.(5) in
  let trade =
    if Array.length argv > 8 then
      Some
        {
          entry_date = Date.of_string argv.(6);
          exit_date = Date.of_string argv.(7);
          stop_distance_pct = Float.of_string argv.(8);
        }
    else None
  in
  let weekly =
    load_weekly ~data_dir ~symbol ~end_date
    |> List.filter ~f:(fun b -> Date.( >= ) b.Types.Daily_price.date start_date)
  in
  let arr = Array.of_list weekly in
  let n = Array.length arr in
  let stages, mas, ma_dirs = classify_series ~enable_stage2_ma_hold:false arr in
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
  Option.iter trade ~f:(fun t ->
      plot_trade ~h ~arr ~closes ~stages ~mas ~ma_dirs t);
  Plot.output h;
  printf "wrote %s (%d weeks)\n" out n
