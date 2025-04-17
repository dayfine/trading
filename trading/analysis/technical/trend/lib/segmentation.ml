module Reg = Regression
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
  r_squared_tolerance : float;
      (** Additional tolerance for R-squared threshold *)
  max_width_penalty : float;
      (** Maximum allowed width penalty before splitting *)
}
[@@deriving show, eq]

type segment = {
  start_idx : int;  (** Starting index of the segment *)
  end_idx : int;  (** Ending index of the segment *)
  trend : Trend_type.t;  (** Trend direction *)
  r_squared : float;  (** R-squared value indicating fit quality *)
  channel_width : float;  (** Standard deviation of residuals (channel width) *)
  slope : float;  (** Slope of the regression line *)
  intercept : float;  (** Y-intercept of the regression line *)
}
[@@deriving show, eq]

let default_params =
  {
    min_segment_length = 3;
    preferred_segment_length = 10;
    length_flexibility = 1.;
    min_r_squared = 0.9;
    min_slope = 0.01;
    max_segments = 10;
    preferred_channel_width = 0.5;
    max_channel_width = 2.0;
    width_penalty_factor = 0.5;
    r_squared_tolerance = 0.1;
    max_width_penalty = 0.3;
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
    match actual_width > max_width with
    | true -> 1.0
    | false ->
        let ratio =
          match actual_width < preferred_width with
          | true -> actual_width /. preferred_width
          | false -> preferred_width /. actual_width
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
      @return Trend direction *)
  let determine_trend ~min_slope slope =
    match (abs_float slope < min_slope, slope > 0.0) with
    | true, _ -> Trend_type.Flat
    | false, true -> Trend_type.Increasing
    | false, false -> Trend_type.Decreasing

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
      slope = stats.Regression.slope;
      intercept = stats.Regression.intercept;
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
      trend = Trend_type.Unknown;
      r_squared = 0.;
      channel_width = 0.;
      slope = 0.;
      intercept = 0.;
    }

  (** Determines whether a segment should be split based on its quality metrics.
      @param r_squared R-squared value of the segment
      @param width_penalty Penalty for channel width
      @param params Segmentation parameters
      @return true if the segment should be split *)
  let should_split ~r_squared ~width_penalty params =
    r_squared < params.min_r_squared +. params.r_squared_tolerance
    || width_penalty >= params.max_width_penalty

  (** Calculates a bonus score when a split point represents a significant trend
      change.
      @param min_slope Minimum slope for trend determination
      @param left_slope Slope of the left segment
      @param right_slope Slope of the right segment
      @return Bonus value (0.0 or 0.2) *)
  let calculate_trend_change_bonus ~min_slope left_slope right_slope =
    let open Trend_type in
    let get_trend slope =
      match (slope > min_slope, slope < -.min_slope) with
      | true, _ -> Increasing
      | _, true -> Decreasing
      | _, _ -> Flat
    in
    let left_trend = get_trend left_slope in
    let right_trend = get_trend right_slope in
    match (left_trend, right_trend) with
    | Increasing, Decreasing | Decreasing, Increasing -> 0.4
    | Flat, _ | _, Flat -> 0.2
    | _ -> 0.0
end

(* Helper function to create a segment from data *)
let create_segment_from_data ~start_idx ~end_idx ~data_array ~params =
  let segment_y = Array.sub data_array start_idx (end_idx - start_idx + 1) in
  let stats = Reg.calculate_stats segment_y in
  SegmentAnalysis.create_segment ~start_idx ~end_idx ~min_slope:params.min_slope
    stats

(* Helper function to evaluate a potential split point *)
let evaluate_split_point ~start_idx ~end_idx ~split_idx ~data_array ~params =
  let left_y = Array.sub data_array start_idx (split_idx - start_idx + 1) in
  let right_y = Array.sub data_array (split_idx + 1) (end_idx - split_idx) in

  let left_stats = Reg.calculate_stats left_y in
  let right_stats = Reg.calculate_stats right_y in

  let total_len = end_idx - start_idx + 1 in
  let left_len = split_idx - start_idx + 1 in
  let right_len = end_idx - split_idx in

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
    SegmentAnalysis.calculate_trend_change_bonus ~min_slope:params.min_slope
      left_stats.slope right_stats.slope
  in

  let score =
    weighted_r2
    +. (trend_change_bonus *. 0.5)
    -. (left_penalty *. 0.2) -. (right_penalty *. 0.2)
  in

  (score, left_stats, right_stats)

(* Helper function to find the best split point *)
let find_best_split ~start_idx ~end_idx ~data_array ~params =
  let best_split = ref None in
  let best_score = ref (-1.0) in

  (* Try each potential split point *)
  for
    split_idx = start_idx + params.min_segment_length - 1
    to end_idx - params.min_segment_length
  do
    let score, _, _ =
      evaluate_split_point ~start_idx ~end_idx ~split_idx ~data_array ~params
    in
    if score > !best_score then (
      best_score := score;
      best_split := Some split_idx)
  done;
  !best_split

(* Helper function to check if a segment needs to be split *)
let needs_split ~start_idx ~end_idx ~data_array ~params =
  let segment_y = Array.sub data_array start_idx (end_idx - start_idx + 1) in
  let stats = Reg.calculate_stats segment_y in

  let width_penalty =
    Penalties.calculate_width_penalty
      ~preferred_width:params.preferred_channel_width
      ~max_width:params.max_channel_width
      ~penalty_factor:params.width_penalty_factor stats.residual_std
  in

  let should_split =
    SegmentAnalysis.should_split ~r_squared:stats.r_squared ~width_penalty
      params
  in
  (should_split, stats)

(* Helper function to process a single segment *)
let rec process_segment ~segments ~remaining_splits ~start_idx ~end_idx
    ~data_array ~params =
  (* Check if segment is too small *)
  let segment_length = end_idx - start_idx + 1 in
  if segment_length < params.min_segment_length then
    create_segment_from_data ~start_idx ~end_idx ~data_array ~params :: segments
  else
    let should_split, stats =
      needs_split ~start_idx ~end_idx ~data_array ~params
    in
    let segment =
      SegmentAnalysis.create_segment ~start_idx ~end_idx
        ~min_slope:params.min_slope stats
    in
    match
      (should_split, find_best_split ~start_idx ~end_idx ~data_array ~params)
    with
    | false, _ -> segment :: segments
    | true, None -> segment :: segments
    | true, Some split_idx ->
        process_split_segments ~segments ~remaining_splits ~start_idx ~end_idx
          ~split_idx ~data_array ~params

(* Helper function to process split segments *)
and process_split_segments ~segments ~remaining_splits ~start_idx ~end_idx
    ~split_idx ~data_array ~params =
  (* Process right segment first *)
  let right_segments =
    process_segment ~segments ~remaining_splits:(remaining_splits - 1)
      ~start_idx:(split_idx + 1) ~end_idx ~data_array ~params
  in
  (* Then process left segment *)
  process_segment ~segments:right_segments
    ~remaining_splits:(remaining_splits - 1) ~start_idx ~end_idx:split_idx
    ~data_array ~params

(* Main segmentation algorithm *)
let segment_by_trends ?(params = default_params) data_array =
  let n = Array.length data_array in

  match n < params.min_segment_length with
  | true ->
      [ SegmentAnalysis.create_unknown_segment ~start_idx:0 ~end_idx:(n - 1) ]
  | false ->
      process_segment ~segments:[] ~remaining_splits:params.max_segments
        ~start_idx:0 ~end_idx:(n - 1) ~data_array ~params
