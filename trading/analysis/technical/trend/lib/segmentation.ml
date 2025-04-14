module Reg = Regression
open Owl
module Arr = Dense.Ndarray.S
module Mat = Dense.Matrix.D
module Plot = Owl_plplot.Plot

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
}
[@@deriving show, eq]

type segment = {
  start_idx : int;  (** Starting index of the segment *)
  end_idx : int;  (** Ending index of the segment *)
  trend : string;
      (** Trend direction: "increasing", "decreasing", "flat", or "unknown" *)
  r_squared : float;  (** R-squared value indicating fit quality *)
  channel_width : float;  (** Standard deviation of residuals (channel width) *)
}
[@@deriving show, eq]

let default_params =
  {
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

  (** Calculates a penalty based on how much the channel width deviates from the
      preferred width.
      @param preferred_width Target channel width
      @param max_width Maximum allowed channel width
      @param penalty_factor How strongly to penalize deviations
      @param actual_width Current channel width
      @return Penalty value between 0 and 1 *)
  let calculate_width_penalty ~preferred_width ~max_width ~penalty_factor
      actual_width =
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
      calculate_length_penalty ~preferred_length:params.preferred_segment_length
        ~flexibility:params.length_flexibility segment_len
    in
    let width_penalty =
      calculate_width_penalty ~preferred_width:params.preferred_channel_width
        ~max_width:params.max_channel_width
        ~penalty_factor:params.width_penalty_factor channel_width
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
  let create_segment ~start_idx ~end_idx ~min_slope
      (stats : Reg.regression_stats) =
    let trend = determine_trend ~min_slope stats.slope in
    {
      start_idx;
      end_idx;
      trend;
      r_squared = stats.r_squared;
      channel_width = stats.residual_std;
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
end

(* Scoring module for evaluating segment splits *)
module Scoring = struct
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

  let calculate_split_score ~(left_stats : Reg.regression_stats)
      ~(right_stats : Reg.regression_stats) ~left_len ~right_len ~total_len
      ~params =
    let left_penalty =
      Penalties.calculate_combined_penalty ~segment_len:left_len
        ~channel_width:left_stats.residual_std ~total_len params
    in
    let right_penalty =
      Penalties.calculate_combined_penalty ~segment_len:right_len
        ~channel_width:right_stats.residual_std ~total_len params
    in

    let weighted_r2 =
      ((left_stats.r_squared *. float_of_int left_len)
      +. (right_stats.r_squared *. float_of_int right_len))
      /. float_of_int total_len
    in

    let trend_change_bonus =
      calculate_trend_change_bonus ~min_slope:params.min_slope left_stats.slope
        right_stats.slope
    in

    weighted_r2
    +. (trend_change_bonus *. 0.5)
    -. (left_penalty *. 0.2) -. (right_penalty *. 0.2)
end

(* Visualization module *)
module Visualization = struct
  let get_segment_color trend =
    match trend with
    | "increasing" -> Plot.RGB (0, 255, 0)
    | "decreasing" -> Plot.RGB (255, 0, 0)
    | "flat" -> Plot.RGB (0, 0, 255)
    | _ -> Plot.RGB (128, 128, 128)

  let plot_segment ~h ~n ~data_array segment =
    let segment_len = segment.end_idx - segment.start_idx + 1 in
    let segment_x = Array.sub (Array.init n float_of_int) segment.start_idx segment_len in
    let segment_y = Array.sub data_array segment.start_idx segment_len in
    let stats = Reg.calculate_stats segment_x segment_y in
    let predicted = Reg.predict_values segment_x stats.intercept stats.slope in
    let predicted_array = Arr.to_array predicted in
    let color = get_segment_color segment.trend in
    Plot.plot ~h ~spec:[ color ] (Mat.of_array segment_x 1 segment_len) (Mat.of_array predicted_array 1 segment_len)
end

(* Main segmentation algorithm *)
let segment_by_trends ?(params = default_params) data_array =
  let n = Array.length data_array in
  if n < 2 then
    [ SegmentAnalysis.create_unknown_segment ~start_idx:0 ~end_idx:(n - 1) ]
  else
    let rec find_segments segments remaining_splits start_idx end_idx =
      if remaining_splits <= 0 || end_idx - start_idx < 2 then
        (* Base case: no more splits allowed or segment too short *)
        let x =
          Array.init
            (end_idx - start_idx + 1)
            (fun i -> float_of_int (i + start_idx))
        in
        let y = Array.sub data_array start_idx (end_idx - start_idx + 1) in
        let stats = Reg.calculate_stats x y in
        SegmentAnalysis.create_segment ~start_idx ~end_idx
          ~min_slope:params.min_slope stats
        :: segments
      else
        (* Try to find the best split point *)
        let best_score = ref (-1.0) in
        let best_split = ref None in

        (* Try each possible split point *)
        for split_idx = start_idx + 1 to end_idx - 1 do
          (* Calculate regression for left segment *)
          let left_x =
            Array.init
              (split_idx - start_idx + 1)
              (fun i -> float_of_int (i + start_idx))
          in
          let left_y =
            Array.sub data_array start_idx (split_idx - start_idx + 1)
          in
          let left_stats = Reg.calculate_stats left_x left_y in

          (* Calculate regression for right segment *)
          let right_x =
            Array.init (end_idx - split_idx) (fun i ->
                float_of_int (i + split_idx))
          in
          let right_y = Array.sub data_array split_idx (end_idx - split_idx) in
          let right_stats = Reg.calculate_stats right_x right_y in

          let left_len = split_idx - start_idx + 1 in
          let right_len = end_idx - split_idx in

          let score =
            Scoring.calculate_split_score ~left_stats ~right_stats ~left_len
              ~right_len ~total_len:n ~params
          in

          if score > !best_score then (
            best_score := score;
            best_split := Some split_idx)
        done;

        match !best_split with
        | None ->
            (* No good split found, create a single segment *)
            let x =
              Array.init
                (end_idx - start_idx + 1)
                (fun i -> float_of_int (i + start_idx))
            in
            let y = Array.sub data_array start_idx (end_idx - start_idx + 1) in
            let stats = Reg.calculate_stats x y in
            SegmentAnalysis.create_segment ~start_idx ~end_idx
              ~min_slope:params.min_slope stats
            :: segments
        | Some split_idx ->
            (* Recursively process both segments *)
            let right_segments =
              find_segments segments (remaining_splits - 1) split_idx end_idx
            in
            find_segments right_segments (remaining_splits - 1) start_idx
              (split_idx - 1)
    in

    (* Start the segmentation process *)
    find_segments [] params.max_segments 0 (n - 1)

let visualize_segmentation data_array segments =
  (* Create a new figure *)
  let h = Plot.create "segmentation.png" in

  (* Plot the original data *)
  let n = Array.length data_array in
  let x = Mat.of_array (Array.init n float_of_int) 1 n in
  let y = Mat.of_array data_array 1 n in
  Plot.plot ~h ~spec:[ Plot.RGB (0, 0, 0) ] x y;

  (* Plot each segment's trend line *)
  List.iter (Visualization.plot_segment ~h ~n ~data_array) segments;

  (* Save the plot *)
  Plot.output h
