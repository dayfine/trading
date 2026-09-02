#!/usr/bin/perl
# Extract per-position decision-time fields from trade_audit.sexp → CSV on stdout.
# cols: position_id,symbol,entry_date,E,close_dec,local_top,inst_stop,floor_kind,screen_vr,age_wk,verdict,spike,buildup,outcome,stage_weeks,cascade_grade
use strict; local $/; my $t=<STDIN>;
print "position_id,symbol,entry_date,E,close_dec,local_top,inst_stop,floor_kind,screen_vr,age_wk,verdict,spike,buildup,outcome,stage_weeks,grade\n";
while ($t =~ /\(entry\s*\(\(symbol (\S+)\) \(entry_date (\S+)\) \(position_id (\S+)\)(.*?)\(alternatives_considered/gs) {
  my ($sym,$d,$pid,$b)=($1,$2,$3,$4);
  my $g = sub { my $re=shift; $b =~ /$re/s ? $1 : "" };
  my $E=$g->(qr/\(suggested_entry ([0-9.eE+-]+)\)/); my $cd=$g->(qr/\(close_at_decision ([0-9.eE+-]+)\)/);
  my $lt=$g->(qr/\(local_range_top ([0-9.eE+-]+)\)/); my $is=$g->(qr/\(installed_stop ([0-9.eE+-]+)\)/);
  my $fk=$g->(qr/\(stop_floor_kind (\S+?)\)/); my $vr=$g->(qr/\(volume_ratio \(?([0-9.eE+-]+)\)?\)/);
  my $age=$g->(qr/\(ticket_age_weeks_at_fill (\d+)\)/); my $sw=$g->(qr/\(weeks_advancing (\d+)\)/); my $gr=$g->(qr/\(cascade_grade (\S+?)\)/);
  my ($verdict,$spike,$bu,$out)=("","","","");
  if ($b =~ /\(fill_volume\s*\(\(verdict\s*(.*?)\)\s*\(outcome (\w+)\)\)\)/s) {
    my $v=$1; $out=$2;
    if ($v =~ /^\((?:Confirmed_spike|Spike) ([0-9.eE+-]+)\)/) { $verdict="Spike"; $spike=$1 }
    elsif ($v =~ /^\((?:Confirmed_buildup|Buildup) ([0-9.eE+-]+)\)/) { $verdict="Buildup"; $bu=$1 }
    elsif ($v =~ /Unconfirmed/) { $verdict="Unconfirmed"; $spike=$1 if $v=~/\(spike_ratio \(([0-9.eE+-]+)\)\)/; $bu=$1 if $v=~/\(buildup_multiple \(([0-9.eE+-]+)\)\)/ }
    else { $verdict="None" }
  } elsif ($b =~ /\(fill_volume\s*\(\(verdict \(\)\)\s*\(outcome (\w+)\)\)\)/s) { $verdict="None"; $out=$1 }
  elsif ($b =~ /\(fill_volume \(\)\)/) { $verdict="NOFIELD" }
  print join(",",$pid,$sym,$d,$E,$cd,$lt,$is,$fk,$vr,$age,$verdict,$spike,$bu,$out,$sw,$gr),"\n";
}
