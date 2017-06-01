#!/usr/bin/perl
use warnings;
use strict;
use local::lib '/usr/src/perl/libs/sms-messenger/perl5';
use Daemon::Control;
my $path = "/usr/src/perl/sms-messenger";

exit Daemon::Control->new(
    name        => "SMS-Messenger",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'SMS Messenger',
    lsb_desc    => 'SMS Messenger controls the SMS Messenger daemon.',
    path        => "$path/messenger_daemon.pl",
    directory   => "$path",
#    init_config => "$path etc/environment",
    user        => 'castaway',
    group       => 'castaway',
    program     => "plackup -r -p 2366 $path/messenger.pl",
#    program_args => [ '-r', '-p 2366', "$path/messenger.pl" ],
    
    pid_file    => '/var/run/sms_messenger.pid',
    stderr_file => '/tmp/sms_messenger_err.out',
    stdout_file => '/tmp/sms_messenger.out',
 
    fork        => 2,
 
    )->run;
