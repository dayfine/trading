(** See [backtest_checkpoint.mli]. *)

open Core
module Sim = Trading_simulation.Simulator
module Strategy_state = Weinstein_strategy.Weinstein_strategy_state

let version = 1
let dir_name = "checkpoint"

type identity = {
  config_digest : string;
  build_sha : string;
  manifest_digest : string;
  seed_salt : string option;
}
[@@deriving sexp]

type header = {
  version : int;
  date : Date.t;
  n_steps : int;
  identity : identity;
}
[@@deriving sexp]

type state = {
  simulator : Sim.Checkpoint.snapshot;
  strategy : Strategy_state.snapshot;
  stop_log : Stop_log.snapshot;
  trade_audit : Trade_audit.snapshot;
  force_liquidation_log : Force_liquidation_log.snapshot;
  candidate_log : Candidate_log.snapshot option;
}

let _digest sexp = Md5.to_hex (Md5.digest_string (Sexp.to_string sexp))

let identity_of ~run_key ~manifest ~seed_salt =
  {
    config_digest = _digest run_key;
    build_sha = Build_info.git_sha;
    manifest_digest = _digest manifest;
    seed_salt;
  }

(* ---- Paths ---- *)

let _final ~scenario_dir = Filename.concat scenario_dir dir_name
let _tmp ~scenario_dir = _final ~scenario_dir ^ ".tmp"
let _old ~scenario_dir = _final ~scenario_dir ^ ".old"

(* Remove a flat directory of files; absent is fine. *)
let _remove_dir dir =
  if Sys_unix.file_exists_exn dir then (
    Array.iter (Sys_unix.readdir dir) ~f:(fun f ->
        Core_unix.unlink (Filename.concat dir f));
    Core_unix.rmdir dir)

(* ---- Component files ---- *)

let _write_sexp ~dir name sexp =
  Out_channel.write_all (Filename.concat dir name)
    ~data:(Sexp.to_string_hum sexp ^ "\n")

let _read_sexp ~dir name =
  let path = Filename.concat dir name in
  if not (Sys_unix.file_exists_exn path) then
    Status.error_not_found (sprintf "checkpoint file missing: %s" path)
  else
    try Ok (Sexp.load_sexp path)
    with e ->
      Status.error_invalid_argument
        (sprintf "checkpoint file %s does not parse: %s" path (Exn.to_string e))

(* Parse a component, naming the file when the sexp has the wrong shape. *)
let _read_as ~dir name of_sexp =
  let open Result.Let_syntax in
  let%bind sexp = _read_sexp ~dir name in
  try Ok (of_sexp sexp)
  with e ->
    Status.error_invalid_argument
      (sprintf "checkpoint file %s/%s is malformed: %s" dir name
         (Exn.to_string e))

(* Write every component into [dir]. The journal goes first and the header last,
   so a header on disk implies the rest was written. *)
let _write_components ~dir ~identity (s : state) =
  let steps = s.simulator.steps in
  Step_journal.append ~path:(Filename.concat dir Step_journal.file_name) steps;
  let simulator = { s.simulator with steps = [] } in
  _write_sexp ~dir "simulator.sexp" (Sim.Checkpoint.sexp_of_snapshot simulator);
  _write_sexp ~dir "strategy.sexp" (Strategy_state.sexp_of_snapshot s.strategy);
  _write_sexp ~dir "stop_log.sexp" (Stop_log.sexp_of_snapshot s.stop_log);
  _write_sexp ~dir "trade_audit.sexp"
    (Trade_audit.sexp_of_snapshot s.trade_audit);
  _write_sexp ~dir "force_liquidation_log.sexp"
    (Force_liquidation_log.sexp_of_snapshot s.force_liquidation_log);
  Option.iter s.candidate_log ~f:(fun c ->
      _write_sexp ~dir "candidates.sexp" (Candidate_log.sexp_of_snapshot c));
  let header =
    {
      version;
      date = s.simulator.current_date;
      n_steps = List.length steps;
      identity;
    }
  in
  _write_sexp ~dir "header.sexp" (sexp_of_header header)

