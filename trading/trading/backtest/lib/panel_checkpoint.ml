(** See [panel_checkpoint.mli]. *)

open Core
module Manifest = Snapshot_pipeline.Snapshot_manifest

type window = Date.t * Date.t * int * float
type resumed = Backtest_checkpoint.header * Backtest_checkpoint.state

let manifest_sexp (m : Manifest.t) =
  let entry (e : Manifest.file_metadata) =
    Sexp.List
      [
        sexp_of_string e.symbol;
        sexp_of_int e.byte_size;
        sexp_of_string e.payload_md5;
        [%sexp_of: Date.t option] e.active_through;
      ]
  in
  Sexp.List
    [
      sexp_of_string m.schema_hash;
      [%sexp_of: string option] m.weekly_sidetable_format_hash;
      Sexp.List (List.map m.entries ~f:entry);
    ]

(* What a resume must reproduce: the strategy config and the run's window. *)
let _run_key (config : Weinstein_strategy.config)
    ((start, end_, warmup, cash) : window) =
  Sexp.List
    (Weinstein_strategy.sexp_of_config config
     :: List.map ~f:Date.sexp_of_t [ start; end_ ]
    @ [ sexp_of_int warmup; sexp_of_float cash ])

let load_resume ~checkpoint ~config ~window ~manifest ~candidate_log =
  match checkpoint with
  | Some ({ Backtest_checkpoint.resume = true; _ } as request) ->
      if Option.is_some candidate_log then
        failwith "Panel_runner: --resume does not support candidate capture";
      Backtest_checkpoint.load_for_resume ~request
        ~run_key:(_run_key config window) ~manifest:(manifest_sexp manifest)
      |> Result.map_error ~f:(fun e -> "Panel_runner: " ^ Status.show e)
      |> Result.ok_or_failwith |> Option.some
  | _ -> None

let restore_sim sim = function
  | None -> sim
  | Some ((_ : Backtest_checkpoint.header), (s : Backtest_checkpoint.state)) ->
      Trading_simulation.Simulator.Checkpoint.restore sim s.simulator
      |> Result.map_error ~f:(fun e ->
          "Panel_runner: checkpoint restore failed: " ^ Status.show e)
      |> Result.ok_or_failwith

let resume_date resumed =
  Option.map resumed ~f:(fun ((h : Backtest_checkpoint.header), _) -> h.date)

let hooks ~resumed ~checkpoint ~strategy_choice ~config ~window ~manifest
    ~stop_log ~trade_audit ~force_liquidation_log ~candidate_log =
  Backtest_checkpoint.setup ~resumed ~request:checkpoint
    ~weinstein:(Strategy_choice.equal strategy_choice Strategy_choice.Weinstein)
    ~run_key:(_run_key config window) ~manifest:(manifest_sexp manifest)
    ~stop_log ~trade_audit ~force_liquidation_log ~candidate_log
