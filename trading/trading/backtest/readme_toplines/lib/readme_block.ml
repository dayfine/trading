open Core

let _is_marker target line = String.equal (String.strip line) target

let render_between ~start_marker ~end_marker body =
  String.concat ~sep:"\n" [ start_marker; body; end_marker ]

(* Given the document [lines], the start-marker index, and the slice of lines
   after the start marker, locate the end marker and return [(before, after)].
   Raises when the start marker has no matching end marker. *)
let _split_at_markers lines ~start_idx ~after_start ~end_marker =
  match List.findi after_start ~f:(fun _ l -> _is_marker end_marker l) with
  | None ->
      raise
        (Invalid_argument
           "Readme_block.upsert: start marker has no matching end marker")
  | Some (rel_end_idx, _) ->
      let before = List.take lines start_idx in
      let after = List.drop after_start (rel_end_idx + 1) in
      (before, after)

(* Split [document] into [(before, after)] around the marker region, where
   [before] is everything strictly before the start-marker line and [after] is
   everything strictly after the end-marker line. [None] when there is no
   start marker. Raises when the start marker has no matching end marker. *)
let _split_around_region document ~start_marker ~end_marker =
  let lines = String.split_lines document in
  match List.findi lines ~f:(fun _ l -> _is_marker start_marker l) with
  | None -> None
  | Some (start_idx, _) ->
      let after_start = List.drop lines (start_idx + 1) in
      Some (_split_at_markers lines ~start_idx ~after_start ~end_marker)

let _join_lines lines =
  match lines with [] -> "" | _ -> String.concat ~sep:"\n" lines

let upsert_between ~start_marker ~end_marker ~document ~block =
  match _split_around_region document ~start_marker ~end_marker with
  | Some (before, after) ->
      _join_lines (before @ String.split_lines block @ after)
  | None ->
      if String.is_empty document then block
      else if String.is_suffix document ~suffix:"\n" then
        document ^ "\n" ^ block
      else document ^ "\n\n" ^ block

(* ----- the light-reference top-line block (default markers) ----- *)

let start_marker = "<!-- toplines:start -->"
let end_marker = "<!-- toplines:end -->"
let render body = render_between ~start_marker ~end_marker body

let upsert ~document ~block =
  upsert_between ~start_marker ~end_marker ~document ~block
