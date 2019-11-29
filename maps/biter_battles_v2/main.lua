-- Biter Battles v2 -- by MewMew

local bb_config = require "maps.biter_battles_v2.config"
require "on_tick_schedule"
require "maps.biter_battles_v2.map_settings_tab"
require "modules.spawners_contain_biters"
require "modules.mineable_wreckage_yields_scrap"

local event = require 'utils.event'

local function init_settings()
	global.bb_settings = {
		--TEAM SETTINGS--
		["team_balancing"] = true,			--Should players only be able to join a team that has less or equal members than the opposing team?
		["only_admins_vote"] = false,		--Are only admins able to vote on the global difficulty?
		
		--GENERAL SETTINGS--
		["blueprint_library_importing"] = false,		--Allow the importing of blueprints from the blueprint library?
		["blueprint_string_importing"] = false,		--Allow the importing of blueprints via blueprint strings?
	}
end

local function init_surface()
	local map_gen_settings = {}
	map_gen_settings.water = math.random(15, 65) * 0.01
	map_gen_settings.starting_area = 2.5
	map_gen_settings.terrain_segmentation = math.random(30, 40) * 0.1
	map_gen_settings.cliff_settings = {cliff_elevation_interval = 0, cliff_elevation_0 = 0}
	map_gen_settings.autoplace_controls = {
		["coal"] = {frequency = 2.5, size = 0.65, richness = 0.5},
		["stone"] = {frequency = 2.5, size = 0.65, richness = 0.5},
		["copper-ore"] = {frequency = 3.5, size = 0.65, richness = 0.5},
		["iron-ore"] = {frequency = 3.5, size = 0.65, richness = 0.5},
		["uranium-ore"] = {frequency = 2, size = 1, richness = 1},
		["crude-oil"] = {frequency = 3, size = 1, richness = 0.75},
		["trees"] = {frequency = math.random(8, 16) * 0.1, size = math.random(8, 16) * 0.1, richness = math.random(2, 10) * 0.1},
		["enemy-base"] = {frequency = 256, size = 0.61, richness = 1}
	}
	game.create_surface("biter_battles", map_gen_settings)

	game.map_settings.enemy_evolution.time_factor = 0
	game.map_settings.enemy_evolution.destroy_factor = 0
	game.map_settings.enemy_evolution.pollution_factor = 0
	game.map_settings.pollution.enabled = false
	game.map_settings.enemy_expansion.enabled = false
end

