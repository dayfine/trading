open Core

let default_config_path = "dev/weekly-picks/record-config-overrides.sexp"

(* Scores print as the sexp prints them ([100], [87.5]), which is how the
   record's [.sexp] carries them and how the committed summaries read. *)
let _num x = Sexp.to_string (Float.sexp_of_t x)

let _header ~config_path (snap : Weekly_snapshot.t) =
  sprintf
    "# Weekly picks — %s (public summary)\n\n\
     System version: `%s`. Generated with `%s` (README, \"Weekly cadence\"). \
     Price-free summary: the full record (entries, stops, tickets, charts, \
     validation) is in the private `dayfine/trading-results` repo under the \
     same path.\n\n"
    (Date.to_string snap.date) snap.system_version config_path

let _macro (snap : Weekly_snapshot.t) =
  sprintf "## Macro\n\n**%s** (score %s)\n\n" snap.macro.regime
    (_num snap.macro.score)

let _sectors ~title names =
  let body =
    match names with
    | [] -> "(none)\n"
    | _ -> String.concat (List.map names ~f:(sprintf "- %s\n"))
  in
  sprintf "## %s\n\n%s\n" title body

let _row i (c : Weekly_snapshot.candidate) =
  sprintf "| %d | %s | %s | %s | %s |\n" (i + 1) c.symbol c.grade (_num c.score)
    c.sector

let _candidates ~title cands =
  match cands with
  | [] -> sprintf "## %s\n\n(none)\n\n" title
  | _ ->
      sprintf
        "## %s\n\n\
         | Rank | Symbol | Grade | Score | Sector |\n\
         |---|---|---|---|---|\n\
         %s\n"
        title
        (String.concat (List.mapi cands ~f:_row))

let _beyond_title ~label ~shown ~beyond ~note =
  sprintf "%s candidates (%d, %d more eligible beyond the cap%s)" label shown
    beyond note

let _short_note shown =
  if shown > Report_renderer.default_short_display_limit then
    sprintf "; the rendered report shows the top %d"
      Report_renderer.default_short_display_limit
  else ""

let _longs (snap : Weekly_snapshot.t) =
  _candidates snap.long_candidates
    ~title:
      (_beyond_title ~label:"Long"
         ~shown:(List.length snap.long_candidates)
         ~beyond:snap.long_eligible_beyond_cap ~note:"")

let _shorts (snap : Weekly_snapshot.t) =
  let shown = List.length snap.short_candidates in
  let table =
    _candidates snap.short_candidates
      ~title:
        (_beyond_title ~label:"Short" ~shown
           ~beyond:snap.short_eligible_beyond_cap ~note:(_short_note shown))
  in
  if shown = 0 then table
  else
    table
    ^ "_Shorts are report-only: the record config sets enable_short_side false._\n"

let render ?(config_path = default_config_path) (snap : Weekly_snapshot.t) =
  String.concat
    [
      _header ~config_path snap;
      _macro snap;
      _sectors ~title:"Strong sectors" snap.sectors_strong;
      _sectors ~title:"Weak sectors" snap.sectors_weak;
      _longs snap;
      _shorts snap;
    ]
