open Core

type cadence = Auto | Daily | Monthly | Quarterly [@@deriving show, eq]

(* Era cutovers from the Phase 1.4 URL probe. The [Auto] cadence policy
   pins quarter-ends until 2008-12-31, then month-ends until the day
   before [_daily_era_start], then every weekday onward. *)
let _monthly_era_start = Date.create_exn ~y:2009 ~m:Month.Jan ~d:1
let _daily_era_start = Date.create_exn ~y:2012 ~m:Month.Apr ~d:30
let _quarterly_months = [ Month.Mar; Month.Jun; Month.Sep; Month.Dec ]

let cadence_of_string s =
  match String.lowercase (String.strip s) with
  | "auto" -> Ok Auto
  | "daily" -> Ok Daily
  | "monthly" -> Ok Monthly
  | "quarterly" -> Ok Quarterly
  | _ ->
      Status.error_invalid_argument
        (Printf.sprintf
           "Unknown cadence %S (expected auto|daily|monthly|quarterly)" s)

let _is_weekday d =
  match Date.day_of_week d with Sat | Sun -> false | _ -> true

let _is_month_end d =
  let next = Date.add_days d 1 in
  not (Month.equal (Date.month next) (Date.month d))

let _is_quarter_end d =
  _is_month_end d
  && List.mem _quarterly_months (Date.month d) ~equal:Month.equal

let _select_auto d =
  if Date.( < ) d _monthly_era_start then _is_quarter_end d
  else if Date.( < ) d _daily_era_start then _is_month_end d
  else _is_weekday d

let _select d = function
  | Auto -> _select_auto d
  | Daily -> _is_weekday d
  | Monthly -> _is_month_end d
  | Quarterly -> _is_quarter_end d

(* Build the date list in reverse and reverse once at the end so we
   don't pay a quadratic append cost over thousands of dates. *)
let enumerate_dates ~from ~until policy =
  if Date.( < ) until from then []
  else
    let rec loop d acc =
      let acc' = if _select d policy then d :: acc else acc in
      if Date.equal d until then List.rev acc'
      else loop (Date.add_days d 1) acc'
    in
    loop from []

type action = Skip_cached | Skip_sentinel | Fetch [@@deriving show, eq]
type planned_step = { as_of : Date.t; action : action } [@@deriving show, eq]

let csv_path ~cache_dir ~as_of =
  Filename.concat cache_dir (Date.to_string as_of ^ ".csv")

let sentinel_path ~cache_dir ~as_of =
  Filename.concat cache_dir (Date.to_string as_of ^ ".sentinel")

let _file_exists_and_nonempty path =
  match Sys_unix.file_exists path with
  | `Yes -> (
      try Int64.( > ) (Core_unix.stat path).st_size Int64.zero
      with Core_unix.Unix_error _ -> false)
  | `No | `Unknown -> false

let _file_exists path =
  match Sys_unix.file_exists path with `Yes -> true | `No | `Unknown -> false

let _classify ~cache_dir ~resume as_of =
  if not resume then { as_of; action = Fetch }
  else if _file_exists (sentinel_path ~cache_dir ~as_of) then
    { as_of; action = Skip_sentinel }
  else if _file_exists_and_nonempty (csv_path ~cache_dir ~as_of) then
    { as_of; action = Skip_cached }
  else { as_of; action = Fetch }

let plan ~cache_dir ~resume dates =
  List.map dates ~f:(_classify ~cache_dir ~resume)

let _count_actions steps =
  List.fold steps ~init:(0, 0, 0) ~f:(fun (f, c, s) step ->
      match step.action with
      | Fetch -> (f + 1, c, s)
      | Skip_cached -> (f, c + 1, s)
      | Skip_sentinel -> (f, c, s + 1))

let _action_label = function
  | Fetch -> "fetch"
  | Skip_cached -> "cached"
  | Skip_sentinel -> "sentinel"

let format_plan_summary steps =
  let fetch, cached, sentinel = _count_actions steps in
  let header =
    Printf.sprintf "Plan: %d dates, %d to fetch, %d cached, %d sentinel."
      (List.length steps) fetch cached sentinel
  in
  let lines =
    List.map steps ~f:(fun step ->
        Printf.sprintf "  %s %s"
          (Date.to_string step.as_of)
          (_action_label step.action))
  in
  String.concat ~sep:"\n" (header :: lines)

let ensure_cache_dir path =
  try
    Core_unix.mkdir_p path;
    Ok ()
  with
  | Core_unix.Unix_error (err, _, _) ->
      Status.error_internal
        (Printf.sprintf "mkdir_p %s failed: %s" path
           (Core_unix.Error.message err))
  | Sys_error msg ->
      Status.error_internal (Printf.sprintf "mkdir_p %s failed: %s" path msg)

let _write_file_atomic ~path ~contents =
  let tmp = path ^ ".tmp" in
  try
    Out_channel.with_file tmp ~f:(fun oc ->
        Out_channel.output_string oc contents);
    Core_unix.rename ~src:tmp ~dst:path;
    Ok ()
  with
  | Sys_error msg ->
      Status.error_internal (Printf.sprintf "write %s failed: %s" path msg)
  | Core_unix.Unix_error (err, _, _) ->
      Status.error_internal
        (Printf.sprintf "rename to %s failed: %s" path
           (Core_unix.Error.message err))

let write_csv_body ~cache_dir ~as_of ~body =
  _write_file_atomic ~path:(csv_path ~cache_dir ~as_of) ~contents:body

(* Sentinel marker contents: one byte. Any payload works; we use a
   newline so [cat] on the file does not look like an empty result. *)
let _sentinel_marker_payload = "\n"

let write_sentinel_marker ~cache_dir ~as_of =
  _write_file_atomic
    ~path:(sentinel_path ~cache_dir ~as_of)
    ~contents:_sentinel_marker_payload
