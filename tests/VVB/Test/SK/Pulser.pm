#!/usr/bin/perl
use strict; use warnings;

package VVB::Test::SK::Pulser;
use base 'VVB::Test::SK::Base';

use Test::Most;

sub _t01_Pulser_found : Tests(1)
{
  my $self = shift;
  die_on_fail;

  my @pulsers = grep { $_->{id} == 0x10 } @{$self->{devices}};
  is(scalar @pulsers, 1, "Exactly one Pulser should be found");
  $self->set_device_id(0x10); 
  $self->reset_cmd_count(); 
}

sub t10_device_default_mode : Tests(3)
{
  my $self = shift;

  my $result = $self->SK_command_execute(100, 0x20, pack('C2', 0, 0));
  cmp_ok($result, '==', 0, "command 0x06 should succeed") || diag $result;
  is(length($result), 1, "answer length of 0x20 should be 1");
  my ($resp) = unpack('C', $result);

  TODO: {
    local $TODO = "This is wrong command for Pulser";
    is($resp, 0, "answer mode should match");
  }
}

sub t11_device_status : Tests(4)
{
  my $self = shift;
  my $code = 1;

    my $result = $self->SK_command_execute(100, 0x06, pack('C1', $code));
    cmp_ok($result, '==', 0, "command 0x06 should succeed") || diag $result;
    is(length($result), 3, "answer length of 0x06 should be 3");
    my ($resp_code, $resp) = unpack('CS', $result);
    is($resp_code, $code, "answer code should match");
    is($resp, 0, "answer status should be 0");
    diag sprintf("0x06 Resp:\t0x%X", $resp);
}

sub t20_clear_mode : Tests(12)
{
  my $self = shift;

  for my $mode (0..1)
  {
    my $result = $self->SK_command_execute(100, 0x23, pack('C2x1', 1, $mode));
    cmp_ok($result, '==', 0, "command 0x23 should succeed") || diag $result;
    is(length($result), 3, "answer length of 0x23 should be 3");
    my ($resp_mode, $resp_pack, $resp_pos) = unpack('C3', $result);
    is($resp_mode, $mode, "answer mode should match");
    diag sprintf("0x23 Pack, Pos:\t%d\t%d", $resp_pack, $resp_pos);

    TODO: {
    local $TODO = "Possibly not implemented in device";

    my $result = $self->SK_command_execute(100, 0x25, pack('C2', $mode, 0));
    cmp_ok($result, '==', 0, "command 0x25 should succeed") || diag $result;
    is(length($result), 3, "answer length of 0x25 should be 3");
    my ($resp_mode, $resp_pack, $resp_is_end) = unpack('C3', $result);
    is($resp_mode, $mode, "answer mode should match");
    diag sprintf("0x25 Pack, Pos:\t%X\t%X", $resp_pack, $resp_is_end);
    }
  }
}


1;
