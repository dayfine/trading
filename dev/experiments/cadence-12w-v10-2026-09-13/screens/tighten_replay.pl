#!/usr/bin/perl
# tighten_replay.pl <trades.csv> <weeks-file> <w_pct> : for positions OPEN on a listed week (first such week), from the
# next trading day replay a w% trailing stop (stop = running high since signal * (1-w), checked against daily lows,
# split-adjusted); if hit before the actual exit, book pnl at the stop; else keep actual pnl. Prints gain vs actual.
use strict; use warnings;
my ($trades,$weeks,$w)=@ARGV; $w/=100; my @Wk; open my $f,'<',$weeks or die; while(<$f>){chomp; push @Wk,$_ if /^\d{4}-\d\d-\d\d$/} close $f; @Wk=sort @Wk;
my %bars; sub load { my $s=shift; return $bars{$s} if exists $bars{$s}; my $p="data/".substr($s,0,1)."/".substr($s,-1)."/$s/data.csv"; my @r; if(open my $g,'<',$p){ <$g>; while(<$g>){ my @c=split /,/; next unless $c[4] && $c[5]; my $k=$c[5]/$c[4]; push @r,[$c[0],$c[2]*$k,$c[3]*$k,$c[5]] } close $g } $bars{$s}=@r?\@r:undef }
my ($n,$hit,$act,$cf,$skip)=(0,0,0,0,0); my %by;
open my $t,'<',$trades or die; <$t>;
while(<$t>){ chomp; my @c=split /,/; my ($sym,$e,$x,$ep,$qty,$pnl)=@c[0,2,3,5,7,8]; my $wk; for my $d (@Wk){ if($d ge $e && $d lt $x){$wk=$d; last} } next unless $wk;
  my $b=load($sym); unless($b){$skip++; next} my ($ae,$hi,$out); for my $r (@$b){ next if $r->[0] lt $e; unless(defined $ae){$ae=$r->[3]} last if $r->[0] gt $x; next unless $r->[0] gt $wk; $hi=$r->[3] unless defined $hi; $hi=$r->[1] if $r->[1]>$hi; if($r->[2]<=$hi*(1-$w)){ $out=$hi*(1-$w); last } }
  unless(defined $ae){$skip++; next} $n++; $act+=$pnl; my $y=substr($wk,0,4); $by{$y}{a}+=$pnl;
  if(defined $out){ $hit++; my $p=$qty*$ep*($out/$ae-1); $cf+=$p; $by{$y}{c}+=$p } else { $cf+=$pnl; $by{$y}{c}+=$pnl } }
printf "  n=%d hit=%d actual %+.0f tightened %+.0f gain %+.0f (skipped %d)\n",$n,$hit,$act,$cf,$cf-$act,$skip;
