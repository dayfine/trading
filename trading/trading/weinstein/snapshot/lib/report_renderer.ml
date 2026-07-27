open Core

(* Default display caps for the candidate tables. These bound the *human*
   report only — the underlying snapshot (.sexp) keeps the screener's full
   capped list, and strategy / backtest selection is unaffected. Callers may
   override both (see [render]'s optional params) to surface a book-sized list
   (~5) or the full set. The section header echoes the effective limit so header
   and content stay in sync. *)
let default_long_display_limit = 7
let default_short_display_limit = 5

(* Marker rendered for empty lists / tables so the reader never sees a missing
   section. *)
let _empty_marker = "(none)"

let _risk_pct ~entry ~stop =
  if Float.equal entry 0.0 then 0.0 else (entry -. stop) /. entry *. 100.0

(* Issue #2084 Finding 2: a candidate's [stop] can be a real structural level
   (support floor / resistance ceiling) or the fixed-buffer fallback proxy —
   see [Weekly_snapshot.candidate.stop_is_structural]. A fallback stop is
   marked with a trailing asterisk so the reader can tell it apart from a
   structural one at a glance, without having to cross-reference the chart. *)
let _stop_cell (c : Weekly_snapshot.candidate) =
  if c.stop_is_structural then Printf.sprintf "$%.2f" c.stop
  else Printf.sprintf "$%.2f*" c.stop

(* Issue #2083 Finding 3: a candidate whose last bar is a single outsized move
   vs the prior bar's close is FLAGGED, not dropped — see
   [Weekly_snapshot.candidate.data_suspect]. The symbol cell carries a "(!)"
   marker so the row reads as suspect at a glance. *)
let _symbol_cell (c : Weekly_snapshot.candidate) =
  if c.data_suspect then c.symbol ^ " (!)" else c.symbol

(* Markdown emphasis wrapper for a {!Report_notes} legend / footnote. The note
   prose itself is shared with the HTML renderer; only the wrapping differs. *)
let _italic note = "_" ^ note ^ "_"

(* Header line plus separator for a Markdown table. *)
let _table_header columns =
  let header = "| " ^ String.concat ~sep:" | " columns ^ " |" in
  let sep =
    "|" ^ String.concat ~sep:"" (List.map columns ~f:(fun _ -> "---|"))
  in
  header ^ "\n" ^ sep

(* Resistance-grade cell for the candidate table. [None] (grade not computed
   for this candidate) renders as a dash so the column is never blank. The grade
   is the v2 sketch-derived form "<quality> (<score>)" or the v1 binary quality
   label, produced upstream by the snapshot generator. *)
let _resistance_cell : string option -> string = function
  | None -> "-"
  | Some g -> g

(* Executable order instruction for one candidate, formatted from the
   generator-computed [sized_*] / [sizing_note] fields (fixed-risk sizing,
   mirroring the backtest). A [0]-share unsized candidate (e.g. a short, which
   the live strategy leaves unsized) renders "-"; a [0]-share result WITH a note
   renders the note (cash / caps exhausted, invalid stop). A placeholder-sized
   candidate prefixes the note so the size reads as provisional. *)
let _instruction_cell (c : Weekly_snapshot.candidate) =
  let order =
    Printf.sprintf
      "BUY STOP %d sh @ $%.2f (~$%.0f, %.1f%% of book, risk $%.0f); on fill \
       place SELL STOP @ $%.2f, GTC; cancel if unfilled by Friday close"
      c.sized_shares c.entry c.sized_position_value
      (c.sized_position_pct *. 100.0)
      c.sized_risk_amount c.stop
  in
  match (c.sized_shares, c.sizing_note) with
  | 0, None -> "-"
  | 0, Some note -> note
  | _, None -> order
  | _, Some note -> Printf.sprintf "%s: %s" note order

let _candidate_row ~rank (c : Weekly_snapshot.candidate) =
  let risk = _risk_pct ~entry:c.entry ~stop:c.stop in
  Printf.sprintf "| %d | %s | %s | %.2f | $%.2f | %s | %.1f%% | %s | %s | %s |"
    rank (_symbol_cell c) c.grade c.score c.entry (_stop_cell c) risk
    (_resistance_cell c.resistance_grade)
    c.rationale (_instruction_cell c)

let _append_note table = function
  | None -> table
  | Some note -> table ^ "\n\n" ^ note

(* Appends, in order, the truncation note (if any candidates were hidden), the
   fallback-stop legend (if any shown candidate carries a non-structural stop),
   and the data-suspect legend (if any shown candidate is spike-flagged) below
   [table]. Split out of {!_candidate_table} to keep that function's nesting
   under the linter cap — each note is an independent, flat append rather than a
   nested match/if chain. *)
let _append_table_notes ~shown ~hidden table =
  let legend flag note = if flag then Some note else None in
  [
    Report_notes.truncation ~shown ~hidden;
    legend (Report_notes.any_fallback_stop shown) Report_notes.stop_fallback;
    legend (Report_notes.any_data_suspect shown) Report_notes.data_suspect;
  ]
  |> List.map ~f:(Option.map ~f:_italic)
  |> List.fold ~init:table ~f:_append_note

let _candidate_table candidates ~limit =
  let header =
    _table_header
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
      ]
  in
  match candidates with
  | [] -> _empty_marker
  | _ ->
      let shown = List.take candidates limit in
      let hidden = List.drop candidates limit in
      let rows =
        List.mapi shown ~f:(fun i c -> _candidate_row ~rank:(i + 1) c)
      in
      String.concat ~sep:"\n" (header :: rows)
      |> _append_table_notes ~shown ~hidden

