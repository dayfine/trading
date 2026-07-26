open Core

module Config = struct
  type t = {
    enabled : bool;
    min_overlap_days : int;
    match_fraction : float;
    ret_epsilon : float;
    min_predecessor_bars : int;
    tail_window_trading_days : int;
    max_predecessor_tail_density : float;
    min_successor_tail_density : float;
  }
  [@@deriving sexp, eq]

  (* See [.mli] for the provenance of each default. *)
  let default =
    {
      enabled = false;
      min_overlap_days = 5;
      match_fraction = Twin_detector.Config.default.match_fraction;
      ret_epsilon = Twin_detector.Config.default.ret_epsilon;
      min_predecessor_bars = 60;
      tail_window_trading_days = 15;
      max_predecessor_tail_density = 0.5;
      min_successor_tail_density = 0.8;
    }

  let armed ~min_overlap_days ~match_fraction =
    {
      default with
      enabled = min_overlap_days > 0 && Float.( > ) match_fraction 0.0;
      min_overlap_days;
      match_fraction;
    }
end

type series = { symbol : string; closes : (Date.t * float) array }
[@@deriving sexp_of]

type rename = {
  old_symbol : string;
  new_symbol : string;
  changeover : Date.t;
  overlap_days : int;
  match_fraction : float;
  old_tail_bars : int;
  new_tail_bars : int;
  tail_window_trading_days : int;
}
[@@deriving sexp_of, eq]

type report = { config : Config.t; renames : rename list } [@@deriving sexp_of]

