local bb_config = require "maps.biter_battles_v2.config"

local food_values = {
	["automation-science-pack"] =	{value = 0.001, name = "automation science", color = "255, 50, 50"},
	["logistic-science-pack"] =			{value = 0.003, name = "logistic science", color = "50, 255, 50"},
	["military-science-pack"] =			{value = 0.00822, name = "military science", color = "105, 105, 105"},
	["chemical-science-pack"] = 		{value = 0.02271, name = "chemical science", color = "100, 200, 255"},
	["production-science-pack"] =	{value = 0.09786, name = "production science", color = "150, 25, 255"},
	["utility-science-pack"] =			{value = 0.10634, name = "utility science", color = "210, 210, 60"},
	["space-science-pack"] = 			{value = 0.41828, name = "space science", color = "255, 255, 255"},
}

local force_translation = {
	["south_biters"] = "south",
	["north_biters"] = "north"
}

local enemy_team_of = {
	["north"] = "south",
	["south"] = "north"
}

local minimum_modifier = 125
local maximum_modifier = 250
local player_amount_for_maximum_threat_gain = 20

function get_instant_threat_player_count_modifier()
	local current_player_count = #game.forces.north.connected_players + #game.forces.south.connected_players
	local gain_per_player = (maximum_modifier - minimum_modifier) / player_amount_for_maximum_threat_gain
	local m = minimum_modifier + gain_per_player * current_player_count
	if m > maximum_modifier then m = maximum_modifier end
	return m
end

local function set_biter_endgame_modifiers(force)
	if force.evolution_factor ~= 1 then return end
	local damage_mod = (global.bb_evolution[force.name] - 1) * 3
	local evasion_mod = ((global.bb_evolution[force.name] - 1) * 3) + 1
	
	force.set_ammo_damage_modifier("melee", damage_mod)
	force.set_ammo_damage_modifier("biological", damage_mod)
	force.set_ammo_damage_modifier("artillery-shell", damage_mod)
	force.set_ammo_damage_modifier("flamethrower", damage_mod)
	force.set_ammo_damage_modifier("laser-turret", damage_mod)
	
	global.bb_evasion[force.name] = evasion_mod
end

local function get_enemy_team_of(team)
	if global.training_mode then
		return team
	else
		return enemy_team_of[team]
	end
end

local function print_feeding_msg(player, food, flask_amount)
	if not get_enemy_team_of(player.force.name) then return end
	
	local n = bb_config.north_side_team_name
	local s = bb_config.south_side_team_name
	if global.tm_custom_name["north"] then n = global.tm_custom_name["north"] end
	if global.tm_custom_name["south"] then s = global.tm_custom_name["south"] end	
	local team_strings = {
		["north"] = table.concat({"[color=120, 120, 255]", n, "'s[/color]"}),
		["south"] = table.concat({"[color=255, 65, 65]", s, "'s[/color]"})
	}
	
	local colored_player_name = table.concat({"[color=", player.color.r * 0.6 + 0.35, ",", player.color.g * 0.6 + 0.35, ",", player.color.b * 0.6 + 0.35, "]", player.name, "[/color]"})
	local formatted_food = table.concat({"[color=", food_values[food].color, "]", food_values[food].name, " juice[/color]", "[img=item/", food, "]"})
	local formatted_amount = table.concat({"[font=heading-1][color=255,255,255]" .. flask_amount .. "[/color][/font]"})
	
	if flask_amount >= 20 then
		game.print(colored_player_name .. " fed " .. formatted_amount .. " flasks of " .. formatted_food .. " to team " .. team_strings[get_enemy_team_of(player.force.name)] .. " biters!", {r = 0.9, g = 0.9, b = 0.9})
	else
		local target_team_text = "the enemy"
		if global.training_mode then
			target_team_text = "your own"
		end
		if flask_amount == 1 then
			player.print("You fed one flask of " .. formatted_food .. " to " .. target_team_text .. " team's biters.", {r = 0.98, g = 0.66, b = 0.22})
		else
			player.print("You fed " .. formatted_amount .. " flasks of " .. formatted_food .. " to " .. target_team_text .. " team's biters.", {r = 0.98, g = 0.66, b = 0.22})
		end				
	end	
end

function set_evo_and_threat(flask_amount, food, biter_force_name)
	local decimals = 9
	local math_round = math.round
	
	local instant_threat_player_count_modifier = get_instant_threat_player_count_modifier()
	
	local food_value = food_values[food].value * global.difficulty_vote_value
	
	for a = 1, flask_amount, 1 do				
		---SET EVOLUTION
		local e2 = (game.forces[biter_force_name].evolution_factor * 100) + 1
		local diminishing_modifier = (1 / (10 ^ (e2 * 0.017))) / (e2 * 0.5)
		local evo_gain = (food_value * diminishing_modifier)
		global.bb_evolution[biter_force_name] = global.bb_evolution[biter_force_name] + evo_gain
		global.bb_evolution[biter_force_name] = math_round(global.bb_evolution[biter_force_name], decimals)
		if global.bb_evolution[biter_force_name] <= 1 then
			game.forces[biter_force_name].evolution_factor = global.bb_evolution[biter_force_name]
		else
			game.forces[biter_force_name].evolution_factor = 1
		end
		
		--ADD INSTANT THREAT
		local diminishing_modifier = 1 / (0.2 + (e2 * 0.018))
		global.bb_threat[biter_force_name] = global.bb_threat[biter_force_name] + (food_value * instant_threat_player_count_modifier * diminishing_modifier)
		global.bb_threat[biter_force_name] = math_round(global.bb_threat[biter_force_name], decimals)		
	end
	
	--SET THREAT INCOME
	global.bb_threat_income[biter_force_name] = global.bb_evolution[biter_force_name] * 20
	
	set_biter_endgame_modifiers(game.forces[biter_force_name])
end

local function feed_biters(player, food)	
	local enemy_force_name = get_enemy_team_of(player.force.name)  ---------------
	--enemy_force_name = player.force.name
	
	local biter_force_name = enemy_force_name .. "_biters"
	
	local i = player.get_main_inventory()
	local flask_amount = i.get_item_count(food)
	if flask_amount == 0 then
		player.print("You have no " .. food_values[food].name .. " flask in your inventory.", {r = 0.98, g = 0.66, b = 0.22})
		return
	end
	
	i.remove({name = food, count = flask_amount})
	
	print_feeding_msg(player, food, flask_amount)							
	
	set_evo_and_threat(flask_amount, food, biter_force_name)
end

return feed_biters