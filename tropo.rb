MANAGER = 'REPLACE_ME_WITH_A_PHONE_NUMBER'

if $currentCall
  case $currentCall.channel.downcase
  when 'voice'
    transfer MANAGER
  when 'text'
    message "#{$currentCall.callerID}: #{$currentCall.initialText}", :to => DONNA, :network => 'SMS'
  end
else

  Array($targets).each do |target|
    call target, :network => 'SMS'
    say $message
    hangup
    sleep 1
  end
end
