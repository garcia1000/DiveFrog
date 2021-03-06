local love = _G.love

local AI = require 'AI'
local camera = require 'camera'
local draw = require 'draw'
local images = require 'images'
local json = require 'dkjson'
local music = require 'music'
local particles = require 'particles'
local settings = require 'settings'
local sounds = require 'sounds'
local stage = require 'stage'  -- total playing field area
local title = require 'title'
local utilities = require 'utilities' -- helper functions
local window = require 'window'  -- current view of stage
local Konrad = require 'Konrad'
local Jean = require 'Jean'
local Sun = require 'Sun'
local Frogson = require 'Frogson'

require 'lovedebug'

math.randomseed(os.time())
math.random(); math.random(); math.random()

utilities.checkVersion()

-- build screen
love.window.setMode(window.width, window.height)
love.window.setTitle("Divefrog the fighting game sensation")

function love.load()
	game = {
		current_screen = "title",
		best_to_x = Params.Rounds,
		speed = Params.Speed,
		current_round = 0,
		match_winner = false,
		superfreeze_time = 0,
		superfreeze_player = nil,
		BGM = nil,
		background_color = nil,
		isScreenShaking = false,
		identical_players = false,
		format = "",
	}

	music.setBGM("Intro.ogg")
	min_dt = 1/60 -- frames per second
	next_time = love.timer.getTime()
	frame = 0 -- framecount
	frame0 = 0 -- timer for start of round fade in
	init_round_timer = Params.Timer * 60 -- round time in frames
	round_timer = init_round_timer
	round_end_frame = 0
	round_ended = false
	keybuffer = {false, false, false, false} -- log of all keystates during the round. Useful for netplay!

	debug = {boxes = false, sprites = false, midpoints = false, camera = false,	keybuffer = false}

	available_chars = {Konrad, Jean, Sun, Frogson}
end

function love.draw()
	if game.current_screen == "maingame" then
		draw.draw_main()
	elseif game.current_screen == "charselect" then
		draw.draw_charselect()
	elseif game.current_screen == "match_end" then
		draw.draw_matchend()
	elseif game.current_screen == "title" then
		draw.draw_title()
	elseif game.current_screen == "settings" then
		draw.draw_settings()
	elseif game.current_screen == "replays" then
		love.graphics.draw(images.replaysscreen, 0, 0, 0)
	end

	local cur_time = love.timer.getTime() -- time after drawing all the stuff

	if cur_time - next_time >= 0 then
	next_time = cur_time -- time needed to sleep until the next frame (?)
	end

	love.timer.sleep(next_time - cur_time) -- advance time to next frame (?)
end

