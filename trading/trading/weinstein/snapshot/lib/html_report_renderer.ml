open Core

type bar_source = symbol:string -> Types.Daily_price.t list

let no_bars ~symbol:_ = []
let _e = Html_page.escape

(* Rendered in place of an empty section so the reader never sees a missing
   one — the HTML counterpart of the Markdown "(none)". *)
let _empty_marker = "<p class=\"empty\">(none)</p>"
let _note note = Printf.sprintf "<p class=\"note\">%s</p>" (_e note)
let _section ~title body = Printf.sprintf "<h2>%s</h2>\n%s" (_e title) body

let _bullet_list items =
  match items with
  | [] -> _empty_marker
  | _ ->
      Printf.sprintf "<ul>%s</ul>"
        (String.concat ~sep:""
           (List.map items ~f:(fun i -> Printf.sprintf "<li>%s</li>" (_e i))))

(* ---- Charts ---- *)

(* Card-width chart: wide enough for [Svg_chart.max_bars] weekly marks plus the
   right-hand label gutter [Svg_chart.render ~annotate] reserves. *)
let _chart_width = 860
let _chart_height = 150

(* Weinstein's weekly trend line. Stage analysis is defined against the 30-week
   moving average — "The stage is determined by the relationship between price
   and the 30-week moving average (MA), the slope of the MA, and the prior stage
   context" (weinstein-book-reference.md §1 "The Four Stages") — so a chart a
   reader is meant to check a Stage-2 entry against has to show it.

   Computed from the bars the caller supplies, never stored: the snapshot schema
   stays decoupled from analysis types. *)
let _ma_period_weeks = 30

let _price_level ~label ~price ~kind =
  { Svg_chart.label = Printf.sprintf "%s $%.2f" label price; price; kind }

(* One card's chart: the weekly close line with its 30-week average, the
   entry-to-stop band, and the two dashed level lines named in the right
   gutter. Weekly rather than daily because that is the cadence the stage
   framework is defined on, and because the same span in dailies is more marks
   than a card-scale chart can distinguish. *)
let _chart ~(bars_for : bar_source) ~symbol ~entry ~entry_label ~stop =
  Svg_chart.render ~width:_chart_width ~height:_chart_height ~band:(entry, stop)
    ~ma_period:_ma_period_weeks ~annotate:true
    ~bars:(Svg_series.weekly_bars (bars_for ~symbol))
    ~levels:
      [
        _price_level ~label:entry_label ~price:entry ~kind:Svg_chart.Entry;
        _price_level ~label:"stop" ~price:stop ~kind:Svg_chart.Stop;
      ]
    ()

(* ---- Candidate sections ---- *)

let _candidate_card ~arm ~bars_for ~rank (c : Weekly_snapshot.candidate) =
  let chart =
    _chart ~bars_for ~symbol:c.symbol ~entry:c.entry ~entry_label:"entry"
      ~stop:c.stop
  in
  Candidate_card.render ~arm ~rank ~chart c

let _candidate_cards ~arm ~bars_for shown =
  List.mapi shown ~f:(fun i c -> _candidate_card ~arm ~bars_for ~rank:(i + 1) c)
  |> String.concat ~sep:"\n"

(* Truncation note, then the fallback-stop legend, then the data-suspect
   legend, then the reconciliation legend — each an independent flat append,
   matching the Markdown renderer's order so the two reports read the same
   way. *)
let _append_notes ~shown ~hidden body =
  let legend flag note = if flag then Some note else None in
  [
    Report_shared.truncation ~shown ~hidden;
    legend (Report_shared.any_fallback_stop shown) Report_shared.stop_fallback;
    legend (Report_shared.any_data_suspect shown) Report_shared.data_suspect;
    legend
      (Report_shared.any_reconciled shown)
      Report_shared.entry_reconciliation;
  ]
  |> List.filter_map ~f:Fn.id
  |> List.fold ~init:body ~f:(fun acc n -> acc ^ "\n" ^ _note n)

let _candidate_list ~arm ~bars_for candidates ~limit =
  match candidates with
  | [] -> _empty_marker
  | _ ->
      let shown = List.take candidates limit in
      let hidden = List.drop candidates limit in
      Printf.sprintf "%s\n<div class=\"cands\">%s</div>"
        (Report_masthead.chart_legend ~ma_period:_ma_period_weeks)
        (_candidate_cards ~arm ~bars_for shown)
      |> _append_notes ~shown ~hidden

(* One display-capped candidate section. The header echoes the effective limit
   so header and content stay in sync. *)
let _candidate_section ~arm ~label ~bars_for candidates ~limit =
  _section
    ~title:(Printf.sprintf "%s (top %d)" label limit)
    (_candidate_list ~arm ~bars_for candidates ~limit)

(* ---- Held positions ---- *)

let _held_chips (h : Weekly_snapshot.held_position) =
  [
    Chip.make ~modifier:"status" h.status;
    Chip.make (Printf.sprintf "entered %s" (Date.to_string h.entered));
  ]

let _held_nums (h : Weekly_snapshot.held_position) =
  [
    Report_card.num ~label:"Shares" (Int.to_string h.shares);
    Report_card.num ~modifier:"entry" ~label:"Fill"
      (Printf.sprintf "$%.2f" h.entry_price);
    Report_card.num ~label:"Current" (Printf.sprintf "$%.2f" h.current_price);
    Report_card.num ~label:"Unrealized"
      (Printf.sprintf "%.1f%%" h.unrealized_pct);
    Report_card.num ~modifier:"stop" ~label:"Stop"
      (Printf.sprintf "$%.2f" h.stop);
  ]

