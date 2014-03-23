DONNA = '+17706709482'

if $currentCall
  case $currentCall.channel.downcase
  when 'voice'
    transfer DONNA
  when 'text'
    message $currentCall.initialText, :to => DONNA, :network => 'SMS'
  end
else
  targets = ["+17706709482"]
  targets.each do |target|
    call target, :network => 'SMS'
    say %q{Hello! Don't forget Invasion: Christmas Carol will be at Fabrefaction Theatre (999 Brady Ave ATL GA 30318) tonight @ 8. Doors @ 7:30. XO, Dad's Garage}
    hangup
    sleep 1
  end
end
