(** Strategy-integration layer for {!Harvest_rotate_runner}. See
    [harvest_rotate_wiring.mli]. *)

open Core
open Weinstein_strategy_config

(** Emit the exit-side audit for harvest [TriggerPartialExit] trims, mirroring
    the other exit runners. [emit_exit_audit] is currently a no-op on
    [TriggerPartialExit] (partial-exit MFE/MAE capture is deferred); piping the
    list through keeps the wiring uniform. Must run while [positions] still
    holds the (un-trimmed) position. *)
let _emit_audit ~config ~audit_recorder ~prior_macro_result ~bar_reader
    ~prior_stages ~positions ts =
  List.iter ts
    ~f:
      (Exit_audit_capture.emit_exit_audit ~audit_recorder ~prior_macro_result
         ~stage_config:config.stage_config ~lookback_bars:config.lookback_bars
         ~bar_reader ~prior_stages ~positions)

let run ~config ~positions ~get_price ~prior_stages ~index_view ~audit_recorder
    ~prior_macro_result ~bar_reader ~current_date =
  if not config.enable_harvest_rotate then []
  else begin
    let is_friday =
      Weinstein_strategy_screening.is_screening_day_view index_view
    in
    let ts =
      Harvest_rotate_runner.update ~harvest_fraction:config.harvest_fraction
        ~is_screening_day:is_friday ~positions ~get_price ~prior_stages
        ~current_date
    in
    _emit_audit ~config ~audit_recorder ~prior_macro_result ~bar_reader
      ~prior_stages ~positions ts;
    ts
  end
