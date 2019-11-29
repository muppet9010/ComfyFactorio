local event = require 'utils.event'

local info = [[
	- - B I T E R    B A T T L E S - -
	
	Your objective is to defend your team's rocket silo and defeat the other team.
	Feed the opponent's biters with science packs to increase their strength.
	High tier science juice will yield stronger results.
	
	There is no major direct pvp combat.
	The horizontal border river is landfill proof.
	Construction robots can not build on the other teams's side.
	The random map layout is mirrored to provide a fair competition.
	
	West and East directions contain no biter nests,
	leaving room for factory expansion and outpost building.
	North and South directions are biter territory.
	
	There is no biter evolution from pollution, or destruction.
	ONLY feeding increases their power and will lead to your teams victory.	
	The gui yields two different main stats for each team's biters.
	
	    - EVO -
	    The evolution of the biters, which increases when they get fed.
	    It can go above 100% which unlocks endgame modifiers,
	    granting them increased damage and evasion.
	
	    - THREAT -
     Causes biters to attack and reduces when biters are slain.
	    Feeding gives permanent "threat-income", as well as creating instant threat.
	    A high threat value causes big attacks.
	    Values of zero or below will cause no attacks.
]]

local function create_map_intro_button(player)
	if player.gui.top["map_intro_button"] then return end
	local b = player.gui.top.add({type = "sprite-button", caption = "?", name = "map_intro_button", tooltip = "Map Info"})
	b.style.font_color = {r=0.5, g=0.3, b=0.99}
	b.style.font = "heading-1"
	b.style.minimal_height = 38
	b.style.minimal_width = 38
	b.style.top_padding = 1
	b.style.left_padding = 1
	b.style.right_padding = 1
	b.style.bottom_padding = 1
end

local function create_map_intro(player)
	if player.gui.center["map_intro_frame"] then player.gui.center["map_intro_frame"].destroy() end
	local frame = player.gui.center.add {type = "frame", name = "map_intro_frame", direction = "vertical"}
	local frame = frame.add {type = "frame"}
	local l = frame.add {type = "label", caption = info, name = "map_intro_text"}
	l.style.single_line = false
	l.style.font = "heading-2"
	l.style.font_color = {r=0.7, g=0.6, b=0.99}			
end

local function on_player_joined_game(event)	
	local player = game.players[event.player_index]
	create_map_intro_button(player)
	if player.online_time == 0 then
		--create_map_intro(player)
	end
end

local function on_gui_click(event)
	if not event then return end
	if not event.element then return end
	if not event.element.valid then return end	
	local player = game.players[event.element.player_index]
	if event.element.name == "close_map_intro_frame" then player.gui.center["map_intro_frame"].destroy() return end	
	if event.element.name == "map_intro_text" then player.gui.center["map_intro_frame"].destroy() return end	
	if event.element.name == "map_intro_button" then
		if player.gui.center["map_intro_frame"] then
			player.gui.center["map_intro_frame"].destroy()
		else
			create_map_intro(player)
		end		
		return
	end	
end

event.add(defines.events.on_player_joined_game, on_player_joined_game)
event.add(defines.events.on_gui_click, on_gui_click)