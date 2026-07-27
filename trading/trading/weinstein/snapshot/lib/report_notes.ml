open Core

let stop_fallback =
  "* fallback stop: no qualifying support floor (prior correction low / rally \
   high) was found in this symbol's recent bar history, so the stop shown is \
   the fixed entry x initial_stop_buffer proxy rather than a real structural \
   level — verify it against the chart before placing the order."

let data_suspect =
  "(!) data-suspect: this candidate's most recent bar moved more than the \
   configured spike threshold vs the prior bar's close, so its signal may rest \
   on a single anomalous print (stale / renamed-ticker feed, unadjusted split, \
   or a genuine but outsized gap) — verify the last bar against an independent \
   quote before placing the order. See the Warnings section for the observed \
   move."

let any_fallback_stop shown =
  List.exists shown ~f:(fun (c : Weekly_snapshot.candidate) ->
      not c.stop_is_structural)

let any_data_suspect shown =
  List.exists shown ~f:(fun (c : Weekly_snapshot.candidate) -> c.data_suspect)

let _plural n = if n = 1 then "" else "s"

(* Body of the truncation note. [n_tied = 0] means the hidden names all score
   below the cutoff (a plain "N lower-scored"); [n_tied > 0] means some hidden
   names tie the cutoff score, so the cut is arbitrary among equals — the note
   says so to keep a reader from trusting the alphabetical tie-break as a
   ranking (score is anti-predictive at the top grade; the RS/earliness
   tie-break was WF-CV-rejected as a return lever). *)
let _note_body ~n_hidden ~n_tied ~cutoff_score =
  if n_tied = 0 then
    Printf.sprintf "%d lower-scored candidate%s not shown." n_hidden
      (_plural n_hidden)
  else
    Printf.sprintf
      "%d more candidate%s not shown; %d tie the cutoff score (%.2f). Among \
       equal scores the order is alphabetical, not a quality ranking — treat \
       the tied set as interchangeable."
      n_hidden (_plural n_hidden) n_tied cutoff_score

(* Score of the last shown candidate — the cutoff below which names are hidden.
   Shown is non-empty whenever a note is produced (the table had rows). *)
let _cutoff_score shown = (List.last_exn shown).Weekly_snapshot.score

(* How many hidden candidates tie the cutoff score. *)
let _count_tied ~cutoff hidden =
  List.count hidden ~f:(fun (c : Weekly_snapshot.candidate) ->
      Float.equal c.score cutoff)

let truncation ~shown ~hidden =
  if List.is_empty hidden then None
  else
    let cutoff = _cutoff_score shown in
    Some
      (_note_body ~n_hidden:(List.length hidden)
         ~n_tied:(_count_tied ~cutoff hidden)
         ~cutoff_score:cutoff)