local function init_forces()
	local surface = game.surfaces["biter_battles"]

	game.create_force("north")
	game.create_force("north_biters")
	game.create_force("south")
	game.create_force("south_biters")
	game.create_force("spectator")

	local f = game.forces["north"]
	f.set_spawn_position({0, -32}, surface)
	f.set_cease_fire('player', true)
	f.set_friend("spectator", true)
	f.set_friend("south_biters", true)
	f.share_chart = true

	local f = game.forces["south"]
	f.set_spawn_position({0, 32}, surface)
	f.set_cease_fire('player', true)
	f.set_friend("spectator", true)
	f.set_friend("north_biters", true)
	f.share_chart = true

	local f = game.forces["north_biters"]
	f.set_friend("south_biters", true)
	f.set_friend("south", true)
	f.set_friend("player", true)
	f.set_friend("spectator", true)
	f.share_chart = false

	local f = game.forces["south_biters"]
	f.set_friend("north_biters", true)
	f.set_friend("north", true)
	f.set_friend("player", true)
	f.set_friend("spectator", true)
	f.share_chart = false

	local f = game.forces["spectator"]
	f.set_spawn_position({0,0},surface)
	f.technologies["toolbelt"].researched=true
	f.set_cease_fire("north_biters", true)
	f.set_cease_fire("south_biters", true)
	f.set_friend("north", true)
	f.set_friend("south", true)
	f.set_cease_fire("player", true)
	f.share_chart = true

	local f = game.forces["player"]
	f.set_spawn_position({0,0},surface)
	f.set_cease_fire('spectator', true)
	f.set_cease_fire("north_biters", true)
	f.set_cease_fire("south_biters", true)
	f.set_cease_fire('north', true)
	f.set_cease_fire('south', true)
	f.share_chart = false

	if not global.bb_settings.blueprint_library_importing then
		game.permissions.get_group("Default").set_allows_action(defines.input_action.grab_blueprint_record, false)
	end
	if not global.bb_settings.blueprint_string_importing then
		game.permissions.get_group("Default").set_allows_action(defines.input_action.import_blueprint_string, false)
		game.permissions.get_group("Default").set_allows_action(defines.input_action.import_blueprint, false)
	end

	local p = game.permissions.create_group("spectator")
	for action_name, _ in pairs(defines.input_action) do
		p.set_allows_action(defines.input_action[action_name], false)
	end

	local defs = {
		defines.input_action.activate_copy,
		defines.input_action.activate_cut,
		defines.input_action.activate_paste,
		defines.input_action.clean_cursor_stack,
		defines.input_action.edit_permission_group,
		defines.input_action.gui_click,
		defines.input_action.gui_confirmed,
		defines.input_action.gui_elem_changed,
		defines.input_action.gui_location_changed,
		defines.input_action.gui_selected_tab_changed,
		defines.input_action.gui_selection_state_changed,
		defines.input_action.gui_switch_state_changed,
		defines.input_action.gui_text_changed,
		defines.input_action.gui_value_changed,
		defines.input_action.open_character_gui,
		defines.input_action.open_kills_gui,
		defines.input_action.rotate_entity,
		defines.input_action.start_walking,
		defines.input_action.toggle_show_entity_info,
		defines.input_action.write_to_console,
	}
	
	for _, d in pairs(defs) do p.set_allows_action(d, true) end

	global.rocket_silo = {}
	global.spectator_rejoin_delay = {}
	global.spy_fish_timeout = {}
	global.force_area = {}
	global.active_biters = {}
	global.biter_raffle = {}
	global.evo_raise_counter = 1
	global.next_attack = "north"
	if math.random(1,2) == 1 then global.next_attack = "south" end
	global.bb_evolution = {}
	global.bb_evasion = {}
	global.bb_threat_income = {}
	global.bb_threat = {}
	global.chunks_to_mirror = {}
	global.map_pregen_message_counter = {}

	for _, force in pairs(game.forces) do
		game.forces[force.name].technologies["artillery"].enabled = false
		game.forces[force.name].technologies["artillery-shell-range-1"].enabled = false
		game.forces[force.name].technologies["artillery-shell-speed-1"].enabled = false
		game.forces[force.name].technologies["atomic-bomb"].enabled = false
		game.forces[force.name].set_ammo_damage_modifier("shotgun-shell", 1)
		game.forces[force.name].research_queue_enabled = true
		global.spy_fish_timeout[force.name] = 0
		global.active_biters[force.name] = {}
		global.biter_raffle[force.name] = {}
		global.bb_evolution[force.name] = 0
		global.bb_evasion[force.name] = false
		global.bb_threat_income[force.name] = 0
		global.bb_threat[force.name] = 0
	end
	global.game_lobby_active = true
end

local function on_player_joined_game(event)
	local surface = game.surfaces["biter_battles"]
	local player = game.players[event.player_index]

	if player.gui.left["map_pregen"] then player.gui.left["map_pregen"].destroy() end

	if player.online_time == 0 then
		player.spectator = true
		player.force = game.forces.spectator
		if surface.is_chunk_generated({0,0}) then
			player.teleport(surface.find_non_colliding_position("character", {0,0}, 3, 0.5), surface)
		else
			player.teleport({0,0}, surface)
		end
		player.character.destructible = false
		game.permissions.get_group("spectator").add_player(player)
	end
end

local function on_init()
	init_settings()
	init_surface()
	init_forces()
	global.gui_refresh_delay = 0
	global.bb_debug = false
end

event.on_init(on_init)
event.add(defines.events.on_player_joined_game, on_player_joined_game)

require "maps.biter_battles_v2.spec_spy"
require "maps.biter_battles_v2.on_tick"
require "maps.biter_battles_v2.terrain"
require "maps.biter_battles_v2.biters_landfill"
require "maps.biter_battles_v2.no_turret_creep"
require "maps.biter_battles_v2.chat"
require "maps.biter_battles_v2.bb_map_intro"
require "maps.biter_battles_v2.difficulty_vote"
require "maps.biter_battles_v2.team_manager"
require "modules.custom_death_messages"