(* This week's recomputed support floor against the stop in force. Weinstein's
   investor trailing method ratchets the sell-stop UP as the MA advances and
   leaves it alone otherwise (weinstein-book-reference.md §5.2 "Trailing Stop —
   Investor Method"), so a recomputed floor below the stop in force is not a
   reason to lower anything. The full state machine is not threaded here; this
   line reports the delta and says which way it points. *)
let _held_stop_line (h : Weekly_snapshot.held_position) =
  match h.recommended_stop with
  | None ->
      Printf.sprintf
        "Stop in force $%.2f. No support floor was recomputed this week." h.stop
  | Some r when Float.( > ) r h.stop ->
      Printf.sprintf
        "Stop in force $%.2f; this week's support floor is $%.2f (%+0.2f) — \
         raise the stop to it."
        h.stop r (r -. h.stop)
  | Some r ->
      Printf.sprintf
        "Stop in force $%.2f; this week's support floor is $%.2f (%+0.2f), \
         below the stop in force — leave the stop where it is."
        h.stop r (r -. h.stop)

let _held_card ~bars_for (h : Weekly_snapshot.held_position) =
  Report_card.render
    {
      modifier = None;
      arm = "held";
      rank = None;
      symbol = h.symbol;
      chips = _held_chips h;
      nums = _held_nums h;
      chart =
        _chart ~bars_for ~symbol:h.symbol ~entry:h.entry_price
          ~entry_label:"fill" ~stop:h.stop;
      footer = Some (Report_card.footer (_e (_held_stop_line h)));
    }

(* Held cards draw the same marks as candidate cards — weekly close, the 30-week
   average, the two dashed levels, the last-close marker — so this section
   carries the same legend. A reader who scrolls straight here would otherwise
   meet the marks with no key. *)
let _held_list ~bars_for positions =
  match positions with
  | [] -> _empty_marker
  | _ ->
      Printf.sprintf "%s\n<div class=\"cands\">%s</div>"
        (Report_masthead.chart_legend ~ma_period:_ma_period_weeks)
        (String.concat ~sep:"\n" (List.map positions ~f:(_held_card ~bars_for)))

(* ---- Page ---- *)

let _sector_list sectors =
  match sectors with
  | [] -> _empty_marker
  | _ ->
      Chip.group ~cls:"sectors"
        (List.map sectors ~f:(Chip.make ~modifier:"sector"))

(* Extended candidates carry no ticket (do-not-chase), so they render in their
   own watch section instead of consuming actionable display slots. The section
   is omitted when nothing is extended.

   Both sides share one section but NOT one arm tag: each card keeps its own
   side's tag, so an extended short's chart cell is addressed [short:SYM], not
   [long:SYM]. Ranks run continuously across the two groups — longs first, then
   shorts — because the section reads as a single list. *)
let _watch_cards ~bars_for ~long_extended ~short_extended =
  let cards ~arm ~offset candidates =
    List.mapi candidates ~f:(fun i c ->
        _candidate_card ~arm ~bars_for ~rank:(offset + i + 1) c)
  in
  cards ~arm:"long" ~offset:0 long_extended
  @ cards ~arm:"short" ~offset:(List.length long_extended) short_extended
  |> String.concat ~sep:"\n"

let _watch_body ~bars_for ~long_extended ~short_extended =
  Printf.sprintf "%s\n<div class=\"cands\">%s</div>"
    (Report_masthead.chart_legend ~ma_period:_ma_period_weeks)
    (_watch_cards ~bars_for ~long_extended ~short_extended)
  |> _append_notes ~shown:(long_extended @ short_extended) ~hidden:[]

let _watch_section ~bars_for ~long_extended ~short_extended =
  match (long_extended, short_extended) with
  | [], [] -> None
  | _ ->
      let body = _watch_body ~bars_for ~long_extended ~short_extended in
      Some (_section ~title:Report_shared.watch_section_title body)

let _body (t : Weekly_snapshot.t) ~title ~long_limit ~short_limit ~bars_for =
  let long_actionable, long_extended =
    Report_shared.partition_extended t.long_candidates
  in
  let short_actionable, short_extended =
    Report_shared.partition_extended t.short_candidates
  in
  List.filter_opt
    [
      Some (Report_masthead.header t ~title);
      Some (Report_masthead.counts_strip t);
      Some (_section ~title:"Strong sectors" (_sector_list t.sectors_strong));
      Some
        (_candidate_section ~arm:"long" ~label:"Long candidates" ~bars_for
           long_actionable ~limit:long_limit);
      Some
        (_candidate_section ~arm:"short" ~label:"Short candidates" ~bars_for
           short_actionable ~limit:short_limit);
      _watch_section ~bars_for ~long_extended ~short_extended;
      Some
        (_section ~title:"Held positions"
           (_held_list ~bars_for t.held_positions));
      Some (_section ~title:"Warnings" (_bullet_list t.warnings));
      Some Report_masthead.closing_notes;
    ]
  |> String.concat ~sep:"\n"

let render ?(long_limit = Report_renderer.default_long_display_limit)
    ?(short_limit = Report_renderer.default_short_display_limit)
    ?(bars_for = no_bars) (t : Weekly_snapshot.t) : string =
  let title =
    Printf.sprintf "Weekly Pick Report — %s" (Date.to_string t.date)
  in
  Html_page.document ~title
    ~body:(_body t ~title ~long_limit ~short_limit ~bars_for)
