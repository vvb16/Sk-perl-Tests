#!/usr/bin/perl
use strict; use warnings;

package VVB::Test::Base;

use base qw<Test::Class Class::Data::Inheritable>;

use Test::Most;
use IXXAT::VCI3 qw(pvciInitialize pvciFormatError openChannel channelActivate readMessage);

our $channel;

INIT
{
  Test::Class->runtests;
}

sub fail_if_returned_early { 1 }

sub startup : Test(startup)
{
  my $test = shift;

  return if $channel;
  diag "CAN initialization...";

  my $result;
  $result = pvciInitialize();
  $test->BAILOUT(__FILE__ . ":" . __LINE__ . ":" .pvciFormatError($result)) if $result != 0;
  $result = openChannel($channel);
  $test->BAILOUT(__FILE__ . ":" . __LINE__ . ":" .pvciFormatError($result)) if $result != 0;
  $test->BAILOUT(__FILE__ . ":" . __LINE__ . ":" ."channel undefined") if !(defined $channel);
  $result = channelActivate($channel);
  $test->BAILOUT(__FILE__ . ":" . __LINE__ . ":" .pvciFormatError($result)) if $result != 0;
  my $response = {};
  my $reason;
  for (1..10)
  {
    $result = readMessage($channel, 1, $response);
    $test->BAILOUT(__FILE__ . ":" . __LINE__ . ":" .pvciFormatError($result)) if $result != 0;
    next if $response->{type} != 1;
    $test->BAILOUT(__FILE__ . ":" . __LINE__ . ":" ."type should be 1 (INFO) got " . $response->{type}) if $response->{type} != 1;
    $test->BAILOUT(__FILE__ . ":" . __LINE__ . ":" ."Id should be 0xFFFFFFFF got " . $response->{Id}) if $response->{Id} != 0xFFFFFFFF;
    $reason = unpack('C', $response->{data});
    last if $reason == 1;
    $test->BAILOUT(__FILE__ . ":" . __LINE__ . ":" ."reason should be 3 (RESET) got " . $reason) if $reason != 3;
  }
  $test->BAILOUT(__FILE__ . ":" . __LINE__ . ":" ."reason should be 1 (START) got " . $reason) if $reason != 1;

  $result = readMessage($channel, 1000, $response);
  $test->BAILOUT(__FILE__ . ":" . __LINE__ . ":" .pvciFormatError($result)) if $result != 0xE001000B;
}

1;
