open Core

type level_kind = Entry | Stop | Reference
type level = { label : string; price : float; kind : level_kind }

let default_width = 260
let default_height = 80
let max_bars = 90

(* Geometry constants, in viewBox units. *)
let _pad = 4.0
let _volume_strip_height = 18.0

(* Radius of the last-close marker. *)
let _marker_radius = 3.5

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

let _geometry ~width ~height ~lo ~span ~n ~gutter =
  let w = Float.of_int width and h = Float.of_int height in
  let price_h = h -. (2.0 *. _pad) -. _panel_gap -. _volume_strip_height in
  let plot_w = w -. (2.0 *. _pad) -. gutter in
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
let _domain ~bars ~levels ~band ~extra =
  let of_bar (b : Types.Daily_price.t) = [ b.high_price; b.low_price ] in
  let of_band = match band with None -> [] | Some (a, b) -> [ a; b ] in
  let prices =
    List.concat_map bars ~f:of_bar
    @ List.map levels ~f:(fun l -> l.price)
    @ of_band @ extra
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

(* Moving-average overlay across the same x-slots as the price line. Only the
   defined suffix is drawn — the leading [None]s (fewer than [period] closes
   behind them) have no value to plot. Fewer than two defined points is not a
   line, so nothing is emitted. *)
let _ma_polyline g values =
  let point i = function
    | None -> None
    | Some v ->
        Some (Printf.sprintf "%s,%s" (_c (_bar_x g i)) (_c (_price_y g v)))
  in
  match List.filter_mapi values ~f:point with
  | [] | [ _ ] -> []
  | points ->
      [
        Printf.sprintf "<polyline class=\"ma\" points=\"%s\"/>"
          (String.concat ~sep:" " points);
      ]

(* The value and its date spelled out, so the chart is readable without
   cross-referencing the surrounding card. *)
let _marker_title (b : Types.Daily_price.t) =
  Printf.sprintf "last close %.2f (%s)" b.close_price (Date.to_string b.date)
  |> Html_page.escape

let _marker g ~i (b : Types.Daily_price.t) =
  Printf.sprintf
    "<circle class=\"last\" cx=\"%s\" cy=\"%s\" \
     r=\"%s\"><title>%s</title></circle>"
    (_c (_bar_x g i))
    (_c (_price_y g b.close_price))
    (_c _marker_radius) (_marker_title b)

(* Marker on the most recent close. *)
let _last_marker g bars =
  match List.last bars with
  | None -> []
  | Some b -> [ _marker g ~i:(List.length bars - 1) b ]

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

let _level_label_class = function
  | Entry -> "lvl-label lvl-label-entry"
  | Stop -> "lvl-label lvl-label-stop"
  | Reference -> "lvl-label lvl-label-ref"

(* Right-margin text labels naming each level. {!Svg_labels} owns the
   collision-avoidance rule; this only projects each level's price to its target
   baseline and hands the set over. *)
let _level_labels g levels =
  List.map levels ~f:(fun l ->
      {
        Svg_labels.cls = _level_label_class l.kind;
        text = l.label;
        y = _price_y g l.price +. Svg_labels.baseline_offset;
      })
  |> Svg_labels.render ~x:(g.x0 +. g.plot_w +. Svg_labels.inset)

(* Screen-reader summary: the mark count, the moving average if one is drawn,
   plus every level by name — so the chart is not information the page carries
   only visually. *)
let _aria_label ~n ~levels ~ma_period =
  let names = List.map levels ~f:(fun l -> l.label) in
  Printf.sprintf "price and volume sparkline, %d bars%s%s" n
    (match ma_period with
    | None -> ""
    | Some p -> Printf.sprintf "; %d-period moving average" p)
    (match names with
    | [] -> ""
    | _ -> "; levels: " ^ String.concat ~sep:", " names)

let _svg ~width ~height ~aria ~children =
  Printf.sprintf
    "<svg class=\"spark\" viewBox=\"0 0 %d %d\" width=\"%d\" height=\"%d\" \
     role=\"img\" aria-label=\"%s\">%s</svg>"
    width height width height (Html_page.escape aria)
    (String.concat ~sep:"" children)

