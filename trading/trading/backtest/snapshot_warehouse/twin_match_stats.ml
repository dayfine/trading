open Core

(* Relative distance between two closes, guarded against a zero magnitude. *)
let relative_diff a b =
  let denom = Float.max (Float.abs a) (Float.abs b) in
  if Float.( <= ) denom 0.0 then 0.0 else Float.abs (a -. b) /. denom

(* Merge two date-sorted close arrays into the (close_a, close_b) pairs on the
   dates both series have, in ascending date order. *)
let shared_closes a b =
  let la = Array.length a and lb = Array.length b in
  let i = ref 0 and j = ref 0 in
  let acc = ref [] in
  while !i < la && !j < lb do
    let da, ca = a.(!i) and db, cb = b.(!j) in
    let c = Date.compare da db in
    if c < 0 then incr i
    else if c > 0 then incr j
    else begin
      acc := (ca, cb) :: !acc;
      incr i;
      incr j
    end
  done;
  Array.of_list (List.rev !acc)

(* Fold a sequence of per-unit verdicts into [(matched, compared, longest
   run)]: [compared] counts the units that were comparable, [matched] those
   that matched, and the longest run is the longest stretch of consecutive
   matches. An incomparable unit breaks the run, the same as a miss. *)
type _tally = { matched : int; compared : int; run : int; best : int }

let _tally_empty = { matched = 0; compared = 0; run = 0; best = 0 }

let _tally_add t = function
  | `Skip -> { t with run = 0 }
  | `Miss -> { t with compared = t.compared + 1; run = 0 }
  | `Match ->
      let run = t.run + 1 in
      {
        matched = t.matched + 1;
        compared = t.compared + 1;
        run;
        best = Int.max t.best run;
      }

let _tally_stats t =
  let frac =
    if Int.equal t.compared 0 then 0.0
    else Float.of_int t.matched /. Float.of_int t.compared
  in
  (frac, t.best)

(* [Levels] stats: the fraction of shared dates whose closes match within
   [epsilon], and the longest run of consecutive matching dates. *)
let levels_match_stats shared ~epsilon =
  Array.fold shared ~init:_tally_empty ~f:(fun t (ca, cb) ->
      _tally_add t
        (if Float.( <= ) (relative_diff ca cb) epsilon then `Match else `Miss))
  |> _tally_stats

(* [Returns] stats over consecutive-shared-date return pairs: the fraction
   whose simple daily returns differ by at most [epsilon] (absolute), and the
   longest run of consecutive matching pairs. A pair is skipped when the prior
   close of either leg is <= 0 (undefined return): it is left out of the
   fraction and breaks the run. Fraction 0.0 when no valid pair exists. *)
let returns_match_stats shared ~epsilon =
  let t = ref _tally_empty in
  for k = 1 to Array.length shared - 1 do
    let pa, pb = shared.(k - 1) and ca, cb = shared.(k) in
    let verdict =
      (* Written as the pre-#3057 positive test, not [pa <= 0 || pb <= 0], so a
         NaN prior close is still skipped rather than scored as a miss. *)
      if Float.( > ) pa 0.0 && Float.( > ) pb 0.0 then
        let ra = (ca -. pa) /. pa and rb = (cb -. pb) /. pb in
        if Float.( <= ) (Float.abs (ra -. rb)) epsilon then `Match else `Miss
      else `Skip
    in
    t := _tally_add !t verdict
  done;
  _tally_stats !t
