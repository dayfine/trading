#!/usr/bin/perl
# width_curve.pl <trades.csv> : replay narrower INITIAL stop widths on an arm's own trades using daily lows (split-adjusted
# via adjusted_close/close). For each width w: a trade is "stopped" if some low between entry and its actual exit is
# <= entry*(1-w); stopped trades are booked at -w (approx: fill at the stop), survivors keep their actual pnl.
# Two horizons: full life (until actual exit) and first 60 trading days (before trail raises matter much).
use strict; use warnings;
my %bars; sub load { my $s=shift; return $bars{$s} if exists $bars{$s}; my $p="data/".substr($s,0,1)."/".substr($s,-1)."/$s/data.csv"; my @r; if(open my $f,'<',$p){ <$f>; while(<$f>){ my @c=split /,/; next unless $c[4] && $c[5]; push @r,[$c[0],$c[3]*$c[5]/$c[4],$c[5]] } close $f } $bars{$s}=@r?\@r:undef }
my @W=(4,5,6,7,8,9,10,11,12); my (%stop,%loss,%surv_p,%stop60,%loss60,%surv60); my ($n,$skip,$act)=(0,0,0);
open my $t,'<',$ARGV[0] or die; <$t>;
while(<$t>){ chomp; my @c=split /,/; my ($sym,$e,$x,$ep,$qty,$pnl)=@c[0,2,3,5,7,8]; my $b=load($sym); unless($b){$skip++; next}
  my ($ae,$mae,$mae60,$k)=(undef,0,0,0); for my $r (@$b){ next if $r->[0] lt $e; last if $r->[0] gt $x; unless(defined $ae){ $ae=$r->[2] } $k++; my $d=$r->[1]/$ae-1; $mae=$d if $d<$mae; $mae60=$d if $k<=60 && $d<$mae60 }
  unless(defined $ae){$skip++; next} $n++; $act+=$pnl; my $notional=$qty*$ep;
  for my $w (@W){ if($mae<=-$w/100){ $stop{$w}++; $loss{$w}-= $notional*$w/100 } else { $surv_p{$w}+=$pnl }
                  if($mae60<=-$w/100){ $stop60{$w}++; $loss60{$w}-= $notional*$w/100 } else { $surv60{$w}+=$pnl } } }
printf "  trades %d (skipped %d)  actual arm pnl %+.0f\n",$n,$skip,$act;
printf "  %-5s | %-40s | %-40s\n","width","FULL LIFE: stopped  survivors-pnl  total","FIRST 60d: stopped  survivors-pnl  total";
for my $w (@W){ printf "  %3d%%  | %5d  %+11.0f  %+11.0f   | %5d  %+11.0f  %+11.0f\n",$w,$stop{$w}||0,$surv_p{$w}||0,($surv_p{$w}||0)+($loss{$w}||0),$stop60{$w}||0,$surv60{$w}||0,($surv60{$w}||0)+($loss60{$w}||0) }
