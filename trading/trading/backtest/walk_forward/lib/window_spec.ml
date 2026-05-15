open Core
module Scenario = Scenario_lib.Scenario

type rolling_spec = {
  start_date : Date.t;
  end_date : Date.t;
  train_days : int;
  test_days : int;
  step_days : int;
}
[@@deriving sexp]

type explicit_fold = {
  name : string;
  train_period : Scenario.period option;
  test_period : Scenario.period;
}
[@@deriving sexp]

type t = Rolling of rolling_spec | Explicit of explicit_fold list
[@@deriving sexp]

(** Sexp parser that accepts both the variant shape ([(Rolling ...)] /
    [(Explicit ...)]) and the legacy flat-record shape. The legacy shape is
    silently promoted to [Rolling] for backwards compatibility with in-tree spec
    files written before the variant was introduced. *)
let t_of_sexp_variant_form = t_of_sexp

let _is_variant_tagged = function
  | Sexp.List (Sexp.Atom ("Rolling" | "Explicit") :: _) -> true
  | _ -> false

let t_of_sexp sexp =
  if _is_variant_tagged sexp then t_of_sexp_variant_form sexp
  else Rolling (rolling_spec_of_sexp sexp)

type fold = {
  index : int;
  name : string;
  train_period : Scenario.period option;
  test_period : Scenario.period;
}
[@@deriving sexp]

(* ----- Rolling generator ----- *)

let _validate_rolling (spec : rolling_spec) =
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

let _build_rolling_fold ~index ~(spec : rolling_spec) ~anchor =
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

let _generate_rolling (spec : rolling_spec) =
  _validate_rolling spec;
  let rec loop ~index ~anchor acc =
    let candidate = _build_rolling_fold ~index ~spec ~anchor in
    if Date.( > ) candidate.test_period.end_date spec.end_date then List.rev acc
    else
      let next_anchor = Date.add_days anchor spec.step_days in
      loop ~index:(index + 1) ~anchor:next_anchor (candidate :: acc)
  in
  if Date.( > ) spec.start_date spec.end_date then []
  else loop ~index:0 ~anchor:spec.start_date []

(* ----- Explicit generator ----- *)

let _validate_explicit (folds : explicit_fold list) =
  if List.is_empty folds then
    failwith "WindowSpec.generate: Explicit folds list must be non-empty";
  let names = List.map folds ~f:(fun f -> f.name) in
  match List.find_a_dup names ~compare:String.compare with
  | Some dup ->
      failwith
        (sprintf "WindowSpec.generate: duplicate fold name in Explicit: %S" dup)
  | None -> ()

let _generate_explicit (folds : explicit_fold list) =
  _validate_explicit folds;
  List.mapi folds ~f:(fun index (ef : explicit_fold) ->
      {
        index;
        name = ef.name;
        train_period = ef.train_period;
        test_period = ef.test_period;
      })

let generate = function
  | Rolling spec -> _generate_rolling spec
  | Explicit folds -> _generate_explicit folds
