open Core

type level_kind = Entry | Stop | Reference
type level = { label : string; price : float; kind : level_kind }

let default_width = 260
let default_height = 80
let max_bars = 90

(* Geometry constants, in viewBox units. *)
let _pad = 4.0
let _volume_strip_height = 18.0

(* Vertical gap between the price panel and the volume strip. *)
let _panel_gap = 3.0

(* Fraction of its x-slot a volume rect occupies — the remainder is the gap
   between adjacent bars. *)
let _volume_bar_fill = 0.7
let _min_volume_bar_width = 1.0

(* Padding applied to each side of a degenerate (zero-width) price domain, in
   price units. Keeps every derived coordinate finite. *)
let _flat_domain_pad = 1.0

(* A single point is not a chart — see [render]'s [None] contract. *)
let _min_bars = 2

(* Plot box plus the price domain it maps. All rendering is expressed against
   this so no coordinate formula is written twice. *)
type _geom = {
  x0 : float;
  plot_w : float;
  price_y0 : float;
  price_h : float;
  vol_y0 : float;
  vol_h : float;
  slot : float;  (** Horizontal width of one bar's column. *)
  lo : float;  (** Bottom of the price domain. *)
  span : float;  (** Domain width; strictly positive. *)
  n : int;  (** Number of bars drawn. *)
}

let _geometry ~width ~height ~lo ~span ~n =
  let w = Float.of_int width and h = Float.of_int height in
  let price_h = h -. (2.0 *. _pad) -. _panel_gap -. _volume_strip_height in
  let plot_w = w -. (2.0 *. _pad) in
  {
    x0 = _pad;
    plot_w;
    price_y0 = _pad;
    price_h;
    vol_y0 = _pad +. price_h +. _panel_gap;
    vol_h = _volume_strip_height;
    slot = plot_w /. Float.of_int n;
    lo;
    span;
    n;
  }

(* x of bar [i] — the centre of its column. Column-centred (rather than
   edge-to-edge) placement is what keeps the outermost volume rects inside the
   viewBox instead of half-clipped at each end. *)
let _bar_x g i = g.x0 +. ((Float.of_int i +. 0.5) *. g.slot)

(* y of a price: domain bottom maps to the bottom of the price panel. *)
let _price_y g p = g.price_y0 +. (g.price_h *. (1.0 -. ((p -. g.lo) /. g.span)))

(* Fixed precision keeps [render] byte-deterministic. *)
let _c v = Printf.sprintf "%.1f" v

(* Price domain: the union of every bar's high and low, every level price, and
   both band bounds — so a level outside the visible price range is still drawn
   inside the viewBox rather than clipped away. A zero-width domain (flat
   series, single price) is padded so [span] is never zero. *)
let _domain ~bars ~levels ~band =
  let of_bar (b : Types.Daily_price.t) = [ b.high_price; b.low_price ] in
  let of_band = match band with None -> [] | Some (a, b) -> [ a; b ] in
  let prices =
    List.concat_map bars ~f:of_bar
    @ List.map levels ~f:(fun l -> l.price)
    @ of_band
  in
  let lo = List.reduce_exn prices ~f:Float.min in
  let hi = List.reduce_exn prices ~f:Float.max in
  if Float.( <= ) (hi -. lo) 0.0 then
    (lo -. _flat_domain_pad, 2.0 *. _flat_domain_pad)
  else (lo, hi -. lo)

let _rect ~cls ~x ~y ~w ~h =
  Printf.sprintf
    "<rect class=\"%s\" x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\"/>" cls
    (_c x) (_c y) (_c w) (_c h)

(* Shaded region between two prices, spanning the full plot width. *)
let _band_rect g (a, b) =
  let y_top = _price_y g (Float.max a b) in
  let y_bot = _price_y g (Float.min a b) in
  _rect ~cls:"band" ~x:g.x0 ~y:y_top ~w:g.plot_w ~h:(y_bot -. y_top)

(* Volume strip: one rect per bar, height proportional to the window maximum.
   An all-zero (or missing) volume column yields no rects rather than a row of
   zero-height artifacts. *)
let _volume_rects g bars =
  let vols = List.map bars ~f:(fun (b : Types.Daily_price.t) -> b.volume) in
  let vmax = List.fold vols ~init:0 ~f:Int.max in
  if vmax <= 0 then []
  else
    let bar_w = Float.max _min_volume_bar_width (g.slot *. _volume_bar_fill) in
    List.mapi vols ~f:(fun i v ->
        let frac = Float.of_int v /. Float.of_int vmax in
        let h = g.vol_h *. frac in
        _rect ~cls:"vol"
          ~x:(_bar_x g i -. (bar_w /. 2.0))
          ~y:(g.vol_y0 +. g.vol_h -. h)
          ~w:bar_w ~h)

let _price_polyline g bars =
  let point i (b : Types.Daily_price.t) =
    Printf.sprintf "%s,%s" (_c (_bar_x g i)) (_c (_price_y g b.close_price))
  in
  Printf.sprintf "<polyline class=\"px\" points=\"%s\"/>"
    (String.concat ~sep:" " (List.mapi bars ~f:point))

let _level_class = function
  | Entry -> "lvl lvl-entry"
  | Stop -> "lvl lvl-stop"
  | Reference -> "lvl lvl-ref"

let _level_line g l =
  let y = _c (_price_y g l.price) in
  Printf.sprintf
    "<line class=\"%s\" x1=\"%s\" y1=\"%s\" x2=\"%s\" \
     y2=\"%s\"><title>%s</title></line>"
    (_level_class l.kind) (_c g.x0) y
    (_c (g.x0 +. g.plot_w))
    y (Html_page.escape l.label)

(* Screen-reader summary: the mark count plus every level by name, so the chart
   is not information the page carries only visually. *)
let _aria_label ~n ~levels =
  let names = List.map levels ~f:(fun l -> l.label) in
  Printf.sprintf "price and volume sparkline, %d bars%s" n
    (match names with
    | [] -> ""
    | _ -> "; levels: " ^ String.concat ~sep:", " names)

let _svg ~width ~height ~aria ~children =
  Printf.sprintf
    "<svg class=\"spark\" viewBox=\"0 0 %d %d\" width=\"%d\" height=\"%d\" \
     role=\"img\" aria-label=\"%s\">%s</svg>"
    width height width height (Html_page.escape aria)
    (String.concat ~sep:"" children)

let render ?(width = default_width) ?(height = default_height) ?band ~bars
    ~levels () =
  let bars = List.drop bars (Int.max 0 (List.length bars - max_bars)) in
  let n = List.length bars in
  if n < _min_bars then None
  else
    let lo, span = _domain ~bars ~levels ~band in
    let g = _geometry ~width ~height ~lo ~span ~n in
    let band_children =
      match band with None -> [] | Some pair -> [ _band_rect g pair ]
    in
    let children =
      band_children @ _volume_rects g bars
      @ [ _price_polyline g bars ]
      @ List.map levels ~f:(_level_line g)
    in
    Some (_svg ~width ~height ~aria:(_aria_label ~n ~levels) ~children)
