# rank.awk -- the screener's top-N order, re-implemented for the offline re-rank (POSIX awk, no gawk extensions).
#
# Source of truth: trading/analysis/weinstein/screener/lib/screener_ranking.ml (#3404 Seeded, #3587 Price_band_seeded).
#   compare_rankable: score descending; then the tiebreak among equal scores.
#   Seeded:            _ticker_hash (seed_key ^ ticker) ascending, then ticker (String.compare, bytewise).
#                      seed_key = sprintf "%d|%s|" tiebreak_seed (Date.to_string as_of), e.g. "0|2010-11-12|MERC".
#   Price_band_seeded: price_band ~edges price ascending, then the Seeded order inside a band.
#                      price_band = number of edges <= price; edges [8; 14; 33].
#   _ticker_hash:      32-bit FNV-1a: h0 = 0x811c9dc5; per byte h = ((h lxor byte) * 0x01000193) land 0xffffffff.
#
# POSIX awk has no xor and its doubles hold 53 bits. The xor touches only the low byte, and the multiply splits the
# prime as 2^24 + 403, so every intermediate stays below 2^42 and is exact.

function rank_init(   i) { for (i = 1; i < 256; i++) RANK_ORD[sprintf("%c", i)] = i; RANK_READY = 1 }

function xor8(a, b,   r, p) {
  r = 0; p = 1
  while (a > 0 || b > 0) { if ((a % 2) != (b % 2)) r += p; a = int(a / 2); b = int(b / 2); p *= 2 }
  return r
}

function fnv1a(s,   h, i, lo) {
  if (!RANK_READY) rank_init()
  h = 2166136261
  for (i = 1; i <= length(s); i++) {
    lo = h % 256; h = h - lo + xor8(lo, RANK_ORD[substr(s, i, 1)])
    h = (h * 403 + (h % 256) * 16777216) % 4294967296
  }
  return h
}

# The Seeded draw key of one candidate on one screen date.
function seeded_key(seed, date, ticker) { return fnv1a(seed "|" date "|" ticker) }

# price_band with the default edges [8; 14; 33]: 0 below $8, 1 for $8-14, 2 for $14-33, 3 at $33 and up.
function band_of(p) { return (p >= 8) + (p >= 14) + (p >= 33) }

# Total order of two pool members i, j of the current screen date (arrays SC score, BD band, HK hash, TK ticker).
# mode "S" = Seeded, "P" = Price_band_seeded, "A" = Alphabetical (the control). Returns < 0 when i sorts first.
function rank_cmp(i, j, mode) {
  if (SC[i] != SC[j]) return SC[j] - SC[i]
  if (mode == "P" && BD[i] != BD[j]) return BD[i] - BD[j]
  if (mode != "A" && HK[i] != HK[j]) return HK[i] - HK[j]
  if (("" TK[i]) < ("" TK[j])) return -1
  if (("" TK[i]) > ("" TK[j])) return 1
  return 0
}

# Insertion sort of pool indices 1..n into out[1..n] under one mode (pools are a few hundred names at most).
function rank_sort(n, mode, out,   a, b, t) {
  for (a = 1; a <= n; a++) out[a] = a
  for (a = 2; a <= n; a++) {
    t = out[a]; b = a - 1
    while (b >= 1 && rank_cmp(out[b], t, mode) > 0) { out[b + 1] = out[b]; b-- }
    out[b + 1] = t
  }
}
