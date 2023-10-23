local monitor = peripheral.find("monitor")
local speaker = peripheral.find("speaker")
local modem = peripheral.wrap("left")
local dfpwm = require "cc.audio.dfpwm"
 
os.loadAPI("surface")
modem.open(69)
 
local x,y = monitor.getSize() 
local BASE_MUSIC_DIR = "/dfpwm/musics/"

local musicindex = 0 --index da musica
local musicData = nil -- arquivo de musica
local playing = false -- controle de play
local looping = false -- controle de loop
local paused = false -- controle pause

local live = false

local mlines = {} -- buffer musica
local currentIndex = 1 -- controle de "progresso" da musica

local musicButtons = {}
local buttonsYindex = 1

function getMusics()
    return fs.find(BASE_MUSIC_DIR.."*dfpwm")
end

function stringSplit (inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		table.insert(t, str)
	end
	return t
end

function resetSpeaker()
	-- reset player
	playing = false
	musicData = nil
	mlines = {}
	currentIndex = 1
	
	-- load music
	speaker.stop()
	playing = true
end

function clickEvent()
	local event, side, tx, ty = os.pullEvent("monitor_touch")
	
	if tx == x-4 and ty == y-buttonsYindex then
		
		--proximo
		resetSpeaker()
		
		-- check for music
		if musicindex+1 <= #musicButtons then
			musicindex = musicindex+1
			musicData = musicButtons[musicindex]
		else
			musicindex = 1
			musicData = musicButtons[musicindex]
		end
		
	elseif tx == x-9 and ty == y-buttonsYindex then 
	
		--anterior
		resetSpeaker()
		
		-- check for music
		if musicindex-1 >= 1 then
			musicindex = musicindex-1
			musicData = musicButtons[musicindex]
		else
			musicindex = #musicButtons
			musicData = musicButtons[musicindex]
		end
		
	elseif (tx == x-7 or tx == x-6) and ty == y-buttonsYindex then
	
		if playing then
			playing = false
			paused = true
			speaker.stop()
		else
			if musicindex == 0 then 
				musicindex = 1
			end
			playing = true
			paused = false
		end
		
	elseif (tx >= x-14 and tx <= x-11) and ty == y-buttonsYindex then 
	
		if live then live = false
		else live = true end
		
	elseif next(musicButtons) ~= nil then
	
		for index,button in pairs(musicButtons) do
			--print("Music at minX:"..button.minx.." maxX: "..button.maxx.." Y:"..button.vy)
			if tx >= button.minx and tx <= button.maxx and ty == button.vy then
				
				resetSpeaker()
				
				musicindex = button.index
				musicData = button

			end
		end
		
	end
	
end

function drawUI()
	
    local surf = surface.create(x, y, " ", colors.black, colors.lightGray)
	
	-- title/header
    surf:drawLine(1,1,x,1," ", colors.lightGray, colors.white)    
    surf:drawText(1,1,"DFPlayer by: Shintaro",colors.lightGray,colors.white)
	
	-- janela lista de musica
    surf:drawRect(3,3,x-2,y-3," ", colors.lightGray,colors.white)
	surf:drawText(5,3," Musicas ",colors.black,colors.white)
	
	
	-- play pause
	if not playing then 
		surf:drawText(x-7, y-buttonsYindex,"> ",colors.lightGray,colors.white)
	else
		surf:drawText(x-7, y-buttonsYindex,"||",colors.lightGray,colors.white)
    end
	
	-- Proximo
	surf:drawText(x-4, y-buttonsYindex,">",colors.lightGray,colors.white)
	
	-- Anterior
	surf:drawText(x-9, y-buttonsYindex,"<",colors.lightGray,colors.white)
	
	-- Live
	if live then
		surf:drawText(x-14, y-buttonsYindex,"Live",colors.red,colors.black)
		liveToggle = false
	else
		surf:drawText(x-14, y-buttonsYindex,"Live",colors.lightGray,colors.white)
		liveToggle = true
	end
	
	--ProgressBar
	surf:drawLine(3,y-buttonsYindex,x-16,y-buttonsYindex," ", colors.lightGray, colors.white)
	
	--calcula valor de possisão
	local valorMapeado = math.floor((currentIndex - 1) * ((x-16) - 3) / (#mlines - 1) + 3)
	
	--desenha
	surf:drawLine(3,y-buttonsYindex,valorMapeado,y-buttonsYindex," ", colors.green, colors.white)
	
    local files = getMusics()
	musicButtons = {}
    for index,filedir in pairs(files) do
	
		local musicNameEX = stringSplit(filedir,"/")
		local musicName = stringSplit(musicNameEX[#musicNameEX],".")
		
		local musicInfo = {minx = 5, maxx = string.len(musicName[1])+1, vy = 4+index, file = filedir, index = index}
		table.insert(musicButtons, musicInfo)
		
		if musicData ~= nil then
			if musicInfo.file == musicData.file then
				surf:drawText(5,4+index,musicName[1],colors.black,colors.gray)
			else
				surf:drawText(5,4+index,musicName[1],colors.black,colors.white)
			end
		else
			surf:drawText(5,4+index,musicName[1],colors.black,colors.white)
		end
    end
    
    surf:render(monitor)
	
	if not playing then
		os.sleep(2)
		monitor.clear()
	end

end

function refreshAudio()

    if playing and musicData ~= nil then
	
		-- pre-processa a musica
		if next(mlines) == nil then
			for line in io.lines(musicData.file, 16 * 1024) do
			  table.insert(mlines, line)
			end
		end
		
		-- cria decoder
		local decoder = dfpwm.make_decoder()
		
		-- executa a musica
		for i = currentIndex, #mlines do
			currentIndex = i --seta o progresso da musica
			local musicLine = mlines[i]
			
			if paused then 
				break
			end
			
			if live then 
				modem.transmit(15, 69, musicLine)
			end
			
			local decoded = decoder(musicLine)
			speaker.playAudio(decoded)
			drawUI()
			os.pullEvent("speaker_audio_empty")
		end
		
		currentIndex=1
		playing = false
		mlines = {}
		
	else
		drawUI()
	end
	
end

function mainProcess()

	-- clear monitor/setup
	monitor.clear()
	monitor.setTextScale(0.5)
	x,y = monitor.getSize()
	
	while true do
		parallel.waitForAny(refreshAudio,clickEvent)
	end
	
end
 
mainProcess()

for line in input do table.insert(lines, line) end