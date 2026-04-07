open OUnit2
open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops

let cfg = default_config

let make_bar ?(high_price = 105.0) ?(low_price = 95.0) c =
  {
    Types.Daily_price.date = Date.of_string "2024-01-01";
    open_price = c;
    high_price;
    low_price;
    close_price = c;
    adjusted_close = c;
    volume = 1000000;
  }

let run_and_print label side initial steps =
  Printf.printf "\n=== %s ===\n%!" label;
  Printf.printf "init: %s\n%!" (show_stop_state initial);
  ignore
    (List.fold steps ~init:(initial, No_change)
       ~f:(fun (st, _) (c, l, h, ma, dir, stg) ->
         let bar = make_bar ~low_price:l ~high_price:h c in
         let ns, ev =
           update ~config:cfg ~side ~state:st ~current_bar:bar ~ma_value:ma
             ~ma_direction:dir ~stage:stg
         in
         Printf.printf "c=%.2f l=%.2f h=%.2f: %s\n  → %s\n%!" c l h
           (show_stop_event ev) (show_stop_state ns);
         (ns, ev)))

let stage2 = Stage2 { weeks_advancing = 4; late = false }
let stage3 = Stage3 { weeks_topping = 3 }
let stage4 = Stage4 { weeks_declining = 3 }

let test_s1 _ =
  let initial =
    Trailing
      {
        stop_level = 95.0;
        last_correction_extreme = 100.0;
        last_trend_extreme = 100.0;
        ma_at_last_adjustment = 98.0;
        correction_count = 0;
      }
  in
  run_and_print "S1 phase A (through first recovery)" Long initial
    [
      (108.0, 105.0, 110.0, 100.0, Rising, stage2);
      (115.0, 112.0, 118.0, 103.0, Rising, stage2);
      (120.0, 117.0, 122.0, 106.0, Rising, stage2);
      (110.0, 105.0, 112.0, 107.0, Rising, stage2);
      (107.0, 104.0, 111.0, 108.0, Rising, stage2);
      (* cycle 1 completes here *)
      (122.0, 119.0, 124.0, 109.0, Rising, stage2);
    ];
  let phase_b_init =
    Trailing
      {
        stop_level = 98.875;
        last_correction_extreme = 119.0;
        last_trend_extreme = 122.0;
        ma_at_last_adjustment = 109.0;
        correction_count = 1;
      }
  in
  run_and_print "S1 phase B (through second recovery)" Long phase_b_init
    [
      (131.0, 128.0, 133.0, 112.0, Rising, stage2);
      (* cycle 2 completes here *)
      (140.0, 137.0, 142.0, 116.0, Rising, stage2);
      (130.0, 126.0, 132.0, 117.0, Rising, stage2);
      (125.0, 122.0, 127.0, 118.0, Rising, stage2);
      (* cycle 3 completes here *)
      (143.0, 140.0, 145.0, 120.0, Rising, stage2);
    ]

let test_s2 _ =
  let initial =
    Trailing
      {
        stop_level = 110.0;
        last_correction_extreme = 115.0;
        last_trend_extreme = 130.0;
        ma_at_last_adjustment = 118.0;
        correction_count = 2;
      }
  in
  run_and_print "S2 tightening" Long initial
    [
      (133.0, 130.0, 135.0, 122.0, Rising, stage2);
      (131.0, 128.0, 134.0, 123.0, Rising, stage2);
      (129.0, 126.0, 131.0, 123.0, Flat, stage3);
    ]

let test_s4 _ =
  let initial =
    Trailing
      {
        stop_level = 115.0;
        last_correction_extreme = 108.0;
        last_trend_extreme = 108.0;
        ma_at_last_adjustment = 110.0;
        correction_count = 0;
      }
  in
  run_and_print "S4 short" Short initial
    [
      (95.0, 92.0, 97.0, 108.0, Declining, stage4);
      (88.0, 85.0, 90.0, 105.0, Declining, stage4);
      (80.0, 78.0, 82.0, 102.0, Declining, stage4);
      (85.0, 82.0, 88.0, 101.0, Declining, stage4);
      (87.0, 84.0, 89.0, 100.0, Declining, stage4);
      (78.0, 75.0, 79.0, 98.0, Declining, stage4);
    ]

