local speaker = peripheral.find("speaker")
local modem = peripheral.find("modem")
local dfpwm = require "cc.audio.dfpwm"

modem.open(15)
local event, side, channel, replyChannel, message, distance

while true do
	repeat
	  event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
	until channel == 15
	print("event recived!!")
	local decoder = dfpwm.make_decoder()
	local decoded = decoder(message)
	speaker.playAudio(decoded)
	os.pullEvent("speaker_audio_empty")
end
print("Received a reply: " .. tostring(message))
