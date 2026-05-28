open Core
open Weinstein_types

type variant = Long_only | Long_short [@@deriving show, eq]

type action = Enter_long | Exit_long | Enter_short | Exit_short | Hold
[@@deriving show, eq]

(* Stage payloads (weeks_in_base, weeks_advancing, etc.) are not relevant for
   the diagnostic — only the discriminant matters. Strip to a small helper to
   keep the match arms terse. *)
let _stage_kind = function
  | Stage1 _ -> 1
  | Stage2 _ -> 2
  | Stage3 _ -> 3
  | Stage4 _ -> 4

let _long_only_action ~prev_kind ~curr_kind =
  match (prev_kind, curr_kind) with
  | 1, 2 -> Enter_long
  | 2, 3 -> Exit_long
  | _ -> Hold

let _long_short_action ~prev_kind ~curr_kind =
  match (prev_kind, curr_kind) with
  | 1, 2 -> Enter_long
  | 2, 3 -> Exit_long
  | 3, 4 -> Enter_short
  | 4, 1 -> Exit_short
  | _ -> Hold

let action_of_transition ~variant ~prev_stage ~curr_stage =
  match prev_stage with
  | None -> Hold
  | Some prev -> (
      let prev_kind = _stage_kind prev in
      let curr_kind = _stage_kind curr_stage in
      if prev_kind = curr_kind then Hold
      else
        match variant with
        | Long_only -> _long_only_action ~prev_kind ~curr_kind
        | Long_short -> _long_short_action ~prev_kind ~curr_kind)
