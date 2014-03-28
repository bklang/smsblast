require 'net/http'
require 'json'

CONTACT = '+17706709482'
WEB_UI_URL = 'http://smsblast.herokuapp.com'

def send_confirmation(id)
  uri = URI.parse "#{WEB_UI_URL}/tropo/update"
  params = { :token => $token, :id => id, :status => "Sent" }
  Net::HTTP.post_form uri, params
end


if $currentCall
  case $currentCall.channel.downcase
  when 'voice'
    transfer DONNA
  when 'text'
    message "#{$currentCall.callerID}: #{$currentCall.initialText}", :to => CONTACT, :network => 'SMS'
  end
else
  targets = JSON.parse $targets
  log "Targets: #{targets.inspect}"
  log "Message: #{$message.inspect}"
  targets.each_pair.each do |id, target|
    call target, :network => 'SMS'
    say $message
    hangup
    send_confirmation id
    sleep 1
  end
end
