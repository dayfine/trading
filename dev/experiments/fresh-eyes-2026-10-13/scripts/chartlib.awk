# Fresh-eyes charts: shared SVG helpers (load after days.awk). Deterministic: every number is printed with a fixed
# format, so the same inputs give byte-identical SVG.
#
# Frame globals set by frame_init(cut, frame): FZ0, FZ1 (first / last week on the x-axis, day numbers), CUTZ,
# PL, PR (plot left / right x). "full" = fixed 2000-01-07..2026-06-26; "5y" = 260 weeks ending at the cut plus 26
# weeks of hidden future.

function frame_init(cut, frame) {
  CUTZ = friday(days(cut)); PL = 70; PR = W - 90
  if (frame == "full") { FZ0 = days("2000-01-07"); FZ1 = days("2026-06-26") }
  else { FZ0 = CUTZ - 259 * 7; FZ1 = CUTZ + 26 * 7 }
  BW = (PR - PL) / ((FZ1 - FZ0) / 7 + 1)
}
function xw(z) { return PL + ((z - FZ0) / 7 + 0.5) * BW }
function inframe(z) { return z >= FZ0 && z <= CUTZ && z <= FZ1 }
function f2(x) { return sprintf("%.2f", x) }
function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); return s }
function txt(x, y, s, size, anchor, extra) {
  printf "<text x=\"%s\" y=\"%s\" font-size=\"%d\" text-anchor=\"%s\"%s>%s</text>\n", f2(x), f2(y), size, anchor, extra, esc(s)
}
function line(x1, y1, x2, y2, stroke, wd, extra) {
  printf "<line x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"%s\" stroke-width=\"%s\"%s/>\n", f2(x1), f2(y1), f2(x2), f2(y2), stroke, wd, extra
}
function svg_open(h) {
  printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" font-family=\"Helvetica, Arial, sans-serif\">\n", W, h, W, h
  printf "<rect x=\"0\" y=\"0\" width=\"%d\" height=\"%d\" fill=\"#ffffff\"/>\n", W, h
}
# Year ticks along the bottom of a panel band [top, bot]; labels under bot when label = 1.
function year_axis(top, bot, label,   y, z) {
  for (y = 1999; y <= 2027; y++) {
    z = days(y "-01-01"); if (z < FZ0 || z > FZ1) continue
    line(PL + ((z - FZ0) / 7) * BW, top, PL + ((z - FZ0) / 7) * BW, bot, "#e4e4e4", 1, "")
    if (label) txt(PL + ((z - FZ0) / 7) * BW, bot + 14, y, 11, "middle", " fill=\"#444\"")
  }
}
# Grey block over the hidden future, from just after the cut week to the right edge, for one panel band.
function future_block(top, bot, label,   x) {
  x = xw(CUTZ) + BW / 2; if (x >= PR - BW / 2) return   # under one bar wide: no block, no label
  if (PR - x < 110) label = 0   # the label is ~100 px wide: draw it only where it fits
  printf "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"#cfcfcf\"/>\n", f2(x), f2(top), f2(PR - x), f2(bot - top)
  if (label) txt((x + PR) / 2, (top + bot) / 2, "future (hidden)", 14, "middle", " fill=\"#777\"")
}
function panel_box(top, bot) {
  printf "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"none\" stroke=\"#999\" stroke-width=\"1\"/>\n", f2(PL), f2(top), f2(PR - PL), f2(bot - top)
}
# Log price scale on [top, bot] for [lo, hi] (padded 4 % each side): sets YLO, YHI, YT, YB; draws grid + labels.
function logscale(top, bot, lo, hi,   a, b, e, k, m, v, n, steps, ns, y) {
  a = log(lo) - 0.04 * (log(hi) - log(lo) + 1e-9); b = log(hi) + 0.04 * (log(hi) - log(lo) + 1e-9)
  if (b - a < 0.05) { a -= 0.05; b += 0.05 }
  YLO = a; YHI = b; YT = top; YB = bot
  ns = split((b - a < log(10)) ? "1 1.5 2 3 4 5 6 7 8" : ((b - a < 2 * log(10)) ? "1 1.5 2 3 4 5 7" : "1 2 5"), steps, " ")
  for (e = int(a / log(10)) - 1; e <= int(b / log(10)) + 1; e++)
    for (k = 1; k <= ns; k++) {
      v = steps[k] * exp(e * log(10)); if (log(v) < a || log(v) > b) continue
      y = ly(v); line(PL, y, PR, y, "#ececec", 1, "")
      txt(PR + 6, y + 4, pfmt(v), 11, "start", " fill=\"#444\"")
    }
}
function ly(v) { return YB - (log(v) - YLO) / (YHI - YLO) * (YB - YT) }
function pfmt(v) { return (v >= 100) ? sprintf("%.0f", v) : ((v >= 10) ? sprintf("%.1f", v) : ((v >= 1) ? sprintf("%.2f", v) : sprintf("%.3f", v))) }
# Linear scale on [top, bot] for [lo, hi]: sets LLO, LHI, LT, LB.
function linscale(top, bot, lo, hi) { if (hi - lo < 1e-9) { hi += 1; lo -= 1 } LLO = lo; LHI = hi; LT = top; LB = bot }
function yl(v) { return LB - (v - LLO) / (LHI - LLO) * (LB - LT) }
function vfmt(v) { return (v >= 1e9) ? sprintf("%.1fB", v / 1e9) : ((v >= 1e6) ? sprintf("%.1fM", v / 1e6) : ((v >= 1e3) ? sprintf("%.0fK", v / 1e3) : sprintf("%.0f", v))) }
