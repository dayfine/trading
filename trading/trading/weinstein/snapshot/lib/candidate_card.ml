open Core

(* Recognised rationale vocabulary -> CSS variant, probed in order. The clause
   TEXT is always rendered verbatim; this table only decides how the chip is
   painted, so an unrecognised clause degrades to a plain chip instead of
   vanishing. *)
let _clause_modifiers =
  [
    ("Strong volume", "vol-strong");
    ("Adequate volume", "vol-ok");
    ("breakout", "breakout");
    ("Early Stage", "early");
    ("RS ", "rs");
    ("Overhead supply", "supply");
    ("Virgin", "virgin");
    ("sector", "sector");
  ]

let _clause_modifier clause =
  List.find_map _clause_modifiers ~f:(fun (needle, modifier) ->
      if String.is_substring clause ~substring:needle then Some modifier
      else None)

(* [rationale] is a "; "-joined signal list. Blank segments are dropped so a
   trailing separator does not produce an empty chip. *)
let _rationale_chips rationale =
  String.split rationale ~on:';'
  |> List.map ~f:String.strip
  |> List.filter ~f:(fun s -> not (String.is_empty s))
  |> List.map ~f:(fun clause ->
      Chip.make ?modifier:(_clause_modifier clause) clause)

(* The resistance grade carries a hover explainer (deliverable 4) reusing the
   single-sourced [Report_shared] prose so the tooltip cannot drift. *)
let _resistance_chip = function
  | None -> []
  | Some grade ->
      let modifier =
        if String.is_prefix grade ~prefix:"Virgin_territory" then "virgin"
        else "resistance"
      in
      [
        Chip.make ~modifier ~title:Report_shared.resistance_grade_explainer
          grade;
      ]

(* Issue #2084 Finding 2 in words rather than as a footnote glyph: whether the
   stop is a real support floor or the fixed entry x buffer proxy. The fallback
   chip hovers the shared fallback-stop explainer (deliverable 4). *)
let _stop_chip (c : Weekly_snapshot.candidate) =
  if c.stop_is_structural then
    Chip.make ~modifier:"structural" "structural stop"
  else
    Chip.make ~modifier:"fallback" ~title:Report_shared.stop_fallback
      "fallback stop"

(* Issue #2083 Finding 3: a spike-flagged candidate is annotated, not dropped —
   its entry, stop and size are unchanged and only this chip is added. Hovers
   the shared data-suspect explainer (deliverable 4). *)
let _suspect_chip (c : Weekly_snapshot.candidate) =
  if c.data_suspect then
    [
      Chip.make ~modifier:"suspect" ~title:Report_shared.data_suspect
        "(!) data-suspect";
    ]
  else []

(* Issue #2103. The chip TEXT is [Report_shared.close_vs_entry] — the same
   string the Markdown column shows — so the two formats cannot drift; only the
   variant is derived from the class. Hovers the shared reconciliation
   explainer (deliverable 4). *)
let _reconciliation_chip (c : Weekly_snapshot.candidate) =
  match Entry_reconciliation.label c.reconciliation with
  | None -> []
  | Some cls ->
      [
        Chip.make ~modifier:(String.lowercase cls)
          ~title:Report_shared.entry_reconciliation
          (Report_shared.close_vs_entry c);
      ]

(* The candidate's sector name, shown plainly (a neutral fact, not a strong /
   weak judgement — the "Strong sector" scoring chip carries that). Omitted when
   the screener recorded no sector. *)
let _sector_chip (c : Weekly_snapshot.candidate) =
  if String.is_empty c.sector then []
  else [ Chip.make ~modifier:"sectorname" c.sector ]

(* Score composition (e.g. "70 = 30 + 20 + 20"), hovering the labelled detail
   ("30 Stage1→Stage2 breakout · …") so the arithmetic is on the face and the
   labels a hover away. Empty when the snapshot predates the breakdown field. *)
let _breakdown_chip (c : Weekly_snapshot.candidate) =
  match Report_shared.score_breakdown c with
  | None -> []
  | Some compact ->
      let title =
        Option.value (Report_shared.score_breakdown_detail c) ~default:compact
      in
      [ Chip.make ~modifier:"breakdown" ~title compact ]

(* The weakest links in the setup (fallback stop, adequate-not-strong volume,
   wide risk, paying up, sector not strong), one chip carrying the whole line so
   the reader sees the caveats without hunting the row. Empty when none apply. *)
let _weakness_chip (c : Weekly_snapshot.candidate) =
  match Report_shared.weakness_line c with
  | None -> []
  | Some line -> [ Chip.make ~modifier:"weak" ("weak: " ^ line) ]

let _chips (c : Weekly_snapshot.candidate) =
  Chip.make ~modifier:"score" (Printf.sprintf "%s %.2f" c.grade c.score)
  :: _breakdown_chip c
  @ _sector_chip c
  @ _rationale_chips c.rationale
  @ _resistance_chip c.resistance_grade
  @ [ _stop_chip c ]
  @ _suspect_chip c @ _reconciliation_chip c @ _weakness_chip c

(* The trailing "*" is kept from the Markdown report so the shared
   [Report_shared.stop_fallback] legend — whose prose opens "* fallback stop:" —
   reads correctly beside the figure. *)
let _stop_value (c : Weekly_snapshot.candidate) =
  if c.stop_is_structural then Printf.sprintf "$%.2f" c.stop
  else Printf.sprintf "$%.2f*" c.stop

(* Quoted against the SIZING BASIS — the do-not-chase cap, i.e. the worst
   admissible fill (issue #2158, "size on the cap") — never the stale entry
   level. For a candidate carrying no cap (disarmed default / pre-#2158
   snapshot) the basis falls back to the expected fill, so the figure is
   unchanged there. Both renderers read the same accessor. *)
let _risk_value (c : Weekly_snapshot.candidate) =
  Printf.sprintf "%.1f%%"
    (Report_shared.risk_pct
       ~entry:(Weekly_snapshot.sizing_basis_price c)
       ~stop:c.stop)

(* The current close, shown only when a reconciliation actually observed one.
   An unreconciled candidate has no close on file, so the figure is omitted
   rather than invented. *)
let _last_num (c : Weekly_snapshot.candidate) =
  match Entry_reconciliation.levels_of c.reconciliation with
  | None -> []
  | Some l -> [ Report_card.num ~label:"Last" (Printf.sprintf "$%.2f" l.close) ]

let _nums (c : Weekly_snapshot.candidate) =
  [
    Report_card.num ~modifier:"entry" ~label:"Entry"
      (Printf.sprintf "$%.2f" c.entry);
    Report_card.num ~modifier:"stop" ~label:"Stop" (_stop_value c);
    Report_card.num ~label:"Risk" (_risk_value c);
  ]
  @ _last_num c

let _is_extended (c : Weekly_snapshot.candidate) =
  match c.reconciliation with
  | Entry_reconciliation.Extended _ -> true
  | Not_reconciled | Valid_stop _ | Through_entry _ -> false

(* The order line, verbatim from [Report_shared] so the broker-facing text is
   character-identical across the two report formats. *)
let _footer (c : Weekly_snapshot.candidate) =
  let modifier = if _is_extended c then Some "suppressed" else None in
  Report_card.footer ?modifier (Html_page.escape (Report_shared.instruction c))

let render ~arm ~rank ~chart (c : Weekly_snapshot.candidate) =
  Report_card.render
    {
      modifier = (if _is_extended c then Some "extended" else None);
      arm;
      rank = Some rank;
      symbol = c.symbol;
      chips = _chips c;
      nums = _nums c;
      chart;
      footer = Some (_footer c);
    }
