#!/usr/bin/perl
# Usage: alias-lists.pl <alias-map: "DROPPED SURVIVOR" per line> <list.sexp>...
# Rewrites each composition list in place: every entry whose symbol is a dropped twin leg is re-pointed at its
# survivor, then entries are deduped per list by symbol (first occurrence kept). Prints per-list counts.
use strict; use warnings;
my ($mapf, @lists) = @ARGV; my %alias;
open my $m, '<', $mapf or die; while (<$m>) { chomp; next unless /^(\S+)\s+(\S+)/; $alias{$1} = $2 } close $m;
for my $f (@lists) {
  local $/; open my $h, '<', $f or die "$f: $!"; my $s = <$h>; close $h;
  my ($ren, $dup, %seen) = (0, 0);
  $s =~ s{\(\(symbol (\S+)\)((?:[^()]|(\((?:[^()]|(?3))*\)))*)\)}{
    my ($sym, $rest) = ($1, $2);
    if (exists $alias{$sym}) { $sym = $alias{$sym}; $ren++ }
    if ($seen{$sym}++) { $dup++; "" } else { "((symbol $sym)$rest)" }
  }ge;
  $s =~ s/\n\s*\n/\n/g;
  open my $o, '>', $f or die; print $o $s; close $o;
  printf "%s: renamed=%d dropped-dups=%d entries=%d\n", $f, $ren, $dup, scalar(keys %seen);
}