(* Swap [tmp] in as the checkpoint. The previous one is parked under [.old]
   until the new one is in place, so no step leaves [checkpoint/] half-written. *)
let _commit ~scenario_dir =
  let final = _final ~scenario_dir and old = _old ~scenario_dir in
  if Sys_unix.file_exists_exn final then Core_unix.rename ~src:final ~dst:old;
  Core_unix.rename ~src:(_tmp ~scenario_dir) ~dst:final;
  _remove_dir old

let write ?(before_commit = fun () -> ()) ~scenario_dir ~identity state =
  let tmp = _tmp ~scenario_dir in
  try
    _remove_dir tmp;
    _remove_dir (_old ~scenario_dir);
    Core_unix.mkdir_p tmp;
    _write_components ~dir:tmp ~identity state;
    before_commit ();
    _commit ~scenario_dir;
    Ok ()
  with e ->
    (try _remove_dir tmp with _ -> ());
    Status.error_internal
      (sprintf "checkpoint write failed in %s: %s" scenario_dir
         (Exn.to_string e))

(* ---- Load ---- *)

let _mismatch field ~expected ~found =
  Status.error_invalid_argument
    (sprintf "checkpoint refused: %s differs (checkpoint %s, this run %s)" field
       found expected)

let _check field ~to_string ~expected ~found =
  if String.equal (to_string expected) (to_string found) then Ok ()
  else _mismatch field ~expected:(to_string expected) ~found:(to_string found)

let _validate_header (h : header) ~(expect : identity) =
  let open Result.Let_syntax in
  let str = Fn.id and opt = Option.value ~default:"<unset>" in
  let%bind () =
    _check "checkpoint version" ~to_string:Int.to_string ~expected:version
      ~found:h.version
  in
  let%bind () =
    _check "config digest" ~to_string:str ~expected:expect.config_digest
      ~found:h.identity.config_digest
  in
  let%bind () =
    _check "build sha" ~to_string:str ~expected:expect.build_sha
      ~found:h.identity.build_sha
  in
  let%bind () =
    _check "snapshot manifest digest" ~to_string:str
      ~expected:expect.manifest_digest ~found:h.identity.manifest_digest
  in
  _check "TRADING_PATH_SEED_SALT" ~to_string:opt ~expected:expect.seed_salt
    ~found:h.identity.seed_salt

let _read_candidates ~dir =
  if Sys_unix.file_exists_exn (Filename.concat dir "candidates.sexp") then
    Result.map
      (_read_as ~dir "candidates.sexp" Candidate_log.snapshot_of_sexp)
      ~f:Option.some
  else Ok None

let _read_state ~dir ~(header : header) =
  let open Result.Let_syntax in
  let%bind simulator =
    _read_as ~dir "simulator.sexp" Sim.Checkpoint.snapshot_of_sexp
  in
  let%bind steps =
    Step_journal.read
      ~path:(Filename.concat dir Step_journal.file_name)
      ~n_steps:header.n_steps
  in
  let%bind strategy =
    _read_as ~dir "strategy.sexp" Strategy_state.snapshot_of_sexp
  in
  let%bind stop_log = _read_as ~dir "stop_log.sexp" Stop_log.snapshot_of_sexp in
  let%bind trade_audit =
    _read_as ~dir "trade_audit.sexp" Trade_audit.snapshot_of_sexp
  in
  let%bind force_liquidation_log =
    _read_as ~dir "force_liquidation_log.sexp"
      Force_liquidation_log.snapshot_of_sexp
  in
  let%map candidate_log = _read_candidates ~dir in
  {
    simulator = { simulator with steps };
    strategy;
    stop_log;
    trade_audit;
    force_liquidation_log;
    candidate_log;
  }