function love.update(dt)
	frame = frame + 1
	if game.current_screen == "maingame" then

		if game.superfreeze_time == 0 then
			local h_midpoint = (p1:getCenter() + p2:getCenter()) / 2
			local highest_sprite = math.min(p1.pos[2] + p1.sprite_size[2], p2.pos[2] + p2.sprite_size[2])
			local screen_bottom = stage.height - window.height

			camera.camera_xy = {utilities.clamp(h_midpoint - window.center, 0, stage.width - window.width),
			screen_bottom - (stage.floor - highest_sprite) / 8 }

				-- screen shake
			local h_displacement = 0
			local v_displacement = 0

			if game.isScreenShaking then
				h_displacement = (frame % 7 * 6 + frame % 13 * 3 + frame % 23 * 2 - 60) / 2
				v_displacement = (frame % 5 * 8 + frame % 11 * 3 + frame % 17 * 2 - 30) / 2
			end
			camera:setPosition(camera.camera_xy[1] + h_displacement, camera.camera_xy[2] - v_displacement)

		-- tweening for scale and camera position
		else
			game.superfreeze_time = game.superfreeze_time - 1
		end

		if not round_ended and not (p1.frozenFrames > 0 and p2.frozenFrames > 0) then
			round_timer = math.max(round_timer - (1 * game.speed), 0)
		end

	-- get button press state, and write to keybuffer table
	if game.format == "2P" then
		keybuffer[frame] = {
			love.keyboard.isDown(settings.buttons.p1jump),
			love.keyboard.isDown(settings.buttons.p1attack),
			love.keyboard.isDown(settings.buttons.p2jump),
			love.keyboard.isDown(settings.buttons.p2attack),
		}
	elseif game.format == "1P" then
		local AIjump, AIattack = AI.Action(p2, p1)
		keybuffer[frame] = {
			love.keyboard.isDown(settings.buttons.p1jump),
			love.keyboard.isDown(settings.buttons.p1attack),
			AIjump,
			AIattack,
		}
	elseif game.format == "Netplay1P" then
		keybuffer[frame] = {
			love.keyboard.isDown(settings.buttons.p1jump),
			love.keyboard.isDown(settings.buttons.p1attack),
			love.keyboard.isDown(settings.buttons.p2jump),   -- get netplay data here
			love.keyboard.isDown(settings.buttons.p2attack), -- get netplay data here
		}
	elseif game.format == "Netplay2P" then
		keybuffer[frame] = {
			love.keyboard.isDown(settings.buttons.p1jump),   -- get netplay data here
			love.keyboard.isDown(settings.buttons.p1attack), -- get netplay data here
			love.keyboard.isDown(settings.buttons.p2jump),
			love.keyboard.isDown(settings.buttons.p2attack),
		}
	end


	-- read keystate from keybuffer and call the associated functions
	if not round_ended then
		if keybuffer[frame][1] and p1.frozenFrames == 0 and not keybuffer[frame-1][1] then p1:jump_key_press() end
		if keybuffer[frame][2] and p1.frozenFrames == 0 and not keybuffer[frame-1][2] then p1:attack_key_press() end
		if keybuffer[frame][3] and p2.frozenFrames == 0 and not keybuffer[frame-1][3] then p2:jump_key_press() end
		if keybuffer[frame][4] and p2.frozenFrames == 0 and not keybuffer[frame-1][4] then p2:attack_key_press() end
	end

	-- update character positions
	p1:updatePos()
	p2:updatePos()

	-- check if anyone got hit
	if utilities.check_got_hit(p1, p2) and utilities.check_got_hit(p2, p1) then
		round_end_frame = frame
		round_ended = true
		p1:gotHit(p2.hit_type)
		p2:gotHit(p1.hit_type)

	elseif utilities.check_got_hit(p1, p2) then
		round_end_frame = frame
		round_ended = true
		p1:gotHit(p2.hit_type)
		p2:hitOpponent()

	elseif utilities.check_got_hit(p2, p1) then
		round_end_frame = frame
		round_ended = true
		p2:gotHit(p1.hit_type)
		p1:hitOpponent()
	end

	-- check if timeout
	if round_timer == 0 and not round_ended then
		round_end_frame = frame
		round_ended = true
		local p1_from_center = math.abs((stage.center) - p1:getCenter())
		local p2_from_center = math.abs((stage.center) - p2:getCenter())
		if p1_from_center < p2_from_center then
			p2:gotHit(p1.hit_type)
			p1:hitOpponent()
		elseif p2_from_center < p1_from_center then
			p1:gotHit(p2.hit_type)
			p2:hitOpponent()
		else
			p1:gotHit(p2.hit_type)
			p2:gotHit(p1.hit_type)
		end
	end

	sounds.update()

	-- after round ended and displayed round end stuff, start new round
	if frame - round_end_frame == 144 then
		for p, _ in pairs(Players) do
			if p.hasWon then p:addScore() end
			if p.score == game.best_to_x then game.match_winner = p end
		end

		if not game.match_winner then
			newRound()
		else -- match end
			frame = 0
			frame0 = 0
			music.setBGM("GameOver.ogg")
			game.current_screen = "match_end" 
			keybuffer = {}
		end
	end

	-- advance time (?)
	next_time = next_time + min_dt
	end
end

