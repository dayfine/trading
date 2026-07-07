(** See [report.mli] for the API contract. *)

open Core

let _sign v =
  if Float.( > ) v 0.0 then "+" else if Float.( < ) v 0.0 then "-" else "0"

let _coverage_section (t : Feature_screen.t) : string list =
  let rows =
    List.map t.coverage ~f:(fun (c : Feature_matrix.coverage) ->
        let pct =
          if c.total = 0 then 0.0
          else 100.0 *. Float.of_int c.present /. Float.of_int c.total
        in
        Printf.sprintf "| %s | %d | %d | %.1f%% |" c.feature c.present c.total
          pct)
  in
  "## Feature coverage (pre complete-case)" :: ""
  :: "| Feature | Present | Total | % |" :: "|---|---|---|---|" :: rows
  @ [ "" ]

let _ols_section (r : Regression.ols_result) : string list =
  let rows =
    List.map r.terms ~f:(fun tm ->
        Printf.sprintf "| %s | %+.6f | %.6f | %+.3f |" tm.name tm.coef tm.se
          tm.stat)
  in
  [
    "## OLS — return_pct on features (HC1-robust SE)";
    "";
    Printf.sprintf "n = %d, p = %d, R² = %.6f" r.n r.p r.r2;
    "";
    "| term | coef | se | t |";
    "|---|---|---|---|";
  ]
  @ rows @ [ "" ]

let _logit_section (r : Regression.logit_result) : string list =
  let rows =
    List.map r.terms ~f:(fun tm ->
        Printf.sprintf "| %s | %+.6f | %.6f | %+.3f |" tm.name tm.coef tm.se
          tm.stat)
  in
  [
    "## Logistic — P(win) on features";
    "";
    Printf.sprintf "n = %d, p = %d, in-sample AUC = %.4f, converged = %b" r.n
      r.p r.auc r.converged;
    "";
    "| term | coef | se | z |";
    "|---|---|---|---|";
  ]
  @ rows @ [ "" ]

(* name -> coef lookup for one era's OLS fit (if present). *)
let _era_coef (fit : (Regression.ols_result * Regression.logit_result) option)
    name : float option =
  match fit with
  | None -> None
  | Some (ols, _) ->
      List.find_map ols.terms ~f:(fun tm ->
          if String.equal tm.name name then Some tm.coef else None)

let _stability_row (t : Feature_screen.t) name : string =
  let full_sign =
    List.find_map t.ols.terms ~f:(fun tm ->
        if String.equal tm.name name then Some (_sign tm.coef) else None)
    |> Option.value ~default:"?"
  in
  let era_signs =
    List.map t.eras ~f:(fun (e : Feature_screen.era_fit) ->
        Option.value_map (_era_coef e.fit name) ~default:"." ~f:_sign)
  in
  let present =
    List.filter (full_sign :: era_signs) ~f:(fun s -> not (String.equal s "."))
  in
  let stable =
    match present with
    | [] -> "n/a"
    | s :: rest -> if List.for_all rest ~f:(String.equal s) then "yes" else "NO"
  in
  Printf.sprintf "| %s | %s | %s | %s |" name full_sign
    (String.concat ~sep:" " era_signs)
    stable

let _stability_section (t : Feature_screen.t) : string list =
  let era_labels = List.map t.eras ~f:(fun e -> e.Feature_screen.label) in
  let rows = List.map t.column_names ~f:(_stability_row t) in
  [
    "## Era-split coefficient sign stability (OLS)";
    "";
    Printf.sprintf "Eras: %s (`.` = era not fit; sign order matches header)"
      (String.concat ~sep:", " era_labels);
    "";
    Printf.sprintf "| term | full | %s | stable |"
      (String.concat ~sep:" | " era_labels);
    (* term + full + one per era + stable. *)
    "|"
    ^ String.concat
        (List.init (3 + List.length era_labels) ~f:(fun _ -> "---|"));
  ]
  @ rows @ [ "" ]

let _caveats : string list =
  [
    "## Screen-rigor caveats";
    "";
    "- IN-SAMPLE fit only — no out-of-sample / walk-forward validation. R² and \
     AUC are optimistic by construction.";
    "- COMPLETE-CASE bias: rows missing any selected feature are dropped; the \
     coverage table above quantifies the loss. Stage-2-only features \
     (weeks_advancing, stage2_late) and RS features are the None-heavy ones.";
    "- SURVIVORSHIP / population: the all-eligible CSV reflects the universe \
     snapshot it was generated from; delisted-name coverage is bounded by the \
     source snapshot.";
    "- This is a READ-ONLY SCREEN. It can support a no-build DECISION or an \
     escalate-to-WF-CV decision; it CANNOT claim causal or deployable alpha. A \
     mechanism is only rejected by the real test (default-off flag + \
     walk-forward CV + confirmation grid).";
    "";
  ]

let render (t : Feature_screen.t) ~title : string =
  let header =
    [
      Printf.sprintf "# %s" title;
      "";
      Printf.sprintf "Rows parsed: %d; complete-case rows (full fit): %d."
        t.n_total t.n_complete;
      "";
    ]
  in
  String.concat ~sep:"\n"
    (header @ _coverage_section t @ _ols_section t.ols @ _logit_section t.logit
   @ _stability_section t @ _caveats)
