(** Stack-backed pool of reusable [float array] workspace buffers.

    PR-4 of the engine-pooling plan
    ([dev/plans/engine-layer-pooling-2026-04-27.md]) targets the residual
    per-call allocations inside [Price_path] hot paths that aren't naturally
    per-symbol. The dominant offender flagged by the post-PR-A memtrace
    ([dev/notes/panels-memtrace-postA-2026-04-26.md]) is
    [Price_path._sample_student_t.sum_squares], which on the [bull-crash-292x6y]
    matrix run accounts for ~85K sampled allocations from a single [ref 0.0]
    accumulator created per call (~850M real allocations on a 6y matrix).

    [Buffer_pool.t] models that as a [Stack] of borrow-and-return [float array]
    workspaces. Callers [acquire] a buffer on entry, mutate in place, then
    [release] on exit. The stack discipline is **load-bearing**: callers must
    release in LIFO order. Because the engine is single-threaded by
    construction, no synchronization is needed.

    The pool grows lazily. [acquire] returns either a recycled buffer (popped
    from the stack) or a freshly-allocated one (sized to [capacity]). [release]
    pushes the buffer back unless the stack is already full
    ([Stack.length >= max_size]), in which case the buffer is dropped to GC —
    bounding the pool's steady-state memory.

    Not thread-safe. *)

type t
(** A pool of [float array] buffers. *)

val create : initial_size:int -> max_size:int -> t
(** [create ~initial_size ~max_size] creates an empty pool that will hold up to
    [max_size] buffers in its free stack. [initial_size] is the default capacity
    that [acquire] uses when no [capacity] argument is supplied; it also
    pre-allocates one buffer at construction so the very first [acquire] is
    allocation-free.

    @raise Invalid_argument
      if [initial_size < 1] or [max_size < 1] or [max_size < initial_size]. *)

val acquire : t -> ?capacity:int -> unit -> float array
(** [acquire pool ?capacity ()] returns a buffer of length at least [capacity]
    (defaulting to the pool's [initial_size] when not specified).

    If the pool's free stack has a buffer of sufficient length, that buffer is
    popped and returned. Otherwise a fresh buffer of length [capacity] is
    allocated. The returned buffer's contents are unspecified; callers must
    initialise the slots they use. *)

val release : t -> float array -> unit
(** [release pool buf] returns [buf] to the pool. If the pool already holds
    [max_size] buffers, [buf] is dropped (left to GC) instead — this bounds the
    pool's steady-state retention.

    Calling [release] on a buffer that wasn't obtained from this pool is
    harmless but pointless. *)

val length : t -> int
(** Number of free buffers currently held by the pool. Diagnostic only. *)
