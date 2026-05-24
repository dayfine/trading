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

type tier = { name : string; fold_count : int; horizon_days : int }
[@@deriving sexp]

type tiered_spec = {
  start_date : Date.t;
  end_date : Date.t;
  train_days : int;
  tiers : tier list;
}
[@@deriving sexp]

type t =
  | Rolling of rolling_spec
  | Explicit of explicit_fold list
  | Tiered of tiered_spec
[@@deriving sexp]

(** Sexp parser that accepts both the variant shape ([(Rolling ...)] /
    [(Explicit ...)]) and the legacy flat-record shape. The legacy shape is
    silently promoted to [Rolling] for backwards compatibility with in-tree spec
    files written before the variant was introduced. *)
let t_of_sexp_variant_form = t_of_sexp

let _is_variant_tagged = function
  | Sexp.List (Sexp.Atom ("Rolling" | "Explicit" | "Tiered") :: _) -> true
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

(* ----- Tiered generator ----- *)

let _validate_tier (tier : tier) =
  if tier.fold_count < 1 then
    failwith
      (sprintf "WindowSpec.generate: tier %S fold_count must be >= 1, got %d"
         tier.name tier.fold_count);
  if tier.horizon_days <= 0 then
    failwith
      (sprintf "WindowSpec.generate: tier %S horizon_days must be > 0, got %d"
         tier.name tier.horizon_days)

let _validate_tiered (spec : tiered_spec) =
  if spec.train_days < 0 then
    failwith
      (sprintf "WindowSpec.generate: Tiered train_days must be >= 0, got %d"
         spec.train_days);
  if List.is_empty spec.tiers then
    failwith "WindowSpec.generate: Tiered tiers list must be non-empty";
  let names = List.map spec.tiers ~f:(fun t -> t.name) in
  (match List.find_a_dup names ~compare:String.compare with
  | Some dup ->
      failwith
        (sprintf "WindowSpec.generate: duplicate tier name in Tiered: %S" dup)
  | None -> ());
  List.iter spec.tiers ~f:_validate_tier

let _tier_fold_name tier_name within_index =
  sprintf "%s-%03d" tier_name within_index

let _build_tier_fold ~global_index ~within_index ~(tier : tier)
    ~(spec : tiered_spec) =
  (* Tier-local anchor: within-tier fold k starts horizon_days * k after the
     tier's first anchor (start_date). The train_period spans the [train_days]
     preceding the test window; the test window spans exactly [horizon_days]. *)
  let test_start =
    Date.add_days spec.start_date
      ((within_index * tier.horizon_days) + spec.train_days)
  in
  let test_end = Date.add_days test_start (tier.horizon_days - 1) in
  let train_period =
    if spec.train_days = 0 then None
    else
      let train_start = Date.add_days test_start (-spec.train_days) in
      let train_end = Date.add_days test_start (-1) in
      Some
        ({ start_date = train_start; end_date = train_end } : Scenario.period)
  in
  let test_period : Scenario.period =
    { start_date = test_start; end_date = test_end }
  in
  {
    index = global_index;
    name = _tier_fold_name tier.name within_index;
    train_period;
    test_period;
  }

let _generate_tier ~start_global_index ~(tier : tier) ~(spec : tiered_spec) =
  let folds =
    List.init tier.fold_count ~f:(fun within_index ->
        _build_tier_fold
          ~global_index:(start_global_index + within_index)
          ~within_index ~tier ~spec)
  in
  let last = List.last_exn folds in
  if Date.( > ) last.test_period.end_date spec.end_date then
    failwith
      (sprintf
         "WindowSpec.generate: tier %S overflows date range (last test ends %s \
          > end_date %s)"
         tier.name
         (Date.to_string last.test_period.end_date)
         (Date.to_string spec.end_date));
  folds

let _generate_tiered (spec : tiered_spec) =
  _validate_tiered spec;
  let _, all =
    List.fold spec.tiers ~init:(0, []) ~f:(fun (next_index, acc) tier ->
        let folds = _generate_tier ~start_global_index:next_index ~tier ~spec in
        (next_index + List.length folds, acc @ folds))
  in
  all

let generate = function
  | Rolling spec -> _generate_rolling spec
  | Explicit folds -> _generate_explicit folds
  | Tiered spec -> _generate_tiered spec
