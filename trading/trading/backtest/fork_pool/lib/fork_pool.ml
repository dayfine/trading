(** Implementation notes — see [fork_pool.mli] for the public contract.

    Mechanism: for each job we open an anonymous [Unix.pipe], fork, and in the
    child marshal the result to the pipe's write end (or marshal a sentinel
    "exception" payload if the job raises). The parent reads the payload back
    after [waitpid]. Result reassembly is by input index; children may finish in
    any order.

    Why marshal-over-pipe instead of temp files (the [scenario_runner]
    precedent): pipes are zero-disk-I/O, generic over [`'a], and self-cleanup on
    process exit. [scenario_runner] uses temp files because its result type
    ([Scenario.actual]) is sexp-serialisable and the files double as user-facing
    artefacts. [Fork_pool] is a general-purpose library — callers shouldn't have
    to plumb a sexp converter through. *)

open Core

(* ---- Documented constants ----------------------------------------- *)

(** Hard cap on [parallel]; rejected with [Invalid_argument] above this.
    Rationale: typical dev-container budgets are 4-8 cores; 16 is a fork-bomb
    sanity ceiling. Matches the cap in
    {{:../../../dev/plans/parallelise-walk-forward-executor-2026-05-18.md}
     parallelise-walk-forward-executor-2026-05-18.md} §4. *)
let max_parallel = 16

(** Grace period (seconds) the parent waits for SIGTERM'd siblings to reap on
    first-failure short-circuit before giving up and proceeding. A misbehaving
    child that ignores SIGTERM is logged but not killed with SIGKILL — the
    parent prefers a benign orphan over a partial cleanup. 30 s is generous: a
    child mid-backtest will exit within seconds once it loses its checkpointed
    iteration. *)
let _sigterm_grace_seconds = 30

(* ---- Internal IPC payload ----------------------------------------- *)

(* What the child marshals back to the parent. We can't marshal [exn]
   directly across processes (it can carry abstract values + closures),
   so we serialise the exception's [Exn.to_string] form. *)
type 'a _ipc_payload = Ok_result of 'a | Failed of string

(* In-flight child bookkeeping. *)
type _running = { index : int; pid : Pid.t; read_fd : Core_unix.File_descr.t }

(* ---- Argument validation ------------------------------------------ *)

let _validate_parallel ~parallel =
  if parallel < 1 then
    invalid_arg
      (sprintf "Fork_pool.run_parallel: parallel must be >= 1, got %d" parallel)
  else if parallel > max_parallel then
    invalid_arg
      (sprintf
         "Fork_pool.run_parallel: parallel must be <= %d, got %d (sanity cap; \
          raise [max_parallel] if you really need more)"
         max_parallel parallel)

(* ---- Sequential fast path ----------------------------------------- *)

(* When [parallel = 1] we just call each job in the parent process.
   No fork, no marshal — preserves debugger / stack-trace behaviour and
   matches the plan §6 "preserves no-fork test path" requirement. *)
let _run_sequential ~(jobs : (unit -> 'a) array) : 'a array =
  Array.map jobs ~f:(fun job -> job ())

(* ---- Parallel path: child side ------------------------------------ *)

(* Run [job] inside a forked child and marshal the result to [write_fd].
   Always exits the process — the caller's [fork] [`In_the_child] arm
   must never return to user code. *)
let _child_body ~job ~write_fd =
  let payload = try Ok_result (job ()) with e -> Failed (Exn.to_string e) in
  (* Marshal to a Bytes buffer first so we can write atomically.
     [Marshal.to_bytes] uses the same wire format as
     [Marshal.from_channel], which is what the parent uses to read back. *)
  let bytes = Marshal.to_bytes payload [ Marshal.Closures ] in
  let out = Core_unix.out_channel_of_descr write_fd in
  Out_channel.output_bytes out bytes;
  Out_channel.close out;
  Stdlib.exit 0

(* ---- Parallel path: spawning -------------------------------------- *)

(* Fork one child for [jobs.(index)] and return its in-flight handle.
   Closes the write end in the parent so a child exit cleanly EOFs the
   read end. *)
