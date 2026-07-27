open Core

let gutter = 112.0
let inset = 6.0
let baseline_offset = 3.5

(* Minimum vertical distance between two adjacent baselines. *)
let _min_gap = 12.0

type placement = { cls : string; text : string; y : float }

(* Fixed precision keeps the output byte-deterministic, as in {!Svg_chart}. *)
let _c v = Printf.sprintf "%.1f" v

(* Push each baseline down until it clears the one above it by [_min_gap].
   Input must be sorted by [y] ascending; output preserves that order. *)
let _nudge_down placed =
  List.folding_map placed ~init:Float.neg_infinity ~f:(fun prev (idx, p) ->
      let y = Float.max p.y (prev +. _min_gap) in
      (y, (idx, { p with y })))

let _text ~x p =
  Printf.sprintf "<text class=\"%s\" x=\"%s\" y=\"%s\">%s</text>" p.cls x
    (_c p.y) (Html_page.escape p.text)

let render ~x placements =
  let x = _c x in
  List.mapi placements ~f:(fun i p -> (i, p))
  |> List.sort ~compare:(fun (_, a) (_, b) -> Float.compare a.y b.y)
  |> _nudge_down
  |> List.sort ~compare:(fun (a, _) (b, _) -> Int.compare a b)
  |> List.map ~f:(fun (_, p) -> _text ~x p)
