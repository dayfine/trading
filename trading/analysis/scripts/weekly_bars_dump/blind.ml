open Core

(* 6 hex digits (24 bits of the MD5 digest) keeps the birthday collision
   probability negligible at cohort scale (~0.04% at 100 cases, vs. ~7% at
   4 digits) -- see [blind.mli]. *)
let _pseudonym_hex_digits = 6

let pseudonym_of_symbol symbol =
  let hex = Md5.to_hex (Md5.digest_string symbol) in
  Printf.sprintf "SYM-%s"
    (String.uppercase (String.sub hex ~pos:0 ~len:_pseudonym_hex_digits))

let week_labels n =
  if n <= 0 then [] else List.init n ~f:(fun i -> Printf.sprintf "w%d" (i + 1))