let load ~scenario_dir ~expect =
  let open Result.Let_syntax in
  let dir = _final ~scenario_dir in
  if not (Sys_unix.file_exists_exn dir) then
    Status.error_not_found (sprintf "no checkpoint at %s" dir)
  else
    let%bind header = _read_as ~dir "header.sexp" header_of_sexp in
    let%bind () = _validate_header header ~expect in
    let%map state = _read_state ~dir ~header in
    (header, state)

(* ---- Friday hook ---- *)

type request = {
  scenario_dir : string;
  every_n_fridays : int;
  resume : bool;
  halt_after_checkpoints : int option;
}

let _capture ~strategy_state ~stop_log ~trade_audit ~force_liquidation_log
    ~candidate_log sim =
  {
    simulator = Sim.Checkpoint.capture sim;
    strategy = Strategy_state.capture strategy_state;
    stop_log = Stop_log.capture stop_log;
    trade_audit = Trade_audit.capture trade_audit;
    force_liquidation_log = Force_liquidation_log.capture force_liquidation_log;
    candidate_log = Option.map candidate_log ~f:Candidate_log.capture;
  }

let _write_or_warn ~scenario_dir ~identity ~date state =
  match write ~scenario_dir ~identity state with
  | Ok () -> true
  | Error e ->
      eprintf "WARNING: checkpoint at %s not written: %s\n"
        (Date.to_string date) (Status.show e);
      false

let _halt_exit_code = 75

(* Test-only pause: leave the process once [halt_after_checkpoints] checkpoints
   are on disk. *)
let _halt_if_due ~request ~written =
  match request.halt_after_checkpoints with
  | Some k when written >= k ->
      eprintf "Backtest_checkpoint: halting after %d checkpoint(s)\n%!" written;
      Stdlib.exit _halt_exit_code
  | _ -> ()

let friday_hook ~request ~identity ~strategy_state ~stop_log ~trade_audit
    ~force_liquidation_log ~candidate_log =
  let fridays = ref 0 and written = ref 0 in
  fun ~date sim ->
    Int.incr fridays;
    if !fridays % request.every_n_fridays = 0 then
      let state =
        _capture ~strategy_state ~stop_log ~trade_audit ~force_liquidation_log
          ~candidate_log sim
      in
      if _write_or_warn ~scenario_dir:request.scenario_dir ~identity ~date state
      then (
        Int.incr written;
        _halt_if_due ~request ~written:!written)

let _expected_identity ~run_key ~manifest =
  identity_of ~run_key ~manifest
    ~seed_salt:(Sys.getenv "TRADING_PATH_SEED_SALT")

let load_for_resume ~request ~run_key ~manifest =
  load ~scenario_dir:request.scenario_dir
    ~expect:(_expected_identity ~run_key ~manifest)

let _setup_armed ~resumed ~request ~run_key ~manifest ~stop_log ~trade_audit
    ~force_liquidation_log ~candidate_log () =
  let state =
    match (resumed : state option) with
    | Some s -> Strategy_state.restore s.strategy
    | None -> Strategy_state.init ~initial_stop_states:String.Map.empty
  in
  let identity = _expected_identity ~run_key ~manifest in
  let hook =
    friday_hook ~request ~identity ~strategy_state:state ~stop_log ~trade_audit
      ~force_liquidation_log ~candidate_log
  in
  (Some state, Some hook)

let setup ~resumed ~request ~weinstein ~run_key ~manifest ~stop_log ~trade_audit
    ~force_liquidation_log ~candidate_log =
  match request with
  | None -> (None, None)
  | Some _ when not weinstein ->
      failwith
        "Backtest_checkpoint: checkpointing supports the Weinstein strategy"
  | Some request ->
      _setup_armed ~resumed ~request ~run_key ~manifest ~stop_log ~trade_audit
        ~force_liquidation_log ~candidate_log ()
