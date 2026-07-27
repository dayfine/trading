open Core

let _e = Html_page.escape

(* A closed set, so no class name is ever derived from free-form snapshot text.
   An unrecognised regime still prints its label — only the colour is dropped. *)
let _regime_modifier regime =
  match String.lowercase regime with
  | "bullish" -> Some "bullish"
  | "bearish" -> Some "bearish"
  | "neutral" -> Some "neutral"
  | _ -> None

let _regime_chip (m : Weekly_snapshot.macro_context) =
  Chip.make
    ?modifier:(_regime_modifier m.regime)
    (Printf.sprintf "%s %.2f" m.regime m.score)

let header (t : Weekly_snapshot.t) ~title =
  Printf.sprintf
    "<header><div class=\"mast-top\"><h1>%s</h1><div class=\"asof\">as-of %s \
     close &middot; system <code>%s</code></div></div><div \
     class=\"mast-meta\">%s</div></header>"
    (_e title)
    (_e (Date.to_string t.date))
    (_e t.system_version)
    (Chip.render (_regime_chip t.macro))

let _stat (label, n) =
  Printf.sprintf
    "<div class=\"stat\"><span class=\"label\">%s</span><b>%d</b></div>"
    (_e label) n

let _counts (t : Weekly_snapshot.t) =
  [
    ("Long candidates", List.length t.long_candidates);
    ("Short candidates", List.length t.short_candidates);
    ("Held positions", List.length t.held_positions);
    ("Warnings", List.length t.warnings);
  ]

let counts_strip t =
  let tiles = String.concat ~sep:"" (List.map (_counts t) ~f:_stat) in
  Printf.sprintf "<div class=\"strip\">%s</div>" tiles

(* A legend entry is a swatch plus its name. [cls] selects the swatch's stroke
   colour and dash pattern from the page stylesheet. *)
let _legend_entry ~cls name =
  Printf.sprintf "<span><span class=\"sw %s\"></span>%s</span>" cls (_e name)

let _legend_entries ~ma_period =
  [
    _legend_entry ~cls:"sw-px" "weekly close";
    _legend_entry ~cls:"sw-ma"
      (Printf.sprintf "%d-week moving average" ma_period);
    _legend_entry ~cls:"sw-entry" "entry trigger";
    _legend_entry ~cls:"sw-stop" "stop";
    "<span>symbol links open TradingView</span>";
  ]

let chart_legend ~ma_period =
  let entries = String.concat ~sep:"" (_legend_entries ~ma_period) in
  Printf.sprintf "<div class=\"legend\">%s</div>" entries

let _how_to_read =
  "How to read it: each chip is one of the screener's own rationale clauses, \
   printed verbatim — the report re-labels nothing. A buy-stop triggers only \
   on upward continuation, so an unfilled order costs nothing; cancel anything \
   still unfilled at Friday close."

let _what_the_figures_mean =
  "Risk is quoted against the price the order is expected to FILL at, not \
   against the historical breakout level. A stop marked with a trailing \
   asterisk is the fixed-buffer proxy rather than a support floor found in the \
   chart — check those against the chart before placing. Share counts come \
   from the sizing pass recorded in the snapshot; they are not recomputed \
   here."

let closing_notes =
  Printf.sprintf "<footer><p>%s</p><p>%s</p></footer>" (_e _how_to_read)
    (_e _what_the_figures_mean)
