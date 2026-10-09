(** ASCII price/MA/stage chart renderer. *)

open Core
open Shiller_decades_stage

(** ASCII chart of price (log scale) vs MA for a date range, with a stage strip
    underneath. Width is fixed at 80 chars. Useful for eyeballing whether stage
    transitions align with intuitive regime shifts. *)
let chart_width = 80

let chart_height = 12

(* @large-function: ASCII chart renderer; range scan + canvas plot + stage strip in one place is simplest *)
let ascii_chart ~prices ~ma ~stages ~dates ~from_idx ~to_idx ~title =
  let n = to_idx - from_idx + 1 in
  if n <= 0 then ()
  else
    let step = Float.of_int n /. Float.of_int chart_width in
    let log_prices = Array.map prices ~f:Float.log in
    let lo = ref Float.infinity in
    let hi = ref Float.neg_infinity in
    for i = from_idx to to_idx do
      lo := Float.min !lo log_prices.(i);
      hi := Float.min Float.infinity (Float.max !hi log_prices.(i));
      if not (Float.is_nan ma.(i)) then begin
        lo := Float.min !lo (Float.log ma.(i));
        hi := Float.max !hi (Float.log ma.(i))
      end
    done;
    let range = !hi -. !lo in
    let row_of v =
      if Float.is_nan v then -1
      else
        let frac = (v -. !lo) /. range in
        chart_height - 1 - Int.of_float (frac *. Float.of_int (chart_height - 1))
    in
    let canvas = Array.make_matrix ~dimx:chart_height ~dimy:chart_width ' ' in
    for col = 0 to chart_width - 1 do
      let idx = from_idx + Int.of_float (Float.of_int col *. step) in
      if idx <= to_idx then begin
        let pr = row_of log_prices.(idx) in
        let mr =
          row_of
            (if Float.is_nan ma.(idx) then Float.nan else Float.log ma.(idx))
        in
        if pr >= 0 && pr < chart_height then canvas.(pr).(col) <- '*';
        if mr >= 0 && mr < chart_height then
          canvas.(mr).(col) <-
            (if Char.equal canvas.(mr).(col) '*' then '#' else '-')
      end
    done;
    printf "\n=== %s ===\n" title;
    printf "(* = price, - = 30mo MA, # = both; log y-axis)\n";
    for row = 0 to chart_height - 1 do
      printf "  %s\n" (String.of_array canvas.(row))
    done;
    (* Stage strip underneath *)
    let stage_strip = Bytes.make chart_width ' ' in
    for col = 0 to chart_width - 1 do
      let idx = from_idx + Int.of_float (Float.of_int col *. step) in
      if idx <= to_idx then begin
        let ch =
          match stages.(idx) with
          | Stage1 -> '.'
          | Stage2 -> '#'
          | Stage3 -> ':'
          | Stage4 -> 'v'
        in
        Bytes.set stage_strip col ch
      end
    done;
    printf "  %s\n" (Bytes.to_string stage_strip);
    printf "  (S1=. S2=# S3=: S4=v)\n";
    let d_lo = dates.(from_idx) in
    let d_hi = dates.(to_idx) in
    printf "  range: %s ... %s\n" (Date.to_string d_lo) (Date.to_string d_hi)
