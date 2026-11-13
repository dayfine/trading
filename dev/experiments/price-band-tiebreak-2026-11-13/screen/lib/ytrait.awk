# ytrait.awk -- the pre-registered trait-Y test (PREREG.md), cut-offs passed in (from 2000-2012 events, via sort).
# usage: awk -F'\t' -v CAP=1.90 -v CUTS="6:a,b,c,d;7:...;" -f ytrait.awk events.tsv   (CAP: Amendment 1, ride capped at p99.5)
# Per trait quintile and half: n, monster rate, lift vs the half's base rate, mean ride, ride > 0, ride >= +100 %.
# PASS = lift >= 1.5 in both halves AND mean ride above the half's population mean in both halves.
BEGIN { nt = split(CUTS, T, ";"); for (i = 1; i <= nt; i++) if (T[i] != "") { split(T[i], kv, ":"); split(kv[2], cv, ","); for (q = 1; q <= 4; q++) CUT[kv[1], q] = cv[q] + 0; HAS[kv[1]] = 1 } }
{ if ($5 > CAP) $5 = CAP; h = (substr($2, 1, 4) <= "2012") ? 1 : 2; nh[h]++; mh[h] += $3; rh[h] += $5
  for (c = 6; c <= 17; c++) { if ($c == "") continue; x = $c + 0
    if (c == 16) q = x + 1; else { q = 5; for (k = 1; k <= 4; k++) if (x <= CUT[c, k]) { q = k; break } }
    N[c, q, h]++; MO[c, q, h] += $3; R[c, q, h] += $5; W[c, q, h] += ($5 > 0); B[c, q, h] += ($5 >= 1) } }
END { for (h = 1; h <= 2; h++) { BR[h] = mh[h] / nh[h]; MR[h] = rh[h] / nh[h] }
  printf "2000-2012 n=%d monster %.2f%% mean ride %+.1f%% | 2013-2025 n=%d monster %.2f%% mean ride %+.1f%%\n", nh[1], 100 * BR[1], 100 * MR[1], nh[2], 100 * BR[2], 100 * MR[2]
  split("base_weeks depth ath_gap age price dollar_vol vol26 volx ret26 ext regime eff104", NM, " ")
  for (c = 6; c <= 17; c++) { nq = (c == 16) ? 2 : 5; printf "\n%s%s\n", NM[c - 5], (c == 16) ? " (Q1 = S&P not in an uptrend, Q2 = uptrend)" : sprintf(" cut-offs %s", "")
    if (c != 16) { printf "  cut-offs (2000-12):"; for (k = 1; k <= 4; k++) printf " %.4g", CUT[c, k]; printf "\n" }
    for (q = 1; q <= nq; q++) { line = ""; pass = 1
      for (h = 1; h <= 2; h++) { n = N[c, q, h]; rate = n ? MO[c, q, h] / n : 0; lift = rate / BR[h]; mr = n ? R[c, q, h] / n : 0
        if (!(lift >= 1.5 && mr > MR[h])) pass = 0
        line = line sprintf(" | %s n=%5d mon %5.2f%% lift %4.2f ride %+6.1f%% win %4.1f%% 2x %4.1f%%", (h == 1) ? "00-12" : "13-25", n, 100 * rate, lift, 100 * mr, n ? 100 * W[c, q, h] / n : 0, n ? 100 * B[c, q, h] / n : 0) }
      printf "  Q%d%s%s\n", q, line, pass ? "  <== PASSES" : "" } } }
