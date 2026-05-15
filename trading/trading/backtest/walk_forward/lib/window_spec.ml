open Core
module Scenario = Scenario_lib.Scenario

type t = {
  start_date : Date.t;
  end_date : Date.t;
  train_days : int;
  test_days : int;
  step_days : int;
}
[@@deriving sexp]

type fold = {
  index : int;
  name : string;
  train_period : Scenario.period option;
  test_period : Scenario.period;
}
[@@deriving sexp]

let _validate spec =
  if spec.train_days < 0 then
    failwith
      (sprintf "WindowSpec.generate: train_days must be >= 0, got %d"
         spec.train_days);
  if spec.test_days <= 0 then
    failwith
      (sprintf "WindowSpec.generate: test_days must be > 0, got %d"
         spec.test_days);
  if spec.step_days <= 0 then
    failwith
      (sprintf "WindowSpec.generate: step_days must be > 0, got %d"
         spec.step_days)

let _fold_name index = sprintf "fold-%03d" index

let _build_fold ~index ~spec ~anchor =
  let train_start = anchor in
  let train_end = Date.add_days anchor (spec.train_days - 1) in
  let test_start = Date.add_days anchor spec.train_days in
  let test_end = Date.add_days test_start (spec.test_days - 1) in
  let train_period =
    if spec.train_days = 0 then None
    else
      Some
        ({ start_date = train_start; end_date = train_end } : Scenario.period)
  in
  let test_period : Scenario.period =
    { start_date = test_start; end_date = test_end }
  in
  { index; name = _fold_name index; train_period; test_period }

let generate spec =
  _validate spec;
  let rec loop ~index ~anchor acc =
    let candidate = _build_fold ~index ~spec ~anchor in
    if Date.( > ) candidate.test_period.end_date spec.end_date then List.rev acc
    else
      let next_anchor = Date.add_days anchor spec.step_days in
      loop ~index:(index + 1) ~anchor:next_anchor (candidate :: acc)
  in
  if Date.( > ) spec.start_date spec.end_date then []
  else loop ~index:0 ~anchor:spec.start_date []
