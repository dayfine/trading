# rules.awk -- the two pre-registered rules (README §Decision rule), applied mechanically to the gate lines the read
# writes: G_* from gbc.awk (one line of key value pairs) and "CF class n mean monster_rate monsters" lines from cf.awk.
# POSIX awk. usage: cat gbcgates.txt cfgates.txt | awk -v YARD="<log/trade> <ln(1+R)> <trades>" -f rules.awk
# read/rules_check.sh feeds it fabricated lines for every branch (results/smoke/rules_check.txt).
/^G_/ { for (i = 1; i < NF; i += 2) v[$i] = $(i + 1); next }
/^CF / { n[$2] = $3; mean[$2] = $4; mr[$2] = $5; mon[$2] = $6 }
END {
  EPS = 1e-9   # a bar met exactly counts as met; guards the float subtraction in the ride clause
  split(YARD, Y, " "); yd = Y[1]; f = v["G_f"]
  printf "Rule inputs: m %.4f | f %.4f | s %.4f | X gross %d (X.f %.1f) | X net %s | X ref %s | yardstick %.6f log per trade | path-aware X (information): gross %s, net %s\n", v["G_m"], f, v["G_s"], v["G_XG"], v["G_XG"] * f, v["G_XN"], v["G_XR"], yd, v["G_PG"], v["G_PN"]
  printf "C* (net) vs funded, mean capped ride: %+.2f %% (n %d) vs %+.2f %% (n %d); monster %.1f %% vs %.1f %% | bear years 2000-02 + 2008: share of X ref %s, of open Fridays %.4f (+ 0.10 = %.4f)\n", 100 * mean["crowd:net"], n["crowd:net"], 100 * mean["walk:Funded"], n["walk:Funded"], 100 * mr["crowd:net"], 100 * mr["walk:Funded"], v["G_bear_x"], v["G_bear_open"], v["G_bear_open"] + 0.10
  if (v["G_net_ok"] != 1) r1 = sprintf("NOT APPLIED (long_resting_reserved_pct absent on some open Friday, so X net cannot be computed; X gross %d, X gross.f %.1f, %.3f log at the yardstick, is reported only)", v["G_XG"], v["G_XG"] * f, v["G_XG"] * f * yd)
  else if (v["G_XN"] * f < 25 - EPS) r1 = sprintf("CLOSE (X net.f = %.1f < 25, about %.3f log at the yardstick: gate-before-cap dead, no build)", v["G_XN"] * f, v["G_XN"] * f * yd)
  else {
    c1 = (v["G_XR"] * f >= 40 - EPS); c2 = (mean["crowd:net"] >= mean["walk:Funded"] - 0.01 - EPS); c3 = (v["G_bear_x"] <= v["G_bear_open"] + 0.10 + EPS)
    printf "REFINE: X ref.f %.1f >= 40: %s | C* mean ride >= funded - 1 pp: %s | bear share within open share + 10 pp: %s\n", v["G_XR"] * f, (c1 ? "yes" : "no"), (c2 ? "yes" : "no"), (c3 ? "yes" : "no")
    r1 = (c1 && c2 && c3) ? sprintf("BUILD (a default-off flag + a K=5 paired pre-registration, never a promotion; X ref.f %.1f, about %.3f log at the yardstick)", v["G_XR"] * f, v["G_XR"] * f * yd) : sprintf("PARK (X net.f %.1f >= 25 but the refined bars are not all met)", v["G_XN"] * f)
  }
  printf "Rule 1 (gate before cap), mechanical: %s\n", r1
  a = "tier:A_plus"; b = "tier:A"
  up = 0; for (h = 1; h <= 2; h++) { if (n[a "|h" h] < 100 || n[b "|h" h] < 100 || mon[a "|h" h] + mon[b "|h" h] < 20) up = 1 }
  d1 = mean[a "|h1"] - mean[b "|h1"]; d2 = mean[a "|h2"] - mean[b "|h2"]; ratio = (mr[b] > 0) ? mr[a] / mr[b] : 0
  printf "Rule 2 inputs: A+ vs A mean capped ride 2000-12 %+.2f pp (n %d / %d), 2013-26 %+.2f pp (n %d / %d); monster rate %.1f %% vs %.1f %% = x%.2f (monsters %d / %d)\n", 100 * d1, n[a "|h1"], n[b "|h1"], 100 * d2, n[a "|h2"], n[b "|h2"], 100 * mr[a], 100 * mr[b], ratio, mon[a], mon[b]
  if (up) r2 = "UNDERPOWERED (a tier has under 100 rows in a half, or the two tiers under 20 monsters in a half): no ranking lever follows"
  else if (d1 >= 0.02 - EPS && d2 >= 0.02 - EPS && ratio >= 1.3 - EPS) r2 = "RANKING LEVER (the top tier beats the next by >= 2 pp in both halves and >= 1.3x monster rate): a later pre-registration may follow"
  else r2 = "NO RANKING LEVER (the top tier does not beat the next by the bars)"
  printf "Rule 2 (score tier), mechanical: %s\n", r2
}
