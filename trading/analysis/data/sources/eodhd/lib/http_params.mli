open CalendarLib

(* params for calling the EODHD API *)
type t = {
  symbol : string;
  (* If specified, omitted from the API call *)
  start_date : Date.t option;
  (* If specified, defaults to today *)
  end_date : Date.t option;
}
