open Core
module Mat = Owl.Mat
module Linalg = Owl.Linalg.D

(** Maximum number of Cholesky attempts (the first at the caller's
    [noise_variance] plus escalating retries). *)
let _chol_retry_max_attempts = 6

(** Floor for the first added jitter on retry, used when [noise_variance] is
    smaller than this (e.g. exactly 0). *)
let _chol_retry_initial_jitter = 1e-9

(** Multiplier applied to the added jitter after each failed retry. *)
let _chol_retry_jitter_growth = 10.0

(** Upper bound on the added jitter, expressed as a fraction of
    [signal_variance] (the kernel's overall scale), so escalation cannot swamp
    the kernel even after several retries. *)
let _chol_retry_max_relative_jitter = 1e-2

(** [true] iff [exn] is the LAPACKE non-positive-definite failure that
    [Linalg.chol] raises via [Owl_lapacke.check_lapack_error] (a bare
    [Failure "LAPACKE: <n>"] for [n > 0]). Any other exception (including
    [Invalid_argument] for LAPACK argument errors, [n < 0]) is not ours to
    retry. *)
let _is_lapack_non_pd_failure = function
  | Failure msg -> String.is_prefix msg ~prefix:"LAPACKE: "
  | _ -> false

let chol_with_nugget_escalation k ~n ~noise_variance ~signal_variance =
  let max_added_jitter = _chol_retry_max_relative_jitter *. signal_variance in
  let rec attempt jitter attempts_left =
    try Linalg.chol ~upper:false k
    with exn when _is_lapack_non_pd_failure exn ->
      if attempts_left <= 0 then raise exn
      else begin
        let added = Float.min jitter max_added_jitter in
        for i = 0 to n - 1 do
          Mat.set k i i (Mat.get k i i +. added)
        done;
        attempt (jitter *. _chol_retry_jitter_growth) (attempts_left - 1)
      end
  in
  let initial_jitter = Float.max noise_variance _chol_retry_initial_jitter in
  attempt initial_jitter (_chol_retry_max_attempts - 1)
