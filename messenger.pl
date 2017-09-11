package SMS::Messenger;

use local::lib '/usr/src/perl/libs/sms-messenger/perl5';

use Web::Simple;
use Config::General;
use JSON::XS;
use Template;
use Path::Class;
use Data::Dumper;
use Number::Phone;

use lib 'lib';
use SMSMessenger::APIs;

has 'app_cwd' => ( is => 'ro', default => sub {'/usr/src/perl/sms-messenger/'});
has 'tt' => (is => 'ro', lazy => 1, builder => '_build_tt');
has 'apis' => ( is => 'ro', default => sub { my ($self) = @_; SMSMessenger::APIs->new(app_cwd => $self->app_cwd ) }, lazy => 1 );
has 'config' => ( is => 'ro',
                  lazy => 1,
                  default => sub {
                      my ($self) = @_;
                      +{ Config::General->new($self->app_cwd . 'messenger.conf')->getall};
                  });


# Where things that have no better place to go end up.  Initially
# retrieved by the group_chat_created message that.  FIXME: Figure out
# a better way to unhardcode?
has 'tg_general_chatid' => (is => 'ro',
                            lazy => 1,
                            default => sub { my ($self) = @_; return $self->config->{Telegram}{default_chat_id} });

sub _build_tt {
    my ($self) = @_;

    return Template->new({ 
        INCLUDE_PATH => dir($self->app_cwd)->subdir('templates')->stringify,
                         });
}

sub twilio {
    my ($self, $method, @args) = @_;

    my $response = $self->apis->twilio_api->$method(@args);
    $response->{result} = decode_json($response->{content});

    if($response->{code} != 200) {
        $response->{error} = $response->{result}{message};
    }
    return $response;
}

sub get_messages {
    my ($self) = @_;

    return $self->twilio('GET', 'Messages.json',
#        To => '+441158244431'
);
}

sub message_page {
    my ($self, $error, $messages) = @_;
    my $output;
    $self->tt->process('message_page.tt',
                       {
                           messages => $messages || [],
                           error => $error,
                       }
                       , \$output
        ) || die $self->tt->error;

    return $output;
}

sub dispatch_request {
    my ($self) = @_;
    
    sub (GET + /messages) {
        my $messages = $self->get_messages();
#        print STDERR "Messages: ", Dumper($messages);
        return [ $messages->{code},
                 [ 'Content-type', 'text/html' ],
                 [ $self->message_page($messages->{error}, $messages->{result}) ] ];
    },
    sub (POST + /new_message + %*) {
        print STDERR Dumper(\%_);

        my $in_number = $_{From};
        my $in_text = $_{Body};
        my $to_num = $_{To};
        my $number_object = Number::Phone->new($in_number);
        my @number_info;
        my $number_pretty;
        if (not $number_object) {
            @number_info = "unparseable $in_number";
            $number_pretty = '';
        } else {
            push @number_info, $number_object->country;
            push @number_info, $number_object->areaname if $number_object->areaname;
            push @number_info, $number_object->operator if $number_object->operator;
            for my $tag (qw<geographic fixed_line mobile pager ipphone isdn tollfree specialrate adult personal corporate government network_service>) {
                push @number_info, $tag if $number_object->can("is_$tag")->();
                $number_pretty = $number_object->format;           
            }
            my $number_info = join " ", @number_info;
            
            my $text = "Incoming SMS from $number_pretty ($number_info): $in_text";
            my $telegram_num = $self->config->{SMS}{OurNumber};
            print STDERR "To: >$to_num<, Our: $telegram_num\n";
            if($to_num =~ /\Q$telegram_num\E/) {
                print STDERR "Sending to Telegram...\n";
                $self->apis->tg_api->sendMessage({chat_id => $self->tg_general_chatid,
                                                  text => $text});
            }
        }
	
        
        return [ 200,
                 ['Content-type', 'text/xml' ],
                 [ '<?xml version="1.0" encoding="UTF-8"?><Response></Response>' ] ];
    };
}

SMS::Messenger->run_if_script;
