open Core

let pseudonym_of_symbol symbol =
  let hex = Md5.to_hex (Md5.digest_string symbol) in
  Printf.sprintf "SYM-%s" (String.uppercase (String.sub hex ~pos:0 ~len:4))

let week_labels n =
  if n <= 0 then [] else List.init n ~f:(fun i -> Printf.sprintf "w%d" (i + 1))
