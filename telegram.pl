#!/usr/bin/perl
use feature 'say';
use strictures 2;
use local::lib '/usr/src/perl/libs/sms-messenger/perl5';

use Config::General;
#use WWW::Telegram::BotAPI;
use Data::Printer;
use Data::Dumper;
use Try::Tiny;

use lib 'lib';
use SMSMessenger::APIs;


$|++;
my $conf_file = '/usr/src/perl/sms-messenger/messenger.conf';
my $cg = Config::General->new($conf_file);
my $config = +{ $cg->getall };

my $apis = SMSMessenger::APIs->new(app_cwd => '/usr/src/perl/sms-messenger/');

#my $tg_api = WWW::Telegram::BotAPI->new(
#    token => $config->{Telegram}{bot_token},
#    );

my $bot_name = 'jandj_bot';    
my $tg_me = $apis->tg_api->getMe;
#p $tg_me;

# WTF?  When this is set to 60 seconds, I get a timeout in 30 seconds.  
# Setting it to 30 gives a timeout in 20 seconds.
# This was due to Mojo::UserAgent having its own extra timeout
# https://core.telegram.org/bots/api#getupdates
my $longpoll_timeout = 30;
$apis->tg_api->agent->inactivity_timeout($longpoll_timeout + 10);

my $message_id = -1024;
while (1) {
    say "Long-polling for messages starting at id $message_id";
    my $updates;

    try {
        $updates = $apis->tg_api->getUpdates({offset => $message_id,
                                           limit => 1,
                                           timeout => $longpoll_timeout
                                       });
    } catch {
        if ($_ =~ m/ERROR: Inactivity timeout/) {
            say "(Ignoring inactivity timeout)";
            $updates->{result} = [];
        } else {
            die $_;
        }
    };
    
    for my $update (@{$updates->{result}}) {
        handle_message($update);
        $message_id = $update->{update_id} + 1;
    }
}

sub handle_message {
    my ($message) = @_;
    
    p $message;

    my $send_to_number;
    my $set_number;
    if ($message->{message}{reply_to_message} and
        $message->{message}{reply_to_message}{text} =~ m/^Incoming SMS from ([\d \+]+)/
        ) {
        $send_to_number = $1;
    } elsif ($message->{message}{text} =~ m{/(\w+)(?:\@$bot_name)?\s(\+[\d ()-.,]+):}) {
        if($1 eq 'send') {
            $send_to_number = $2;
        } elsif ($1 eq 'set_number') {
            $set_number = $2;
        } else {
            print "Don't recognize command: $1\n";
        }
    }

    if($send_to_number) {
        my $text = $message->{message}{text};
        if ($message->{message}{from}{username} eq 'theorbtwo') {
            $text = "JMM: $text";
        } elsif ($message->{message}{from}{username} eq 'castaway') {
            $text = "JAR: $text";
        } else {
            $text = $message->{message}{from}{username} . ": " . $text;
        }
    
        send_sms($send_to_number, $message->{message}{text});
        if (defined $send_to_number) {
            say "Should be sending SMS: ($send_to_number, $message->{message}{text})";
        }
    }
    if($set_number) {
        $config->{Groups}{ $message->{chat}{id} } = $set_number;
        $cg->save_file($conf_file, $config);
    }
}

sub send_sms {
    my ($to, $mesg) = @_;
    my $response = $apis->twilio_api->POST('SMS/Messages',
                          From => $config->{SMS}{OurNumber},
                          To   => $to,
                                           Body => $mesg );

    print STDERR "Sent sms, response: ", Dumper $response;
}
