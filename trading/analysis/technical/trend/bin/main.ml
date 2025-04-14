open Trend.Segmentation
open Trend.Visualization

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

  let params =
    {
      default_params with
      min_segment_length = 4;
      preferred_segment_length = 8;
      length_flexibility = 0.3;
      min_r_squared = 0.8;
      min_slope = 0.0;
    }
  in

  (* Segment the data *)
  let segments = segment_by_trends ~params data in

  (* Generate visualization *)
  create_plot data segments;

  Printf.printf "Visualization saved to segmentation.png\n"
