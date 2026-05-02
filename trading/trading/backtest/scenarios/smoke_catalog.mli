(** Fixed three-window smoke catalog used by [backtest_runner --smoke].

    Each window is a short, representative period chosen to exercise the
    strategy across a different macro regime. All three together should run in
    well under 20 minutes on M2-class hardware against the {b sp500 universe}
    (~491 symbols) — the goal is fast iteration, not statistical significance.

    - {b Bull}: 2019-06-01 .. 2019-12-31 (~6 months, persistent uptrend)
    - {b Crash}: 2020-01-02 .. 2020-06-30 (~6 months, COVID + recovery)
    - {b Recovery}: 2023-01-02 .. 2023-12-31 (~12 months, post-bear rebound)

    The catalog is deliberately fixed (not configurable) — variation comes from
    [--override] flags applied to each window in turn.

    {b Universe sizing.} Every window's [universe_path] points at
    [universes/sp500.sexp] by default. The previous behaviour (defaulting to the
    full ~10K-symbol [sectors.csv] universe) OOMed the 8 GB dev container at
    ~6.9 GB RSS during the first window's panel load — defeating the whole point
    of "smoke" being fast iteration. See dispatch note for the M5.4 E1
    short-on/off A/B that surfaced this. *)

open Core

type window = {
  name : string;
      (** Short label used in output paths and progress logs (e.g. ["bull"],
          ["crash"], ["recovery"]). *)
  start_date : Date.t;
  end_date : Date.t;
  description : string;  (** One-line description of the macro regime. *)
  universe_path : string;
      (** Universe-file path relative to the fixtures root (i.e.
          [TRADING_DATA_DIR/backtest_scenarios/]). Loaded by the runner via
          {!Scenario_lib.Universe_file.load} + [to_sector_map_override]; the
          runner then passes the resulting [sector_map_override] to
          {!Backtest.Runner.run_backtest}. Defaults to ["universes/sp500.sexp"]
          across all windows so the smoke run stays under the 8 GB container
          memory budget. *)
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
