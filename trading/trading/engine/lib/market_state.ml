(** Per-symbol market state + lazy intraday-path generation. See
    [market_state.mli]. *)

open Core
open Trading_base.Types
open Types

type t = {
  bars : (symbol, price_bar) Hashtbl.t;
      (** Most-recent bar per symbol, set by {!update}. *)
  scratches : (symbol, Price_path.Scratch.t) Hashtbl.t;
      (** Reusable per-symbol [Price_path] scratch buffers. PR-3 of the
          engine-pooling plan ([dev/plans/engine-layer-pooling.md]): one
          pre-allocated scratch per symbol means zero per-call allocation inside
          [Price_path] in steady state. Grown lazily if a later config needs a
          larger capacity. *)
  generated : (symbol, intraday_path) Hashtbl.t;
      (** Per-tick memo of paths already generated this tick; cleared by
          {!update}. *)
  mutable path_config : Price_path.path_config;
      (** [path_config] from the latest {!update}, threaded to lazy generation.
      *)
}

let create () =
  {
    bars = Hashtbl.create (module String);
    scratches = Hashtbl.create (module String);
    generated = Hashtbl.create (module String);
    path_config = Price_path.default_config;
  }

let update t ~path_config bars =
  t.path_config <- path_config;
  Hashtbl.clear t.generated;
  List.iter bars ~f:(fun bar -> Hashtbl.set t.bars ~key:bar.symbol ~data:bar)

(* Look up (or lazily create / grow) the scratch for [symbol] sized for the
   current [path_config]. [find_or_add] allocates only on a miss. *)
let _scratch_for t ~symbol =
  let required = Price_path.Scratch.required_capacity t.path_config in
  let scratch =
    Hashtbl.find_or_add t.scratches symbol ~default:(fun () ->
        Price_path.Scratch.for_config t.path_config)
  in
  if Price_path.Scratch.capacity scratch >= required then scratch
  else
    let grown = Price_path.Scratch.for_config t.path_config in
    Hashtbl.set t.scratches ~key:symbol ~data:grown;
    grown

let _generate t ~symbol bar =
  let scratch = _scratch_for t ~symbol in
  Price_path.generate_path_into ~scratch ~config:t.path_config bar

let path_for t ~symbol =
  match Hashtbl.find t.generated symbol with
  | Some path -> Some path
  | None ->
      Option.map (Hashtbl.find t.bars symbol) ~f:(fun bar ->
          let path = _generate t ~symbol bar in
          Hashtbl.set t.generated ~key:symbol ~data:path;
          path)
