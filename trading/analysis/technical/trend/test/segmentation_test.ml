open Core
open OUnit2
open Trend.Segmentation

let segment_equal a b =
  a.start_idx = b.start_idx && a.end_idx = b.end_idx
  && String.equal a.trend b.trend

let test_basic_segmentation _ =
  (* Test data with clear trends *)
  let data =
    [|
      1.0;
      2.0;
      3.0;
      4.0;
      5.0;
      (* increasing *)
      5.0;
      5.0;
      5.0;
      5.0;
      5.0;
      (* flat *)
      5.0;
      4.0;
      3.0;
      2.0;
      1.0 (* decreasing *);
    |]
  in

  let segments = segment_by_trends ~params:default_params data in
  let expected =
    [
      {
        start_idx = 0;
        end_idx = 6;
        trend = "increasing";
        r_squared = 0.909090953228;
        channel_width = 0.487949937588;
        slope = 1.0;
        intercept = 1.0;
      };
      {
        start_idx = 7;
        end_idx = 14;
        trend = "decreasing";
        r_squared = 0.850340107509;
        channel_width = 0.611677835971;
        slope = -1.0;
        intercept = 10.0;
      };
    ]
  in

  assert_equal
    ~printer:(fun l -> List.map ~f:show_segment l |> String.concat ~sep:"; ")
    ~cmp:(List.equal segment_equal) segments expected

let test_short_data _ =
  (* Test with data too short for segmentation *)
  let data = [| 1.0; 2.0; 3.0 |] in
  let segments = segment_by_trends ~params:default_params data in

  assert_equal segments
    [
      {
        start_idx = 0;
        end_idx = 2;
        trend = "unknown";
        r_squared = 0.0;
        channel_width = 0.0;
        slope = 0.0;
        intercept = 0.0;
      };
    ]

let test_complex_segmentation _ =
  (* Test data with multiple trend changes *)
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

  let segments = segment_by_trends ~params data in
  let expected =
    [
      {
        start_idx = 0;
        end_idx = 4;
        trend = "increasing";
        r_squared = 0.990269418573;
        channel_width = 0.098742295943;
        slope = 1.0;
        intercept = 10.0;
      };
      {
        start_idx = 5;
        end_idx = 19;
        trend = "decreasing";
        r_squared = 0.910274046695;
        channel_width = 0.467855281206;
        slope = -1.0;
        intercept = 15.0;
      };
      {
        start_idx = 20;
        end_idx = 24;
        trend = "increasing";
        r_squared = 0.0169173031313;
        channel_width = 0.361593649799;
        slope = 1.0;
        intercept = 10.0;
      };
      {
        start_idx = 25;
        end_idx = 35;
        trend = "increasing";
        r_squared = 0.978035397787;
        channel_width = 0.482568843996;
        slope = 1.0;
        intercept = 10.0;
      };
    ]
  in

  assert_equal
    ~printer:(fun l -> List.map ~f:show_segment l |> String.concat ~sep:"; ")
    ~cmp:(List.equal segment_equal) segments expected

let suite =
  "segmentation_suite"
  >::: [
         "test_basic_segmentation" >:: test_basic_segmentation;
         "test_short_data" >:: test_short_data;
         "test_complex_segmentation" >:: test_complex_segmentation;
       ]

let () = run_test_tt_main suite
