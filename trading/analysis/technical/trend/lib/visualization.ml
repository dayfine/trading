open Owl_plplot
module Arr = Owl.Dense.Ndarray.S
module Mat = Owl.Dense.Matrix.D
module Linalg = Owl.Linalg.S

(* Helper function to get color based on trend *)
let get_trend_color = function
  | Trend_type.Increasing -> Plot.(RGB (0, 200, 0)) (* green *)
  | Trend_type.Decreasing -> Plot.(RGB (200, 0, 0)) (* red *)
  | Trend_type.Flat -> Plot.(RGB (0, 0, 200)) (* blue *)
  | Trend_type.Unknown -> Plot.(RGB (100, 100, 100))
(* gray *)

(* Initialize the plot with basic settings *)
let init_plot () =
  (* Set environment variable for non-interactive display *)
  Unix.putenv "QT_QPA_PLATFORM" "offscreen";

  let h = Plot.create ~n:1 ~m:1 "segmentation.png" in
  Plot.set_output h "segmentation.png";
  Plot.set_background_color h 255 255 255;
  (* white background *)
  Plot.set_pen_size h 2.;
  Plot.set_title h "Trend Segmentation";
  Plot.set_xlabel h "Time";
  Plot.set_ylabel h "Value";
  h

(* Calculate trend line values for a segment *)
let calculate_trend_line segment =
  let segment_length = segment.Segmentation.end_idx - segment.start_idx + 1 in
  let x_segment =
    Array.init segment_length (fun i -> float_of_int (i + segment.start_idx))
  in
  let trend_y =
    Array.init segment_length (fun i ->
        let slope = segment.Segmentation.slope in
        let intercept = segment.Segmentation.intercept in
        intercept +. (slope *. float_of_int i))
  in
  (x_segment, trend_y)

(* Calculate and plot channel boundaries for a segment *)
let plot_channel_boundaries ~h ~x_segment ~trend_y ~channel_width ~color =
  let upper_y = Array.map (fun y -> y +. channel_width) trend_y in
  let lower_y = Array.map (fun y -> y -. channel_width) trend_y in
  let y_upper = Mat.of_array upper_y 1 (Array.length upper_y) in
  let y_lower = Mat.of_array lower_y 1 (Array.length lower_y) in
  let x_mat = Mat.of_array x_segment 1 (Array.length x_segment) in
  Plot.(plot ~h ~spec:[ color; LineStyle 2 ] x_mat y_upper);
  Plot.(plot ~h ~spec:[ color; LineStyle 2 ] x_mat y_lower)

(* Plot the original data series as gray points *)
let plot_data_series ~h data =
  let n = Array.length data in
  let x = Array.init n float_of_int in
  let x_mat = Mat.of_array x 1 n in
  let y_mat = Mat.of_array data 1 n in
  Plot.(
    plot ~h
      ~spec:[ RGB (100, 100, 100); Marker "*"; MarkerSize 1.0 ]
      x_mat y_mat)

(* Plot trend line for a segment *)
let plot_trend_line ~h ~x_segment ~trend_y ~color =
  let x_mat = Mat.of_array x_segment 1 (Array.length x_segment) in
  let y_mat = Mat.of_array trend_y 1 (Array.length trend_y) in
  Plot.(plot ~h ~spec:[ color; LineStyle 1; LineWidth 2.0 ] x_mat y_mat)

(* Plot R² value for a segment *)
let plot_r_squared ~h ~segment ~color =
  let mid_x =
    float_of_int (segment.Segmentation.start_idx + segment.Segmentation.end_idx)
    /. 2.0
  in
  let mid_y =
    segment.Segmentation.intercept +. (segment.Segmentation.slope *. mid_x)
  in
  Plot.(
    text ~h ~spec:[ color ] mid_x mid_y
      (Printf.sprintf "R²=%.2f" segment.r_squared))

(* Main visualization function *)
let create_plot data segments =
  let h = init_plot () in

  (* Plot the entire data series first *)
  plot_data_series ~h data;

  (* Plot each segment *)
  List.iter
    (fun segment ->
      let x_segment, trend_y = calculate_trend_line segment in
      let color = get_trend_color segment.trend in

      plot_trend_line ~h ~x_segment ~trend_y ~color;

      plot_channel_boundaries ~h ~x_segment ~trend_y
        ~channel_width:segment.channel_width ~color;

      plot_r_squared ~h ~segment ~color)
    segments;

  Plot.output h
