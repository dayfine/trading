#!/usr/bin/perl
# cf_exit.pl <trades.csv> <weeks-file> : for each position OPEN on a listed week (first such week per position),
# counterfactual = exit at the first close AFTER that week's date, priced by the adjusted_close ratio from the CSV store.
# Prints per cluster-year: n, actual final pnl, counterfactual pnl, gain-from-exiting (cf - actual), and skipped symbols.
use strict; use warnings; use POSIX;
my ($trades,$weeks,$lag)=@ARGV; $lag||=0; my @W; open my $w,'<',$weeks or die; while(<$w>){chomp; push @W,$_ if /^\d{4}-\d\d-\d\d$/} close $w; @W=sort @W;
my %adj; sub load { my $s=shift; return $adj{$s} if exists $adj{$s}; my $p="data/".substr($s,0,1)."/".substr($s,-1)."/$s/data.csv"; my %h; if(open my $f,'<',$p){ my $hdr=<$f>; while(<$f>){ my @c=split /,/; $h{$c[0]}=$c[5] if defined $c[5] && $c[5] ne '' } close $f } $adj{$s}= %h ? \%h : undef; return $adj{$s} }
sub at_or_after { my ($h,$d)=@_; my @ds=sort keys %$h; for my $x (@ds){ return $h->{$x} if $x ge $d } return undef }
sub after { my ($h,$d)=@_; my @ds=sort keys %$h; for my $x (@ds){ return ($x,$h->{$x}) if $x gt $d } return () }
my (%n,%act,%cf,%skip,%nskip); open my $t,'<',$trades or die; my $hdr=<$t>;
while(<$t>){ chomp; my @c=split /,/; my ($sym,$entry,$exit,$ep,$qty,$pnl)=($c[0],$c[2],$c[3],$c[5],$c[7],$c[8]);
  my $wk; for my $d (@W){ if($d ge $entry && $d lt $exit){ $wk=$d; last } } next unless $wk; my $y=substr($wk,0,4);
  my $h=load($sym); if(!$h){ $nskip{$y}++; $skip{$y}.=" $sym"; next }
  my $ae=at_or_after($h,$entry); my $wl=$wk; if($lag){ my @p=split /-/,$wk; my $t=POSIX::mktime(0,0,12,$p[2],$p[1]-1,$p[0]-1900)+$lag*86400; $wl=POSIX::strftime("%Y-%m-%d",localtime($t)) } my ($xd,$ax)=after($h,$wl); if(!$ae||!$ax){ $nskip{$y}++; $skip{$y}.=" $sym?"; next }
  my $cfp=$qty*$ep*($ax/$ae-1); $n{$y}++; $act{$y}+=$pnl; $cf{$y}+=$cfp }
close $t; my ($N,$A,$C)=(0,0,0);
for my $y (sort keys %n){ printf "  %s  n=%3d  actual %+10.0f  exit-next-close %+10.0f  gain-from-exit %+10.0f%s\n",$y,$n{$y},$act{$y},$cf{$y},$cf{$y}-$act{$y},($nskip{$y}?"  (skipped $nskip{$y}:$skip{$y})":""); $N+=$n{$y};$A+=$act{$y};$C+=$cf{$y} }
printf "  TOTAL n=%d actual %+.0f exit-next-close %+.0f gain-from-exit %+.0f\n",$N,$A,$C,$C-$A;
