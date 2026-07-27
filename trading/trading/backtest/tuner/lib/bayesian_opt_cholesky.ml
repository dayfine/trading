open Core
module Mat = Owl.Mat

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

type pivot_failure = { index : int; value : float }
(** The column at which the factorisation hit a non-positive pivot (1-based, so
    it reads the same way as LAPACK's [potrf] [info]), plus the pivot value. *)

(** {1 Flat row-major storage}

    The factorisation runs on flat [float array]s rather than [Owl.Mat.mat] so
    the inner loops are plain array reads. [_at ~n i j] is the offset of element
    [(i, j)] of an [n x n] row-major matrix. *)

let _at ~n i j = (i * n) + j

let _flatten k ~n =
  Array.init (n * n) ~f:(fun idx -> Mat.get k (idx / n) (idx % n))

let _unflatten a ~n = Mat.init_2d n n (fun i j -> a.(_at ~n i j))

(** First non-finite entry of [a] as [(row, column, value)], if any. *)
let _first_non_finite a ~n =
  Array.findi a ~f:(fun _ v -> not (Float.is_finite v))
  |> Option.map ~f:(fun (idx, v) -> (idx / n, idx % n, v))

(** {1 Unblocked Cholesky}

    A textbook right-looking unblocked lower Cholesky — the same recurrence as
    LAPACK's [dpotf2], in OCaml. See the [.mli] for why the factorisation is not
    delegated to [Owl.Linalg.D.chol]. *)

(** Inner product of the first [len] entries of rows [i] and [j] of [l]. *)
let _row_dot l ~n ~i ~j ~len =
  let acc = ref 0.0 in
  for p = 0 to len - 1 do
    acc := !acc +. (l.(_at ~n i p) *. l.(_at ~n j p))
  done;
  !acc

(** Fill column [j] of [l] below the diagonal, given the diagonal entry [ljj].
*)
let _fill_below_diagonal l ~a ~n ~j ~ljj =
  for i = j + 1 to n - 1 do
    let dot = _row_dot l ~n ~i ~j ~len:j in
    l.(_at ~n i j) <- (a.(_at ~n i j) -. dot) /. ljj
  done

(** Factor column [j], assuming columns [0 .. j-1] of [l] are already final. *)
let _factor_column l ~a ~n ~j =
  let pivot = a.(_at ~n j j) -. _row_dot l ~n ~i:j ~j ~len:j in
  if Float.( <= ) pivot 0.0 then Error { index = j + 1; value = pivot }
  else begin
    let ljj = Float.sqrt pivot in
    l.(_at ~n j j) <- ljj;
    _fill_below_diagonal l ~a ~n ~j ~ljj;
    Ok ()
  end

(** Lower-triangular factor of the row-major [n x n] matrix [a], or the column
    at which [a] proved not positive definite. *)
let _cholesky_lower a ~n =
  let l = Array.create ~len:(n * n) 0.0 in
  let rec factor j =
    if j >= n then Ok l
    else
      match _factor_column l ~a ~n ~j with
      | Error failure -> Error failure
      | Ok () -> factor (j + 1)
  in
  factor 0

(** {1 Nugget escalation} *)

let _add_to_diagonal a ~n ~amount =
  for i = 0 to n - 1 do
    a.(_at ~n i i) <- a.(_at ~n i i) +. amount
  done

let _raise_non_finite (row, col, value) =
  invalid_arg
    (Printf.sprintf
       "Bayesian_opt_cholesky: kernel matrix entry (%d, %d) is not finite \
        (%g); the GP observations or length scales are degenerate"
       row col value)

let _raise_not_positive_definite { index; value } ~n ~total_jitter =
  failwith
    (Printf.sprintf
       "Bayesian_opt_cholesky: %dx%d kernel matrix is not positive definite \
        after %d attempts (cumulative diagonal jitter %g); pivot %d is %g"
       n n _chol_retry_max_attempts total_jitter index value)

type escalation = {
  jitter : float;  (** Increment the next retry would add to the diagonal. *)
  max_added_jitter : float;  (** Cap on any single increment. *)
  total_jitter : float;  (** Cumulative amount added so far. *)
  attempts_left : int;
}
(** Retry budget and jitter schedule carried across escalation steps. *)

(** Widen the diagonal of [a] by the next (capped) increment and advance the
    schedule. *)
let _escalate a ~n escalation =
  let added = Float.min escalation.jitter escalation.max_added_jitter in
  _add_to_diagonal a ~n ~amount:added;
  {
    escalation with
    jitter = escalation.jitter *. _chol_retry_jitter_growth;
    total_jitter = escalation.total_jitter +. added;
    attempts_left = escalation.attempts_left - 1;
  }

let rec _attempt a ~n escalation =
  match _cholesky_lower a ~n with
  | Ok l -> _unflatten l ~n
  | Error failure when escalation.attempts_left <= 0 ->
      _raise_not_positive_definite failure ~n
        ~total_jitter:escalation.total_jitter
  | Error _ -> _attempt a ~n (_escalate a ~n escalation)

let chol_with_nugget_escalation k ~n ~noise_variance ~signal_variance =
  let a = _flatten k ~n in
  Option.iter (_first_non_finite a ~n) ~f:_raise_non_finite;
  _attempt a ~n
    {
      jitter = Float.max noise_variance _chol_retry_initial_jitter;
      max_added_jitter = _chol_retry_max_relative_jitter *. signal_variance;
      total_jitter = 0.0;
      attempts_left = _chol_retry_max_attempts - 1;
    }
