open Core

let risk_pct ~entry ~stop =
  if Float.equal entry 0.0 then 0.0 else (entry -. stop) /. entry *. 100.0

(* The do-not-chase cap price carried by a reconciled candidate, or [None] for
   an unreconciled one and for a pre-#2158 snapshot (whose [cap] defaults to
   [0.0]). Drives whether the ticket carries a limit leg. *)
let _cap_of (c : Weekly_snapshot.candidate) =
  match Entry_reconciliation.levels_of c.reconciliation with
  | Some l when Float.( > ) l.cap 0.0 -> Some l.cap
  | Some _ | None -> None

(* Resting stop-limit ticket (issue #2158): price has not reached the entry, so
   the order rests at the breakout level and fills anywhere up to the
   do-not-chase [cap]. The displayed risk is the WORST case — [sized_risk_amount]
   is sized on the cap, not on the entry (see [Trade_sizing]). *)
let _stop_limit_order (c : Weekly_snapshot.candidate) ~cap =
  Printf.sprintf
    "BUY STOPLIMIT %d sh, trigger $%.2f limit $%.2f (~$%.0f, %.1f%% of book, \
     worst-case risk $%.0f); on fill place SELL STOP @ $%.2f, GTC; cancel if \
     unfilled by Friday close"
    c.sized_shares c.entry cap c.sized_position_value
    (c.sized_position_pct *. 100.0)
    c.sized_risk_amount c.stop

(* Legacy resting-stop ticket for a candidate carrying no cap (disarmed default
   / pre-#2158 snapshot): the exact string the report emitted before #2158, so
   an unreconciled row renders unchanged. *)
let _stop_order (c : Weekly_snapshot.candidate) =
  match _cap_of c with
  | Some cap -> _stop_limit_order c ~cap
  | None ->
      Printf.sprintf
        "BUY STOP %d sh @ $%.2f (~$%.0f, %.1f%% of book, risk $%.0f); on fill \
         place SELL STOP @ $%.2f, GTC; cancel if unfilled by Friday close"
        c.sized_shares c.entry c.sized_position_value
        (c.sized_position_pct *. 100.0)
        c.sized_risk_amount c.stop

(* Re-anchored ticket (issues #2103, #2158): price is already through the entry,
   so a resting stop there is already triggered. Rather than a MARKET order that
   chases whatever the open prints, the ticket is a LIMIT at ~the Friday close
   with the do-not-chase [cap] as the ceiling — it fills at or below the cap and
   refuses to chase past it. The displayed risk is the worst case
   ([sized_risk_amount], sized on the cap).

   The quoted price comes from {!Weekly_snapshot.expected_fill_price} — the
   ~close it would fill around — while [l] carries the overshoot and cap. A
   pre-#2158 snapshot with no cap keeps the old MARKET wording. *)
let _capped_limit_order (c : Weekly_snapshot.candidate)
    (l : Entry_reconciliation.levels) ~cap =
  Printf.sprintf
    "BUY LIMIT %d sh @ ~$%.2f, limit $%.2f (~$%.0f, %.1f%% of book, worst-case \
     risk $%.0f) — price is %.1f%% through the $%.2f entry level; sized on the \
     cap, not the entry level; on fill place SELL STOP @ $%.2f, GTC"
    c.sized_shares
    (Weekly_snapshot.expected_fill_price c)
    cap c.sized_position_value
    (c.sized_position_pct *. 100.0)
    c.sized_risk_amount l.overshoot_pct c.entry c.stop

let _legacy_market_order (c : Weekly_snapshot.candidate)
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

let _limit_order (c : Weekly_snapshot.candidate)
    (l : Entry_reconciliation.levels) =
  match _cap_of c with
  | Some cap -> _capped_limit_order c l ~cap
  | None -> _legacy_market_order c l

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
  | Entry_reconciliation.Through_entry l -> _limit_order c l
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
   is a LIMIT buy at ~the close capped at the do-not-chase ceiling rather than \
   a resting stop at the level. A row marked \"EXTENDED\" is past the \
   configured chase cap: no order is issued and the row is kept for watch \
   only."

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

let resistance_grade_explainer =
  "resistance grade: how much overhead supply (prior trapped buyers) sits \
   between the entry and the swing target. Virgin_territory / Clean = little \
   to none, the cleanest runway; Moderate / Heavy_resistance = old highs to \
   chew through first. The parenthesised figure is the supply score (0 clean, \
   1 heavy)."

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

let _beyond_cap_line ~beyond_cap ~lowest_shown =
  Printf.sprintf
    "%d additional eligible candidate%s beyond the displayed cap (lowest shown \
     score %.2f)."
    beyond_cap (_plural beyond_cap) lowest_shown

let eligible_beyond_cap ~shown ~beyond_cap =
  match shown with
  | [] -> None
  | _ when beyond_cap <= 0 -> None
  | _ ->
      let lowest_shown = (List.last_exn shown).Weekly_snapshot.score in
      Some (_beyond_cap_line ~beyond_cap ~lowest_shown)

(* Score breakdown — points sum to the candidate's score by construction
   (components come straight from the screener's own scoring). *)
let score_breakdown (c : Weekly_snapshot.candidate) =
  match c.score_components with
  | [] -> None
  | components ->
      let total = List.sum (module Int) components ~f:snd in
      let points =
        List.map components ~f:(fun (_, p) -> Int.to_string p)
        |> String.concat ~sep:" + "
      in
      Some (Printf.sprintf "%d = %s" total points)

let score_breakdown_detail (c : Weekly_snapshot.candidate) =
  match c.score_components with
  | [] -> None
  | components ->
      List.map components ~f:(fun (label, p) -> Printf.sprintf "%d %s" p label)
      |> String.concat ~sep:" · " |> Option.some

(* Per-candidate weakness line — from the row, no new scoring. Risk beyond this
   fraction of the fill basis is "wide" (initial stop sits below support, §5.1). *)
let _wide_risk_pct = 15.0

(* Longs stop below entry, shorts above — the sign gives the side. *)
let _looks_long (c : Weekly_snapshot.candidate) = Float.( < ) c.stop c.entry

let _rationale_has (c : Weekly_snapshot.candidate) needle =
  String.is_substring c.rationale ~substring:needle

let _volume_weakness (c : Weekly_snapshot.candidate) =
  if _rationale_has c "Adequate volume" || _rationale_has c "Adequate breakdown"
  then Some "adequate (not strong) volume"
  else None

let _stop_weakness (c : Weekly_snapshot.candidate) =
  if c.stop_is_structural then None
  else Some "fallback stop (no structural floor)"

let _risk_weakness (c : Weekly_snapshot.candidate) =
  let risk =
    Float.abs
      (risk_pct ~entry:(Weekly_snapshot.sizing_basis_price c) ~stop:c.stop)
  in
  if Float.( >= ) risk _wide_risk_pct then
    Some (Printf.sprintf "wide risk %.1f%%" risk)
  else None

let _chase_weakness (c : Weekly_snapshot.candidate) =
  match c.reconciliation with
  | Entry_reconciliation.Through_entry l ->
      Some (Printf.sprintf "paying up %+.1f%% through entry" l.overshoot_pct)
  | Extended l ->
      Some (Printf.sprintf "extended %+.1f%% past entry" l.overshoot_pct)
  | Not_reconciled | Valid_stop _ -> None

let _sector_weakness (c : Weekly_snapshot.candidate) =
  if _looks_long c && not (_rationale_has c "Strong sector") then
    Some "sector not strong"
  else None

let weaknesses (c : Weekly_snapshot.candidate) =
  List.filter_map
    [
      _volume_weakness c;
      _stop_weakness c;
      _risk_weakness c;
      _chase_weakness c;
      _sector_weakness c;
    ]
    ~f:Fn.id

let weakness_line c =
  match weaknesses c with [] -> None | ws -> Some (String.concat ~sep:"; " ws)

let is_extended (c : Weekly_snapshot.candidate) =
  match c.reconciliation with
  | Entry_reconciliation.Extended _ -> true
  | Not_reconciled | Valid_stop _ | Through_entry _ -> false

let partition_extended candidates =
  List.partition_tf candidates ~f:(Fn.non is_extended)

let watch_section_title = "Watch — extended, do not chase"
