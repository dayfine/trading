open Trend_lib.Segmentation

let () =
  (* Sample data with multiple trend changes *)
  let data =
    [|
      (* Increasing with low noise *)
      10.0;
      10.5;
      11.2;
      12.0;
      12.4;
      12.9;
      13.5;
      (* Decreasing with moderate noise *)
      13.2;
      12.8;
      13.0;
      12.5;
      12.0;
      11.5;
      10.8;
      10.3;
      9.7;
      (* Flat with high noise *)
      9.5;
      9.9;
      9.1;
      9.8;
      9.0;
      9.7;
      9.2;
      9.8;
      9.1;
      9.6;
      (* Steep increasing trend *)
      9.8;
      10.5;
      11.3;
      12.0;
      13.1;
      14.0;
      15.2;
      16.5;
      17.8;
      19.0;
    |]
  in

  (* Segment the data *)
  let segments =
    segment_by_trends ~min_segment_length:4 ~preferred_segment_length:8
      ~preferred_channel_width:0.3 ~max_channel_width:1.0 data
  in

  (* Print segment information *)
  Printf.printf "Identified %d segments:\n\n" (List.length segments);

  List.iteri
    (fun i segment ->
      Printf.printf "Segment %d (indices %d-%d):\n" (i + 1) segment.start_idx
        segment.end_idx;
      Printf.printf "  - Trend: %s\n" segment.trend;
      Printf.printf "  - Quality (R²): %.4f\n" segment.r_squared;
      Printf.printf "  - Channel width (std dev): %.4f\n" segment.channel_width;
      Printf.printf "  - Length: %d data points\n\n"
        (segment.end_idx - segment.start_idx + 1))
    segments;

  (* Generate visualization *)
  visualize_segmentation data segments;

  Printf.printf "Visualization saved to segmentation.png\n"
