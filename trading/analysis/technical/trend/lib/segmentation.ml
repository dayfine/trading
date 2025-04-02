open Owl

(* Helper function: Calculate linear regression statistics for a segment of data *)
let segment_stats x_arr y_arr start_idx end_idx =
  (* Extract the segment *)
  let segment_length = end_idx - start_idx + 1 in
  let x_segment = Arr.get_slice [[start_idx; end_idx]] x_arr in
  let y_segment = Arr.get_slice [[start_idx; end_idx]] y_arr in

  (* Perform linear regression *)
  let a, b = Stats.linreg x_segment y_segment in

  (* Calculate predictions and residuals *)
  let predicted = Arr.add (Arr.scalar_mul x_segment b) a in
  let residuals = Arr.sub y_segment predicted in
  let residual_std = Stats.std (Arr.flatten residuals) in

  (* Calculate R-squared *)
  let y_mean = Stats.mean (Arr.flatten y_segment) in
  let ss_total = Arr.(sum' (sqr (sub y_segment (scalar y_mean)))) in
  let ss_residual = Arr.(sum' (sqr residuals)) in
  let r_squared = if ss_total = 0. then 1. else 1. -. (ss_residual /. ss_total) in

  (* Return statistics *)
  (a, b, r_squared, residual_std)

(* Function to classify trend of a segment *)
let classify_trend slope r_squared min_slope =
  let abs_slope = abs_float slope in
  if abs_slope < min_slope then ("flat", r_squared)
  else if slope > 0. then ("increasing", r_squared)
  else ("decreasing", r_squared)

(* Main function to segment a data series by trends *)
let segment_by_trends
    ?(min_segment_length=3)
    ?(min_r_squared=0.6)
    ?(min_slope=0.01)
    ?(max_segments=10)
    data =

  if Array.length data < min_segment_length then
    [| (0, Array.length data - 1, "unknown", 0.) |]
  else
    (* Create x and y arrays *)
    let n = Array.length data in
    let x_arr = Arr.sequential n |> Arr.reshape ~-1 1 in
    let y_arr = Arr.of_array data 1 n |> Arr.reshape ~-1 1 in

    (* Recursive function to find best split points *)
    let rec find_splits segments remaining_splits start_idx end_idx =
      (* If we've reached the max segments or segment is too small, return *)
      if remaining_splits <= 0 || end_idx - start_idx + 1 < min_segment_length * 2 then
        let (_, slope, r_squared, _) = segment_stats x_arr y_arr start_idx end_idx in
        let (trend, quality) = classify_trend slope r_squared min_slope in
        (start_idx, end_idx, trend, quality) :: segments
      else
        (* Try splitting at each possible point and find best split *)
        let best_split_idx = ref (-1) in
        let best_score = ref min_r_squared in  (* Minimum threshold *)

        (* Calculate whole segment fit quality *)
        let (_, whole_slope, whole_r2, _) = segment_stats x_arr y_arr start_idx end_idx in

        (* If current segment already fits well, don't split further *)
        if whole_r2 >= min_r_squared +. 0.1 then
          let (trend, quality) = classify_trend whole_slope whole_r2 min_slope in
          (start_idx, end_idx, trend, quality) :: segments
        else
          begin
            (* Try each potential split point *)
            for split_idx = start_idx + min_segment_length - 1 to end_idx - min_segment_length do
              (* Calculate statistics for both potential segments *)
              let (_, left_slope, left_r2, _) =
                segment_stats x_arr y_arr start_idx split_idx in
              let (_, right_slope, right_r2, _) =
                segment_stats x_arr y_arr (split_idx + 1) end_idx in

              (* Score this split (average R² weighted by segment length) *)
              let left_len = float_of_int (split_idx - start_idx + 1) in
              let right_len = float_of_int (end_idx - split_idx) in
              let total_len = left_len +. right_len in
              let weighted_r2 =
                (left_r2 *. left_len +. right_r2 *. right_len) /. total_len in

              (* Check if trends differ (one increasing, one decreasing) - bonus points *)
              let left_trend = if left_slope > min_slope then 1
                              else if left_slope < -.min_slope then -1
                              else 0 in
              let right_trend = if right_slope > min_slope then 1
                               else if right_slope < -.min_slope then -1
                               else 0 in

              let trend_change_bonus =
                if left_trend != 0 && right_trend != 0 && left_trend != right_trend
                then 0.1 else 0.0 in

              let split_score = weighted_r2 +. trend_change_bonus in

              (* Update best split if this one is better *)
              if split_score > !best_score then begin
                best_score := split_score;
                best_split_idx := split_idx
              end
            done;

            (* If we found a good split, recurse on both segments *)
            if !best_split_idx <> -1 then begin
              let left_segments =
                find_splits segments (remaining_splits - 1) start_idx !best_split_idx in
              find_splits left_segments (remaining_splits - 1) (!best_split_idx + 1) end_idx
            end else
              (* No good split found, keep segment as is *)
              let (trend, quality) = classify_trend whole_slope whole_r2 min_slope in
              (start_idx, end_idx, trend, quality) :: segments
          end
    in

    (* Start recursive segmentation and convert result to array *)
    let segments = find_splits [] (max_segments - 1) 0 (n - 1) in
    Array.of_list (List.rev segments)

(* Function to interpret and display segmentation results *)
let interpret_segmentation data segments =
  Printf.printf "Identified %d segments:\n\n" (Array.length segments);

  Array.iteri (fun i (start_idx, end_idx, trend, quality) ->
    let segment_data = Array.sub data start_idx (end_idx - start_idx + 1) in
    let segment_x = Array.init (Array.length segment_data) (fun i -> start_idx + i) in

    Printf.printf "Segment %d (indices %d-%d):\n" (i+1) start_idx end_idx;
    Printf.printf "  - Trend: %s\n" trend;
    Printf.printf "  - Quality (R²): %.4f\n" quality;
    Printf.printf "  - Duration: %d data points\n" (end_idx - start_idx + 1);

    (* Calculate additional statistics for the segment *)
    if Array.length segment_data >= 2 then
      let first = segment_data.(0) in
      let last = segment_data.(Array.length segment_data - 1) in
      let change = last -. first in
      let percent_change =
        if first <> 0. then (change /. first) *. 100. else Float.infinity in

      Printf.printf "  - Change: %.4f (%.2f%%)\n" change percent_change;

      (* Linear regression on this segment for more precise slope *)
      let x_arr = Arr.of_array segment_x 1 (Array.length segment_x) |> Arr.reshape ~-1 1 in
      let y_arr = Arr.of_array segment_data 1 (Array.length segment_data) |> Arr.reshape ~-1 1 in
      let a, b = Stats.linreg x_arr y_arr in

      Printf.printf "  - Slope: %.4f\n" b;
      Printf.printf "  - Y-intercept: %.4f\n\n" a;
    else
      Printf.printf "  - Segment too short for detailed analysis\n\n"
  ) segments

(* Example usage *)
let () =
  (* Sample data with multiple trend changes *)
  let data = [|
    10.0; 10.5; 11.2; 12.0; 12.4; 12.9; 13.5;  (* Increasing *)
    13.2; 12.8; 12.0; 11.5; 10.8; 10.3; 9.7;   (* Decreasing *)
    9.5; 9.6; 9.4; 9.5; 9.3; 9.6; 9.4;         (* Flat *)
    9.8; 10.5; 11.3; 12.0; 13.1; 14.0; 15.2;   (* Increasing *)
    14.9; 14.8; 15.0; 14.7; 15.1; 14.9; 15.2   (* Flat *)
  |] in

  (* Segment the data *)
  let segments = segment_by_trends ~min_segment_length:5 ~min_r_squared:0.6 ~min_slope:0.05 data in

  (* Interpret results *)
  interpret_segmentation data segments
