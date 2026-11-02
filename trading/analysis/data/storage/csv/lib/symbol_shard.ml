open Core

let letters symbol =
  let first = String.get symbol 0 in
  let last = String.get symbol (String.length symbol - 1) in
  (String.make 1 (Char.uppercase first), String.make 1 (Char.uppercase last))

let dir symbol =
  let l1, l2 = letters symbol in
  l1 ^ "/" ^ l2
