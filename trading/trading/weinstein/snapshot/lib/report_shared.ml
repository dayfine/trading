open Core

let risk_pct ~entry ~stop =
  if Float.equal entry 0.0 then 0.0 else (entry -. stop) /. entry *. 100.0

(* Resting stop ticket — the ordinary case: price has not reached the entry, so
   the order sits at the breakout level and expires unfilled if it never gets
   there. *)
let _stop_order (c : Weekly_snapshot.candidate) =
  Printf.sprintf
    "BUY STOP %d sh @ $%.2f (~$%.0f, %.1f%% of book, risk $%.0f); on fill \
     place SELL STOP @ $%.2f, GTC; cancel if unfilled by Friday close"
    c.sized_shares c.entry c.sized_position_value
    (c.sized_position_pct *. 100.0)
    c.sized_risk_amount c.stop

(* Re-anchored market ticket (issue #2103): price is already through the entry,
   so a resting stop there is an instantly-filling market order. The ticket says
   so, quotes the fill it is sized on, and names the overshoot.

   The quoted price comes from {!Weekly_snapshot.expected_fill_price} — the same
   accessor [Trade_sizing] sizes on — and NOT from [l.close], which merely
   happens to hold the same value. Sourcing it structurally is what makes the
   single-source-of-truth claim in [weekly_snapshot.mli] true rather than
   coincidentally true (review round 1). [l] remains the source of the
   overshoot, which only the class carries. *)
let _market_order (c : Weekly_snapshot.candidate)
    (l : Entry_reconciliation.levels) =
  Printf.sprintf
    "BUY MARKET %d sh @ ~$%.2f (~$%.0f, %.1f%% of book, risk $%.0f) — price is \
     %.1f%% through the $%.2f entry level, so the order fills at the market; \
     sized on the expected fill, not the entry level; on fill place SELL STOP \
     @ $%.2f, GTC"
    c.sized_shares
    (Weekly_snapshot.expected_fill_price c)
    c.sized_position_value
    (c.sized_position_pct *. 100.0)
    c.sized_risk_amount l.overshoot_pct c.entry c.stop

(* Suppressed ticket (issue #2103): the name has run too far past its own
   breakout to buy. The row is kept so the reader can watch it, but there is no
   order — see weinstein-book-reference.md §1 "Stage 2 detail (Ch. 2)". *)
let _do_not_chase (c : Weekly_snapshot.candidate)
    (l : Entry_reconciliation.levels) =
  Printf.sprintf
    "NO ORDER — do not chase: %+.1f%% past the $%.2f entry level (close \
     $%.2f). Reward/risk has shifted against a fresh entry here; keep it on \
     the watch list for a pullback toward the entry level."
    l.overshoot_pct c.entry l.close

(* The ticket body for a candidate that still has one, before the 0-share /
   sizing-note fallbacks are applied. *)
let _order (c : Weekly_snapshot.candidate) =
  match c.reconciliation with
  | Entry_reconciliation.Through_entry l -> _market_order c l
  | Not_reconciled | Valid_stop _ | Extended _ -> _stop_order c

(* Executable order instruction for one candidate. Kept here rather than in a
   renderer because it is the artifact the user copies into their broker: the
   Markdown and HTML reports must carry character-identical order text. *)
let instruction (c : Weekly_snapshot.candidate) =
  match c.reconciliation with
  | Entry_reconciliation.Extended l -> _do_not_chase c l
  | Not_reconciled | Valid_stop _ | Through_entry _ -> (
      match (c.sized_shares, c.sizing_note) with
      | 0, None -> "-"
      | 0, Some note -> note
      | _, None -> _order c
      | _, Some note -> Printf.sprintf "%s: %s" note (_order c))

let close_vs_entry (c : Weekly_snapshot.candidate) =
  match c.reconciliation with
  | Entry_reconciliation.Not_reconciled -> "-"
  | Valid_stop l -> Printf.sprintf "$%.2f (%+.1f%%)" l.close l.overshoot_pct
  | Through_entry l ->
      Printf.sprintf "$%.2f (%+.1f%% through)" l.close l.overshoot_pct
  | Extended l ->
      Printf.sprintf "$%.2f (%+.1f%% EXTENDED)" l.close l.overshoot_pct

let entry_reconciliation =
  "close vs entry: the Entry column is the BREAKOUT level from the week the \
   stock turned Stage 2, which the <=4-week early-Stage-2 window lets a pick \
   outrun by weeks; this column reconciles it against the current close (issue \
   #2103). A row marked \"through\" is already past its trigger, so the order \
   is a MARKET buy re-sized on that fill rather than a resting stop at the \
   level. A row marked \"EXTENDED\" is past the configured chase cap: no order \
   is issued and the row is kept for watch only."

let any_reconciled shown =
  List.exists shown ~f:(fun (c : Weekly_snapshot.candidate) ->
      match c.reconciliation with
      | Entry_reconciliation.Not_reconciled | Valid_stop _ -> false
      | Through_entry _ | Extended _ -> true)

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
