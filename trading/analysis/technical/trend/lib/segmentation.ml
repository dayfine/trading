open Owl_plplot
module Stats = Owl.Stats
module Arr = Owl.Dense.Ndarray.S
module Mat = Owl.Dense.Matrix.D
module Linalg = Owl.Linalg.S

(* Types *)
type segmentation_params = {
  min_segment_length : int;
  preferred_segment_length : int;
  length_flexibility : float;
  min_r_squared : float;
  min_slope : float;
  max_segments : int;
  preferred_channel_width : float;
  max_channel_width : float;
  width_penalty_factor : float;
} [@@deriving show, eq]

type segment = {
  start_idx : int;  (** Starting index of the segment *)
  end_idx : int;  (** Ending index of the segment *)
  trend : string;  (** Trend direction: "increasing", "decreasing", "flat", or "unknown" *)
  r_squared : float;  (** R-squared value indicating fit quality *)
  channel_width : float;  (** Standard deviation of residuals (channel width) *)
} [@@deriving show, eq]

let default_params = {
  min_segment_length = 3;
  preferred_segment_length = 10;
  length_flexibility = 0.5;
  min_r_squared = 0.6;
  min_slope = 0.01;
  max_segments = 10;
  preferred_channel_width = 0.5;
  max_channel_width = 2.0;
  width_penalty_factor = 0.5;
}

(* Internal module for regression calculations and statistical analysis.
   This module handles all the linear regression computations and statistical
   metrics used in the segmentation algorithm. *)
