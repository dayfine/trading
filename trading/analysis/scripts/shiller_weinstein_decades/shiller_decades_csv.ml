(** Parser for the derived 6-column Shiller CSV (see {!parse_derived_csv}). *)

open Core
module Client = Shiller.Shiller_client

(** Parser for the *derived* 6-column CSV emitted by [fetch_shiller_history.exe]
    (period,sp_price,dividend,earnings,cpi,long_rate), NOT the raw 10-column
    mirror format that [Shiller_client.parse] consumes. We do this here rather
    than going through [Client.parse] because the pinned fixture stores the
    derived form. *)
let parse_derived_csv body : Client.series =
  let lines = String.split_lines body in
  let observations =
    List.filter_mapi lines ~f:(fun i line ->
        if i = 0 then None
        else if String.is_empty (String.strip line) then None
        else
          let cols = String.split line ~on:',' in
          match cols with
          | [ date_s; sp_s; div_s; earn_s; cpi_s; long_s ] ->
              let parse_opt s =
                if String.is_empty (String.strip s) then None
                else Some (Float.of_string s)
              in
              Some
                {
                  Client.period = Date.of_string date_s;
                  sp_price = Float.of_string sp_s;
                  dividend = parse_opt div_s;
                  earnings = parse_opt earn_s;
                  cpi = parse_opt cpi_s;
                  long_rate = parse_opt long_s;
                }
          | _ ->
              failwithf "shiller_weinstein_decades: malformed CSV line %d: %s" i
                line ())
  in
  { Client.observations }
