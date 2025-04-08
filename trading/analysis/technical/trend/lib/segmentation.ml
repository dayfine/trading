open Owl_plplot
module Stats = Owl.Stats
module Arr = Owl.Dense.Ndarray.S
module Mat = Owl.Dense.Matrix.D
module Linalg = Owl.Linalg.S

(** Type representing a trend segment *)
type segment = {
  start_idx: int;         (** Starting index of the segment *)
  end_idx: int;          (** Ending index of the segment *)
  trend: string;         (** Trend direction: "increasing", "decreasing", "flat", or "unknown" *)
  r_squared: float;      (** R-squared value indicating fit quality *)
  channel_width: float;  (** Standard deviation of residuals (channel width) *)
}

(* Enhanced segmentation algorithm using Owl's built-in functions *)
let segment_by_trends
    ?(min_segment_length=3)
    ?(preferred_segment_length=10)
    ?(length_flexibility=0.5)
    ?(min_r_squared=0.6)
    ?(min_slope=0.01)
    ?(max_segments=10)
    ?(preferred_channel_width=0.5)
    ?(max_channel_width=2.0)
    ?(width_penalty_factor=0.5)
    data_array =

  (* Convert data to Owl array *)
  let data = Arr.of_array data_array [|Array.length data_array|] in
  let n = (Arr.shape data).(0) in

  (* Not enough data for segmentation *)
  if n < min_segment_length * 2 then
    [| { start_idx = 0; end_idx = n-1; trend = "unknown"; r_squared = 0.; channel_width = 0. } |]
  else
    (* Create x coordinates *)
    let x = Arr.of_array (Array.init n float_of_int) [|n|] in

    (* Function to calculate segment statistics *)
    let segment_stats start_idx end_idx =
      (* Extract segment data *)
      let x_segment = Arr.get_slice [[start_idx; end_idx]] x in
      let y_segment = Arr.get_slice [[start_idx; end_idx]] data in

      (* Reshape arrays for regression *)
      let x_segment = Arr.reshape x_segment [|end_idx - start_idx + 1; 1|] in
      let y_segment = Arr.reshape y_segment [|end_idx - start_idx + 1; 1|] in

      (* Perform linear regression *)
      let (a, b) = Linalg.linreg x_segment y_segment in

      (* Calculate predictions and residuals *)
      let predicted = Arr.map (fun x -> a +. b *. x) x_segment in
      let residuals = Arr.(y_segment - predicted) in

      (* Calculate R-squared *)
      let y_mean = Arr.mean' y_segment in
      let y_mean_arr = Arr.create [|1|] y_mean in
      let ss_total = Arr.(sum' (sqr (y_segment - y_mean_arr))) in
      let ss_residual = Arr.(sum' (sqr residuals)) in
      let r_squared = if ss_total = 0. then 1. else 1. -. (ss_residual /. ss_total) in

      (* Calculate residual standard deviation (channel width) *)
      let residual_std = Stats.std (Arr.to_array residuals) in

      (a, b, r_squared, residual_std)
    in

    (* Calculate segment length penalty *)
    let length_penalty segment_length =
      let ratio =
        if segment_length < preferred_segment_length
        then float_of_int segment_length /. float_of_int preferred_segment_length
        else float_of_int preferred_segment_length /. float_of_int segment_length
      in
      1.0 -. (ratio ** length_flexibility)
    in

    (* Calculate channel width penalty *)
    let width_penalty channel_width =
      if channel_width > max_channel_width then
        1.0
      else
        let ratio =
          if channel_width < preferred_channel_width
          then channel_width /. preferred_channel_width
          else preferred_channel_width /. channel_width
        in
        (1.0 -. ratio) *. width_penalty_factor
    in

    (* Helper to create a segment record *)
    let make_segment start_idx end_idx slope r_squared std_dev =
      let trend =
        if abs_float slope < min_slope then "flat"
        else if slope > 0.0 then "increasing"
        else "decreasing"
      in
      { start_idx; end_idx; trend; r_squared; channel_width = std_dev }
    in

    (* Recursive function to find segments *)
    let rec find_segments segments remaining_splits start_idx end_idx =
      (* Check termination conditions *)
      if remaining_splits <= 0 || end_idx - start_idx + 1 < min_segment_length * 2 then
        let (_, slope, r_squared, std_dev) = segment_stats start_idx end_idx in
        make_segment start_idx end_idx slope r_squared std_dev :: segments
      else
        (* Calculate whole segment statistics *)
        let (_, whole_slope, whole_r2, whole_std) = segment_stats start_idx end_idx in

        (* Find best split point *)
        let best_split_idx = ref (-1) in
        let best_score = ref (-1.0) in

        (* Try each potential split point *)
        for split_idx = start_idx + min_segment_length - 1 to end_idx - min_segment_length do
          (* Get stats for both segments *)
          let (_, left_slope, left_r2, left_std) = segment_stats start_idx split_idx in
          let (_, right_slope, right_r2, right_std) = segment_stats (split_idx + 1) end_idx in

          (* Calculate segment lengths *)
          let left_len = split_idx - start_idx + 1 in
          let right_len = end_idx - split_idx in
          let total_len = left_len + right_len in

          (* Calculate penalties *)
          let left_len_penalty = length_penalty left_len in
          let right_len_penalty = length_penalty right_len in
          let length_penalty_score =
            (left_len_penalty *. float_of_int left_len +.
             right_len_penalty *. float_of_int right_len) /. float_of_int total_len in

          let left_width_penalty = width_penalty left_std in
          let right_width_penalty = width_penalty right_std in
          let width_penalty_score =
            (left_width_penalty *. float_of_int left_len +.
             right_width_penalty *. float_of_int right_len) /. float_of_int total_len in

          (* Calculate weighted R² *)
          let weighted_r2 =
            (left_r2 *. float_of_int left_len +.
             right_r2 *. float_of_int right_len) /. float_of_int total_len in

          (* Check for trend change *)
          let left_trend = if left_slope > min_slope then 1
                         else if left_slope < -.min_slope then -1
                         else 0 in
          let right_trend = if right_slope > min_slope then 1
                          else if right_slope < -.min_slope then -1
                          else 0 in

          let trend_change_bonus =
            if left_trend != 0 && right_trend != 0 && left_trend != right_trend
            then 0.5  (* Increased bonus for trend changes *)
            else if left_trend != right_trend
            then 0.3  (* Smaller bonus for any trend difference *)
            else 0.0 in

          (* Combined score *)
          let split_score = weighted_r2 +. trend_change_bonus -.
                          (length_penalty_score *. 0.2) -.  (* Reduced length penalty *)
                          (width_penalty_score *. 0.3) in   (* Reduced width penalty *)

          (* Update best split if better *)
          if split_score > !best_score && left_r2 >= min_r_squared && right_r2 >= min_r_squared then begin
            best_score := split_score;
            best_split_idx := split_idx
          end
        done;

        (* Process the best split or keep as is *)
        if !best_split_idx <> -1 &&
           (!best_score > whole_r2 -. 0.2 ||
            end_idx - start_idx + 1 >= preferred_segment_length * 2) then begin
          let left_segments =
            find_segments segments (remaining_splits - 1) start_idx !best_split_idx in
          find_segments left_segments (remaining_splits - 1) (!best_split_idx + 1) end_idx
        end else
          (* No good split found, keep segment as is *)
          make_segment start_idx end_idx whole_slope whole_r2 whole_std :: segments
    in

    (* Start segmentation and convert to array *)
    let segments = find_segments [] (max_segments - 1) 0 (n - 1) in
    Array.of_list (List.rev segments)

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
  Plot.(plot ~h ~spec:[ RGB (100,100,100); Marker "*"; MarkerSize 1.0 ] x y);

  (* Plot each segment with trend line and channel *)
  Array.iter (fun segment ->
    (* Extract segment data *)
    let segment_length = segment.end_idx - segment.start_idx + 1 in
    let x_segment = Array.init segment_length (fun i -> float_of_int (i + segment.start_idx)) in
    let y_segment = Array.sub data segment.start_idx segment_length in

    (* Convert to Owl arrays *)
    let x_arr = Arr.of_array x_segment [|segment_length|] in
    let y_arr = Arr.of_array y_segment [|segment_length|] in

    (* Calculate trend line *)
    let (trend_a, trend_b) = Linalg.linreg x_arr y_arr in

    (* Create trend line *)
    let trend_y = Array.map (fun x -> trend_a +. trend_b *. x) x_segment in

    (* Plot segment trend line *)
    let (r, g, b) = match segment.trend with
      | "increasing" -> (0, 200, 0)    (* green *)
      | "decreasing" -> (200, 0, 0)    (* red *)
      | _ -> (100, 100, 100)          (* gray *)
    in

    (* Plot trend line *)
    let x_mat = Mat.of_array x_segment 1 segment_length in
    let y_mat = Mat.of_array trend_y 1 segment_length in
    Plot.(plot ~h ~spec:[ RGB (r,g,b); LineStyle 1 ] x_mat y_mat);

    (* Plot channel boundaries *)
    let upper_y = Array.map (fun y -> y +. segment.channel_width) trend_y in
    let lower_y = Array.map (fun y -> y -. segment.channel_width) trend_y in
    let y_upper = Mat.of_array upper_y 1 segment_length in
    let y_lower = Mat.of_array lower_y 1 segment_length in
    Plot.(plot ~h ~spec:[ RGB (r,g,b); LineStyle 2 ] x_mat y_upper);
    Plot.(plot ~h ~spec:[ RGB (r,g,b); LineStyle 2 ] x_mat y_lower);

    (* Add R² value as text *)
    let mid_x = float_of_int (segment.start_idx + segment.end_idx) /. 2.0 in
    let mid_y = trend_a +. trend_b *. mid_x in
    Plot.(text ~h ~spec:[ RGB (r,g,b) ] mid_x mid_y
      (Printf.sprintf "R²=%.2f" segment.r_squared))
  ) segments;

  (* Set plot properties *)
  Plot.set_title h "Trend Segmentation";
  Plot.set_xlabel h "Time";
  Plot.set_ylabel h "Value";
  Plot.output h