module Regression = struct
  (** Statistics calculated from a linear regression analysis *)
  type regression_stats = {
    intercept : float;  (** Y-intercept of the regression line *)
    slope : float;      (** Slope of the regression line *)
    r_squared : float;  (** Coefficient of determination *)
    residual_std : float;  (** Standard deviation of residuals *)
  }

  (** Performs linear regression on the given data points and calculates
      various statistical metrics.
      @param x_data Array of x-coordinates
      @param y_data Array of y-coordinates
      @return regression_stats containing the calculated metrics *)
  let calculate_stats x_data y_data =
    (* Reshape arrays for regression *)
    let n = Array.length x_data in
    let x = Arr.of_array x_data [| n; 1 |] in
    let y = Arr.of_array y_data [| n; 1 |] in

    (* Perform linear regression *)
    let a, b = Linalg.linreg x y in

    (* Calculate predictions and residuals *)
    let predicted = Arr.map (fun x -> a +. (b *. x)) x in
    let residuals = Arr.(y - predicted) in

    (* Calculate R-squared *)
    let y_mean = Arr.mean' y in
    let y_mean_arr = Arr.create [| 1 |] y_mean in
    let ss_total = Arr.(sum' (sqr (y - y_mean_arr))) in
    let ss_residual = Arr.(sum' (sqr residuals)) in
    let r_squared =
      if ss_total = 0. then 1. else 1. -. (ss_residual /. ss_total)
    in

    (* Calculate residual standard deviation *)
    let residual_std = Stats.std (Arr.to_array residuals) in

    { intercept = a; slope = b; r_squared; residual_std }

  (** Predicts the y-value for a given x using the regression line.
      @param intercept Y-intercept of the regression line
      @param slope Slope of the regression line
      @param x Input x-value
      @return Predicted y-value *)
  let predict ~intercept ~slope x = intercept +. (slope *. x)
end

(* Internal module for calculating various penalties used in the segmentation
   scoring system. These penalties help balance different aspects of segment
   quality like length and channel width. *)
module Penalties = struct
  (** Calculates a penalty based on how much the segment length deviates from
      the preferred length.
      @param preferred_length Target segment length
      @param flexibility How much deviation is allowed (0-1)
      @param actual_length Current segment length
      @return Penalty value between 0 and 1 *)
  let calculate_length_penalty ~preferred_length ~flexibility actual_length =
    let ratio =
      if actual_length < preferred_length then
        float_of_int actual_length /. float_of_int preferred_length
      else float_of_int preferred_length /. float_of_int actual_length
    in
    1.0 -. (ratio ** flexibility)

  (** Calculates a penalty based on how much the channel width deviates from
      the preferred width.
      @param preferred_width Target channel width
      @param max_width Maximum allowed channel width
      @param penalty_factor How strongly to penalize deviations
      @param actual_width Current channel width
      @return Penalty value between 0 and 1 *)
  let calculate_width_penalty ~preferred_width ~max_width ~penalty_factor actual_width =
    if actual_width > max_width then 1.0
    else
      let ratio =
        if actual_width < preferred_width then actual_width /. preferred_width
        else preferred_width /. actual_width
      in
      (1.0 -. ratio) *. penalty_factor

  (** Combines length and width penalties into a single score, weighted by
      segment length relative to total data length.
      @param segment_len Length of the current segment
      @param channel_width Width of the price channel
      @param total_len Total length of the data
      @param params Segmentation parameters
      @return Combined penalty score *)
  let calculate_combined_penalty ~segment_len ~channel_width ~total_len params =
    let len_penalty =
      calculate_length_penalty
        ~preferred_length:params.preferred_segment_length
        ~flexibility:params.length_flexibility segment_len
    in
    let width_penalty =
      calculate_width_penalty
        ~preferred_width:params.preferred_channel_width
        ~max_width:params.max_channel_width
        ~penalty_factor:params.width_penalty_factor
        channel_width
    in
    ((len_penalty *. float_of_int segment_len)
    +. (width_penalty *. float_of_int segment_len))
    /. float_of_int total_len
end

(* Internal module for segment analysis and creation.
   This module handles the logic for determining segment characteristics
   and creating segment objects. *)
module SegmentAnalysis = struct
  (** Determines the trend direction based on the slope value.
      @param min_slope Minimum slope magnitude to consider a trend
      @param slope Calculated slope of the segment
      @return Trend direction as a string *)
  let determine_trend ~min_slope slope =
    if abs_float slope < min_slope then "flat"
    else if slope > 0.0 then "increasing"
    else "decreasing"

  (** Creates a segment object with calculated statistics.
      @param start_idx Starting index of the segment
      @param end_idx Ending index of the segment
      @param min_slope Minimum slope for trend determination
      @param stats Regression statistics for the segment
      @return A new segment object *)
  let create_segment ~start_idx ~end_idx ~min_slope stats =
    let trend = determine_trend ~min_slope stats.Regression.slope in
    {
      start_idx;
      end_idx;
      trend;
      r_squared = stats.Regression.r_squared;
      channel_width = stats.Regression.residual_std;
    }

  (** Creates a segment marked as unknown, used when there's insufficient data
      or when the segment quality is too poor.
      @param start_idx Starting index of the segment
      @param end_idx Ending index of the segment
      @return A new unknown segment *)
  let create_unknown_segment ~start_idx ~end_idx =
    {
      start_idx;
      end_idx;
      trend = "unknown";
      r_squared = 0.;
      channel_width = 0.;
    }

  (** Determines whether a segment should be split based on its quality metrics.
      @param r_squared R-squared value of the segment
      @param width_penalty Penalty for channel width
      @param params Segmentation parameters
      @return true if the segment should be split *)
  let should_split ~r_squared ~width_penalty params =
    r_squared < params.min_r_squared +. 0.1 || width_penalty >= 0.3

  (** Calculates a bonus score when a split point represents a significant
      trend change.
      @param min_slope Minimum slope for trend determination
      @param left_slope Slope of the left segment
      @param right_slope Slope of the right segment
      @return Bonus value (0.0 or 0.2) *)
  let calculate_trend_change_bonus ~min_slope left_slope right_slope =
    let left_trend =
      if left_slope > min_slope then 1
      else if left_slope < -.min_slope then -1
      else 0
    in
    let right_trend =
      if right_slope > min_slope then 1
      else if right_slope < -.min_slope then -1
      else 0
    in
    if left_trend != 0 && right_trend != 0 && left_trend != right_trend then 0.2
    else 0.0
end

(* Main segmentation algorithm *)
let segment_by_trends ?(params = default_params) data_array =
  let n = Array.length data_array in
  let x_data = Array.init n float_of_int in

  (* Not enough data for segmentation *)
  if n < params.min_segment_length * 2 then
    [ SegmentAnalysis.create_unknown_segment ~start_idx:0 ~end_idx:(n - 1) ]
  else
    let rec find_segments segments remaining_splits start_idx end_idx =
      (* Check termination conditions *)
      if remaining_splits <= 0 || end_idx - start_idx + 1 < params.min_segment_length * 2 then
        let segment_x = Array.sub x_data start_idx (end_idx - start_idx + 1) in
        let segment_y = Array.sub data_array start_idx (end_idx - start_idx + 1) in
        let stats = Regression.calculate_stats segment_x segment_y in
        SegmentAnalysis.create_segment ~start_idx ~end_idx ~min_slope:params.min_slope stats
        :: segments
      else
        (* Calculate whole segment statistics *)
        let segment_x = Array.sub x_data start_idx (end_idx - start_idx + 1) in
        let segment_y = Array.sub data_array start_idx (end_idx - start_idx + 1) in
        let whole_stats = Regression.calculate_stats segment_x segment_y in

        (* Check if current segment is good enough *)
        let whole_width_penalty =
          Penalties.calculate_width_penalty
            ~preferred_width:params.preferred_channel_width
            ~max_width:params.max_channel_width
            ~penalty_factor:params.width_penalty_factor
            whole_stats.residual_std
        in

        if not (SegmentAnalysis.should_split ~r_squared:whole_stats.r_squared ~width_penalty:whole_width_penalty params) then
          SegmentAnalysis.create_segment ~start_idx ~end_idx ~min_slope:params.min_slope whole_stats
          :: segments
        else
          (* Find best split point *)
          let best_split = ref None in
          let best_score = ref (-1.0) in

          (* Try each potential split point *)
          for split_idx = start_idx + params.min_segment_length - 1 to end_idx - params.min_segment_length do
            (* Calculate stats for both segments *)
            let left_x = Array.sub x_data start_idx (split_idx - start_idx + 1) in
            let left_y = Array.sub data_array start_idx (split_idx - start_idx + 1) in
            let right_x = Array.sub x_data (split_idx + 1) (end_idx - split_idx) in
            let right_y = Array.sub data_array (split_idx + 1) (end_idx - split_idx) in

            let left_stats = Regression.calculate_stats left_x left_y in
            let right_stats = Regression.calculate_stats right_x right_y in

            (* Calculate combined score *)
            let total_len = end_idx - start_idx + 1 in
            let left_len = split_idx - start_idx + 1 in
            let right_len = end_idx - split_idx in

            let left_penalty =
              Penalties.calculate_combined_penalty
                ~segment_len:left_len
                ~channel_width:left_stats.residual_std
                ~total_len params
            in
            let right_penalty =
              Penalties.calculate_combined_penalty
                ~segment_len:right_len
                ~channel_width:right_stats.residual_std
                ~total_len params
            in

            let weighted_r2 =
              ((left_stats.r_squared *. float_of_int left_len)
              +. (right_stats.r_squared *. float_of_int right_len))
              /. float_of_int total_len
            in

            let trend_change_bonus =
              SegmentAnalysis.calculate_trend_change_bonus
                ~min_slope:params.min_slope
                left_stats.slope
                right_stats.slope
            in

            let score =
              weighted_r2 +. (trend_change_bonus *. 0.5)
              -. (left_penalty *. 0.2)
              -. (right_penalty *. 0.2)
            in

            if score > !best_score then (
              best_score := score;
              best_split := Some split_idx
            )
          done;

          match !best_split with
          | None ->
              SegmentAnalysis.create_segment ~start_idx ~end_idx ~min_slope:params.min_slope whole_stats
              :: segments
          | Some split_idx ->
              (* Recursively process both segments *)
              let right_segments =
                find_segments segments (remaining_splits - 1) (split_idx + 1) end_idx
              in
              find_segments right_segments (remaining_splits - 1) start_idx split_idx
    in

    find_segments [] params.max_segments 0 (n - 1)

(* Function to visualize segmentation results with Owl *)
let visualize_segmentation data segments =
  (* Set environment variable for non-interactive display *)
  Unix.putenv "QT_QPA_PLATFORM" "offscreen";

  let h = Plot.create ~n:1 ~m:1 "segmentation.png" in
  Plot.set_output h "segmentation.png";
  Plot.set_background_color h 255 255 255;  (* white background *)
  Plot.set_pen_size h 2.;  (* thicker lines *)

  (* Plot original data *)
  let n = Array.length data in
  (* Use Mat (float64) instead of Arr (float32) because owl-plplot requires float64 matrices for plotting *)
  let x = Mat.of_array (Array.init n float_of_int) 1 n in
  let y = Mat.of_array data 1 n in
  Plot.(plot ~h ~spec:[ RGB (100, 100, 100); Marker "*"; MarkerSize 1.0 ] x y);

  (* Plot each segment with trend line and channel *)
  List.iter
    (fun segment ->
      (* Extract segment data *)
      let segment_length = segment.end_idx - segment.start_idx + 1 in
      let x_segment =
        Array.init segment_length (fun i ->
            float_of_int (i + segment.start_idx))
      in
      let y_segment = Array.sub data segment.start_idx segment_length in

      (* Calculate trend line *)
      let stats = Regression.calculate_stats x_segment y_segment in

      (* Create trend line *)
      let trend_y = Array.map (fun x -> Regression.predict ~intercept:stats.intercept ~slope:stats.slope x) x_segment in

      (* Plot segment trend line *)
      let r, g, b =
        match segment.trend with
        | "increasing" -> (0, 200, 0) (* green *)
        | "decreasing" -> (200, 0, 0) (* red *)
        | _ -> (100, 100, 100) (* gray *)
      in

      (* Plot trend line *)
      let x_mat = Mat.of_array x_segment 1 segment_length in
      let y_mat = Mat.of_array trend_y 1 segment_length in
      Plot.(plot ~h ~spec:[ RGB (r, g, b); LineStyle 1 ] x_mat y_mat);

      (* Plot channel boundaries *)
      let upper_y = Array.map (fun y -> y +. segment.channel_width) trend_y in
      let lower_y = Array.map (fun y -> y -. segment.channel_width) trend_y in
      let y_upper = Mat.of_array upper_y 1 segment_length in
      let y_lower = Mat.of_array lower_y 1 segment_length in
      Plot.(plot ~h ~spec:[ RGB (r, g, b); LineStyle 2 ] x_mat y_upper);
      Plot.(plot ~h ~spec:[ RGB (r, g, b); LineStyle 2 ] x_mat y_lower);

      (* Add R² value as text *)
      let mid_x = float_of_int (segment.start_idx + segment.end_idx) /. 2.0 in
      let mid_y = Regression.predict ~intercept:stats.intercept ~slope:stats.slope mid_x in
      Plot.(
        text ~h
          ~spec:[ RGB (r, g, b) ]
          mid_x mid_y
          (Printf.sprintf "R²=%.2f" segment.r_squared)))
    segments;

  (* Set plot properties *)
  Plot.set_title h "Trend Segmentation";
  Plot.set_xlabel h "Time";
  Plot.set_ylabel h "Value";
  Plot.output h