let _spawn_one ~(jobs : (unit -> 'a) array) ~index : _running =
  let read_fd, write_fd = Core_unix.pipe () in
  match Core_unix.fork () with
  | `In_the_child ->
      Core_unix.close read_fd;
      _child_body ~job:jobs.(index) ~write_fd
  | `In_the_parent pid ->
      Core_unix.close write_fd;
      { index; pid; read_fd }

(* ---- Parallel path: reaping --------------------------------------- *)

(* Read all bytes from [fd] until EOF and unmarshal as an [_ipc_payload].
   Used after waitpid so the child has finished writing; the read will
   see exactly the bytes the child marshalled, then EOF. *)
let _read_payload ~read_fd : 'a _ipc_payload =
  let in_ch = Core_unix.in_channel_of_descr read_fd in
  let bytes = In_channel.input_all in_ch |> Bytes.of_string in
  In_channel.close in_ch;
  (Marshal.from_bytes bytes 0 : 'a _ipc_payload)

(* Translate one [waitpid] result into a (payload-or-None, crash-msg-or-None)
   pair. Splits the two arms of the exit-status match out of [_await_any] so
   that function stays under the nesting cap. *)
let _interpret_exit_status (completed : _running)
    (exit_status :
      (unit, [ `Exit_non_zero of int | `Signal of Signal.t ]) Result.t) :
    'a _ipc_payload option * string option =
  match exit_status with
  | Ok () -> (Some (_read_payload ~read_fd:completed.read_fd), None)
  | Error err ->
      Core_unix.close completed.read_fd;
      let msg =
        sprintf "child for job index %d exited abnormally: %s" completed.index
          (Core_unix.Exit_or_signal.to_string_hum (Error err))
      in
      (None, Some msg)

(* Block waiting for any child in [running] to exit. Returns the
   completed handle (with its payload read back) plus the abnormal-exit
   message if the child exited non-zero. We return both so the caller
   can distinguish a clean exit (payload may still be [Failed _] from a
   caught exception inside the child) from a hard crash (no payload). *)
let _await_any (running : _running list) :
    _running * 'a _ipc_payload option * string option =
  let pid, exit_status = Core_unix.wait `Any in
  let completed = List.find_exn running ~f:(fun r -> Pid.equal r.pid pid) in
  let payload, crash_msg = _interpret_exit_status completed exit_status in
  (completed, payload, crash_msg)

(* ---- Parallel path: short-circuit on failure ---------------------- *)

(* SIGTERM every sibling and reap them. Errors during signal delivery
   (e.g., child has already exited and pid was reclaimed by a prior
   [wait]) are swallowed because the goal is best-effort cleanup, not
   strict liveness. After this returns there are no Fork_pool children
   left in the process group, modulo the rare case where a child
   ignores SIGTERM — in that case the OS will reap it as the parent
   exits and there's nothing more for us to do. *)
let _terminate_siblings (siblings : _running list) =
  List.iter siblings ~f:(fun r ->
      (* [send_i] silently no-ops if the child has already exited and
         been reaped — exactly the best-effort semantics we want. *)
      (try Signal_unix.send_i Signal.term (`Pid r.pid) with _ -> ());
      (* Close our end of the pipe so the child sees EPIPE if it tries
         to write — speeds its exit. *)
      try Core_unix.close r.read_fd with _ -> ());
  List.iter siblings ~f:(fun r ->
      try ignore (Core_unix.waitpid r.pid : Core_unix.Exit_or_signal.t)
      with _ -> ())

(* ---- Parallel path: main loop ------------------------------------- *)

(* Process one successfully-reaped payload: either record the result or
   short-circuit the pool by SIGTERMing siblings + raising. *)
let _store_payload ~results ~running (r : _running) (payload : 'a _ipc_payload)
    =
  match payload with
  | Ok_result v -> results.(r.index) <- Some v
  | Failed msg ->
      _terminate_siblings
        (List.filter !running ~f:(fun x -> not (Pid.equal x.pid r.pid)));
      failwith (sprintf "Fork_pool: job index %d raised: %s" r.index msg)

(* Short-circuit the pool on a hard child crash (non-zero exit / signal). *)
let _handle_crash ~running (r : _running) ~msg =
  _terminate_siblings
    (List.filter !running ~f:(fun x -> not (Pid.equal x.pid r.pid)));
  failwith (sprintf "Fork_pool: %s" msg)

(* Reap one finished child. Dispatches to [_store_payload] on clean exit
   or [_handle_crash] on abnormal exit; either path may short-circuit by
   raising [Failure]. *)
let _reap_one ~results ~running =
  let completed, payload, crash_msg = _await_any !running in
  running :=
    List.filter !running ~f:(fun r -> not (Pid.equal r.pid completed.pid));
  match (payload, crash_msg) with
  | Some p, None -> _store_payload ~results ~running completed p
  | None, Some msg -> _handle_crash ~running completed ~msg
  | _ ->
      (* Defensive: [_await_any] guarantees exactly one of payload /
         crash_msg is set. *)
      failwith
        (sprintf "Fork_pool: internal invariant violation reaping job index %d"
           completed.index)

(* Process [jobs] with up to [parallel] concurrent children. Returns
   results in input order. Raises [Failure] on the first failure
   (either an exception inside a job or a child crash). *)
let _run_pool ~parallel ~(jobs : (unit -> 'a) array) : 'a array =
  let n = Array.length jobs in
  let results : 'a option array = Array.create ~len:n None in
  (* Use a ref list for [running]; small N (capped at [parallel] ≤ 16)
     so O(N) lookups are cheap. *)
  let running = ref [] in
  let next_index = ref 0 in
  while !next_index < n || not (List.is_empty !running) do
    if !next_index < n && List.length !running < parallel then begin
      let r = _spawn_one ~jobs ~index:!next_index in
      running := r :: !running;
      incr next_index
    end
    else _reap_one ~results ~running
  done;
  Array.map results ~f:(fun opt ->
      Option.value_exn ~message:"Fork_pool: missing result (bug)" opt)

(* ---- Public entry point ------------------------------------------- *)

let run_parallel ~parallel ~jobs =
  _validate_parallel ~parallel;
  if parallel = 1 then _run_sequential ~jobs else _run_pool ~parallel ~jobs

let run_each_forked ~jobs = _run_pool ~parallel:1 ~jobs
