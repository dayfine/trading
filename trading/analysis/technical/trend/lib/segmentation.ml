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

(* Penalty calculations module *)
module Penalties = struct
  let calculate_length_penalty ~preferred_length ~flexibility actual_length =
    let ratio =
      if actual_length < preferred_length then
        float_of_int actual_length /. float_of_int preferred_length
      else float_of_int preferred_length /. float_of_int actual_length
    in
    1.0 -. (ratio ** flexibility)

  let calculate_width_penalty ~preferred_width ~max_width ~penalty_factor actual_width =
    if actual_width > max_width then 1.0
    else
      let ratio =
        if actual_width < preferred_width then actual_width /. preferred_width
        else preferred_width /. actual_width
      in
      (1.0 -. ratio) *. penalty_factor

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

  let calculate_split_score ~left_stats ~right_stats ~left_len ~right_len ~total_len ~params =
    let left_penalty =
      Penalties.calculate_combined_penalty
        ~segment_len:left_len
        ~channel_width:left_stats.Regression.residual_std
        ~total_len params
    in
    let right_penalty =
      Penalties.calculate_combined_penalty
        ~segment_len:right_len
        ~channel_width:right_stats.Regression.residual_std
        ~total_len params
    in

    let weighted_r2 =
      ((left_stats.Regression.r_squared *. float_of_int left_len)
      +. (right_stats.Regression.r_squared *. float_of_int right_len))
      /. float_of_int total_len
    in

    let trend_change_bonus =
      calculate_trend_change_bonus
        ~min_slope:params.min_slope
        left_stats.Regression.slope
        right_stats.Regression.slope
    in

    weighted_r2 +. (trend_change_bonus *. 0.5)
    -. (left_penalty *. 0.2)
    -. (right_penalty *. 0.2)
end

(* Segment creation and analysis module *)
module SegmentAnalysis = struct
  let determine_trend ~min_slope slope =
    if abs_float slope < min_slope then "flat"
    else if slope > 0.0 then "increasing"
    else "decreasing"

  let create_segment ~start_idx ~end_idx ~min_slope stats =
    let trend = determine_trend ~min_slope stats.Regression.slope in
    {
      start_idx;
      end_idx;
      trend;
      r_squared = stats.Regression.r_squared;
      channel_width = stats.Regression.residual_std;
    }

  let create_unknown_segment ~start_idx ~end_idx =
    {
      start_idx;
      end_idx;
      trend = "unknown";
      r_squared = 0.;
      channel_width = 0.;
    }

  let should_split ~r_squared ~width_penalty params =
    r_squared < params.min_r_squared +. 0.1 || width_penalty >= 0.3
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
            whole_stats.Regression.residual_std
        in

        if not (SegmentAnalysis.should_split ~r_squared:whole_stats.Regression.r_squared ~width_penalty:whole_width_penalty params) then
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

            let score =
              Scoring.calculate_split_score
                ~left_stats
                ~right_stats
                ~left_len
                ~right_len
                ~total_len
                ~params
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
                find_segments segments (remaining_splits - 1) split_idx end_idx
              in
              find_segments right_segments (remaining_splits - 1) start_idx (split_idx - 1)
    in

    (* Start the segmentation process *)
    find_segments [] params.max_segments 0 (n - 1)

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
    let stats = Regression.calculate_stats segment_x segment_y in
    let predicted = Regression.predict_values segment_x stats.Regression.intercept stats.Regression.slope in
    let predicted_array = Arr.to_array predicted in
    let color = get_segment_color segment.trend in
    Plot.plot ~h ~spec:[ color ] (Mat.of_array segment_x 1 segment_len) (Mat.of_array predicted_array 1 segment_len)
end

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