let test_s5_long _ =
  let state0 =
    compute_initial_stop ~config:cfg ~side:Long ~reference_level:52.0
  in
  Printf.printf "\n=== S5 long lifecycle ===\n";
  Printf.printf "state0 stop=%.4f\n%!" (get_stop_level state0);
  let bar_advance = make_bar ~low_price:53.0 ~high_price:58.0 56.0 in
  let state1, _ =
    update ~config:cfg ~side:Long ~state:state0 ~current_bar:bar_advance
      ~ma_value:51.0 ~ma_direction:Rising
      ~stage:(Stage2 { weeks_advancing = 1; late = false })
  in
  Printf.printf "state1: %s\n%!" (show_stop_state state1);
  let steps_to_raise =
    [
      (62.0, 59.0, 64.0, 53.0, Rising, stage2);
      (68.0, 65.0, 70.0, 55.0, Rising, stage2);
      (63.0, 60.0, 65.0, 56.0, Rising, stage2);
      (70.0, 67.0, 72.0, 57.0, Rising, stage2);
    ]
  in
  let state2, _ =
    List.fold steps_to_raise ~init:(state1, No_change)
      ~f:(fun (st, _) (c, l, h, ma, dir, stg) ->
        let bar = make_bar ~low_price:l ~high_price:h c in
        let ns, ev =
          update ~config:cfg ~side:Long ~state:st ~current_bar:bar ~ma_value:ma
            ~ma_direction:dir ~stage:stg
        in
        Printf.printf "  c=%.0f: %s → stop=%.4f\n%!" c (show_stop_event ev)
          (get_stop_level ns);
        (ns, ev))
  in
  Printf.printf "state2: %s\n%!" (show_stop_state state2);
  let bar_top = make_bar ~low_price:68.0 ~high_price:72.0 70.0 in
  let state3, ev3 =
    update ~config:cfg ~side:Long ~state:state2 ~current_bar:bar_top
      ~ma_value:58.0 ~ma_direction:Flat ~stage:stage3
  in
  Printf.printf "state3: %s  ev=%s\n%!" (show_stop_state state3)
    (show_stop_event ev3);
  let tightened_stop = get_stop_level state3 in
  let bar_exit =
    make_bar ~low_price:(tightened_stop -. 2.0) ~high_price:68.0 66.0
  in
  let _state4, ev4 =
    update ~config:cfg ~side:Long ~state:state3 ~current_bar:bar_exit
      ~ma_value:57.0 ~ma_direction:Flat ~stage:stage3
  in
  Printf.printf "ev4: %s\n%!" (show_stop_event ev4)

let test_s5_short _ =
  (* Mirror of long lifecycle: short entry, stage4 decline, stage1 tightening, stop hit *)
  let state0 =
    compute_initial_stop ~config:cfg ~side:Short ~reference_level:50.0
  in
  Printf.printf "\n=== S5 short lifecycle ===\n";
  Printf.printf "state0: %s  stop=%.4f\n%!" (show_stop_state state0)
    (get_stop_level state0);
  let bar_decline = make_bar ~low_price:44.0 ~high_price:48.0 46.0 in
  let state1, ev1 =
    update ~config:cfg ~side:Short ~state:state0 ~current_bar:bar_decline
      ~ma_value:51.0 ~ma_direction:Declining ~stage:stage4
  in
  Printf.printf "state1: %s  ev=%s\n%!" (show_stop_state state1)
    (show_stop_event ev1);
  (* Build decline, correction cycle, tightening, stop hit *)
  let steps =
    [
      (42.0, 40.0, 44.0, 50.0, Declining, stage4);
      (38.0, 36.0, 40.0, 49.0, Declining, stage4);
      (* counter-rally *)
      (41.0, 39.0, 43.0, 48.0, Declining, stage4);
      (* renewed decline below prior trough *)
      (35.0, 33.0, 37.0, 47.0, Declining, stage4);
      (* stage1 triggers tightening *)
      (36.0, 34.0, 38.0, 46.0, Rising, Stage1 { weeks_in_base = 3 });
    ]
  in
  let state2, _ =
    List.fold steps ~init:(state1, No_change)
      ~f:(fun (st, _) (c, l, h, ma, dir, stg) ->
        let bar = make_bar ~low_price:l ~high_price:h c in
        let ns, ev =
          update ~config:cfg ~side:Short ~state:st ~current_bar:bar ~ma_value:ma
            ~ma_direction:dir ~stage:stg
        in
        Printf.printf "  c=%.0f: %s → %s\n%!" c (show_stop_event ev)
          (show_stop_state ns);
        (ns, ev))
  in
  Printf.printf "state2 stop=%.4f\n%!" (get_stop_level state2);
  let tightened_stop = get_stop_level state2 in
  let bar_exit =
    make_bar ~low_price:30.0 ~high_price:(tightened_stop +. 2.0) 32.0
  in
  let _state3, ev3 =
    update ~config:cfg ~side:Short ~state:state2 ~current_bar:bar_exit
      ~ma_value:46.0 ~ma_direction:Rising
      ~stage:(Stage1 { weeks_in_base = 4 })
  in
  Printf.printf "event3 (stop hit): %s\n%!" (show_stop_event ev3)

let () =
  run_test_tt_main
    ("debug"
    >::: [
           "s1" >:: test_s1;
           "s2" >:: test_s2;
           "s4" >:: test_s4;
           "s5_long" >:: test_s5_long;
           "s5_short" >:: test_s5_short;
         ])
