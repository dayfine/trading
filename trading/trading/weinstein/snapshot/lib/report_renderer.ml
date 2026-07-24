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

let _candidate_row ~rank (c : Weekly_snapshot.candidate) =
  let risk = _risk_pct ~entry:c.entry ~stop:c.stop in
  Printf.sprintf "| %d | %s | %s | %.2f | $%.2f | $%.2f | %.1f%% | %s | %s |"
    rank c.symbol c.grade c.score c.entry c.stop risk
    (_resistance_cell c.resistance_grade)
    c.rationale

let _plural n = if n = 1 then "" else "s"

(* Body of the truncation note. [n_tied = 0] means the hidden names all score
   below the cutoff (a plain "N lower-scored"); [n_tied > 0] means some hidden
   names tie the cutoff score, so the cut is arbitrary among equals — the note
   says so to keep a reader from trusting the alphabetical tie-break as a
   ranking (score is anti-predictive at the top grade; the RS/earliness
   tie-break was WF-CV-rejected as a return lever). *)
let _note_body ~n_hidden ~n_tied ~cutoff_score =
  if n_tied = 0 then
    Printf.sprintf "_%d lower-scored candidate%s not shown._" n_hidden
      (_plural n_hidden)
  else
    Printf.sprintf
      "_%d more candidate%s not shown; %d tie the cutoff score (%.2f). Among \
       equal scores the order is alphabetical, not a quality ranking — treat \
       the tied set as interchangeable._"
      n_hidden (_plural n_hidden) n_tied cutoff_score

(* Score of the last shown candidate — the cutoff below which names are hidden.
   Shown is non-empty whenever a note is produced (the table had rows). *)
let _cutoff_score shown = (List.last_exn shown).Weekly_snapshot.score

(* How many hidden candidates tie the cutoff score. *)
let _count_tied ~cutoff hidden =
  List.count hidden ~f:(fun (c : Weekly_snapshot.candidate) ->
      Float.equal c.score cutoff)

(* Honesty note appended below a truncated table. Candidates arrive sorted
   score-descending with an alphabetical tie-break (screener default). [None]
   when nothing was hidden. *)
let _truncation_note ~shown ~hidden =
  if List.is_empty hidden then None
  else
    let cutoff = _cutoff_score shown in
    Some
      (_note_body ~n_hidden:(List.length hidden)
         ~n_tied:(_count_tied ~cutoff hidden)
         ~cutoff_score:cutoff)

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
      ]
  in
  match candidates with
  | [] -> _empty_marker
  | _ -> (
      let shown = List.take candidates limit in
      let hidden = List.drop candidates limit in
      let rows =
        List.mapi shown ~f:(fun i c -> _candidate_row ~rank:(i + 1) c)
      in
      let table = String.concat ~sep:"\n" (header :: rows) in
      match _truncation_note ~shown ~hidden with
      | None -> table
      | Some note -> table ^ "\n\n" ^ note)

let _held_row (h : Weekly_snapshot.held_position) =
  Printf.sprintf "| %s | %s | $%.2f | %s |" h.symbol (Date.to_string h.entered)
    h.stop h.status

let _held_table positions =
  let header = _table_header [ "Symbol"; "Entered"; "Stop"; "Status" ] in
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
  Buffer.add_string buf "\n";
  Buffer.contents buf
