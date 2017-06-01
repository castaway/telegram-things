package SMSMessenger::APIs;

use strict;
use warnings;

use Moo;
use WWW::Twilio::API;
use WWW::Telegram::BotAPI;

has 'app_cwd' => ( is => 'ro', default => sub {''});
has 'twilio_api' => ( is => 'ro',
                      lazy => 1,
                      default => sub {
                          my ($self) = @_;
                          WWW::Twilio::API->new(
                              AccountSid => $self->config->{Twilio}{keys}{sid},
                              AuthToken => $self->config->{Twilio}{keys}{token},
                              )
                      });
has 'config' => ( is => 'ro',
                  lazy => 1,
                  default => sub {
                      my ($self) = @_;
                      +{ Config::General->new($self->app_cwd . 'messenger.conf')->getall};
                  });
has 'tg_api', (is => 'ro',
               lazy => 1,
               default => sub {
                   WWW::Telegram::BotAPI->new(
                       token => $_[0]->config->{Telegram}{bot_token},
                       );
               });


1;
