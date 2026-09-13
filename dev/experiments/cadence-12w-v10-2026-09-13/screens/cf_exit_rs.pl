#!/usr/bin/perl
# cf_exit_rs.pl <trades.csv> <weeks-file> <lookback_weeks> <rs_threshold>
# Positions OPEN on a listed week (first such week per position) are split by relative strength at that week:
# rs = stock adj-close return over <lookback> weeks minus the GSPC return over the same span. "poor" = rs < threshold.
# For each subset prints n, actual final pnl, exit-next-close pnl, gain-from-exit.
use strict; use warnings; use POSIX;
my ($trades,$weeks,$lb,$thr)=@ARGV; $lb||=13; $thr=0 unless defined $thr;
my @W; open my $w,'<',$weeks or die; while(<$w>){chomp; push @W,$_ if /^\d{4}-\d\d-\d\d$/} close $w; @W=sort @W;
my %adj; sub load { my $s=shift; return $adj{$s} if exists $adj{$s}; my $p="data/".substr($s,0,1)."/".substr($s,-1)."/$s/data.csv"; my (%h,@d); if(open my $f,'<',$p){ <$f>; while(<$f>){ my @c=split /,/; next unless defined $c[5] && $c[5] ne ''; $h{$c[0]}=$c[5]; push @d,$c[0] } close $f } $adj{$s}= %h ? {h=>\%h,d=>\@d} : undef; return $adj{$s} }
sub at_or_after { my ($o,$d)=@_; for my $x (@{$o->{d}}){ return $o->{h}{$x} if $x ge $d } undef }
sub at_or_before { my ($o,$d)=@_; my $v; for my $x (@{$o->{d}}){ last if $x gt $d; $v=$o->{h}{$x} } $v }
sub after { my ($o,$d)=@_; for my $x (@{$o->{d}}){ return $o->{h}{$x} if $x gt $d } undef }
sub minus_weeks { my ($d,$n)=@_; my @p=split /-/,$d; strftime("%Y-%m-%d",localtime(mktime(0,0,12,$p[2],$p[1]-1,$p[0]-1900)-$n*7*86400)) }
my $idx=load("GSPC.INDX") or die "no index";
my %acc; my ($skip)=(0);
open my $t,'<',$trades or die; <$t>;
while(<$t>){ chomp; my @c=split /,/; my ($sym,$entry,$exit,$ep,$qty,$pnl)=($c[0],$c[2],$c[3],$c[5],$c[7],$c[8]);
  my $wk; for my $d (@W){ if($d ge $entry && $d lt $exit){ $wk=$d; last } } next unless $wk;
  my $o=load($sym); unless($o){ $skip++; next } my $ae=at_or_after($o,$entry); my $ax=after($o,$wk);
  my $s1=at_or_before($o,$wk); my $s0=at_or_before($o,minus_weeks($wk,$lb)); my $i1=at_or_before($idx,$wk); my $i0=at_or_before($idx,minus_weeks($wk,$lb));
  unless($ae&&$ax&&$s1&&$s0&&$i1&&$i0){ $skip++; next }
  my $rs=($s1/$s0-1)-($i1/$i0-1); my $sub = $rs<$thr ? "poor" : "leader"; my $cf=$qty*$ep*($ax/$ae-1);
  $acc{$sub}{n}++; $acc{$sub}{a}+=$pnl; $acc{$sub}{c}+=$cf }
for my $sub (qw(poor leader)){ my $r=$acc{$sub}||{n=>0,a=>0,c=>0}; printf "  %-6s n=%3d actual %+10.0f exit-next-close %+10.0f gain-from-exit %+10.0f\n",$sub,$r->{n},$r->{a},$r->{c},$r->{c}-$r->{a} }
print "  (skipped $skip)\n" if $skip;
