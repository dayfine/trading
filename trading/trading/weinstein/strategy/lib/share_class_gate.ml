open Core
open Weinstein_strategy_config
module Position = Trading_strategy.Position

let resolve_config ~data_dir (config : config) =
  if
    config.max_one_share_class_per_issuer
    && Share_class_map.is_empty config.share_class_groups
  then
    let path = Filename.concat data_dir Share_class_map.default_file_name in
    { config with share_class_groups = Share_class_map.load path }
  else config

let validate (config : config) =
  if
    config.max_one_share_class_per_issuer
    && Share_class_map.is_empty config.share_class_groups
  then
    failwith
      "max_one_share_class_per_issuer is on but share_class_groups is empty: \
       load the map (Share_class_gate.resolve_config) or set it in the spec"

type t = { map : Share_class_map.t; occupied : String.Set.t ref }

(* A long the book still has a stake in: anything not yet [Closed]. The match
   is exhaustive so a new position state forces this decision to be revisited. *)
let _open_long_symbol (p : Position.t) =
  match (p.side, p.state) with
  | Trading_base.Types.Short, _ -> None
  | Trading_base.Types.Long, (Entering _ | Holding _ | Exiting _) ->
      Some p.symbol
  | Trading_base.Types.Long, Closed _ -> None

let create ~(config : config) ~(portfolio : Trading_strategy.Portfolio_view.t)
    ~suspended_held =
  if not config.max_one_share_class_per_issuer then None
  else
    let map = config.share_class_groups in
    let open_longs =
      List.filter_map (Map.data portfolio.positions) ~f:_open_long_symbol
    in
    let occupied =
      List.filter_map
        (open_longs @ suspended_held)
        ~f:(Share_class_map.group_of map)
      |> String.Set.of_list
    in
    Some { map; occupied = ref occupied }

(* The group the rule must check for [c], or [None] when the rule does not
   apply: a short, an already-held symbol (left to [Already_held]), or an
   unmapped symbol. *)
let _group_to_check t ~held_set (c : Screener.scored_candidate) =
  match c.side with
  | Trading_base.Types.Short -> None
  | Trading_base.Types.Long ->
      if Set.mem held_set c.ticker then None
      else Share_class_map.group_of t.map c.ticker

let _occupy_if_kept t group (d : Entry_audit_capture.candidate_decision) =
  match d with
  | Kept _ -> t.occupied := Set.add !(t.occupied) group
  | Skipped _ -> ()

let _classify_with t ~held_set c ~decide :
    Entry_audit_capture.candidate_decision =
  match _group_to_check t ~held_set c with
  | None -> decide ()
  | Some group when Set.mem !(t.occupied) group ->
      Skipped Audit_recorder.Share_class_held
  | Some group ->
      let d = decide () in
      _occupy_if_kept t group d;
      d

let classify gate ~held_set c ~decide =
  match gate with
  | None -> decide ()
  | Some t -> _classify_with t ~held_set c ~decide
