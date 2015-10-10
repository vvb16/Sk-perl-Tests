#!/usr/bin/perl
use strict; use warnings;

package VVB::Test::SK::Base;
use base 'VVB::Test::Base';

use Test::Most;
use IXXAT::VCI3 qw(pvciFormatError readMessage sendMessage);
use Scalar::Util qw(dualvar);
use List::Util qw(min);
use Time::HiRes;
use POSIX;

VVB::Test::SK::Base->SKIP_CLASS( 1 );

sub set_device_id
{
  my $test = shift;
  $test->{device_id} = shift;
}

sub reset_cmd_count
{
  my $test = shift;
  $test->{cmd_count} = 0;
}

sub SK_command_execute
{
  my $test = shift;
  my ($timeout, $command, $data) = @_;
  my $result;
  my $response = {};

  return dualvar(-1, "too long command: " . length($data)) if length($data) > 6;

  $test->{cmd_count} = ($test->{cmd_count} + 1) & 0xFF;
  $result = sendMessage($VVB::Test::Base::channel, $timeout,
    $test->{device_id}, length($data) + 2,
    pack('C2', $test->{cmd_count}, $command) . $data);
  return dualvar(-1, "sendMessage error: " . pvciFormatError($result)) if $result != 0;

  $result = readMessage($VVB::Test::Base::channel, $timeout, $response);
  return dualvar(-1, "readMessage error: " . pvciFormatError($result)) if $result != 0;
  return dualvar(-1, "answer type should be 0 (DATA) got " . $response->{type}) if $response->{type} != 0;
  return dualvar(-1, "answer length should be at least 2 got " . length($response->{data})) if length($response->{data}) < 2;
  my ($cmd_count, $cmd, $resp_data) = unpack('C2a*', $response->{data});
  return dualvar(-1, sprintf("answer command counter should be %d got %d", $test->{cmd_count}, $cmd_count)) if $cmd_count != $test->{cmd_count};
  return dualvar(-1, sprintf("answer command should be 0x%X (RESPONSE_OK) got 0x%X", ($command | 0x80), $cmd)) if $cmd != ($command | 0x80);

  return dualvar(0, $resp_data);
}

sub check_CAN_channel #: Tests(1)
{
  my $test = shift;
  die_on_fail;
  ok(defined $VVB::Test::Base::channel, "CAN channel connection");
}

sub find_devices #: Tests(3)
{
  my $test = shift;
  my $response = {};

  my $command = pack('C*', 0);
  my $result = sendMessage($VVB::Test::Base::channel, 10, 0x0, length($command), $command);
  return dualvar(-1, "sendMessage error: " . pvciFormatError($result)) if $result != 0;

  while (1)
  {
    $result = readMessage($VVB::Test::Base::channel, 1000, $response);
    last if $result == 0xE001000B;
    return dualvar(-1, "readMessage error: " . pvciFormatError($result)) if $result != 0;
    return dualvar(-1, "answer type should be 0 (DATA) got " . $response->{type}) if $response->{type} != 0;
    return dualvar(-1, "answer length should be 5 got " . length($response->{data})) if length($response->{data}) != 5;
    my ($code, $id, $serial) = unpack('CS2', $response->{data});
    return dualvar(-1, "answer code should be 128 (RESPONSE_OK) got " . $code) if $code != 0x80;
    diag sprintf("Found device ID: 0x%X\tSerial: %d", $id, $serial);
    push $test->{devices}, {id => $id, serial => $serial};
  }
  return dualvar(0, "");
}

sub startup : Tests(startup => 3)
{
  my $test = shift;
  die_on_fail;

  SKIP: {
    skip "Already initialized", 3 if $test->{devices};
    $test->{devices} = [];
    $test->SUPER::startup();
    $test->check_CAN_channel();
    my $result = $test->find_devices();
    cmp_ok($result, '==', 0, "find_devices should succeed") || diag $result;
    cmp_ok(scalar(@{$test->{devices}}), '>', 0, "at least one device should present");
  }
}

sub t05_SW_VER : Tests(2)
{
  my $test = shift;

  my $result = $test->SK_command_execute(100, 0x00, '');
  cmp_ok($result, '==', 0, "command SW_VER should succeed") || diag $result;
  is(length($result), 4, "answer length of SW_VER should be 4");
  diag sprintf("SW_VER: 0x%X", unpack('L', $result));
}

sub t06_runtime_stats : Tests(21)
{
  my $test = shift;
  my @dict = ("power cycles",
    "total time",
    "time at t < 0",
    "time at 0 < t < 35",
    "time at 35 < t < 90",
    "time at 90 < t < 120",
    "time at t > 120",
  );
  my $code = 0;
  for my $descr (@dict)
  {
    my $result = $test->SK_command_execute(100, 0x01, pack('C', $code));
    cmp_ok($result, '==', 0, "command runtime_stats should succeed") || diag $result;
    is(length($result), 5, "answer length of runtime_stats should be 5");
    my ($resp_code, $duration) = unpack('CL', $result);
    is($resp_code, $code, "answer type of runtime_stats should match");
    diag sprintf("%s: %d", $descr, $duration);
    ++$code;
  }
}

1;
