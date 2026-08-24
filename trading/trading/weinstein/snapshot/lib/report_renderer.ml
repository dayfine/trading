open Core

(* Default display caps for the candidate tables. These bound the *human*
   report only — the underlying snapshot (.sexp) keeps the screener's full
   capped list, and strategy / backtest selection is unaffected. Callers may
   override both (see [render]'s optional params) to surface a book-sized list
   (~5) or the full set. The section header echoes the effective limit so header
   and content stay in sync. The long default matches the screener's candidate
   cap, so a default render shows every pick (2026-07-27 user feedback: the
   earlier cap of 7 hid 13 of 20 candidates). *)
let default_long_display_limit = 20
let default_short_display_limit = 5

(* Marker rendered for empty lists / tables so the reader never sees a missing
   section. *)
let _empty_marker = "(none)"

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

(* Markdown emphasis wrapper for a {!Report_shared} legend / footnote. The note
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

(* Risk % is computed against the SIZING BASIS — the do-not-chase cap, i.e. the
   worst admissible fill (issue #2158, "size on the cap") — not the stale entry
   level. Quoting the risk of a fill below the worst case understates the risk
   in a column named "Risk %". For a candidate carrying no cap (disarmed default
   / pre-#2158 snapshot) the basis falls back to the expected fill, so this is
   identical to the previous behaviour there. *)
(* A dash placeholder so a column is never blank: the sector name (absent when
   the screener recorded none), the score breakdown (pre-field snapshots), the
   weakness line (a setup with no weak links). *)
let _cell = function "" -> "-" | s -> s
let _opt_cell = function None -> "-" | Some s -> s

let _candidate_row ~rank (c : Weekly_snapshot.candidate) =
  let risk =
    Report_shared.risk_pct
      ~entry:(Weekly_snapshot.sizing_basis_price c)
      ~stop:c.stop
  in
  (* Sector / Score breakdown / Weakness are appended AFTER Instruction rather
     than interleaved: the order is the widest cell, so the identity + price +
     order columns stay leftmost and scannable, and the advisory columns trail. *)
  Printf.sprintf
    "| %d | %s | %s | %.2f | $%.2f | %s | %s | %.1f%% | %s | %s | %s | %s | %s \
     | %s |"
    rank (_symbol_cell c) c.grade c.score c.entry
    (Report_shared.close_vs_entry c)
    (_stop_cell c) risk
    (_resistance_cell c.resistance_grade)
    c.rationale
    (Report_shared.instruction c)
    (_cell c.sector)
    (_opt_cell (Report_shared.score_breakdown c))
    (_opt_cell (Report_shared.weakness_line c))

let _append_note table = function
  | None -> table
  | Some note -> table ^ "\n\n" ^ note

(* Appends, in order, the truncation note (if any candidates were hidden), the
   fallback-stop legend (if any shown candidate carries a non-structural stop),
   and the data-suspect legend (if any shown candidate is spike-flagged) below
   [table]. Split out of {!_candidate_table} to keep that function's nesting
   under the linter cap — each note is an independent, flat append rather than a
   nested match/if chain. *)
let _append_table_notes ~shown ~hidden ~beyond_cap table =
  let legend flag note = if flag then Some note else None in
  [
    Report_shared.truncation ~shown ~hidden;
    Report_shared.eligible_beyond_cap ~shown ~beyond_cap;
    legend (Report_shared.any_fallback_stop shown) Report_shared.stop_fallback;
    legend (Report_shared.any_data_suspect shown) Report_shared.data_suspect;
    legend
      (Report_shared.any_reconciled shown)
      Report_shared.entry_reconciliation;
  ]
  |> List.map ~f:(Option.map ~f:_italic)
  |> List.fold ~init:table ~f:_append_note

(* Hoisted out of {!_candidate_table} so that function stays a flat match — the
   inline list literal counted against the nesting cap. Mirrors the HTML
   renderer's [_candidate_columns], and the two must stay in the same order so
   the reports read alike. *)
let _candidate_columns =
  [
    "Rank";
    "Symbol";
    "Grade";
    "Score";
    "Entry";
    "Close vs entry";
    "Stop";
    "Risk %";
    "Resistance";
    "Rationale";
    "Instruction";
    "Sector";
    "Score breakdown";
    "Weakness";
  ]

let _candidate_rows shown =
  List.mapi shown ~f:(fun i c -> _candidate_row ~rank:(i + 1) c)

let _candidate_table ?(beyond_cap = 0) candidates ~limit =
  match candidates with
  | [] -> _empty_marker
  | _ ->
      let shown = List.take candidates limit in
      let hidden = List.drop candidates limit in
      String.concat ~sep:"\n"
        (_table_header _candidate_columns :: _candidate_rows shown)
      |> _append_table_notes ~shown ~hidden ~beyond_cap

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
  (* Issue #2404: every candidate — including one whose price has run past the
     do-not-chase cap — keeps its ticket and its rank in the candidate table.
     A past-cap row's order simply will not fill at the current price and says
     so; it is no longer split into a separate do-not-chase watch section. *)
  Buffer.add_string buf
    (_section
       ~title:(Printf.sprintf "Long candidates (top %d)" long_limit)
       (_candidate_table ~beyond_cap:t.long_eligible_beyond_cap
          t.long_candidates ~limit:long_limit));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf
    (_section
       ~title:(Printf.sprintf "Short candidates (top %d)" short_limit)
       (_candidate_table ~beyond_cap:t.short_eligible_beyond_cap
          t.short_candidates ~limit:short_limit));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf
    (_section ~title:"Held positions" (_held_table t.held_positions));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf (_section ~title:"Warnings" (_warnings_list t.warnings));
  Buffer.add_string buf "\n";
  Buffer.contents buf