function newRound()
	--Uncomment this for replays later. Too annoying atm sorry
	--local keybuffer_string = json.encode(keybuffer)
	--local filename = "saves/" .. os.date("%m%d%H%M") .. p1_char .. "v" ..
	--	p2_char .. "R" .. game.current_round .. ".txt" -- need to modify this later if 10+ chars
	--love.filesystem.write(filename, keybuffer_string)

	p1:initialize(1, p2, p1.super, p1.hitflag.Mugshot, p1.score)
	p2:initialize(2, p1, p2.super, p2.hitflag.Mugshot, p2.score)

	frame = 0
	frame0 = 0
	round_timer = init_round_timer
	round_ended = false
	round_end_frame = 100000 -- arbitrary number, larger than total round time
	game.current_round = game.current_round + 1
	game.background_color = nil
	game.isScreenShaking = false
	keybuffer = {}
	particles.clear_buffers()
	sounds.reset()

	if not music.currentBGM:isPlaying() then music.currentBGM:play() end
	if music.currentBGM2:isPlaying() then music.currentBGM2:pause() end

	if p1.score == game.best_to_x - 1 and p2.score == game.best_to_x - 1 then
		music.setBGMspeed(2 ^ (4/12))
	end
end

function startGame()
	if game.format == "1P" then
		title.default_selections.player1P = p1_char
		title.default_selections.AI1P = p2_char
	elseif game.format == "2P" then
		title.default_selections.player12P = p1_char
		title.default_selections.player22P = p2_char
	end
	love.filesystem.write("choices.txt", json.encode(title.default_selections))

	game.current_screen = "maingame"

	p1 = available_chars[p1_char](1, p2, 0, false, 0)
	p2 = available_chars[p2_char](2, p1, 0, false, 0)
	if p1_char == p2_char then game.identical_players = true end

	Players = {
		[p1] = {move = -1, flip = 1, offset = 0},
		[p2] = {move = 1, flip = -1, offset = 1},
	}
	game.BGM = p2.BGM
	music.setBGM(game.BGM)
	newRound()
end


function love.keypressed(key)
	if key == "escape" then love.event.quit() end

	if game.current_screen == "title" then
		if key == settings.buttons.p1attack or key == settings.buttons.start then
			sounds.playCharSelectedSFX()
			title.choices.action[title.choices.option]()

		elseif key == settings.buttons.p1jump or key == "down" then
			sounds.playCharSelectSFX()
			title.choices.option = title.choices.option % #title.choices.menu + 1

		elseif key == "up" then
			sounds.playCharSelectSFX()
			title.choices.option = (title.choices.option - 2) % #title.choices.menu + 1
		end

	elseif game.current_screen == "charselect" then
		if key == settings.buttons.p1attack or key == settings.buttons.p2attack then
			sounds.playCharSelectedSFX()
			startGame()
		end

		if key == settings.buttons.p1jump then
			p1_char = p1_char % #available_chars + 1
			draw.portraitsQuad = love.graphics.newQuad(0, (p1_char - 1) * 140, 200, 140, images.portraits:getDimensions())
			sounds.playCharSelectSFX()
		end

		if key == settings.buttons.p2jump then
			p2_char = p2_char % #available_chars + 1
			sounds.playCharSelectSFX()
		end

	elseif game.current_screen == "settings" then
		settings.receive_keypress(key)

	elseif game.current_screen == "replays" then
		if key == settings.buttons.start then
			sounds.playCharSelectSFX()
			game.current_screen = "title"
		end

	elseif game.current_screen == "match_end" then
		if key ==  settings.buttons.start then
			love.load()
			game.current_screen = "title"
		end
	end

	if key == '`' then p1.super = 90 p2.super = 90 end
	if key == '1' then debug.boxes = not debug.boxes end
	if key == '2' then debug.sprites = not debug.sprites end
	if key == '3' then debug.midpoints = not debug.midpoints end
	if key == '4' then debug.camera = not debug.camera end
	if key == '5' then debug.keybuffer = not debug.keybuffer end
	if key == '6' then print(love.filesystem.getSaveDirectory()) end
	if key == '7' then
		local output_keybuffer = json.encode(keybuffer)
		local filename = os.date("%Y.%m.%d.%H%M") .. " Keybuffer.txt"
		love.filesystem.write(filename, output_keybuffer)
	end
	if key == '9' then
		local globaltable = {}
		local num = 1
		for k, v in pairs(_G) do
			globaltable[num] = k
			num = num + 1
		end
		local output_globals = json.encode(globaltable)
		local filename = os.date("%Y.%m.%d.%H%M") .. " globals.txt"
		love.filesystem.write(filename, output_globals)
		print("Globals written to file " .. love.filesystem.getSaveDirectory())
	end
end
