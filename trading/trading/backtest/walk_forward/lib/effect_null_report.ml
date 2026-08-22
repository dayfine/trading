open Core

type metrics = (string * float) list [@@deriving sexp]

type run_context = {
  universe_size : int option;
  start_date : string option;
  end_date : string option;
}
[@@deriving sexp]

type context_check = Verified | Unverified of string | Mismatch of string
[@@deriving sexp]

type verdict = Pass | Inside_noise | Not_judged | No_null_band
[@@deriving sexp]

type metric_row = {
  metric : string;
  arm_values : float list;
  null_values : float list;
  paired_gaps : float list;
  mean_gap : float;
  null_band : float;
  ratio : float option;
  verdict : verdict;
}
[@@deriving sexp]

type report = { salt_count : int; rows : metric_row list; notes : string list }
[@@deriving sexp]

(* -------------- parsing -------------- *)

(** Only [(name numeric)] pairs are metrics; bookkeeping fields such as
    [(crashed false)] are not comparable and are dropped. *)
let _metric_of_pair = function
  | Sexp.List [ Sexp.Atom name; Sexp.Atom value ] ->
      Option.map (Float.of_string_opt value) ~f:(fun v -> (name, v))
  | _ -> None

let parse_metrics sexp =
  match sexp with
  | Sexp.List entries ->
      let metrics = List.filter_map entries ~f:_metric_of_pair in
      if List.is_empty metrics then
        Status.error_invalid_argument
          "no numeric (name value) metric pairs found in result sexp"
      else Ok metrics
  | Sexp.Atom _ ->
      Status.error_invalid_argument
        "expected a list of (name value) pairs, got a bare atom"

(** Top-level [(key value)] lookup over a flat sexp list. *)
let _field sexp key =
  match sexp with
  | Sexp.List entries ->
      List.find_map entries ~f:(function
        | Sexp.List (Sexp.Atom k :: [ v ]) when String.equal k key -> Some v
        | _ -> None)
  | Sexp.Atom _ -> None

let _atom = function Sexp.Atom a -> Some a | Sexp.List _ -> None

