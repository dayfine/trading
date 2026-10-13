# The short side's fat left tail on the no-stop outcome.
NR==1 { hdr(); next }
{ for (u = 1; u <= 2; u++) { if (u == 2 && !isP()) continue; key = (u == 1 ? "ALL" : "P1"); x = $(c["e1_o1_120"]); if (x == "") continue; x += 0
    n[key]++; s[key] += x; sc[key] += (x < -1) ? -1 : (x > 1 ? 1 : x); if (x < -0.5) { lo[key]++; slo[key] += x } if (x > 0.5) { hi[key]++; shi[key] += x } } }
END { for (key in n) printf "%s O1+120: n=%d mean %+.2f%% (clipped +-100%%: %+.2f%%); < -50%%: %d (%.1f%%, sum %+.0f pp); > +50%%: %d (%.1f%%, sum %+.0f pp)\n", key, n[key], 100*s[key]/n[key], 100*sc[key]/n[key], lo[key], 100*lo[key]/n[key], 100*slo[key], hi[key], 100*hi[key]/n[key], 100*shi[key] }
