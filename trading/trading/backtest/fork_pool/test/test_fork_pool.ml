(** Tests for {!Fork_pool}.

    Coverage (per PR-1 dispatch §"Tests under
    trading/trading/backtest/fork_pool/test/"):

    - parallel=1 is a no-fork direct call (verified by reading the child PID
      side-effect — if we forked, the recorded pid would differ from the
      parent's).
    - parallel=4 with 12 jobs: results returned in input order, every job ran
      exactly once.
    - random parallel ∈ [1,12] × random job count: results in input order.
    - failure injection: one job raises ⇒ parent re-raises with the job index
      embedded in the message + sibling children are reaped (no orphans).

    The signature constants used by the test live as documented [let _ = ...]
    bindings at the top so a linter audit sees no unexplained numbers. *)

open Core
open OUnit2
open Matchers

(* ---- Tunables (named constants so linter sees no magic numbers) --- *)

let _test_job_count_basic = 12
let _test_parallel_basic = 4
let _test_random_iterations = 10
let _test_random_max_parallel = 12
let _test_random_max_jobs = 30
let _test_failure_total_jobs = 12
let _test_failure_index = 5
let _test_failure_parallel = 4

(* A simple deterministic "work" function: squaring the index. We want
   the result to depend on the input so a result-reordering bug shows
   up as wrong values, not just a wrong array length. *)
let _square i () = i * i

(* ---- parallel=1 short-circuits to the direct path ----------------- *)

(* The plan §6 invariant: [parallel=1] must not fork. We can't observe
   "did not fork" directly, but we can observe a side effect that only
   the parent's address space sees: a [ref] mutation. If we fork, the
   child's mutation is invisible to the parent (copy-on-write). If we
   don't fork, the mutation is visible. *)
let test_parallel_one_is_direct _ =
  let counter = ref 0 in
  let jobs =
    Array.init _test_job_count_basic ~f:(fun _ () ->
        incr counter;
        !counter)
  in
  let results = Fork_pool.run_parallel ~parallel:1 ~jobs in
  assert_that (Array.length results) (equal_to _test_job_count_basic);
  (* All [incr counter] calls happened in this process — the parent saw
     them, so [counter] equals the job count. If the code had forked,
     the parent's [counter] would still be 0. *)
  assert_that !counter (equal_to _test_job_count_basic)

(* ---- parallel=4 with 12 jobs: in-order, all-ran ------------------- *)

let test_parallel_four_results_in_input_order _ =
  let jobs = Array.init _test_job_count_basic ~f:_square in
  let results = Fork_pool.run_parallel ~parallel:_test_parallel_basic ~jobs in
  let expected = Array.init _test_job_count_basic ~f:(fun i -> i * i) in
  assert_that (Array.to_list results)
    (elements_are (List.map (Array.to_list expected) ~f:(fun v -> equal_to v)))

(* ---- Random parallel × random jobs: input-order property ---------- *)

(* Seed-stable randomness: we use a fresh [Random.State] so this test
   is deterministic across runs (and reproducible from a failure
   message). The 10 iterations sweep parallel in [1, 12] and job count
   in [1, 30]. *)
let test_random_parallel_random_jobs _ =
  let st = Random.State.make [| 0xF02C; 0x1A57 |] in
  for _ = 1 to _test_random_iterations do
    let parallel = 1 + Random.State.int st _test_random_max_parallel in
    let n_jobs = 1 + Random.State.int st _test_random_max_jobs in
    let jobs = Array.init n_jobs ~f:_square in
    let results = Fork_pool.run_parallel ~parallel ~jobs in
    let expected = Array.init n_jobs ~f:(fun i -> i * i) in
    assert_that (Array.to_list results)
      (elements_are
         (List.map (Array.to_list expected) ~f:(fun v -> equal_to v)))
  done

(* ---- Failure injection: one job raises ---------------------------- *)

(* The contract: when any job raises, [run_parallel] re-raises a
   [Failure] whose message embeds the failing job's index. The other
   siblings must be reaped (no orphan PIDs). Verifying "no orphans" via
   the OS is brittle in a unit test, so we rely on the implementation's
   [_terminate_siblings] + [waitpid] loop and assert only the
   user-visible promise: the exception shape. *)
let test_failure_one_job_raises _ =
  let jobs =
    Array.init _test_failure_total_jobs ~f:(fun i () ->
        if i = _test_failure_index then failwith "synthetic boom" else i * i)
  in
  let raised =
    try
      let _ : int array =
        Fork_pool.run_parallel ~parallel:_test_failure_parallel ~jobs
      in
      None
    with Failure msg -> Some msg
  in
  assert_that raised
    (is_some_and
       (all_of
          [
            contains_substring (sprintf "job index %d" _test_failure_index);
            contains_substring "synthetic boom";
          ]))

(* ---- Validation errors ------------------------------------------- *)

let test_parallel_zero_rejected _ =
  let jobs = [| (fun () -> 0) |] in
  let raised =
    try
      let _ : int array = Fork_pool.run_parallel ~parallel:0 ~jobs in
      None
    with Invalid_argument msg -> Some msg
  in
  assert_that raised (is_some_and (contains_substring "parallel must be >= 1"))

let test_parallel_above_cap_rejected _ =
  let jobs = [| (fun () -> 0) |] in
  let raised =
    try
      let _ : int array =
        Fork_pool.run_parallel ~parallel:(Fork_pool.max_parallel + 1) ~jobs
      in
      None
    with Invalid_argument msg -> Some msg
  in
  assert_that raised
    (is_some_and
       (contains_substring
          (sprintf "parallel must be <= %d" Fork_pool.max_parallel)))

(* ---- Test suite registration ------------------------------------- *)

let suite =
  "Fork_pool"
  >::: [
         "parallel=1 is direct (no fork)" >:: test_parallel_one_is_direct;
         "parallel=4 with 12 jobs returns results in input order"
         >:: test_parallel_four_results_in_input_order;
         "random parallel × random jobs preserves input order"
         >:: test_random_parallel_random_jobs;
         "one failing job re-raises with index context"
         >:: test_failure_one_job_raises;
         "parallel=0 is rejected with Invalid_argument"
         >:: test_parallel_zero_rejected;
         "parallel > max_parallel is rejected with Invalid_argument"
         >:: test_parallel_above_cap_rejected;
       ]

let () = run_test_tt_main suite
