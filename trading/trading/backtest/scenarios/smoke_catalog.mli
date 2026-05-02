(** Fixed three-window smoke catalog used by [backtest_runner --smoke].

    Each window is a short, representative period chosen to exercise the
    strategy across a different macro regime. All three together should run in
    well under 20 minutes on M2-class hardware against the broad universe — the
    goal is fast iteration, not statistical significance.

    - {b Bull}: 2019-06-01 .. 2019-12-31 (~6 months, persistent uptrend)
    - {b Crash}: 2020-01-02 .. 2020-06-30 (~6 months, COVID + recovery)
    - {b Recovery}: 2023-01-02 .. 2023-12-31 (~12 months, post-bear rebound)

    The catalog is deliberately fixed (not configurable) — variation comes from
    [--override] flags applied to each window in turn. *)

open Core

type window = {
  name : string;
      (** Short label used in output paths and progress logs (e.g. ["bull"],
          ["crash"], ["recovery"]). *)
  start_date : Date.t;
  end_date : Date.t;
  description : string;  (** One-line description of the macro regime. *)
}
[@@deriving sexp]

val all : window list
(** The full catalog in deterministic order: Bull, Crash, Recovery. *)

val bull : window
(** Bull window — exposed individually so callers can pick a single window
    without scanning [all]. *)

val crash : window
(** Crash window. *)

val recovery : window
(** Recovery window. *)
