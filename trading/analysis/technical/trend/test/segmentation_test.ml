open Core
open OUnit2
open Trend_lib.Segmentation

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

  let segments =
    segment_by_trends ~min_segment_length:3 ~preferred_segment_length:5
      ~min_r_squared:0.6 ~min_slope:0.1 data
  in

  assert_equal ~printer:(fun l -> List.map ~f:show_segment l |> String.concat ~sep:"; ")
    segments
    [
      { start_idx = 0; end_idx = 4; trend = "increasing"; r_squared = 1.0;
        channel_width = 0.0;
      };
      { start_idx = 5; end_idx = 9; trend = "flat"; r_squared = 1.0;
        channel_width = 0.0;
      };
      { start_idx = 10; end_idx = 14; trend = "decreasing"; r_squared = 1.0;
        channel_width = 0.0;
      };
    ]

let test_short_data _ =
  (* Test with data too short for segmentation *)
  let data = [| 1.0; 2.0; 3.0 |] in
  let segments =
    segment_by_trends ~min_segment_length:3 ~preferred_segment_length:5 data
  in

  assert_equal segments [
    { start_idx = 0; end_idx = 2; trend = "unknown"; r_squared = 0.0;
      channel_width = 0.0;
    };
  ]

let suite =
  "segmentation_test"
  >::: [
         "test_basic_segmentation" >:: test_basic_segmentation;
         "test_short_data" >:: test_short_data;
       ]

let () = run_test_tt_main suite
