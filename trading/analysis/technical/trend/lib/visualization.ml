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

(* Main visualization function *)
let create_plot data segments =
  (* Set environment variable for non-interactive display *)
  Unix.putenv "QT_QPA_PLATFORM" "offscreen";

  let h = Plot.create ~n:1 ~m:1 "segmentation.png" in
  Plot.set_output h "segmentation.png";
  Plot.set_background_color h 255 255 255;
  (* white background *)
  Plot.set_pen_size h 2.;

  (* thicker lines *)

  (* Plot the entire data series first *)
  let n = Array.length data in
  let x = Array.init n float_of_int in
  let x_mat = Mat.of_array x 1 n in
  let y_mat = Mat.of_array data 1 n in
  Plot.(
    plot ~h
      ~spec:[ RGB (100, 100, 100); Marker "*"; MarkerSize 1.0 ]
      x_mat y_mat);

  (* Plot each segment *)
  List.iter
    (fun segment ->
      let segment_length =
        segment.Segmentation.end_idx - segment.start_idx + 1
      in
      let x_segment =
        Array.init segment_length (fun i ->
            float_of_int (i + segment.start_idx))
      in
      let trend_y =
        Array.init segment_length (fun i ->
            let slope = segment.Segmentation.slope in
            let intercept = segment.Segmentation.intercept in
            intercept +. (slope *. float_of_int i))
      in
      let color = get_trend_color segment.trend in

      (* Plot trend line *)
      let x_mat = Mat.of_array x_segment 1 segment_length in
      let y_mat = Mat.of_array trend_y 1 segment_length in
      Plot.(plot ~h ~spec:[ color; LineStyle 1; LineWidth 2.0 ] x_mat y_mat);

      (* Plot channel boundaries *)
      let upper_y = Array.map (fun y -> y +. segment.channel_width) trend_y in
      let lower_y = Array.map (fun y -> y -. segment.channel_width) trend_y in
      let y_upper = Mat.of_array upper_y 1 segment_length in
      let y_lower = Mat.of_array lower_y 1 segment_length in
      Plot.(plot ~h ~spec:[ color; LineStyle 2 ] x_mat y_upper);
      Plot.(plot ~h ~spec:[ color; LineStyle 2 ] x_mat y_lower);

      (* Plot R² value *)
      let mid_x = float_of_int (segment.start_idx + segment.end_idx) /. 2.0 in
      let mid_y = segment.intercept +. (segment.slope *. mid_x) in
      Plot.(
        text ~h ~spec:[ color ] mid_x mid_y
          (Printf.sprintf "R²=%.2f" segment.r_squared)))
    segments;

  (* Set plot properties *)
  Plot.set_title h "Trend Segmentation";
  Plot.set_xlabel h "Time";
  Plot.set_ylabel h "Value";
  Plot.output h