(** Top level in a [params.sexp]; nested in a spec's [(period ...)] block. *)
let _date sexp key =
  match Option.bind (_field sexp key) ~f:_atom with
  | Some d -> Some d
  | None ->
      Option.bind (_field sexp "period") ~f:(fun p ->
          Option.bind (_field p key) ~f:_atom)

let parse_context sexp =
  {
    universe_size =
      Option.bind (_field sexp "universe_size") ~f:(fun v ->
          Option.bind (_atom v) ~f:Int.of_string_opt);
    start_date = _date sexp "start_date";
    end_date = _date sexp "end_date";
  }

(* -------------- context compatibility -------------- *)

let _scale_warning =
  "a null does not transfer across scales or universes (see \
   .claude/rules/universe-discipline.md)"

let _field_diff ~name ~to_string a n =
  sprintf "%s differs: arm=%s null=%s" name (to_string a) (to_string n)

(** [None] = not comparable (absent on a side); [Some (Ok ())] = agreed. *)
let _compare_field ~name ~arm ~null ~to_string =
  match (arm, null) with
  | Some a, Some n when Poly.equal a n -> Some (Ok ())
  | Some a, Some n -> Some (Error (_field_diff ~name ~to_string a n))
  | _ -> None

let _unverified_message =
  "run context could not be verified: no universe_size / start_date / end_date \
   available on both sides"

let _comparisons ~arm ~null =
  List.filter_opt
    [
      _compare_field ~name:"universe_size" ~arm:arm.universe_size
        ~null:null.universe_size ~to_string:Int.to_string;
      _compare_field ~name:"start_date" ~arm:arm.start_date
        ~null:null.start_date ~to_string:Fn.id;
      _compare_field ~name:"end_date" ~arm:arm.end_date ~null:null.end_date
        ~to_string:Fn.id;
    ]

let check_context ~arm ~null =
  let comparisons = _comparisons ~arm ~null in
  let mismatches =
    List.filter_map comparisons ~f:(function
      | Error m -> Some m
      | Ok () -> None)
  in
  let joined = String.concat ~sep:"; " mismatches in
  if not (List.is_empty mismatches) then
    Mismatch (sprintf "%s; %s" joined _scale_warning)
  else if List.is_empty comparisons then Unverified _unverified_message
  else Verified

(* -------------- metric-set agreement -------------- *)

let _names metrics = List.map metrics ~f:fst

let _diff_part name = function
  | [] -> None
  | names -> Some (sprintf "%s %s" name (String.concat ~sep:"," names))

let _describe_metric_diff ~missing ~extra =
  [ _diff_part "missing" missing; _diff_part "extra" extra ]
  |> List.filter_opt |> String.concat ~sep:"; "

(** Names the difference rather than silently intersecting — a silent
    intersection is how a metric disappears from a verdict table. *)
let _check_same_metrics ~reference ~label metrics =
  let ref_names = String.Set.of_list (_names reference) in
  let got = String.Set.of_list (_names metrics) in
  let missing = Set.diff ref_names got |> Set.to_list in
  let extra = Set.diff got ref_names |> Set.to_list in
  if List.is_empty missing && List.is_empty extra then Ok ()
  else
    Status.error_invalid_argument
      (sprintf "%s has a different metric set: %s" label
         (_describe_metric_diff ~missing ~extra))

let _check_all_metric_sets ~arm ~null =
  match arm with
  | [] -> Status.error_invalid_argument "no arm result files given"
  | reference :: _ ->
      let labelled =
        List.mapi arm ~f:(fun i m -> (sprintf "arm[%d]" i, m))
        @ List.mapi null ~f:(fun i m -> (sprintf "null[%d]" i, m))
      in
      List.fold_result labelled ~init:() ~f:(fun () (label, metrics) ->
          _check_same_metrics ~reference ~label metrics)

(* -------------- band + verdict -------------- *)

let _mean xs =
  match xs with
  | [] -> Float.nan
  | _ -> List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int (List.length xs)

let min_pairs_for_a_band = 2

(** The null's own salt-to-salt spread [max - min] — for a scalar set exactly
    the largest pairwise |gap|. [nan], never [0.0], below
    {!min_pairs_for_a_band} values. *)
let _band values =
  match
    ( List.max_elt values ~compare:Float.compare,
      List.min_elt values ~compare:Float.compare )
  with
  | Some hi, Some lo when List.length values >= min_pairs_for_a_band -> hi -. lo
  | _ -> Float.nan

(** One pair, or salts whose null values are identical, both mean the salt axis
    moved the null by nothing: the noise floor is unmeasured, not zero. *)
let _band_is_measured ~band ~salt_count =
  salt_count >= min_pairs_for_a_band
  && Float.is_finite band && Float.( > ) band 0.0

(** Rule 4 proper: same direction on every pair, and every |gap| above band. *)
let _clears_the_band ~gaps ~band =
  let all_positive = List.for_all gaps ~f:(fun g -> Float.( > ) g 0.0) in
  let all_negative = List.for_all gaps ~f:(fun g -> Float.( < ) g 0.0) in
  let all_above =
    List.for_all gaps ~f:(fun g -> Float.( > ) (Float.abs g) band)
  in
  (all_positive || all_negative) && all_above

(** The band check precedes the effect check: calling an unmeasured band a PASS
    is the overclaim this tool exists to prevent. *)
let _verdict ~directionless ~gaps ~band ~salt_count =
  if directionless then Not_judged
  else if not (_band_is_measured ~band ~salt_count) then No_null_band
  else if _clears_the_band ~gaps ~band then Pass
  else Inside_noise

let _value_of metric m =
  List.Assoc.find m metric ~equal:String.equal
  |> Option.value ~default:Float.nan

let _ratio ~mean_gap ~null_band =
  if Float.is_finite null_band && Float.( > ) null_band 0.0 then
    Some (Float.abs mean_gap /. null_band)
  else None

let _row ~directionless ~arm ~null ~salt_count metric =
  let arm_values = List.map arm ~f:(_value_of metric) in
  let null_values = List.map null ~f:(_value_of metric) in
  let paired_gaps = List.map2_exn arm_values null_values ~f:( -. ) in
  let mean_gap = _mean paired_gaps in
  let null_band = _band null_values in
  {
    metric;
    arm_values;
    null_values;
    paired_gaps;
    mean_gap;
    null_band;
    ratio = _ratio ~mean_gap ~null_band;
    verdict =
      _verdict ~directionless ~gaps:paired_gaps ~band:null_band ~salt_count;
  }

let _rows ~arm ~null ~no_direction =
  let directionless = String.Set.of_list no_direction in
  let salt_count = List.length arm in
  let row metric =
    _row
      ~directionless:(Set.mem directionless metric)
      ~arm ~null ~salt_count metric
  in
  List.map (_names (List.hd_exn arm)) ~f:row

let _count_mismatch ~arm ~null =
  Status.error_invalid_argument
    (sprintf
       "arm/null are paired by position, so the counts must match: %d arm \
        file(s) vs %d null file(s)"
       (List.length arm) (List.length null))

let _assemble ~arm ~null ~no_direction () =
  {
    salt_count = List.length arm;
    rows = _rows ~arm ~null ~no_direction;
    notes = [];
  }

let build ~arm ~null ~no_direction =
  if List.is_empty arm || List.is_empty null then
    Status.error_invalid_argument
      "both --arm and --null need at least one result file"
  else if List.length arm <> List.length null then _count_mismatch ~arm ~null
  else
    Result.map
      (_check_all_metric_sets ~arm ~null)
      ~f:(_assemble ~arm ~null ~no_direction)
