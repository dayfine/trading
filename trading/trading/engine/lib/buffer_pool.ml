open Core

(** See [.mli] for the public contract. *)

type t = { free : float array Stack.t; initial_size : int; max_size : int }

let create ~initial_size ~max_size =
  if initial_size < 1 then
    invalid_arg
      (Printf.sprintf "Buffer_pool.create: initial_size %d < 1" initial_size);
  if max_size < 1 then
    invalid_arg (Printf.sprintf "Buffer_pool.create: max_size %d < 1" max_size);
  if max_size < initial_size then
    invalid_arg
      (Printf.sprintf "Buffer_pool.create: max_size %d < initial_size %d"
         max_size initial_size);
  let free = Stack.create () in
  (* Pre-seed one buffer so the first [acquire] is allocation-free. *)
  Stack.push free (Array.create ~len:initial_size 0.0);
  { free; initial_size; max_size }

let acquire t ?capacity () =
  let needed = Option.value capacity ~default:t.initial_size in
  match Stack.pop t.free with
  | Some buf when Array.length buf >= needed -> buf
  | Some _too_small ->
      (* The popped buffer wasn't large enough. Drop it and allocate fresh
         at the requested capacity. The undersized buffer is left to GC
         rather than re-pushed: keeping it would just trigger the same
         miss on the next [acquire ~capacity]. *)
      Array.create ~len:needed 0.0
  | None -> Array.create ~len:needed 0.0

let release t buf =
  if Stack.length t.free < t.max_size then Stack.push t.free buf
(* else: drop [buf] to GC — the pool is already at its retention bound. *)

let length t = Stack.length t.free
