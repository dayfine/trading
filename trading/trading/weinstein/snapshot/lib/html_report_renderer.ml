open Core

type bar_source = symbol:string -> Types.Daily_price.t list

let no_bars ~symbol:_ = []
let _e = Html_page.escape

(* Rendered in place of an empty table / list so the reader never sees a
   missing section — the HTML counterpart of the Markdown "(none)". *)
let _empty_marker = "<p class=\"empty\">(none)</p>"

(* Rendered in place of a sparkline when the caller had no bars for the symbol
   (fewer than two, or no bar source at all). The row stays complete. *)
let _no_chart_marker = "<span class=\"nochart\">no chart data</span>"
let _note note = Printf.sprintf "<p class=\"note\">%s</p>" (_e note)
let _section ~title body = Printf.sprintf "<h2>%s</h2>\n%s" (_e title) body

(* ---- Table primitives ---- *)

let _td ~cls body = Printf.sprintf "<td class=\"%s\">%s</td>" cls body
let _text_td ~cls body = _td ~cls (_e body)

(* Numeric cells share one class so the stylesheet can right-align them and
   apply tabular figures in one place. *)
let _num_td body = _text_td ~cls:"num" body

let _table ~columns ~rows =
  let head =
    String.concat ~sep:""
      (List.map columns ~f:(fun c -> Printf.sprintf "<th>%s</th>" (_e c)))
  in
  let body =
    String.concat ~sep:"\n"
      (List.map rows ~f:(fun r ->
           Printf.sprintf "<tr>%s</tr>" (String.concat ~sep:"" r)))
  in
  Printf.sprintf
    "<table>\n<thead><tr>%s</tr></thead>\n<tbody>\n%s\n</tbody>\n</table>" head
    body

let _bullet_list items =
  match items with
  | [] -> _empty_marker
  | _ ->
      Printf.sprintf "<ul>%s</ul>"
        (String.concat ~sep:""
           (List.map items ~f:(fun i -> Printf.sprintf "<li>%s</li>" (_e i))))

(* ---- Charts ---- *)

let _price_level ~label ~price ~kind =
  { Svg_chart.label = Printf.sprintf "%s $%.2f" label price; price; kind }

(* Chart cell for one row. [arm] ("long" / "short" / "held") is emitted in the
   [data-chart] attribute so each of the three rendering arms is separable by
   anything reading the page programmatically. *)
let _chart_td ~arm ~symbol svg =
  Printf.sprintf "<td class=\"chart\" data-chart=\"%s:%s\">%s</td>" arm
    (_e symbol)
    (Option.value svg ~default:_no_chart_marker)

(* Entry-to-stop band plus the two dashed level lines. Shared by candidates and
   held positions — the only difference is what "entry" means (breakout trigger
   vs fill price). *)
let _sparkline ~bars ~entry ~entry_label ~stop =
  Svg_chart.render ~bars ~band:(entry, stop)
    ~levels:
      [
        _price_level ~label:entry_label ~price:entry ~kind:Svg_chart.Entry;
        _price_level ~label:"stop" ~price:stop ~kind:Svg_chart.Stop;
      ]
    ()

let _candidate_chart_td ~arm ~(bars_for : bar_source)
    (c : Weekly_snapshot.candidate) =
  _sparkline
    ~bars:(bars_for ~symbol:c.symbol)
    ~entry:c.entry ~entry_label:"entry" ~stop:c.stop
  |> _chart_td ~arm ~symbol:c.symbol

let _held_chart_td ~(bars_for : bar_source) (h : Weekly_snapshot.held_position)
    =
  _sparkline
    ~bars:(bars_for ~symbol:h.symbol)
    ~entry:h.entry_price ~entry_label:"fill" ~stop:h.stop
  |> _chart_td ~arm:"held" ~symbol:h.symbol

(* ---- Candidate table ---- *)

(* Issue #2084 Finding 2: a fallback (non-structural) stop carries a trailing
   asterisk so it is distinguishable from a real support floor at a glance. *)
let _stop_td (c : Weekly_snapshot.candidate) =
  if c.stop_is_structural then _num_td (Printf.sprintf "$%.2f" c.stop)
  else _num_td (Printf.sprintf "$%.2f*" c.stop)

(* Issue #2083 Finding 3: a spike-flagged candidate is annotated, not dropped —
   the "(!)" marker rides beside the symbol and the row is otherwise intact. *)
let _symbol_td (c : Weekly_snapshot.candidate) =
  if c.data_suspect then
    _td ~cls:"" (_e c.symbol ^ " <span class=\"flag\">(!)</span>")
  else _text_td ~cls:"" c.symbol

let _resistance_td = function
  | None -> _text_td ~cls:"" "-"
  | Some g -> _text_td ~cls:"" g

let _candidate_row ~arm ~bars_for ~rank (c : Weekly_snapshot.candidate) =
  [
    _num_td (Int.to_string rank);
    _symbol_td c;
    _text_td ~cls:"" c.grade;
    _num_td (Printf.sprintf "%.2f" c.score);
    _num_td (Printf.sprintf "$%.2f" c.entry);
    _stop_td c;
    _num_td
      (Printf.sprintf "%.1f%%"
         (Report_shared.risk_pct ~entry:c.entry ~stop:c.stop));
    _resistance_td c.resistance_grade;
    _text_td ~cls:"rationale" c.rationale;
    _text_td ~cls:"instruction" (Report_shared.instruction c);
    _candidate_chart_td ~arm ~bars_for c;
  ]

