open Core

type config = { hysteresis_weeks : int; rs_window_weeks : int }
[@@deriving sexp]

let _default_hysteresis_weeks = 4
let _default_rs_window_weeks = 13

let default_config =
  {
    hysteresis_weeks = _default_hysteresis_weeks;
    rs_window_weeks = _default_rs_window_weeks;
  }

type decision = Hold | Laggard_exit of { rs_13w_neg_weeks : int }
[@@deriving show, eq]

(** Effective hysteresis floor: a non-positive [config.hysteresis_weeks] would
    otherwise short-circuit the detector. Treat any [<= 0] as [1] — a single
    negative-RS observation fires immediately. The default is positive (4). *)
let _effective_threshold ~config =
  if config.hysteresis_weeks <= 0 then 1 else config.hysteresis_weeks

let observe ~config ~prior_consecutive_neg_rs ~position_13w_return
    ~benchmark_13w_return =
  if Float.( < ) position_13w_return benchmark_13w_return then
    let new_count = prior_consecutive_neg_rs + 1 in
    let threshold = _effective_threshold ~config in
    let decision =
      if new_count >= threshold then
        Laggard_exit { rs_13w_neg_weeks = new_count }
      else Hold
    in
    (new_count, decision)
  else (0, Hold)

let observe_position ~config ~state ~symbol ~position_13w_return
    ~benchmark_13w_return =
  let prior_consecutive_neg_rs =
    Hashtbl.find state symbol |> Option.value ~default:0
  in
  let new_count, decision =
    observe ~config ~prior_consecutive_neg_rs ~position_13w_return
      ~benchmark_13w_return
  in
  Hashtbl.set state ~key:symbol ~data:new_count;
  decision
