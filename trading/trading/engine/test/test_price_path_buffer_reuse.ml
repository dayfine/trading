(** Parity tests for the [Price_path.Scratch] buffer-reuse path.

    These tests are the load-bearing parity gate for PR-2 of the engine-pooling
    plan: any drift in [generate_path_into] vs [generate_path] (or any leftover
    state across sequential calls sharing a scratch) shows up here as a
    bit-equality failure.

    The seeded golden tests in [test_price_path.ml] cover [generate_path] output
    stability against pinned numeric values; this file complements them with the
    *buffer reuse* invariants. *)

open OUnit2
open Core
open Trading_engine.Types
open Trading_engine.Price_path
open Matchers

(** {1 Helpers} *)

let make_bar symbol ~open_price ~high_price ~low_price ~close_price =
  { symbol; open_price; high_price; low_price; close_price }

let bar_aapl =
  make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
    ~close_price:105.0

let bar_googl =
  make_bar "GOOGL" ~open_price:200.0 ~high_price:215.0 ~low_price:198.0
    ~close_price:212.0

let bar_msft =
  make_bar "MSFT" ~open_price:300.0 ~high_price:305.0 ~low_price:290.0
    ~close_price:292.0

let make_config ?(profile = Uniform) ?(total_points = 30) ~seed
    ?(degrees_of_freedom = 4.0) () =
  { profile; total_points; seed = Some seed; degrees_of_freedom }

(** Compare two [intraday_path]s for bit-equal float prices. *)
let path_bit_eq (a : intraday_path) (b : intraday_path) : bool =
  List.equal
    (fun (p1 : path_point) (p2 : path_point) -> Float.(p1.price = p2.price))
    a b

(** {1 R1: idempotence — same inputs + same scratch → same output} *)

let test_buffer_reuse_idempotent _ =
  (* Calling [generate_path_into] twice with the same scratch and the same
     (seeded) inputs must yield bit-equal outputs. This pins the first-order
     buffer-reuse invariant: no hidden state survives across calls. *)
  let config = make_config ~seed:12345 ~total_points:30 () in
  let scratch = Scratch.for_config config in
  let path1 = generate_path_into ~scratch ~config bar_aapl in
  let path2 = generate_path_into ~scratch ~config bar_aapl in
  assert_that (path_bit_eq path1 path2) (equal_to true)

(** {1 R2: no leftover state across different inputs} *)

let test_buffer_reuse_different_inputs_match_fresh _ =
  (* Sharing a scratch between two different bars must produce the same
     output for the second bar as a fresh scratch would. This catches
     leftover state from the first call leaking into the second. *)
  let config = make_config ~seed:7 ~total_points:50 () in
  let shared = Scratch.for_config config in
  let _first = generate_path_into ~scratch:shared ~config bar_aapl in
  let after_reuse = generate_path_into ~scratch:shared ~config bar_googl in
  let fresh_scratch = Scratch.for_config config in
  let from_fresh =
    generate_path_into ~scratch:fresh_scratch ~config bar_googl
  in
  assert_that (path_bit_eq after_reuse from_fresh) (equal_to true)

(** {1 R3: parity with the non-scratch entry point} *)

let test_into_matches_generate_path _ =
  (* [generate_path_into ~scratch] and [generate_path] must produce
     bit-equal outputs for the same seeded config + bar. *)
  let bars = [ bar_aapl; bar_googl; bar_msft ] in
  let config = make_config ~seed:42 ~total_points:30 () in
  let scratch = Scratch.for_config config in
  List.iter bars ~f:(fun bar ->
      let from_into = generate_path_into ~scratch ~config bar in
      let from_plain = generate_path ~config bar in
      assert_that (path_bit_eq from_into from_plain) (equal_to true))

(** {1 R4: parity across all distribution profiles} *)

let test_parity_all_profiles _ =
  (* All four profiles must have generate_path_into ≡ generate_path. *)
  let profiles = [ UShaped; JShaped; ReverseJ; Uniform ] in
  List.iter profiles ~f:(fun profile ->
      let config = make_config ~profile ~seed:99 ~total_points:40 () in
      let scratch = Scratch.for_config config in
      let from_into = generate_path_into ~scratch ~config bar_aapl in
      let from_plain = generate_path ~config bar_aapl in
      assert_that (path_bit_eq from_into from_plain) (equal_to true))

