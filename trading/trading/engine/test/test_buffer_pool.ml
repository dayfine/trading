(** Unit tests for [Trading_engine.Buffer_pool] — the Stack-backed pool of
    [float array] workspace buffers introduced in PR-4 of the engine-pooling
    plan.

    The bit-equality parity gate that locks the pool's behaviour against
    [Price_path] callers lives in [test_price_path_buffer_reuse.ml]
    ([test_golden_bit_equality]) and [test_engine.ml]
    ([test_engine_scratch_threading_parity]). This file pins the pool API
    contract itself: acquire/release semantics, capacity guarantees, and the
    [max_size] retention bound. *)

open OUnit2
open Trading_engine
open Matchers

(** {1 Construction validation} *)

let test_create_rejects_zero_initial_size _ =
  let result =
    try
      let _ = Buffer_pool.create ~initial_size:0 ~max_size:4 in
      `Ok
    with Invalid_argument _ -> `Invalid_argument
  in
  assert_that result (equal_to `Invalid_argument)

let test_create_rejects_zero_max_size _ =
  let result =
    try
      let _ = Buffer_pool.create ~initial_size:4 ~max_size:0 in
      `Ok
    with Invalid_argument _ -> `Invalid_argument
  in
  assert_that result (equal_to `Invalid_argument)

let test_create_rejects_max_below_initial _ =
  let result =
    try
      let _ = Buffer_pool.create ~initial_size:8 ~max_size:4 in
      `Ok
    with Invalid_argument _ -> `Invalid_argument
  in
  assert_that result (equal_to `Invalid_argument)

(** {1 Pre-seeded buffer is allocation-free on first acquire} *)

let test_create_pre_seeds_one_buffer _ =
  (* The pool pre-allocates a single buffer at construction so the first
     [acquire] doesn't allocate — verified here by [length = 1]. *)
  let pool = Buffer_pool.create ~initial_size:4 ~max_size:8 in
  assert_that (Buffer_pool.length pool) (equal_to 1)

(** {1 Acquire / release round-trip} *)

let test_acquire_release_round_trip _ =
  (* Acquire pops, release pushes back. After one round-trip the pool's
     length returns to its original value. *)
  let pool = Buffer_pool.create ~initial_size:4 ~max_size:8 in
  let buf = Buffer_pool.acquire pool () in
  assert_that (Buffer_pool.length pool) (equal_to 0);
  Buffer_pool.release pool buf;
  assert_that (Buffer_pool.length pool) (equal_to 1)

let test_acquire_returns_buffer_at_initial_size _ =
  (* When [?capacity] is omitted, [acquire] uses the pool's [initial_size]. *)
  let pool = Buffer_pool.create ~initial_size:7 ~max_size:8 in
  let buf = Buffer_pool.acquire pool () in
  assert_that (Array.length buf) (equal_to 7)

let test_acquire_with_capacity_returns_at_least_capacity _ =
  (* Re-using a pre-seeded buffer of size 4 to satisfy a capacity:5 request
     would underflow — so [acquire] allocates fresh instead. *)
  let pool = Buffer_pool.create ~initial_size:4 ~max_size:8 in
  let buf = Buffer_pool.acquire pool ~capacity:5 () in
  assert_that (Array.length buf >= 5) (equal_to true)

(** {1 Max-size retention bound} *)

let test_release_drops_when_pool_is_full _ =
  (* When the pool already holds [max_size] buffers, [release] drops the
     buffer rather than growing the stack unboundedly. *)
  let pool = Buffer_pool.create ~initial_size:1 ~max_size:2 in
  (* Pool starts with 1 pre-seeded buffer. *)
  let b1 = Buffer_pool.acquire pool () in
  let b2 = Buffer_pool.acquire pool () in
  let b3 = Buffer_pool.acquire pool () in
  Buffer_pool.release pool b1;
  Buffer_pool.release pool b2;
  Buffer_pool.release pool b3;
  (* Three releases against max_size=2 → only two stick. *)
  assert_that (Buffer_pool.length pool) (equal_to 2)

(** {1 Pool reuse: same buffer returned on consecutive acquires} *)

let test_release_then_acquire_reuses_same_buffer _ =
  (* The Stack discipline guarantees LIFO reuse: a single acquire/release
     pair returns the same array object on the next acquire. This is the
     core invariant that makes pooling allocation-free. *)
  let pool = Buffer_pool.create ~initial_size:4 ~max_size:8 in
  let buf1 = Buffer_pool.acquire pool () in
  Buffer_pool.release pool buf1;
  let buf2 = Buffer_pool.acquire pool () in
  assert_that (buf1 == buf2) (equal_to true)

(** {1 Test Suite} *)

let suite =
  "Buffer Pool Tests"
  >::: [
         "create rejects initial_size=0"
         >:: test_create_rejects_zero_initial_size;
         "create rejects max_size=0" >:: test_create_rejects_zero_max_size;
         "create rejects max_size<initial_size"
         >:: test_create_rejects_max_below_initial;
         "create pre-seeds one buffer" >:: test_create_pre_seeds_one_buffer;
         "acquire/release round-trip" >:: test_acquire_release_round_trip;
         "acquire returns buffer at initial_size"
         >:: test_acquire_returns_buffer_at_initial_size;
         "acquire ?capacity returns >= capacity"
         >:: test_acquire_with_capacity_returns_at_least_capacity;
         "release drops when pool is full"
         >:: test_release_drops_when_pool_is_full;
         "release then acquire reuses same buffer"
         >:: test_release_then_acquire_reuses_same_buffer;
       ]

let () = run_test_tt_main suite