(* Recommended-stop cell: this week's recomputed Weinstein support-floor stop
   shown with its delta vs the current stop, so the reader sees whether to raise
   it (Weinstein never lowers a stop). [None] (not recomputed) renders "-". *)
let _suggested_stop_cell ~current_stop = function
  | None -> "-"
  | Some r -> Printf.sprintf "$%.2f (%+0.2f)" r (r -. current_stop)

let _held_row (h : Weekly_snapshot.held_position) =
  Printf.sprintf "| %s | %d | $%.2f | $%.2f | %.1f%% | $%.2f | %s | %s | %s |"
    h.symbol h.shares h.entry_price h.current_price h.unrealized_pct h.stop
    (_suggested_stop_cell ~current_stop:h.stop h.recommended_stop)
    (Date.to_string h.entered) h.status

let _held_table positions =
  let header =
    _table_header
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
      ]
  in
  match positions with
  | [] -> _empty_marker
  | _ ->
      let rows = List.map positions ~f:_held_row in
      String.concat ~sep:"\n" (header :: rows)

let _sector_list sectors =
  match sectors with
  | [] -> _empty_marker
  | _ -> String.concat ~sep:"\n" (List.map sectors ~f:(fun s -> "- " ^ s))

let _macro_section (m : Weekly_snapshot.macro_context) =
  Printf.sprintf "**%s** (score %.2f)" m.regime m.score

(* Data-quality warnings (issue #2083 fix 1): one bullet per dropped ticker so
   a candidate that vanished from the tables is explained, not just missing. *)
let _warnings_list warnings =
  match warnings with
  | [] -> _empty_marker
  | _ -> String.concat ~sep:"\n" (List.map warnings ~f:(fun w -> "- " ^ w))

let _section ~title body = Printf.sprintf "## %s\n%s" title body

let render ?(long_limit = default_long_display_limit)
    ?(short_limit = default_short_display_limit) (t : Weekly_snapshot.t) :
    string =
  let buf = Buffer.create 1024 in
  Buffer.add_string buf
    (Printf.sprintf "# Weekly Pick Report — %s\n\n" (Date.to_string t.date));
  Buffer.add_string buf
    (Printf.sprintf "System version: `%s`\n\n" t.system_version);
  Buffer.add_string buf (_section ~title:"Macro" (_macro_section t.macro));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf
    (_section ~title:"Strong sectors" (_sector_list t.sectors_strong));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf
    (_section
       ~title:(Printf.sprintf "Long candidates (top %d)" long_limit)
       (_candidate_table t.long_candidates ~limit:long_limit));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf
    (_section
       ~title:(Printf.sprintf "Short candidates (top %d)" short_limit)
       (_candidate_table t.short_candidates ~limit:short_limit));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf
    (_section ~title:"Held positions" (_held_table t.held_positions));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf (_section ~title:"Warnings" (_warnings_list t.warnings));
  Buffer.add_string buf "\n";
  Buffer.contents buf