(* Truncation note, then the fallback-stop legend, then the data-suspect
   legend — each an independent flat append, matching the Markdown renderer's
   order so the two reports read the same way. *)
let _append_table_notes ~shown ~hidden table =
  let legend flag note = if flag then Some note else None in
  [
    Report_shared.truncation ~shown ~hidden;
    legend (Report_shared.any_fallback_stop shown) Report_shared.stop_fallback;
    legend (Report_shared.any_data_suspect shown) Report_shared.data_suspect;
  ]
  |> List.filter_map ~f:Fn.id
  |> List.fold ~init:table ~f:(fun acc n -> acc ^ "\n" ^ _note n)

let _candidate_columns =
  [
    "Rank";
    "Symbol";
    "Grade";
    "Score";
    "Entry";
    "Stop";
    "Risk %";
    "Resistance";
    "Rationale";
    "Instruction";
    "Chart";
  ]

let _candidate_rows ~arm ~bars_for shown =
  List.mapi shown ~f:(fun i c -> _candidate_row ~arm ~bars_for ~rank:(i + 1) c)

let _candidate_table ~arm ~bars_for candidates ~limit =
  match candidates with
  | [] -> _empty_marker
  | _ ->
      let shown = List.take candidates limit in
      let hidden = List.drop candidates limit in
      _table ~columns:_candidate_columns
        ~rows:(_candidate_rows ~arm ~bars_for shown)
      |> _append_table_notes ~shown ~hidden

(* One display-capped candidate section. The header echoes the effective limit
   so header and content stay in sync. *)
let _candidate_section ~arm ~label ~bars_for candidates ~limit =
  _section
    ~title:(Printf.sprintf "%s (top %d)" label limit)
    (_candidate_table ~arm ~bars_for candidates ~limit)

(* ---- Held-position table ---- *)

(* This week's recomputed support-floor stop with its delta vs the stop in
   force, so the reader sees whether to raise it (Weinstein never lowers a
   stop). [None] (not recomputed) renders "-". *)
let _suggested_stop_td ~current_stop = function
  | None -> _num_td "-"
  | Some r -> _num_td (Printf.sprintf "$%.2f (%+0.2f)" r (r -. current_stop))

let _held_row ~bars_for (h : Weekly_snapshot.held_position) =
  [
    _text_td ~cls:"" h.symbol;
    _num_td (Int.to_string h.shares);
    _num_td (Printf.sprintf "$%.2f" h.entry_price);
    _num_td (Printf.sprintf "$%.2f" h.current_price);
    _num_td (Printf.sprintf "%.1f%%" h.unrealized_pct);
    _num_td (Printf.sprintf "$%.2f" h.stop);
    _suggested_stop_td ~current_stop:h.stop h.recommended_stop;
    _text_td ~cls:"" (Date.to_string h.entered);
    _text_td ~cls:"" h.status;
    _held_chart_td ~bars_for h;
  ]

let _held_columns =
  [
    "Symbol";
    "Shares";
    "Entry";
    "Current";
    "Unrealized %";
    "Stop";
    "Suggested stop";
    "Entered";
    "Status";
    "Chart";
  ]

let _held_table ~bars_for positions =
  match positions with
  | [] -> _empty_marker
  | _ ->
      _table ~columns:_held_columns
        ~rows:(List.map positions ~f:(_held_row ~bars_for))

(* ---- Page ---- *)

let _macro_section (m : Weekly_snapshot.macro_context) =
  Printf.sprintf "<p class=\"macro\"><strong>%s</strong> (score %.2f)</p>"
    (_e m.regime) m.score

let _header (t : Weekly_snapshot.t) ~title =
  Printf.sprintf
    "<h1>%s</h1>\n<p class=\"subtitle\">System version: <code>%s</code></p>"
    (_e title) (_e t.system_version)

let _body (t : Weekly_snapshot.t) ~title ~long_limit ~short_limit ~bars_for =
  String.concat ~sep:"\n"
    [
      _header t ~title;
      _section ~title:"Macro" (_macro_section t.macro);
      _section ~title:"Strong sectors" (_bullet_list t.sectors_strong);
      _candidate_section ~arm:"long" ~label:"Long candidates" ~bars_for
        t.long_candidates ~limit:long_limit;
      _candidate_section ~arm:"short" ~label:"Short candidates" ~bars_for
        t.short_candidates ~limit:short_limit;
      _section ~title:"Held positions" (_held_table ~bars_for t.held_positions);
      _section ~title:"Warnings" (_bullet_list t.warnings);
    ]

let render ?(long_limit = Report_renderer.default_long_display_limit)
    ?(short_limit = Report_renderer.default_short_display_limit)
    ?(bars_for = no_bars) (t : Weekly_snapshot.t) : string =
  let title =
    Printf.sprintf "Weekly Pick Report — %s" (Date.to_string t.date)
  in
  Html_page.document ~title
    ~body:(_body t ~title ~long_limit ~short_limit ~bars_for)