(* Monday of the ISO week [d] falls in. Shifting to a weekday (rather than
   keying on a (year, week-number) pair) has no year-boundary discontinuity: a
   week straddling New Year keeps one key. *)
let _monday d =
  let iso = Date.day_of_week d |> Day_of_week.iso_8601_weekday_number in
  Date.add_days d (-(iso - 1))

(* One weekly bar from the dailies that fall in it: opening at the week's first
   open, spanning its extremes, closing at its last close. The bar is DATED at
   its last daily bar, so an as-of-Friday series ends on the snapshot's own
   Friday rather than on the following Monday. *)
let _fold_week week : Types.Daily_price.t =
  let first = List.hd_exn week and last = List.last_exn week in
  let extreme ~f ~init =
    List.fold week ~init ~f:(fun acc (b : Types.Daily_price.t) -> f acc b)
  in
  Types.Daily_price.make ~date:last.Types.Daily_price.date
    ~open_price:first.Types.Daily_price.open_price
    ~high_price:
      (extreme ~init:Float.neg_infinity ~f:(fun a b -> Float.max a b.high_price))
    ~low_price:
      (extreme ~init:Float.infinity ~f:(fun a b -> Float.min a b.low_price))
    ~close_price:last.Types.Daily_price.close_price
    ~volume:
      (List.sum (module Int) week ~f:(fun b -> b.Types.Daily_price.volume))
    ~adjusted_close:last.Types.Daily_price.adjusted_close ()

let weekly_bars bars =
  List.group bars ~break:(fun (a : Types.Daily_price.t) b ->
      not (Date.equal (_monday a.date) (_monday b.date)))
  |> List.map ~f:_fold_week

(* Simple moving average of [values] over [period], aligned to the input:
   element [i] is the mean of the [period] values ENDING at [i], or [None] when
   fewer than [period] values precede it. *)
let _sma ~period values =
  let arr = Array.of_list values in
  let mean_ending_at i =
    if period <= 0 || i + 1 < period then None
    else
      let window = Array.sub arr ~pos:(i + 1 - period) ~len:period in
      Some (Array.fold window ~init:0.0 ~f:( +. ) /. Float.of_int period)
  in
  List.init (Array.length arr) ~f:mean_ending_at

(* The moving average over the WHOLE supplied series, restricted to the drawn
   window. Computing over the whole series and then windowing (rather than
   computing over the window alone) means a caller who supplies history beyond
   the window gets an average defined across the full width of the chart. *)
let _ma_over_window ~period ~all ~dropped =
  _sma ~period
    (List.map all ~f:(fun (b : Types.Daily_price.t) -> b.close_price))
  |> fun values -> List.drop values dropped

let render ?(width = default_width) ?(height = default_height) ?band ?ma_period
    ?(annotate = false) ~bars ~levels () =
  let dropped = Int.max 0 (List.length bars - max_bars) in
  let window = List.drop bars dropped in
  let n = List.length window in
  if n < _min_bars then None
  else
    let ma =
      Option.map ma_period ~f:(fun period ->
          _ma_over_window ~period ~all:bars ~dropped)
    in
    let extra = Option.value_map ma ~default:[] ~f:List.filter_opt in
    let lo, span = _domain ~bars:window ~levels ~band ~extra in
    let gutter = if annotate then Svg_labels.gutter else 0.0 in
    let g = _geometry ~width ~height ~lo ~span ~n ~gutter in
    let optional flag children = if flag then children else [] in
    let children =
      Option.value_map band ~default:[] ~f:(fun pair -> [ _band_rect g pair ])
      @ _volume_rects g window
      @ Option.value_map ma ~default:[] ~f:(_ma_polyline g)
      @ [ _price_polyline g window ]
      @ List.map levels ~f:(_level_line g)
      @ optional annotate (_level_labels g levels @ _last_marker g window)
    in
    Some
      (_svg ~width ~height ~aria:(_aria_label ~n ~levels ~ma_period) ~children)