(** {1 R5: parity at default (390-point) resolution} *)

let test_parity_default_resolution _ =
  (* The default config — what production uses — must round-trip through
     scratch buffers. *)
  let config = { default_config with seed = Some 2026 } in
  let scratch = Scratch.for_config config in
  let from_into = generate_path_into ~scratch ~config bar_aapl in
  let from_plain = generate_path ~config bar_aapl in
  assert_that (path_bit_eq from_into from_plain) (equal_to true)

(** {1 R6: small-resolution edge case (total_points <= 4)} *)

let test_waypoints_only_mode_reuse _ =
  (* total_points <= 4 takes the "waypoints only" code path which doesn't
     write to scratch. Reuse must still be safe and match the plain entry
     point. *)
  let config = make_config ~seed:42 ~total_points:4 () in
  let scratch = Scratch.for_config config in
  let path1 = generate_path_into ~scratch ~config bar_aapl in
  let path2 = generate_path_into ~scratch ~config bar_aapl in
  let from_plain = generate_path ~config bar_aapl in
  assert_that
    (path_bit_eq path1 path2 && path_bit_eq path1 from_plain)
    (equal_to true)

(** {1 R7: capacity validation} *)

let test_too_small_scratch_raises _ =
  (* If the user hands in a buffer too small for the requested config, we
     must reject loudly (rather than silently writing past the end of the
     array). *)
  let small = Scratch.create ~capacity:10 in
  let config = make_config ~seed:1 ~total_points:50 () in
  let result =
    try
      let _ = generate_path_into ~scratch:small ~config bar_aapl in
      `Ok
    with Invalid_argument _ -> `Invalid_argument
  in
  assert_that result (equal_to `Invalid_argument)

let test_create_below_min_raises _ =
  let result =
    try
      let _ = Scratch.create ~capacity:2 in
      `Ok
    with Invalid_argument _ -> `Invalid_argument
  in
  assert_that result (equal_to `Invalid_argument)

(** {1 R8: golden bit-equality with pinned values}

    These bit-equality checks pin [generate_path_into] against the same golden
    output asserted in [test_price_path.ml] for [generate_path]. If the refactor
    drifted the floating-point order, this test would fail. *)

let test_golden_bit_equality _ =
  let bar = bar_aapl in
  let config = make_config ~seed:12345 ~total_points:10 () in
  let scratch = Scratch.for_config config in
  let path = generate_path_into ~scratch ~config bar in
  let expected : intraday_path =
    [
      { price = 100.0 };
      { price = 100.86187228911206 };
      { price = 102.40592847455183 };
      { price = 103.76781747465134 };
      { price = 106.35315965230939 };
      { price = 108.0731149431833 };
      { price = 109.94664616190269 };
      { price = 110.0 };
      { price = 95.0 };
      { price = 95.0 };
      { price = 100.10734547267361 };
      { price = 104.09730483755989 };
      { price = 105.0 };
    ]
  in
  assert_that (path_bit_eq path expected) (equal_to true)

(** {1 Test Suite} *)

let suite =
  "Price Path Buffer Reuse Tests"
  >::: [
         "buffer reuse: idempotent same inputs" >:: test_buffer_reuse_idempotent;
         "buffer reuse: different inputs match fresh scratch"
         >:: test_buffer_reuse_different_inputs_match_fresh;
         "into matches generate_path" >:: test_into_matches_generate_path;
         "parity across all distribution profiles" >:: test_parity_all_profiles;
         "parity at default 390-point resolution"
         >:: test_parity_default_resolution;
         "waypoints-only mode reuse" >:: test_waypoints_only_mode_reuse;
         "too-small scratch raises Invalid_argument"
         >:: test_too_small_scratch_raises;
         "Scratch.create below min capacity raises"
         >:: test_create_below_min_raises;
         "golden bit-equality with seed=12345" >:: test_golden_bit_equality;
       ]

let () = run_test_tt_main suite
