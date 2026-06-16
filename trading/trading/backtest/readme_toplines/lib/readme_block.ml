open Core

let start_marker = "<!-- toplines:start -->"
let end_marker = "<!-- toplines:end -->"
let render body = String.concat ~sep:"\n" [ start_marker; body; end_marker ]
let _is_marker target line = String.equal (String.strip line) target

(* Given the document [lines], the start-marker index, and the slice of lines
   after the start marker, locate the end marker and return [(before, after)].
   Raises when the start marker has no matching end marker. *)
let _split_at_markers lines ~start_idx ~after_start =
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
let _split_around_region document =
  let lines = String.split_lines document in
  match List.findi lines ~f:(fun _ l -> _is_marker start_marker l) with
  | None -> None
  | Some (start_idx, _) ->
      let after_start = List.drop lines (start_idx + 1) in
      Some (_split_at_markers lines ~start_idx ~after_start)

let _join_lines lines =
  match lines with [] -> "" | _ -> String.concat ~sep:"\n" lines

let upsert ~document ~block =
  match _split_around_region document with
  | Some (before, after) ->
      _join_lines (before @ String.split_lines block @ after)
  | None ->
      if String.is_empty document then block
      else if String.is_suffix document ~suffix:"\n" then
        document ^ "\n" ^ block
      else document ^ "\n\n" ^ block