(* Two shared dates are the minimum that yields one comparable return, so an
   overlap requirement below this carries no returns evidence at all. Also the
   [min_overlap_days] handed to [Twin_detector], where it additionally sets the
   prefilter's anchor stride to 1 (exhaustive over a two-series input). *)
let _min_scorable_overlap_days = 2

(* A leg of a candidate pair: the series restricted to bars at or before the
   as-of date, plus the summary statistics the shape tests need. Kept separate
   from [series] so each statistic is computed once per symbol rather than once
   per pair. *)
type leg = {
  leg_symbol : string;
  leg_bars : (Date.t * float) array;
  leg_first : Date.t;
  leg_last : Date.t;
  leg_tail_bars : int;
}

(* The trailing [window] trading days ending at [as_of], drawn from the input's
   own date union — over a whole universe that union IS the trading calendar,
   which keeps this module free of any bar-reader dependency. *)
let _tail_dates ~as_of ~window series_list =
  let seen = Hash_set.create (module Date) in
  List.iter series_list ~f:(fun s ->
      Array.iter s.closes ~f:(fun (d, _) ->
          if Date.( <= ) d as_of then Hash_set.add seen d));
  let all = Hash_set.to_list seen |> List.sort ~compare:Date.compare in
  List.drop all (Int.max 0 (List.length all - window)) |> Date.Set.of_list

let _leg_of_series ~as_of ~tail_dates s =
  let bars = Array.filter s.closes ~f:(fun (d, _) -> Date.( <= ) d as_of) in
  if Array.is_empty bars then None
  else
    Some
      {
        leg_symbol = s.symbol;
        leg_bars = bars;
        leg_first = fst bars.(0);
        leg_last = fst bars.(Array.length bars - 1);
        leg_tail_bars = Array.count bars ~f:(fun (d, _) -> Set.mem tail_dates d);
      }

let _density ~window_days n =
  Float.of_int n /. Float.of_int (Int.max 1 window_days)

let _bars_before bars ~date =
  Array.count bars ~f:(fun (d, _) -> Date.( < ) d date)

(* Returns-basis similarity for one pair, delegated wholesale to
   [Twin_detector] so no similarity arithmetic is duplicated here. The
   [prefilter_rel_tol] is infinite because the input is exactly two series:
   every anchor-date run must contain both legs, so the prefilter can never
   drop a genuine match. [close_epsilon] is unused under [Returns]. *)
let _returns_score (config : Config.t) old_leg new_leg =
  let twin_config =
    {
      Twin_detector.Config.enabled = true;
      min_overlap_days = _min_scorable_overlap_days;
      match_fraction = config.match_fraction;
      close_epsilon = Twin_detector.Config.default.close_epsilon;
      basis = Twin_detector.Config.Returns;
      ret_epsilon = config.ret_epsilon;
      prefilter_rel_tol = Float.infinity;
    }
  in
  let twin_series l =
    {
      Twin_detector.symbol = l.leg_symbol;
      data_end = l.leg_last;
      closes = l.leg_bars;
    }
  in
  let report =
    Twin_detector.detect twin_config
      [ twin_series old_leg; twin_series new_leg ]
  in
  match report.groups with
  | [ { matches = [ m ]; _ } ] -> Some (m.overlap_days, m.match_fraction)
  | _ -> None

let _rename_of_score (config : Config.t) ~window_days old_leg new_leg
    (overlap_days, match_fraction) =
  if overlap_days < config.min_overlap_days then None
  else
    Some
      {
        old_symbol = old_leg.leg_symbol;
        new_symbol = new_leg.leg_symbol;
        changeover = new_leg.leg_first;
        overlap_days;
        match_fraction;
        old_tail_bars = old_leg.leg_tail_bars;
        new_tail_bars = new_leg.leg_tail_bars;
        tail_window_trading_days = window_days;
      }

(* The succession shape (S1/S2) plus the returns score (S4). The tail-density
   half of the handover (S3) is applied by [detect] when it splits the legs into
   the stale and fresh pools, so it is not re-tested here. *)
let _succession (config : Config.t) ~window_days old_leg new_leg =
  let changeover = new_leg.leg_first in
  if
    String.equal old_leg.leg_symbol new_leg.leg_symbol
    || Date.( <= ) changeover old_leg.leg_first
    || Date.( > ) changeover old_leg.leg_last
    || _bars_before old_leg.leg_bars ~date:changeover
       < config.min_predecessor_bars
  then None
  else
    Option.bind
      (_returns_score config old_leg new_leg)
      ~f:(_rename_of_score config ~window_days old_leg new_leg)

(* Higher match fraction wins; ties broken by the smaller successor symbol so
   the result is deterministic. *)
let _better a b =
  match Float.compare a.match_fraction b.match_fraction with
  | 0 -> String.compare a.new_symbol b.new_symbol < 0
  | c -> c > 0

(* One entry per predecessor, so [mapping] is a function. [Map.data] yields the
   entries sorted ascending by [old_symbol]. *)
let _best_per_predecessor renames =
  List.fold renames ~init:String.Map.empty ~f:(fun acc r ->
      Map.update acc r.old_symbol ~f:(function
        | None -> r
        | Some prev -> if _better r prev then r else prev))
  |> Map.data

let detect (config : Config.t) ~as_of series_list =
  if
    (not config.enabled) || config.min_overlap_days < _min_scorable_overlap_days
  then { config; renames = [] }
  else begin
    let tail_dates =
      _tail_dates ~as_of ~window:config.tail_window_trading_days series_list
    in
    let window_days = Set.length tail_dates in
    let legs =
      List.filter_map series_list ~f:(_leg_of_series ~as_of ~tail_dates)
    in
    let density l = _density ~window_days l.leg_tail_bars in
    let stale =
      List.filter legs ~f:(fun l ->
          Float.( <= ) (density l) config.max_predecessor_tail_density)
    in
    let fresh =
      List.filter legs ~f:(fun l ->
          Float.( >= ) (density l) config.min_successor_tail_density)
    in
    let renames =
      List.concat_map stale ~f:(fun old_leg ->
          List.filter_map fresh ~f:(_succession config ~window_days old_leg))
      |> _best_per_predecessor
    in
    { config; renames }
  end

let mapping report =
  List.map report.renames ~f:(fun r -> (r.old_symbol, r.new_symbol))

let survivors report ~all_symbols =
  let dropped =
    List.map report.renames ~f:(fun r -> r.old_symbol) |> String.Set.of_list
  in
  List.filter all_symbols ~f:(fun s -> not (Set.mem dropped s))

let _describe r =
  Printf.sprintf
    "%s -> %s (changeover %s, overlap %dd, returns match %.4f, tail bars %d/%d \
     -> %d/%d)"
    r.old_symbol r.new_symbol
    (Date.to_string r.changeover)
    r.overlap_days r.match_fraction r.old_tail_bars r.tail_window_trading_days
    r.new_tail_bars r.tail_window_trading_days

let warnings report =
  List.map report.renames ~f:(fun r ->
      Printf.sprintf
        "rename detected: %s; %s dropped from candidate consideration — screen \
         %s instead"
        (_describe r) r.old_symbol r.new_symbol)

let render report =
  let c = report.config in
  let header =
    Printf.sprintf
      "rename-succession report: enabled=%b min_overlap_days=%d \
       match_fraction=%.4f ret_epsilon=%.6g min_predecessor_bars=%d \
       tail_window_trading_days=%d\n\
       %d succession(s)"
      c.enabled c.min_overlap_days c.match_fraction c.ret_epsilon
      c.min_predecessor_bars c.tail_window_trading_days
      (List.length report.renames)
  in
  String.concat ~sep:"\n"
    (header :: List.map report.renames ~f:(fun r -> "  " ^ _describe r))
