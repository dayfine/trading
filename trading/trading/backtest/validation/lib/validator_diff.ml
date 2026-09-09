open Core
module Vt = Validator_types

type severity_filter = Invariant_only | All_checks
type labeled_report = { label : string; report : Vt.report }
type check_row = { id : string; counts : (string * int) list; agreed : bool }

type specimen_delta = {
  check_id : string;
  specimen : Vt.specimen;
  present_in : string list;
}

type t = { rows : check_row list; specimen_deltas : specimen_delta list }

let _min_reports = 2

let _lookup (lr : labeled_report) id =
  List.find lr.report.checks ~f:(fun (c : Vt.check_result) ->
      String.equal c.id id)

let _ids_in_order reports =
  List.concat_map reports ~f:(fun lr ->
      List.map lr.report.checks ~f:(fun (c : Vt.check_result) -> c.id))
  |> List.stable_dedup ~compare:String.compare

let _is_invariant_anywhere reports id =
  List.exists reports ~f:(fun lr ->
      match _lookup lr id with
      | None -> false
      | Some c -> Vt.equal_severity c.severity Vt.Invariant)

(* An explicit [check_ids] is the selection; otherwise every id in any report,
   narrowed by severity. *)
let _selected_ids reports ~check_ids ~severity =
  match check_ids with
  | _ :: _ -> check_ids
  | [] -> (
      let ids = _ids_in_order reports in
      match severity with
      | All_checks -> ids
      | Invariant_only ->
          List.filter ids ~f:(fun id -> _is_invariant_anywhere reports id))

let _missing_check_error label id =
  Status.not_found_error
    (sprintf
       "report %S has no check %s; the two runs ran different check sets and \
        cannot be diffed"
       label id)

let _count_in id (lr : labeled_report) =
  match _lookup lr id with
  | None -> Error (_missing_check_error lr.label id)
  | Some c -> Ok (lr.label, c.n_violations)

let _counts_for reports id = List.map reports ~f:(_count_in id) |> Result.all

let _all_equal counts =
  match counts with
  | [] -> true
  | (_, first) :: rest -> List.for_all rest ~f:(fun (_, n) -> n = first)

let _row_for reports id =
  Result.map (_counts_for reports id) ~f:(fun counts ->
      { id; counts; agreed = _all_equal counts })

let _compare_specimen (a : Vt.specimen) (b : Vt.specimen) =
  [%compare: string * string * string]
    (a.symbol, a.entry_date, a.detail)
    (b.symbol, b.entry_date, b.detail)

let _labelled_specimens reports id =
  List.concat_map reports ~f:(fun lr ->
      match _lookup lr id with
      | None -> []
      | Some c -> List.map c.specimens ~f:(fun s -> (lr.label, s)))

let _labels_holding pairs specimen =
  List.filter_map pairs ~f:(fun (label, s) ->
      if _compare_specimen s specimen = 0 then Some label else None)
  |> List.stable_dedup ~compare:String.compare

(* A specimen is a delta when it is absent from at least one report. *)
let _delta_of pairs ~n_reports ~check_id specimen =
  let present_in = _labels_holding pairs specimen in
  if List.length present_in = n_reports then None
  else Some { check_id; specimen; present_in }

let _deltas_for reports id =
  let pairs = _labelled_specimens reports id in
  let n_reports = List.length reports in
  List.map pairs ~f:snd
  |> List.stable_dedup ~compare:_compare_specimen
  |> List.filter_map ~f:(_delta_of pairs ~n_reports ~check_id:id)

let _too_few_reports_error reports =
  Status.invalid_argument_error
    (sprintf "need at least %d reports to diff, got %d" _min_reports
       (List.length reports))

let _empty_selection_error =
  Status.invalid_argument_error "no checks selected; nothing would be compared"

let _build reports selected =
  let open Result.Let_syntax in
  let%map rows = List.map selected ~f:(_row_for reports) |> Result.all in
  let differing = List.filter rows ~f:(fun r -> not r.agreed) in
  let specimen_deltas =
    List.concat_map differing ~f:(fun r -> _deltas_for reports r.id)
  in
  { rows; specimen_deltas }

let compute ?(check_ids = []) ?(severity = Invariant_only) reports =
  let open Result.Let_syntax in
  let%bind () =
    Result.ok_if_true
      (List.length reports >= _min_reports)
      ~error:(_too_few_reports_error reports)
  in
  let selected = _selected_ids reports ~check_ids ~severity in
  let%bind () =
    Result.ok_if_true
      (not (List.is_empty selected))
      ~error:_empty_selection_error
  in
  _build reports selected

let agreed t = List.for_all t.rows ~f:(fun r -> r.agreed)

let _labels t =
  match t.rows with [] -> [] | r :: _ -> List.map r.counts ~f:fst

let _col_width t label =
  List.fold t.rows ~init:(String.length label) ~f:(fun acc r ->
      match List.Assoc.find r.counts label ~equal:String.equal with
      | None -> acc
      | Some n -> Int.max acc (String.length (Int.to_string n)))

let _id_width t =
  List.fold t.rows ~init:(String.length "check") ~f:(fun acc r ->
      Int.max acc (String.length r.id))

let _render_row ~id_width ~widths ~id ~cells ~verdict =
  let body =
    List.map2_exn widths cells ~f:(fun w c -> sprintf "%*s" w c)
    |> String.concat ~sep:" | "
  in
  sprintf "%-*s | %s | %s" id_width id body verdict

let _render_table t =
  let labels = _labels t in
  let widths = List.map labels ~f:(fun l -> _col_width t l) in
  let id_width = _id_width t in
  let header =
    _render_row ~id_width ~widths ~id:"check" ~cells:labels ~verdict:"verdict"
  in
  let body =
    List.map t.rows ~f:(fun r ->
        let cells = List.map r.counts ~f:(fun (_, n) -> Int.to_string n) in
        let verdict = if r.agreed then "agree" else "DIFFER" in
        _render_row ~id_width ~widths ~id:r.id ~cells ~verdict)
  in
  String.concat ~sep:"\n" (header :: body)

let _render_delta d =
  sprintf "  %s %s %s (%s) -- only in: %s" d.check_id d.specimen.symbol
    d.specimen.entry_date d.specimen.detail
    (String.concat ~sep:", " d.present_in)

let render t =
  let table = [ _render_table t ] in
  let deltas =
    if List.is_empty t.specimen_deltas then []
    else
      "" :: "specimens present in some reports but not all:"
      :: List.map t.specimen_deltas ~f:_render_delta
  in
  String.concat ~sep:"\n" (table @ deltas)
