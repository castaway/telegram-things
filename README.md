SMS Messenger
=============

Setup/howto:

* Twilio messaging url = http://jandj.me.uk/messenger/new_message
* Apache proxying to app = ProxyPass /messenger http://localhost:2366
* Actual app: plackup -r -p 2366 $path/messenger.pl
* Started by: sms_messenger_daemon
* Logs: /tmp/sms_messenger_err.out, /tmp/sms_messenger.out

Code:
* API: WWW::Twilio::API
