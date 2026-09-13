#!/usr/bin/perl
# by_state.pl <trades.csv>: entries grouped by the breadth state of the latest weekly screen row strictly before entry_date.
use strict; use warnings; my @S; open my $s,'<','/tmp/claude-states.txt' or die; while(<$s>){chomp; my ($d,$b,$t)=split; push @S,[$d,$b,$t]} close $s;
my (%n,%p,%w,%sl,%rot); open my $t,'<',$ARGV[0] or die; <$t>; while(<$t>){ chomp; my @c=split /,/; my ($e,$pnl,$trig)=($c[2],$c[8],$c[12]); my $st="?"; for my $r (reverse @S){ if($r->[0] lt $e){ $st=$r->[1]; last } } $n{$st}++; $p{$st}+=$pnl; $w{$st}++ if $pnl>0; $sl{$st}++ if $trig eq 'stop_loss'; $rot{$st}++ if $trig eq 'laggard_rotation' }
for my $k (qw(Bullish_breadth Neutral_breadth Recovering Deteriorating Bearish_breadth)){ next unless $n{$k}; printf "  %-16s n=%3d pnl %+9.0f  mean %+7.0f  win %2.0f%%  stop %2.0f%%  rot %2.0f%%\n",$k,$n{$k},$p{$k},$p{$k}/$n{$k},100*$w{$k}/$n{$k},100*($sl{$k}||0)/$n{$k},100*($rot{$k}||0)/$n{$k} }
