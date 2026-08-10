extends Node2D

const GameStats = preload("res://stat_database.gd")
const MOB_SCENE = preload("res://mob.tscn")
const SPAWN_STYLES := {
	&"steady": {
		"minimum_group_size": 6,
		"maximum_group_size": 10,
		"interval": 0.5,
		"gap_after_group": 0.8,
	},
	&"stream": {
		"minimum_group_size": 10,
		"maximum_group_size": 16,
		"interval": 0.15,
		"gap_after_group": 0.8,
	},
	&"burst": {
		"minimum_group_size": 7,
		"maximum_group_size": 11,
		"interval": 0.08,
		"gap_after_group": 1.1,
	},
	&"spaced": {
		"minimum_group_size": 5,
		"maximum_group_size": 8,
		"interval": 0.8,
		"gap_after_group": 0.8,
	},
}
const WAVE_STYLE_UNLOCKS := {
	&"pulses": 3,
	&"simultaneous_batch": 4,
	&"convoy": 6,
	&"sandwich": 7,
	&"escorted_elite": 9,
}
const ROLE_FODDER := &"fodder"
const ROLE_PRESSURE := &"pressure"
const ROLE_TANK := &"tank"
const ROLE_SUPPORT := &"support"
const ROUND_STANDARD: StringName = &"standard"
const ROUND_HORDE: StringName = &"horde"
const ROUND_ELITE: StringName = &"elite"
const ROUND_GAUNTLET: StringName = &"gauntlet"
const ROUND_PAYDAY: StringName = &"payday"
const VARIANT_NORMAL: StringName = &"normal"
const VARIANT_HORDE: StringName = &"horde"
const VARIANT_ELITE: StringName = &"elite"
const VARIANT_PAYDAY: StringName = &"payday"
const HORDE_THREAT_MULTIPLIER := 2.0
const HORDE_GROUP_SIZE_MULTIPLIER := 2.0
const HORDE_SPAWN_DELAY_MULTIPLIER := 0.5
const HORDE_ACTIVE_CAP_MULTIPLIER := 1.5
const GAUNTLET_ACTIVE_CAP_MULTIPLIER := 1.75
const ELITE_EVENT_MIN_INTERVAL := 15.0
const ELITE_EVENT_MAX_INTERVAL := 25.0
const GAUNTLET_ELITE_MIN_INTERVAL := 10.0
const GAUNTLET_ELITE_MAX_INTERVAL := 18.0
const FINAL_ELITE_PACK_START_RATIO := 0.8
const ELITE_EVENT_RESERVED_SLOTS := 12
const GAUNTLET_EVENT_RESERVED_SLOTS := 20
const SHOP_CHOICE_COUNT := 3
const GAUNTLET_RELIC_CHOICE_COUNT := 4
const MINIMUM_APPLICABLE_RELIC_CHOICES := 2
const TOWER_DRAFT_ROUNDS: Array[int] = [4, 9, 14]
const RELIC_DRAFT_ROUNDS: Array[int] = [6, 11, 16]
const RELIC_RARITY_WEIGHTS_BY_ROUND := {
	6: {&"common": 70.0, &"rare": 30.0},
	11: {&"common": 35.0, &"rare": 55.0, &"legendary": 10.0},
	16: {&"rare": 70.0, &"legendary": 30.0},
}
const RELIC_MINIMUM_RARE_PLUS_BY_ROUND := {
	6: 1,
	11: 2,
}
const RELIC_ROLL_MAX_ATTEMPTS := 256
const RELIC_REFRESH_BASE_COST := 75
const RELIC_REFRESH_COST_INCREASE := 50
const RELIC_REFRESH_DIFFERENT_ROLL_ATTEMPTS := 24
const WAVE_ROLE_WEIGHTS := [
	{
		"maximum_wave": 3,
		"weights": {
			ROLE_FODDER: 80.0,
			ROLE_PRESSURE: 20.0,
			ROLE_TANK: 0.0,
			ROLE_SUPPORT: 0.0,
		},
	},
	{
		"maximum_wave": 8,
		"weights": {
			ROLE_FODDER: 60.0,
			ROLE_PRESSURE: 25.0,
			ROLE_TANK: 15.0,
			ROLE_SUPPORT: 0.0,
		},
	},
	{
		"maximum_wave": 13,
		"weights": {
			ROLE_FODDER: 50.0,
			ROLE_PRESSURE: 20.0,
			ROLE_TANK: 20.0,
			ROLE_SUPPORT: 10.0,
		},
	},
	{
		"maximum_wave": 999,
		"weights": {
			ROLE_FODDER: 45.0,
			ROLE_PRESSURE: 25.0,
			ROLE_TANK: 20.0,
			ROLE_SUPPORT: 10.0,
		},
	},
]
const FORMATION_ROLE_WEIGHTS := {
	&"steady": {
		ROLE_FODDER: 60.0,
		ROLE_PRESSURE: 20.0,
		ROLE_TANK: 15.0,
		ROLE_SUPPORT: 5.0,
	},
	&"stream": {
		ROLE_FODDER: 75.0,
		ROLE_PRESSURE: 20.0,
		ROLE_TANK: 0.0,
		ROLE_SUPPORT: 5.0,
	},
	&"burst": {
		ROLE_FODDER: 40.0,
		ROLE_PRESSURE: 50.0,
		ROLE_TANK: 10.0,
		ROLE_SUPPORT: 0.0,
	},
	&"spaced": {
		ROLE_FODDER: 25.0,
		ROLE_PRESSURE: 20.0,
		ROLE_TANK: 45.0,
		ROLE_SUPPORT: 10.0,
	},
	&"pulses": {
		ROLE_FODDER: 65.0,
		ROLE_PRESSURE: 25.0,
		ROLE_TANK: 10.0,
		ROLE_SUPPORT: 0.0,
	},
	&"simultaneous_batch": {
		ROLE_FODDER: 70.0,
		ROLE_PRESSURE: 20.0,
		ROLE_TANK: 10.0,
		ROLE_SUPPORT: 0.0,
	},
	&"convoy": {
		ROLE_FODDER: 50.0,
		ROLE_PRESSURE: 30.0,
		ROLE_TANK: 15.0,
		ROLE_SUPPORT: 5.0,
	},
	&"escorted_elite": {
		ROLE_FODDER: 45.0,
		ROLE_PRESSURE: 30.0,
		ROLE_TANK: 20.0,
		ROLE_SUPPORT: 5.0,
	},
	&"sandwich": {
		ROLE_FODDER: 45.0,
		ROLE_PRESSURE: 30.0,
		ROLE_TANK: 20.0,
		ROLE_SUPPORT: 5.0,
	},
}
const TOWER_SCENE = preload("res://base_tower.tscn")
const DEFAULT_TOWER_ICON = preload("res://icon.svg")
const TOWER_SLOT_COUNT := 5
const CONTRABAND_SLOT_INDEX := TOWER_SLOT_COUNT
const TRADE_AGREEMENT_TOWER_IDS: Array[StringName] = [
	&"hivemother",
	&"dronedepot",
	&"mechbay",
]
const DRAFT_TOWER: StringName = &"tower"
const DRAFT_RELIC: StringName = &"relic"
const BUILD_CELL_SIZE := GameStats.BUILD_CELL_SIZE
const PLACEMENT_SNAP_SIZE := 16.0
const MIN_SIDEBAR_WIDTH := 192.0
const PATH_NO_BUILD_RADIUS := 46.0
const BUILD_BLOCKER_COLLISION_MASK := 4
const AFFORDABLE_TOWER_COLOR := Color(0.35, 1.0, 0.35)
const UNAFFORDABLE_TOWER_COLOR := Color(1.0, 0.3, 0.3)

signal money_changed(new_amount: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)

@onready var spawntimer: Timer = $SpawnTimer
@onready var tower_list: ItemList = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerSelectionArea/ItemList
@onready var between_round_shop: Control = $MainUI/BetweenRoundShop
@onready var pause_menu: Control = $MainUI/PauseMenu
@onready var speed_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/SidebarHeader/SpeedButton
@onready var pause_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/SidebarHeader/PauseButton
@onready var sidebar: Control = $MainUI/HUDRoot/Sidebar
@onready var money_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/moneydisplay
@onready var lives_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/livesdisplay
@onready var round_count_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/roundcount
@onready var round_timer_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/roundtimer
@onready var tower_details_placeholder: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerDetailsPlaceholder
@onready var tower_stats_layout: VBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout
@onready var tower_name_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout/TowerNameLabel
@onready var tower_level_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout/TowerLevelLabel
@onready var tower_path_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout/TowerPathLabel
@onready var tower_tags_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout/TowerTagsLabel
@onready var tower_upgrade_header: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout/UpgradeHeaderLabel
var lives: int
var max_lives: int
var place_mode := false
var build_mode := false
var tower_to_place: Node2D = null
var manual_targeting_tower: Node2D
var money: int
var pending_tower_type: StringName = &""
var pending_tower_cost := 0
var pending_tower_is_contraband := false
var round_number := 0
var mobs_left_to_spawn := 0
var mobs_alive := 0
var spawn_schedule: Array[Dictionary] = []
var enemy_rng := RandomNumberGenerator.new()
var shop_rng := RandomNumberGenerator.new()
var current_wave_spawn_style: StringName = &"standard"
var current_round_type: StringName = ROUND_STANDARD
var round_six_type: StringName = ROUND_HORDE
var round_eleven_type: StringName = ROUND_ELITE
var round_time_remaining := 0.0
var round_duration := 0.0
var round_elapsed := 0.0
var next_elite_event_time := INF
var final_elite_pack_spawned := false
var last_gauntlet_spawn_style: StringName = &""
var gauntlet_style_repeat_count := 0
var spawn_threat := 0.0
var threat_per_second := 0.0
var threat_chunk_elapsed := 0.0
var threat_continuous_ratio := 1.0
var threat_chunk_ratio := 0.0
var threat_chunk_interval := 4.0
var active_enemy_cap := 120
var spawning_active := false
var director_cooldown := 0.0
var round_active := false
var spore_network_last_refresh_msec := -1000000
var spore_network_primary_owner_id := 0
var spore_network_primary_target: Node2D
var spore_network_secondary_owner_id := 0
var spore_network_secondary_target: Node2D
var game_ended := false
var max_rounds: int
var mode_id: StringName = &"easy"
var shop_open := false
var active_draft_type: StringName = &""
var active_draft_offers: Array[StringName] = []
var active_draft_choice_quantities: Dictionary = {}
var pending_path_relic_tower_selection: StringName = &""
var relic_refresh_count := 0
var tower_roster: Array[StringName] = [&"invader", &"gauss_repeater"]
var contraband_tower_id: StringName = &""
var holiday_sale_tower_id: StringName = &""
var owned_shop_items: Dictionary = {}
var run_bonuses: Dictionary = {}
var damage_by_tower_instance: Dictionary = {}
var eliminations_by_tower_instance: Dictionary = {}
var damage_by_tower_type: Dictionary = {}
var eliminations_by_tower_type: Dictionary = {}
var displayed_tower: Node = null
var occupied_build_cells: Dictionary = {}
var playable_map_width := 0.0
var game_speed := 1.0

func _ready() -> void:
	Engine.time_scale = 1.0
	game_speed = 1.0
	update_speed_button()
	enemy_rng.randomize()
	shop_rng.randomize()
	roll_challenge_round_order()
	_align_sidebar_to_build_grid()
	get_viewport().size_changed.connect(_align_sidebar_to_build_grid)
	var mode: Dictionary = GameStats.get_mode(mode_id)
	money = mode["starting_cash"]
	lives = mode["starting_lives"]
	max_lives = lives
	max_rounds = mode["max_rounds"]
	populate_tower_list()
	clear_tower_details()
	update_money()
	update_lives()
	update_round_count()
	spawntimer.timeout.connect(_spawn_mob)
	between_round_shop.draft_confirmed.connect(_on_draft_confirmed)
	between_round_shop.draft_refresh_requested.connect(_on_relic_refresh_requested)
	update_play_pause_button()


func populate_tower_list() -> void:
	tower_list.clear()
	for slot_index in TOWER_SLOT_COUNT:
		if slot_index < tower_roster.size():
			var tower_id: StringName = tower_roster[slot_index]
			tower_list.add_item(
				"$%d" % get_tower_build_cost(tower_id),
				DEFAULT_TOWER_ICON
			)
			tower_list.set_item_tooltip(
				slot_index,
				GameStats.get_tower(tower_id)["display_name"]
			)
			continue

		tower_list.add_item("Empty Slot", DEFAULT_TOWER_ICON)
		tower_list.set_item_icon_modulate(slot_index, Color.TRANSPARENT)
		tower_list.set_item_disabled(slot_index, true)
		tower_list.set_item_selectable(slot_index, false)
	if not contraband_tower_id.is_empty():
		tower_list.add_item("$0", DEFAULT_TOWER_ICON)
		tower_list.set_item_tooltip(
			CONTRABAND_SLOT_INDEX,
			"Contraband: %s" % GameStats.get_tower(contraband_tower_id)["display_name"]
		)


func show_tower_details(tower: Node) -> void:
	if not is_instance_valid(tower) or not tower.has_method("get_sidebar_stats"):
		clear_tower_details()
		return

	displayed_tower = tower
	var stats: Dictionary = tower.get_sidebar_stats()
	var is_placed: bool = stats["is_placed"]
	var current_level: int = stats["level"]
	var maximum_level: int = stats["maximum_level"]

	tower_details_placeholder.hide()
	tower_stats_layout.show()
	tower_name_label.text = stats["display_name"]
	var show_upgrade_info: bool = stats["show_upgrade_info"] and stats["has_next_level"]
	tower_level_label.visible = is_placed and not show_upgrade_info
	if tower_level_label.visible:
		tower_level_label.text = "Level %d/%d" % [current_level + 1, maximum_level + 1]
	var path_status: String = stats.get("path_status", "")
	tower_path_label.visible = is_placed and not path_status.is_empty()
	tower_path_label.text = path_status
	tower_tags_label.text = "Type: %s\nAttack: %s\nBonus: %s" % [
		format_tower_tags(stats.get("type_tags", [])),
		format_tower_tags(stats.get("attack_tags", [])),
		format_tower_tags(stats.get("bonus_tags", [])),
	]
	tower_upgrade_header.visible = show_upgrade_info
	if show_upgrade_info:
		var next_level: int = stats["next_level"]
		tower_upgrade_header.text = "Upgrade to Level %d/%d" % [
			next_level + 1,
			maximum_level + 1,
		]


func format_tower_tags(tags: Array) -> String:
	if tags.is_empty():
		return "None"
	var display_tags: Array[String] = []
	for tag in tags:
		var words := String(tag).replace("_", " ").split(" ")
		for index in words.size():
			words[index] = words[index].capitalize()
		display_tags.append(" ".join(words))
	return ", ".join(display_tags)


func clear_tower_details(tower: Node = null) -> void:
	if tower != null and displayed_tower != tower:
		return
	displayed_tower = null
	tower_details_placeholder.show()
	tower_stats_layout.hide()


func refresh_tower_details() -> void:
	if is_instance_valid(displayed_tower):
		show_tower_details(displayed_tower)
	else:
		clear_tower_details()

func _process(delta: float) -> void:
	if place_mode and tower_to_place:
		var snap := get_tower_build_position(
			get_global_mouse_position(),
			pending_tower_type
		)
		var sprite = tower_to_place.get_node("Rotator")
		tower_to_place.position = snap
		var placement_is_valid := can_place_tower(snap)
		tower_to_place.set_range_preview(true, placement_is_valid)
		if placement_is_valid:
			sprite.modulate = Color(1, 1, 1, 0.5)
		else:
			sprite.modulate = Color(1, 0, 0, 0.5)

	_process_round_director(delta)

func update_lives() -> void:
	lives_display.text = "Health: %d/%d" % [lives, max_lives]

func update_money() -> void:
	money_display.text = "Money: $%d" % money
	update_tower_affordability()
	money_changed.emit(money)


func update_tower_affordability() -> void:
	for slot_index in tower_list.item_count:
		var tower_id := get_sidebar_tower_id(slot_index)
		if tower_id.is_empty():
			continue
		var placement_cost := get_tower_build_cost(
			tower_id,
			slot_index == CONTRABAND_SLOT_INDEX
		)
		var price_color := (
			AFFORDABLE_TOWER_COLOR
			if money >= placement_cost
			else UNAFFORDABLE_TOWER_COLOR
		)
		tower_list.set_item_custom_fg_color(slot_index, price_color)

func add_money(amount: int) -> void:
	money += amount
	update_money()

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		update_money()
		return true
	return false

func close_all_tower_menus() -> void:
	cancel_manual_tower_targeting()
	for tower in get_tree().get_nodes_in_group("towers"):
		tower.set_selected(false)


func begin_manual_tower_targeting(tower: Node2D) -> void:
	if is_instance_valid(manual_targeting_tower) and manual_targeting_tower != tower:
		manual_targeting_tower.cancel_manual_targeting()
	manual_targeting_tower = tower


func finish_manual_tower_targeting(tower: Node2D) -> void:
	if manual_targeting_tower == tower:
		manual_targeting_tower = null


func cancel_manual_tower_targeting() -> void:
	if not is_instance_valid(manual_targeting_tower):
		manual_targeting_tower = null
		return
	var tower := manual_targeting_tower
	manual_targeting_tower = null
	tower.cancel_manual_targeting()


func roll_challenge_round_order() -> void:
	if enemy_rng.randf() < 0.5:
		round_six_type = ROUND_HORDE
		round_eleven_type = ROUND_ELITE
	else:
		round_six_type = ROUND_ELITE
		round_eleven_type = ROUND_HORDE


func get_round_type(wave: int) -> StringName:
	match wave:
		6:
			return round_six_type
		11:
			return round_eleven_type
		16:
			return ROUND_GAUNTLET
		17:
			return ROUND_PAYDAY
		_:
			return ROUND_STANDARD


func start_round() -> void:
	if (
		round_active
		or round_number >= max_rounds
		or shop_open
		or build_mode
		or is_selecting_path_relic_tower()
	):
		return
	close_all_tower_menus()
	round_number += 1
	spawn_schedule.clear()
	current_round_type = get_round_type(round_number)
	round_duration = get_wave_duration(round_number)
	round_time_remaining = round_duration
	round_elapsed = 0.0
	threat_per_second = get_wave_threat_rate(round_number)
	if current_round_type in [ROUND_HORDE, ROUND_GAUNTLET, ROUND_PAYDAY]:
		threat_per_second *= HORDE_THREAT_MULTIPLIER
	var mode: Dictionary = GameStats.get_mode(mode_id)
	spawn_threat = mode.get("starting_spawn_threat", 1.0)
	threat_chunk_elapsed = 0.0
	threat_continuous_ratio = mode.get("threat_continuous_ratio", 1.0)
	threat_chunk_ratio = mode.get("threat_chunk_ratio", 0.0)
	threat_chunk_interval = mode.get("threat_chunk_interval", 4.0)
	active_enemy_cap = mode.get("active_enemy_cap", 120)
	if current_round_type in [ROUND_HORDE, ROUND_PAYDAY]:
		active_enemy_cap = roundi(active_enemy_cap * HORDE_ACTIVE_CAP_MULTIPLIER)
	elif current_round_type == ROUND_GAUNTLET:
		active_enemy_cap = roundi(active_enemy_cap * GAUNTLET_ACTIVE_CAP_MULTIPLIER)
	director_cooldown = 0.0
	final_elite_pack_spawned = false
	last_gauntlet_spawn_style = &""
	gauntlet_style_repeat_count = 0
	if current_round_type == ROUND_ELITE:
		next_elite_event_time = enemy_rng.randf_range(
			ELITE_EVENT_MIN_INTERVAL,
			ELITE_EVENT_MAX_INTERVAL
		)
	elif current_round_type == ROUND_GAUNTLET:
		next_elite_event_time = enemy_rng.randf_range(
			GAUNTLET_ELITE_MIN_INTERVAL,
			GAUNTLET_ELITE_MAX_INTERVAL
		)
	else:
		next_elite_event_time = INF
	spawning_active = true
	current_wave_spawn_style = choose_wave_spawn_style(round_number)
	if round_number == max_rounds:
		current_wave_spawn_style = &"boss_escort"
		spawn_schedule = build_timed_boss_opening()
	mobs_left_to_spawn = spawn_schedule.size()
	round_active = true
	round_started.emit(round_number)
	spawntimer.one_shot = true
	update_round_count()
	update_play_pause_button()
	
func update_round_count() -> void:
	var displayed_round := round_number
	if not round_active and round_number < max_rounds:
		displayed_round += 1
	round_count_display.text = "Round: %d/%d" % [displayed_round, max_rounds]
	var round_type_name := get_round_type_display_name(current_round_type)
	if round_active and spawning_active:
		if current_round_type == ROUND_STANDARD:
			round_timer_display.text = "Spawning: %ds" % ceili(round_time_remaining)
		else:
			round_timer_display.text = "%s: %ds" % [
				round_type_name,
				ceili(round_time_remaining),
			]
	elif round_active:
		if current_round_type == ROUND_STANDARD:
			round_timer_display.text = "Clear remaining enemies"
		else:
			round_timer_display.text = "%s: Clear remaining enemies" % round_type_name
	elif shop_open:
		round_timer_display.text = "Draft"
	elif is_selecting_path_relic_tower():
		var relic := GameStats.get_relic(pending_path_relic_tower_selection)
		round_timer_display.text = "%s: Select a tower" % relic["display_name"]
	else:
		round_timer_display.text = "Build Phase"


func get_round_type_display_name(round_type: StringName) -> String:
	match round_type:
		ROUND_HORDE:
			return "Horde Round"
		ROUND_ELITE:
			return "Elite Round"
		ROUND_GAUNTLET:
			return "Gauntlet"
		ROUND_PAYDAY:
			return "Payday Round"
		_:
			return "Standard Round"
	
func end_round() -> void:
	if game_ended or not round_active:
		return
	
	round_active = false
	spawning_active = false
	clear_active_projectiles()
	spawn_schedule.clear()
	mobs_left_to_spawn = 0
	spawntimer.stop()
	round_ended.emit(round_number)
	add_money(calculate_end_round_reward())
	roll_holiday_sale_tower()
	update_round_count()

	if round_number >= max_rounds:
		victory()
	elif TOWER_DRAFT_ROUNDS.has(round_number):
		open_tower_draft()
	elif RELIC_DRAFT_ROUNDS.has(round_number):
		open_relic_draft()
	else:
		enter_build_phase()


func enter_build_phase() -> void:
	update_round_count()
	update_play_pause_button()


func calculate_end_round_reward() -> int:
	var reward := 20 + round_number * 5
	if get_relic_count(&"dividends") > 0:
		reward += mini(
			floori(float(money) * GameStats.DIVIDENDS_INTEREST_RATE),
			GameStats.DIVIDENDS_INTEREST_CAP
		)
	return reward


func clear_active_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("tower_projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()
	for resolver in get_tree().get_nodes_in_group("tower_attack_resolvers"):
		if is_instance_valid(resolver):
			resolver.queue_free()
	for effect in get_tree().get_nodes_in_group("tower_attack_visuals"):
		if is_instance_valid(effect):
			effect.queue_free()


func get_shared_spore_target(requesting_tower: Node) -> Node2D:
	refresh_spore_network_cache()
	if not is_instance_valid(requesting_tower):
		return null
	var requesting_owner_id := requesting_tower.get_instance_id()
	if (
		spore_network_primary_owner_id != requesting_owner_id
		and is_valid_spore_network_target(spore_network_primary_target)
	):
		return spore_network_primary_target
	if (
		spore_network_secondary_owner_id != requesting_owner_id
		and is_valid_spore_network_target(spore_network_secondary_target)
	):
		return spore_network_secondary_target
	return null


func refresh_spore_network_cache() -> void:
	var current_time_msec := Time.get_ticks_msec()
	if current_time_msec - spore_network_last_refresh_msec < 200:
		return
	spore_network_last_refresh_msec = current_time_msec
	spore_network_primary_owner_id = 0
	spore_network_primary_target = null
	spore_network_secondary_owner_id = 0
	spore_network_secondary_target = null
	var owner_targets: Dictionary = {}
	for candidate in get_tree().get_nodes_in_group("spawned_units"):
		if (
			candidate.unit_id != &"spore_turret"
			or not is_instance_valid(candidate.parent_tower)
			or not candidate.locally_acquired_target
			or not is_valid_spore_network_target(candidate.local_target)
		):
			continue
		var owner_id: int = candidate.parent_tower.get_instance_id()
		var progress := float(candidate.local_target.path_follow.progress)
		if (
			not owner_targets.has(owner_id)
			or progress > float(owner_targets[owner_id]["progress"])
		):
			owner_targets[owner_id] = {
				"target": candidate.local_target,
				"progress": progress,
			}
	for owner_id in owner_targets:
		var entry: Dictionary = owner_targets[owner_id]
		var entry_progress := float(entry["progress"])
		var primary_progress := get_spore_network_target_progress(
			spore_network_primary_target
		)
		if entry_progress > primary_progress:
			spore_network_secondary_owner_id = spore_network_primary_owner_id
			spore_network_secondary_target = spore_network_primary_target
			spore_network_primary_owner_id = int(owner_id)
			spore_network_primary_target = entry["target"]
		elif entry_progress > get_spore_network_target_progress(
			spore_network_secondary_target
		):
			spore_network_secondary_owner_id = int(owner_id)
			spore_network_secondary_target = entry["target"]


func is_valid_spore_network_target(candidate: Variant) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
		and is_instance_valid(candidate.path_follow)
	)


func get_spore_network_target_progress(candidate: Variant) -> float:
	if not is_valid_spore_network_target(candidate):
		return -INF
	return float(candidate.path_follow.progress)


func open_tower_draft() -> void:
	open_between_round_draft(
		DRAFT_TOWER,
		roll_tower_offers(),
		get_tower_roster_dictionary()
	)


func open_relic_draft() -> void:
	var offers := roll_relic_offers()
	var choice_quantities := get_relic_choice_quantities(offers)
	relic_refresh_count = 0
	open_between_round_draft(
		DRAFT_RELIC,
		offers,
		owned_shop_items,
		choice_quantities
	)


func open_between_round_draft(
	draft_type: StringName,
	offers: Array[StringName],
	owned_items: Dictionary,
	choice_quantities: Dictionary = {}
) -> void:
	if shop_open or game_ended:
		return
	cancel_pending_tower_placement()
	close_all_tower_menus()
	shop_open = true
	active_draft_type = draft_type
	active_draft_offers = offers.duplicate()
	active_draft_choice_quantities = choice_quantities.duplicate()
	update_round_count()
	update_play_pause_button()
	var refresh_cost := get_relic_refresh_cost() if draft_type == DRAFT_RELIC else 0
	between_round_shop.open_draft(
		round_number,
		max_rounds,
		draft_type,
		offers,
		owned_items,
		choice_quantities,
		refresh_cost,
		draft_type == DRAFT_RELIC and money >= refresh_cost
	)


func get_relic_choice_quantities(offers: Array[StringName]) -> Dictionary:
	var choice_quantities: Dictionary = {}
	if round_number == 16 and offers.size() >= GAUNTLET_RELIC_CHOICE_COUNT:
		choice_quantities[offers[GAUNTLET_RELIC_CHOICE_COUNT - 1]] = 2
	return choice_quantities


func get_relic_refresh_cost() -> int:
	return (
		RELIC_REFRESH_BASE_COST
		+ relic_refresh_count * RELIC_REFRESH_COST_INCREASE
	)


func _on_relic_refresh_requested() -> void:
	if not shop_open or active_draft_type != DRAFT_RELIC:
		return
	var refresh_cost := get_relic_refresh_cost()
	if not spend_money(refresh_cost):
		return
	var refreshed_offers := roll_different_relic_offers(active_draft_offers)
	relic_refresh_count += 1
	active_draft_offers = refreshed_offers
	active_draft_choice_quantities = get_relic_choice_quantities(refreshed_offers)
	var next_refresh_cost := get_relic_refresh_cost()
	between_round_shop.open_draft(
		round_number,
		max_rounds,
		DRAFT_RELIC,
		active_draft_offers,
		owned_shop_items,
		active_draft_choice_quantities,
		next_refresh_cost,
		money >= next_refresh_cost
	)


func roll_different_relic_offers(
	previous_offers: Array[StringName]
) -> Array[StringName]:
	var refreshed_offers: Array[StringName] = []
	for _attempt in RELIC_REFRESH_DIFFERENT_ROLL_ATTEMPTS:
		refreshed_offers = roll_relic_offers()
		if not relic_offer_sets_match(previous_offers, refreshed_offers):
			return refreshed_offers
	return refreshed_offers


func relic_offer_sets_match(
	first: Array[StringName],
	second: Array[StringName]
) -> bool:
	if first.size() != second.size():
		return false
	for item_id in first:
		if not second.has(item_id):
			return false
	return true


func roll_relic_offers() -> Array[StringName]:
	var available: Array[StringName] = []
	for item_key in GameStats.RELICS:
		var item_id := StringName(item_key)
		var item_stats: Dictionary = GameStats.get_relic(item_id)
		if not bool(item_stats.get("enabled", true)):
			continue
		if (
			not item_stats.get("stackable", false)
			and int(owned_shop_items.get(item_id, 0)) > 0
		):
			continue
		if (
			item_id in [&"singularity_core", &"perfect_mutation"]
			and not has_eligible_built_tower_for_path_relic(item_id)
		):
			continue
		available.append(item_id)
	assert(
		available.size() >= SHOP_CHOICE_COUNT,
		"The shop needs at least %d items." % SHOP_CHOICE_COUNT
	)

	var rarity_weights: Dictionary = RELIC_RARITY_WEIGHTS_BY_ROUND.get(
		round_number,
		{}
	)
	var minimum_rare_plus := int(
		RELIC_MINIMUM_RARE_PLUS_BY_ROUND.get(round_number, 0)
	)
	var offers: Array[StringName] = []
	for _attempt in RELIC_ROLL_MAX_ATTEMPTS:
		offers = roll_weighted_relic_set(
			available,
			rarity_weights,
			SHOP_CHOICE_COUNT
		)
		if (
			count_rare_plus_relics(offers) >= minimum_rare_plus
			and count_applicable_relics(offers) >= MINIMUM_APPLICABLE_RELIC_CHOICES
		):
			if round_number == 16:
				offers.append(choose_stacked_common_relic(available, offers))
			return offers

	assert(
		false,
		"Unable to satisfy the relic draft guarantees for round %d." % round_number
	)
	return offers


func roll_weighted_relic_set(
	available: Array[StringName],
	rarity_weights: Dictionary,
	choice_count: int
) -> Array[StringName]:
	var remaining: Array[StringName] = available.duplicate()
	var offers: Array[StringName] = []
	while offers.size() < choice_count:
		var item_id := choose_weighted_relic_by_rarity(remaining, rarity_weights)
		assert(not item_id.is_empty(), "No eligible relic remains for this draft.")
		offers.append(item_id)
		remaining.erase(item_id)
	return offers


func choose_weighted_relic_by_rarity(
	available: Array[StringName],
	rarity_weights: Dictionary
) -> StringName:
	if rarity_weights.is_empty():
		return available[shop_rng.randi_range(0, available.size() - 1)]

	var eligible_by_rarity: Dictionary = {}
	var total_weight := 0.0
	for rarity_key in rarity_weights:
		var rarity := StringName(rarity_key)
		var eligible: Array[StringName] = []
		for item_id in available:
			if GameStats.get_relic(item_id)["rarity"] == rarity:
				eligible.append(item_id)
		if eligible.is_empty():
			continue
		eligible_by_rarity[rarity] = eligible
		total_weight += float(rarity_weights[rarity_key])

	if eligible_by_rarity.is_empty() or total_weight <= 0.0:
		return &""

	var roll := shop_rng.randf_range(0.0, total_weight)
	for rarity_key in rarity_weights:
		var rarity := StringName(rarity_key)
		if not eligible_by_rarity.has(rarity):
			continue
		roll -= float(rarity_weights[rarity_key])
		if roll <= 0.0:
			var eligible: Array[StringName] = eligible_by_rarity[rarity]
			return eligible[shop_rng.randi_range(0, eligible.size() - 1)]

	var fallback_rarity: StringName = eligible_by_rarity.keys().back()
	var fallback: Array[StringName] = eligible_by_rarity[fallback_rarity]
	return fallback[shop_rng.randi_range(0, fallback.size() - 1)]


func count_rare_plus_relics(offers: Array[StringName]) -> int:
	var count := 0
	for item_id in offers:
		if GameStats.get_relic(item_id)["rarity"] in [&"rare", &"legendary"]:
			count += 1
	return count


func count_applicable_relics(offers: Array[StringName]) -> int:
	var roster_tags := get_tower_roster_tags()
	var count := 0
	for item_id in offers:
		var category: StringName = GameStats.get_relic(item_id)["category"]
		if item_id == &"trade_agreement":
			if has_dedicated_spawner_available():
				count += 1
		elif category == &"global" or roster_tags.has(category):
			count += 1
	return count


func has_dedicated_spawner_available() -> bool:
	for tower_id in TRADE_AGREEMENT_TOWER_IDS:
		if tower_roster.has(tower_id) or tower_id == contraband_tower_id:
			return true
	for tower in get_tree().get_nodes_in_group("towers"):
		if (
			is_instance_valid(tower)
			and tower.is_placed
			and TRADE_AGREEMENT_TOWER_IDS.has(StringName(tower.tower_id))
		):
			return true
	return false


func choose_stacked_common_relic(
	available: Array[StringName],
	excluded: Array[StringName]
) -> StringName:
	var eligible: Array[StringName] = []
	for item_id in available:
		if excluded.has(item_id):
			continue
		var item_stats: Dictionary = GameStats.get_relic(item_id)
		if (
			item_stats["rarity"] == &"common"
			and item_stats.get("stackable", false)
		):
			eligible.append(item_id)
	assert(not eligible.is_empty(), "The Gauntlet needs a stackable common relic.")
	return eligible[shop_rng.randi_range(0, eligible.size() - 1)]


func get_tower_roster_tags() -> Array[StringName]:
	var roster_tags: Array[StringName] = []
	for tower_id in tower_roster:
		var tower_stats: Dictionary = GameStats.get_tower(tower_id)
		for tag_group in ["type_tags", "damage_tags", "bonus_tags"]:
			for tag in tower_stats.get(tag_group, []):
				var typed_tag := StringName(tag)
				if not roster_tags.has(typed_tag):
					roster_tags.append(typed_tag)
	if not contraband_tower_id.is_empty():
		var contraband_stats := GameStats.get_tower(contraband_tower_id)
		for tag_group in ["type_tags", "damage_tags", "bonus_tags"]:
			for tag in contraband_stats.get(tag_group, []):
				var typed_tag := StringName(tag)
				if not roster_tags.has(typed_tag):
					roster_tags.append(typed_tag)
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not tower.is_placed:
			continue
		for tag_group in [tower.type_tags, tower.damage_tags, tower.bonus_tags]:
			for tag in tag_group:
				var typed_tag := StringName(tag)
				if not roster_tags.has(typed_tag):
					roster_tags.append(typed_tag)
	return roster_tags


func roll_tower_offers() -> Array[StringName]:
	var available: Array[StringName] = []
	for tower_key in GameStats.TOWERS:
		var tower_id := StringName(tower_key)
		if not tower_roster.has(tower_id):
			available.append(tower_id)
	assert(
		available.size() >= SHOP_CHOICE_COUNT,
		"The tower draft needs at least %d available towers." % SHOP_CHOICE_COUNT
	)
	var offers: Array[StringName] = []
	while offers.size() < SHOP_CHOICE_COUNT:
		var index := shop_rng.randi_range(0, available.size() - 1)
		offers.append(available.pop_at(index))
	return offers


func _on_draft_confirmed(item_id: StringName, quantity: int) -> void:
	if not shop_open:
		return
	if active_draft_type == DRAFT_TOWER:
		collect_tower(item_id)
	else:
		collect_relic(item_id, quantity)
	shop_open = false
	active_draft_type = &""
	active_draft_offers.clear()
	active_draft_choice_quantities.clear()
	relic_refresh_count = 0
	between_round_shop.hide()
	if item_id in [&"singularity_core", &"perfect_mutation"]:
		begin_path_relic_tower_selection(item_id)
		return
	enter_build_phase()


func collect_relic(item_id: StringName, quantity := 1) -> void:
	var item_stats: Dictionary = GameStats.get_relic(item_id)
	if (
		not item_stats.get("stackable", false)
		and int(owned_shop_items.get(item_id, 0)) > 0
	):
		return
	owned_shop_items[item_id] = (
		int(owned_shop_items.get(item_id, 0))
		+ maxi(quantity, 1)
	)
	if item_id == &"contraband_blueprint":
		activate_contraband_blueprint()
	elif item_id == &"holiday_sale":
		roll_holiday_sale_tower()
	refresh_placed_tower_stats()
	populate_tower_list()
	update_tower_affordability()


func activate_contraband_blueprint() -> void:
	if not contraband_tower_id.is_empty():
		return
	var available: Array[StringName] = []
	for tower_key in GameStats.TOWERS:
		var tower_id := StringName(tower_key)
		if not tower_roster.has(tower_id):
			available.append(tower_id)
	if available.is_empty():
		return
	contraband_tower_id = available[shop_rng.randi_range(0, available.size() - 1)]


func roll_holiday_sale_tower() -> void:
	holiday_sale_tower_id = &""
	if get_relic_count(&"holiday_sale") <= 0 or tower_roster.is_empty():
		return
	holiday_sale_tower_id = tower_roster[shop_rng.randi_range(0, tower_roster.size() - 1)]
	populate_tower_list()
	update_tower_affordability()


func get_sidebar_tower_id(slot_index: int) -> StringName:
	if slot_index >= 0 and slot_index < tower_roster.size():
		return tower_roster[slot_index]
	if slot_index == CONTRABAND_SLOT_INDEX:
		return contraband_tower_id
	return &""


func get_tower_build_cost(tower_id: StringName, is_contraband := false) -> int:
	if is_contraband and tower_id == contraband_tower_id:
		return 0
	var cost := float(GameStats.get_tower(tower_id)["placement_cost"])
	if get_relic_count(&"holiday_sale") > 0:
		cost *= (
			GameStats.HOLIDAY_SALE_DISCOUNT_MULTIPLIER
			if tower_id == holiday_sale_tower_id
			else GameStats.HOLIDAY_SALE_OTHER_COST_MULTIPLIER
		)
	if (
		get_relic_count(&"trade_agreement") > 0
		and TRADE_AGREEMENT_TOWER_IDS.has(tower_id)
	):
		cost *= GameStats.TRADE_AGREEMENT_BUILD_COST_MULTIPLIER
	return maxi(roundi(cost), 0)


func collect_tower(tower_id: StringName) -> void:
	if tower_roster.has(tower_id) or tower_roster.size() >= TOWER_SLOT_COUNT:
		return
	GameStats.get_tower(tower_id)
	tower_roster.append(tower_id)
	populate_tower_list()
	update_tower_affordability()


func get_tower_roster_dictionary() -> Dictionary:
	var roster: Dictionary = {}
	for tower_id in tower_roster:
		roster[tower_id] = 1
	return roster


func refresh_placed_tower_stats() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.is_placed:
			tower.load_base_tags()
			tower.load_level_stats()
			tower.update_menu_buttons()
	refresh_tower_details()


func get_run_bonus(effect: StringName) -> float:
	return float(run_bonuses.get(effect, 0.0))


func get_relic_count(relic_id: StringName) -> int:
	if not bool(GameStats.get_relic(relic_id).get("enabled", true)):
		return 0
	return maxi(int(owned_shop_items.get(relic_id, 0)), 0)


func is_selecting_path_relic_tower() -> bool:
	return not pending_path_relic_tower_selection.is_empty()


func get_path_relic_required_type(relic_id: StringName) -> StringName:
	return &"technology" if relic_id == &"singularity_core" else &"biological"


func is_tower_eligible_for_path_relic(tower: Node, relic_id: StringName) -> bool:
	return (
		is_instance_valid(tower)
		and not tower.is_queued_for_deletion()
		and bool(tower.get("is_placed"))
		and tower.has_method("has_type_tag")
		and tower.has_type_tag(get_path_relic_required_type(relic_id))
		and tower.has_method("has_path_options")
		and tower.has_path_options()
		and StringName(tower.get("dual_path_relic_source")).is_empty()
	)


func has_eligible_built_tower_for_path_relic(relic_id: StringName) -> bool:
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_tower_eligible_for_path_relic(tower, relic_id):
			return true
	return false


func begin_path_relic_tower_selection(relic_id: StringName) -> void:
	pending_path_relic_tower_selection = relic_id
	close_all_tower_menus()
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and bool(tower.get("is_placed")):
			tower.set_range_preview(
				true,
				is_tower_eligible_for_path_relic(tower, relic_id)
			)
	update_round_count()
	update_play_pause_button()


func try_assign_path_relic_to_tower(tower: Node) -> void:
	if not is_selecting_path_relic_tower():
		return
	var relic_id := pending_path_relic_tower_selection
	if not is_tower_eligible_for_path_relic(tower, relic_id):
		return
	tower.grant_dual_path_relic(relic_id)
	pending_path_relic_tower_selection = &""
	for candidate in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(candidate) and bool(candidate.get("is_placed")):
			candidate.set_range_preview(false)
	update_round_count()
	update_play_pause_button()
	show_tower_details(tower)


func can_tower_purchase_both_paths(tower: Node) -> bool:
	return (
		is_instance_valid(tower)
		and not StringName(tower.get("dual_path_relic_source")).is_empty()
	)


func cancel_pending_tower_placement() -> void:
	if is_instance_valid(tower_to_place):
		clear_tower_details(tower_to_place)
		tower_to_place.queue_free()
	tower_to_place = null
	place_mode = false
	build_mode = false
	pending_tower_type = &""
	pending_tower_cost = 0
	pending_tower_is_contraband = false
	tower_list.deselect_all()
	update_play_pause_button()
	
func _spawn_mob():
	if not spawning_active or spawn_schedule.is_empty():
		mobs_left_to_spawn = 0
		spawntimer.stop()
		return
	var spawn_event: Dictionary = spawn_schedule.front()
	var event_cap := active_enemy_cap
	if not spawn_event.get("special_event", false):
		if current_round_type == ROUND_ELITE:
			event_cap = maxi(active_enemy_cap - ELITE_EVENT_RESERVED_SLOTS, 1)
		elif current_round_type == ROUND_GAUNTLET:
			event_cap = maxi(active_enemy_cap - GAUNTLET_EVENT_RESERVED_SLOTS, 1)
	if mobs_alive >= event_cap:
		spawntimer.start(0.2)
		return

	var enemy_id: StringName = spawn_event["enemy_id"]
	var spawn_cost := get_enemy_spawn_cost(enemy_id)
	var free_spawn: bool = spawn_event.get("free_spawn", false)
	if not free_spawn and spawn_threat < spawn_cost:
		spawntimer.start(0.1)
		return

	spawn_schedule.pop_front()
	if not free_spawn:
		spawn_threat -= spawn_cost
	_create_mob(
		enemy_id,
		0.0,
		spawn_event.get("variant", VARIANT_NORMAL)
	)
	mobs_left_to_spawn = spawn_schedule.size()

	if spawn_schedule.is_empty():
		spawntimer.stop()
		director_cooldown = spawn_event["delay_after"]
	else:
		var delay_after: float = spawn_event["delay_after"]
		spawntimer.start(delay_after)


func _create_mob(
	enemy_id: StringName,
	start_progress: float,
	spawn_variant: StringName = VARIANT_NORMAL
) -> void:
	if game_ended:
		return

	var mob = MOB_SCENE.instantiate()
	mob.enemy_id = enemy_id
	mob.wave_number = round_number
	mob.health_multiplier = get_enemy_health_multiplier(round_number)
	mob.spawn_variant = spawn_variant
	mob.mob_killed.connect(_on_mob_killed)
	mob.damage_received.connect(_on_mob_damage_received)
	mob.eliminated.connect(_on_mob_eliminated)
	mob.reached_end.connect(_on_mob_reached_end)
	mob.spawn_requested.connect(_on_mob_spawn_requested)
	var pf := PathFollow2D.new()
	$path.add_child(pf)
	pf.loop = false
	pf.add_child(mob)
	mob.set_path_follow(pf, start_progress)
	mobs_alive += 1


func _on_mob_spawn_requested(
	enemy_id: StringName,
	path_progress: float,
	spawn_variant: StringName
) -> void:
	if mobs_alive >= active_enemy_cap:
		return
	_create_mob(enemy_id, path_progress, spawn_variant)


func choose_wave_spawn_style(wave: int) -> StringName:
	var available_styles: Array[StringName] = [&"standard"]
	for style_name in WAVE_STYLE_UNLOCKS:
		if wave >= WAVE_STYLE_UNLOCKS[style_name]:
			available_styles.append(style_name)

	return available_styles[
		enemy_rng.randi_range(0, available_styles.size() - 1)
	]


func get_wave_duration(wave: int) -> float:
	var mode: Dictionary = GameStats.get_mode(mode_id)
	if wave >= max_rounds:
		return mode.get("final_wave_duration", 90.0)
	return minf(
		mode.get("wave_duration_start", 20.0)
		+ float(wave - 1) * mode.get("wave_duration_growth", 5.0),
		mode.get("wave_duration_max", 60.0)
	)


func get_wave_threat_rate(wave: int) -> float:
	var mode: Dictionary = GameStats.get_mode(mode_id)
	return (
		mode.get("threat_rate_base", 0.35)
		+ float(wave) * mode.get("threat_rate_growth", 0.04)
		+ float(wave * wave) * mode.get("threat_rate_curve", 0.003)
	)


func get_enemy_health_multiplier(wave: int) -> float:
	var mode: Dictionary = GameStats.get_mode(mode_id)
	return (
		mode.get("enemy_health_multiplier_base", 1.0)
		+ float(maxi(wave - 1, 0))
		* mode.get("enemy_health_multiplier_growth", 0.0)
	)


func _process_round_director(delta: float) -> void:
	if not round_active or not spawning_active:
		return

	round_elapsed += delta
	round_time_remaining = maxf(round_time_remaining - delta, 0.0)
	spawn_threat += threat_per_second * threat_continuous_ratio * delta
	threat_chunk_elapsed += delta
	while threat_chunk_interval > 0.0 and threat_chunk_elapsed >= threat_chunk_interval:
		threat_chunk_elapsed -= threat_chunk_interval
		spawn_threat += (
			threat_per_second
			* threat_chunk_interval
			* threat_chunk_ratio
		)
	director_cooldown = maxf(director_cooldown - delta, 0.0)
	process_special_round_events()
	update_round_count()

	if round_time_remaining <= 0.0:
		stop_timed_spawning()
		return

	if not spawntimer.is_stopped():
		return

	if spawn_schedule.is_empty() and director_cooldown <= 0.0:
		spawn_schedule = build_director_group()
		mobs_left_to_spawn = spawn_schedule.size()

	if not spawn_schedule.is_empty():
		spawntimer.start(0.01)


func stop_timed_spawning() -> void:
	spawning_active = false
	spawn_schedule.clear()
	mobs_left_to_spawn = 0
	spawntimer.stop()
	update_round_count()

	if mobs_alive == 0:
		end_round()


func get_available_enemies(wave: int) -> Array[StringName]:
	var available: Array[StringName] = []
	for enemy_key in GameStats.ENEMIES:
		var enemy_id := StringName(enemy_key)
		var stats: Dictionary = GameStats.get_enemy(enemy_id)
		if not stats.get("boss", false) and stats.get("first_wave", 1) <= wave:
			available.append(enemy_id)
	return available


func process_special_round_events() -> void:
	if current_round_type not in [ROUND_ELITE, ROUND_GAUNTLET]:
		return

	var final_pack_time := round_duration * FINAL_ELITE_PACK_START_RATIO
	if not final_elite_pack_spawned and round_elapsed >= final_pack_time:
		final_elite_pack_spawned = true
		var final_elite_count := 3 if round_number >= 11 else 2
		var final_escort_count := (
			enemy_rng.randi_range(6, 10)
			if current_round_type == ROUND_GAUNTLET
			else enemy_rng.randi_range(4, 7)
		)
		inject_special_spawn_schedule(build_elite_event_schedule(
			final_elite_count,
			final_escort_count,
			VARIANT_HORDE if current_round_type == ROUND_GAUNTLET else VARIANT_NORMAL
		))

	if round_elapsed < next_elite_event_time or round_elapsed >= final_pack_time:
		return

	var elite_count := 1
	var escort_count := enemy_rng.randi_range(3, 6)
	var next_interval_min := ELITE_EVENT_MIN_INTERVAL
	var next_interval_max := ELITE_EVENT_MAX_INTERVAL
	var escort_variant := VARIANT_NORMAL
	if current_round_type == ROUND_GAUNTLET:
		elite_count = enemy_rng.randi_range(1, 3)
		escort_count = enemy_rng.randi_range(4, 8)
		next_interval_min = GAUNTLET_ELITE_MIN_INTERVAL
		next_interval_max = GAUNTLET_ELITE_MAX_INTERVAL
		escort_variant = VARIANT_HORDE
	elif round_number == 6:
		elite_count = 2 if enemy_rng.randf() < 0.25 else 1
	else:
		elite_count = enemy_rng.randi_range(1, 2)

	inject_special_spawn_schedule(build_elite_event_schedule(
		elite_count,
		escort_count,
		escort_variant
	))
	next_elite_event_time += enemy_rng.randf_range(
		next_interval_min,
		next_interval_max
	)


func build_elite_event_schedule(
	elite_count: int,
	escort_count: int,
	escort_variant: StringName
) -> Array[Dictionary]:
	var available := get_available_enemies(round_number)
	var schedule: Array[Dictionary] = []
	if available.is_empty():
		return schedule

	var elites: Array[StringName] = []
	for _index in elite_count:
		elites.append(choose_elite_enemy(available))
	var escorts: Array[StringName] = []
	for _index in escort_count:
		escorts.append(choose_weighted_enemy(available))

	var front_escort_count := ceili(escorts.size() / 2.0)
	for _index in front_escort_count:
		append_special_spawn_event(
			schedule,
			escorts.pop_front(),
			escort_variant,
			0.12
		)
	for elite_id in elites:
		append_special_spawn_event(
			schedule,
			elite_id,
			VARIANT_ELITE,
			0.18
		)
		if not escorts.is_empty():
			append_special_spawn_event(
				schedule,
				escorts.pop_front(),
				escort_variant,
				0.12
			)
	while not escorts.is_empty():
		append_special_spawn_event(
			schedule,
			escorts.pop_front(),
			escort_variant,
			0.12
		)
	if not schedule.is_empty():
		schedule.back()["delay_after"] = 1.0
	return schedule


func choose_elite_enemy(available: Array[StringName]) -> StringName:
	var preferred: Array[StringName] = []
	for enemy_id in available:
		var role: StringName = GameStats.get_enemy(enemy_id).get("role", ROLE_FODDER)
		if role in [ROLE_PRESSURE, ROLE_TANK]:
			preferred.append(enemy_id)
	if preferred.is_empty():
		preferred = available.duplicate()
	return choose_weighted_enemy(preferred)


func append_special_spawn_event(
	schedule: Array[Dictionary],
	enemy_id: StringName,
	spawn_variant: StringName,
	delay_after: float
) -> void:
	schedule.append({
		"enemy_id": enemy_id,
		"delay_after": delay_after,
		"style": &"elite_event",
		"variant": spawn_variant,
		"free_spawn": true,
		"special_event": true,
	})


func inject_special_spawn_schedule(schedule: Array[Dictionary]) -> void:
	if schedule.is_empty():
		return
	for index in range(schedule.size() - 1, -1, -1):
		spawn_schedule.push_front(schedule[index])
	mobs_left_to_spawn = spawn_schedule.size()
	spawntimer.stop()
	spawntimer.start(0.01)


func build_director_group() -> Array[Dictionary]:
	var available := get_available_enemies(round_number)
	if current_round_type == ROUND_PAYDAY:
		available = available.filter(
			func(enemy_id: StringName) -> bool:
				var role: StringName = GameStats.get_enemy(enemy_id).get(
					"role",
					ROLE_FODDER
				)
				return role in [ROLE_FODDER, ROLE_PRESSURE]
		)
	if available.is_empty():
		return []

	var group_style := current_wave_spawn_style
	if current_round_type == ROUND_GAUNTLET:
		group_style = choose_gauntlet_spawn_style()
	elif current_round_type == ROUND_PAYDAY:
		group_style = choose_payday_spawn_style()
	var group_size := get_director_group_size(group_style)
	if current_round_type in [ROUND_HORDE, ROUND_GAUNTLET, ROUND_PAYDAY]:
		group_size = maxi(
			1,
			roundi(group_size * HORDE_GROUP_SIZE_MULTIPLIER)
		)
	var enemy_queue := build_role_based_enemy_queue(
		group_style,
		group_size,
		available
	)

	var schedule: Array[Dictionary]
	match group_style:
		&"pulses":
			schedule = build_pulse_schedule(enemy_queue)
		&"simultaneous_batch":
			schedule = build_simultaneous_batch_schedule(enemy_queue)
		&"convoy":
			schedule = build_convoy_schedule(enemy_queue)
		&"sandwich":
			schedule = build_sandwich_schedule(enemy_queue)
		&"escorted_elite":
			schedule = build_escorted_elite_schedule(enemy_queue)
		_:
			schedule = build_standard_schedule(enemy_queue)
	if current_round_type in [ROUND_HORDE, ROUND_GAUNTLET, ROUND_PAYDAY]:
		var spawn_variant := (
			VARIANT_PAYDAY
			if current_round_type == ROUND_PAYDAY
			else VARIANT_HORDE
		)
		apply_spawn_schedule_variant(
			schedule,
			spawn_variant,
			HORDE_SPAWN_DELAY_MULTIPLIER
		)
	return schedule


func choose_gauntlet_spawn_style() -> StringName:
	var styles: Array[StringName] = [
		&"pulses",
		&"simultaneous_batch",
		&"convoy",
		&"sandwich",
		&"escorted_elite",
		&"stream",
	]
	if gauntlet_style_repeat_count >= 2:
		styles.erase(last_gauntlet_spawn_style)
	var selected := styles[enemy_rng.randi_range(0, styles.size() - 1)]
	if selected == last_gauntlet_spawn_style:
		gauntlet_style_repeat_count += 1
	else:
		last_gauntlet_spawn_style = selected
		gauntlet_style_repeat_count = 1
	return selected


func choose_payday_spawn_style() -> StringName:
	var styles: Array[StringName] = [
		&"stream",
		&"pulses",
		&"simultaneous_batch",
		&"burst",
	]
	return styles[enemy_rng.randi_range(0, styles.size() - 1)]


func apply_spawn_schedule_variant(
	schedule: Array[Dictionary],
	spawn_variant: StringName,
	delay_multiplier: float
) -> void:
	for spawn_event in schedule:
		spawn_event["variant"] = spawn_variant
		spawn_event["delay_after"] = maxf(
			float(spawn_event.get("delay_after", 0.1)) * delay_multiplier,
			0.01
		)


func build_role_based_enemy_queue(
	style_name: StringName,
	group_size: int,
	available: Array[StringName]
) -> Array[StringName]:
	var group: Array[StringName] = []
	var recipe_style := style_name
	if recipe_style == &"standard" or recipe_style == &"boss_escort":
		recipe_style = &"steady"

	var forced_roles: Array[StringName] = []
	match style_name:
		&"convoy", &"escorted_elite":
			forced_roles = [ROLE_TANK]
		&"sandwich":
			forced_roles = [ROLE_TANK, ROLE_TANK]

	for forced_role in forced_roles:
		var forced_enemy := choose_enemy_for_role(
			forced_role,
			available,
			group,
			group_size
		)
		if not forced_enemy.is_empty():
			group.append(forced_enemy)

	if style_name == &"standard" or style_name == &"boss_escort":
		var leader_role := choose_formation_role(
			recipe_style,
			available,
			group,
			group_size
		)
		var leader := choose_enemy_for_role(
			leader_role,
			available,
			group,
			group_size
		)
		if not leader.is_empty():
			group.push_front(leader)
			recipe_style = GameStats.get_enemy(leader).get("spawn_style", &"steady")

	while group.size() < group_size:
		var role := choose_formation_role(
			recipe_style,
			available,
			group,
			group_size
		)
		var enemy_id := choose_enemy_for_role(
			role,
			available,
			group,
			group_size
		)
		if enemy_id.is_empty():
			break
		group.append(enemy_id)

	return group


func choose_formation_role(
	style_name: StringName,
	available: Array[StringName],
	current_group: Array[StringName],
	group_size: int
) -> StringName:
	var wave_weights := get_wave_role_weights(round_number)
	var formation_weights: Dictionary = FORMATION_ROLE_WEIGHTS.get(
		style_name,
		FORMATION_ROLE_WEIGHTS[&"steady"]
	)
	var roles: Array[StringName] = [
		ROLE_FODDER,
		ROLE_PRESSURE,
		ROLE_TANK,
		ROLE_SUPPORT,
	]
	var candidates: Array[StringName] = []
	var candidate_weights: Array[float] = []
	var total_weight := 0.0

	for role in roles:
		if role == ROLE_SUPPORT and count_role_in_group(current_group, ROLE_SUPPORT) >= 1:
			continue
		if get_valid_enemies_for_role(
			role,
			available,
			current_group,
			group_size
		).is_empty():
			continue

		var weight: float = (
			float(wave_weights.get(role, 0.0))
			+ float(formation_weights.get(role, 0.0))
		) * 0.5
		if weight <= 0.0:
			continue
		candidates.append(role)
		candidate_weights.append(weight)
		total_weight += weight

	if candidates.is_empty():
		return ROLE_FODDER

	var roll := enemy_rng.randf_range(0.0, total_weight)
	for index in candidates.size():
		roll -= candidate_weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()


func get_wave_role_weights(wave: int) -> Dictionary:
	for entry in WAVE_ROLE_WEIGHTS:
		if wave <= entry["maximum_wave"]:
			return entry["weights"]
	return WAVE_ROLE_WEIGHTS.back()["weights"]


func choose_enemy_for_role(
	role: StringName,
	available: Array[StringName],
	current_group: Array[StringName],
	group_size: int
) -> StringName:
	var candidates := get_valid_enemies_for_role(
		role,
		available,
		current_group,
		group_size
	)
	if candidates.is_empty():
		for fallback_role in [ROLE_FODDER, ROLE_PRESSURE, ROLE_TANK, ROLE_SUPPORT]:
			candidates = get_valid_enemies_for_role(
				fallback_role,
				available,
				current_group,
				group_size
			)
			if not candidates.is_empty():
				break
	if candidates.is_empty():
		return &""
	return choose_weighted_enemy(candidates)


func get_valid_enemies_for_role(
	role: StringName,
	available: Array[StringName],
	current_group: Array[StringName],
	group_size: int
) -> Array[StringName]:
	var candidates: Array[StringName] = []
	for enemy_id in available:
		var stats: Dictionary = GameStats.get_enemy(enemy_id)
		if stats.get("role", ROLE_FODDER) != role:
			continue
		if role == ROLE_SUPPORT and count_role_in_group(current_group, ROLE_SUPPORT) >= 1:
			continue
		if enemy_id in [&"buffer", &"summoner"]:
			if get_active_enemy_count(enemy_id) + current_group.count(enemy_id) >= 2:
				continue
		if enemy_id == &"rusher":
			var rusher_limit := maxi(1, floori(float(group_size) * 0.3))
			if current_group.count(&"rusher") >= rusher_limit:
				continue
		candidates.append(enemy_id)
	return candidates


func count_role_in_group(group: Array[StringName], role: StringName) -> int:
	var count := 0
	for enemy_id in group:
		if GameStats.get_enemy(enemy_id).get("role", ROLE_FODDER) == role:
			count += 1
	return count


func get_active_enemy_count(enemy_id: StringName) -> int:
	var count := 0
	for mob in get_tree().get_nodes_in_group("mobs"):
		if (
			is_instance_valid(mob)
			and not mob.finished
			and mob.enemy_id == enemy_id
		):
			count += 1
	return count


func get_director_group_size(style_name: StringName) -> int:
	match style_name:
		&"pulses":
			return enemy_rng.randi_range(7, 12)
		&"simultaneous_batch":
			return enemy_rng.randi_range(8, 14)
		&"convoy":
			return 8
		&"sandwich":
			return enemy_rng.randi_range(10, 14)
		&"escorted_elite":
			return 9
		_:
			return enemy_rng.randi_range(6, 10)


func build_timed_boss_opening() -> Array[Dictionary]:
	var available := get_available_enemies(round_number)
	if available.is_empty():
		var boss_only_schedule: Array[Dictionary] = []
		append_enemy_group(
			boss_only_schedule,
			[&"brute"],
			0.2,
			2.0,
			&"boss_escort"
		)
		return boss_only_schedule

	var cheapest: Array[StringName] = []
	var cheapest_cost := 2147483647
	for enemy_id in available:
		var cost := get_enemy_threat_cost(enemy_id)
		if cost < cheapest_cost:
			cheapest_cost = cost
			cheapest = [enemy_id]
		elif cost == cheapest_cost:
			cheapest.append(enemy_id)

	var escorts: Array[StringName] = []
	for _index in 4:
		escorts.append(choose_weighted_enemy(cheapest))

	var boss_group: Array[StringName] = [escorts[0], escorts[1], &"brute"]
	boss_group.append(escorts[2])
	boss_group.append(escorts[3])
	var schedule: Array[Dictionary] = []
	append_enemy_group(schedule, boss_group, 0.2, 2.0, &"boss_escort")
	return schedule


func build_standard_schedule(enemy_queue: Array[StringName]) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []

	while not enemy_queue.is_empty():
		var group_leader: StringName = enemy_queue[0]
		var leader_stats: Dictionary = GameStats.get_enemy(group_leader)
		var style_name: StringName = leader_stats.get("spawn_style", &"steady")
		var style: Dictionary = SPAWN_STYLES.get(style_name, SPAWN_STYLES[&"steady"])
		var minimum_group_size: int = style["minimum_group_size"]
		var maximum_group_size: int = style["maximum_group_size"]
		var requested_size := enemy_rng.randi_range(
			minimum_group_size,
			maximum_group_size
		)
		var group_size := mini(requested_size, enemy_queue.size())
		var interval: float = style["interval"]
		var gap_after_group: float = style["gap_after_group"]

		var group := take_front_group(enemy_queue, group_size)
		append_enemy_group(
			schedule,
			group,
			interval,
			gap_after_group,
			style_name
		)

	return schedule


func build_pulse_schedule(enemy_queue: Array[StringName]) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var group_size := mini(enemy_rng.randi_range(7, 12), enemy_queue.size())
		var group := take_front_group(enemy_queue, group_size)
		append_enemy_group(schedule, group, 0.12, 1.2, &"pulses")
	return schedule


func build_simultaneous_batch_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var group_size := mini(enemy_rng.randi_range(8, 14), enemy_queue.size())
		var group := take_front_group(enemy_queue, group_size)
		append_enemy_group(schedule, group, 0.05, 1.2, &"simultaneous_batch")
	return schedule


func build_convoy_schedule(enemy_queue: Array[StringName]) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var group: Array[StringName] = [take_enemy_by_role(enemy_queue, ROLE_TANK)]
		var escort_count := mini(7, enemy_queue.size())
		for _index in escort_count:
			group.append(take_weakest_enemy(enemy_queue))
		append_enemy_group(schedule, group, 0.2, 1.2, &"convoy")
	return schedule


func build_escorted_elite_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var elite := take_enemy_by_role(enemy_queue, ROLE_TANK)
		var escorts: Array[StringName] = []
		var escort_count := mini(8, enemy_queue.size())
		for _index in escort_count:
			escorts.append(take_weakest_enemy(enemy_queue))

		var group: Array[StringName] = []
		var front_count := ceili(escorts.size() / 2.0)
		for _index in front_count:
			group.append(escorts.pop_front())
		group.append(elite)
		group.append_array(escorts)
		append_enemy_group(schedule, group, 0.16, 1.3, &"escorted_elite")
	return schedule


func build_sandwich_schedule(enemy_queue: Array[StringName]) -> Array[Dictionary]:
	if enemy_queue.size() < 3:
		return build_standard_schedule(enemy_queue)

	var first_elite := take_enemy_by_role(enemy_queue, ROLE_TANK)
	var last_elite := take_enemy_by_role(enemy_queue, ROLE_TANK)
	var group: Array[StringName] = [first_elite]
	group.append_array(enemy_queue)
	group.append(last_elite)

	var schedule: Array[Dictionary] = []
	append_enemy_group(schedule, group, 0.3, 0.8, &"sandwich")
	return schedule


func take_front_group(
	enemy_queue: Array[StringName],
	count: int
) -> Array[StringName]:
	var group: Array[StringName] = []
	for _index in mini(count, enemy_queue.size()):
		group.append(enemy_queue.pop_front())
	return group


func append_enemy_group(
	schedule: Array[Dictionary],
	group: Array[StringName],
	interval: float,
	gap_after_group: float,
	style_name: StringName
) -> void:
	for index in group.size():
		var delay_after := interval
		if index == group.size() - 1:
			delay_after = gap_after_group
		schedule.append({
			"enemy_id": group[index],
			"delay_after": delay_after,
			"style": style_name,
		})


func take_strongest_enemy(enemy_queue: Array[StringName]) -> StringName:
	return take_enemy_by_threat(enemy_queue, true)


func take_enemy_by_role(
	enemy_queue: Array[StringName],
	role: StringName
) -> StringName:
	for index in enemy_queue.size():
		if GameStats.get_enemy(enemy_queue[index]).get("role", ROLE_FODDER) == role:
			var selected := enemy_queue[index]
			enemy_queue.remove_at(index)
			return selected
	return take_strongest_enemy(enemy_queue)


func take_weakest_enemy(enemy_queue: Array[StringName]) -> StringName:
	return take_enemy_by_threat(enemy_queue, false)


func take_enemy_by_threat(
	enemy_queue: Array[StringName],
	take_strongest: bool
) -> StringName:
	if enemy_queue.is_empty():
		return &""

	var selected_index := 0
	var selected_cost := get_enemy_threat_cost(enemy_queue[0])

	for index in range(1, enemy_queue.size()):
		var candidate_cost := get_enemy_threat_cost(enemy_queue[index])
		if (
			(take_strongest and candidate_cost > selected_cost)
			or (not take_strongest and candidate_cost < selected_cost)
		):
			selected_index = index
			selected_cost = candidate_cost

	var selected_enemy := enemy_queue[selected_index]
	enemy_queue.remove_at(selected_index)
	return selected_enemy


func get_enemy_threat_cost(enemy_id: StringName) -> int:
	return GameStats.get_enemy(enemy_id).get("threat_cost", 1)


func get_enemy_spawn_cost(enemy_id: StringName) -> int:
	var stats: Dictionary = GameStats.get_enemy(enemy_id)
	return stats.get("spawn_cost", stats.get("threat_cost", 1))


func choose_weighted_enemy(available: Array[StringName]) -> StringName:
	if available.is_empty():
		return &""

	var total_weight := 0
	for enemy_id in available:
		total_weight += GameStats.get_enemy(enemy_id).get("spawn_weight", 1)
	if total_weight <= 0:
		return available[0]

	var roll := enemy_rng.randi_range(1, total_weight)
	for enemy_id in available:
		roll -= GameStats.get_enemy(enemy_id).get("spawn_weight", 1)
		if roll <= 0:
			return enemy_id

	return available[0]


func _on_mob_reached_end(damage: int) -> void:
	lives -= damage
	lives = maxi(lives, 0)
	update_lives()
	
	if lives == 0:
		defeat()
		return

	mob_finished()

func defeat() -> void:
	finish_game("Defeat!\nYou reached round %d." % round_number)

func victory() -> void:
	finish_game("Victory!\nYou completed all %d rounds." % max_rounds)

func finish_game(message: String) -> void:
	if game_ended:
		return
	game_ended = true
	round_active = false
	spawning_active = false
	spawn_schedule.clear()
	mobs_left_to_spawn = 0
	spawntimer.stop()
	clear_active_projectiles()
	shop_open = false
	between_round_shop.hide()
	place_mode = false
	build_mode = false
	close_all_tower_menus()
	clear_tower_details()

	if is_instance_valid(tower_to_place):
		tower_to_place.queue_free()
		tower_to_place = null
	
	pause_button.disabled = true
	speed_button.disabled = true
	tower_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_timer_display.text = "Run complete"
	$MainUI/endscreen/VBoxContainer/resultlabel.text = message
	$MainUI/endscreen.visible = true
	
	for pf in $path.get_children():
		pf.queue_free()
	mobs_alive = 0

func _on_mob_killed(reward: int) -> void:
	var reward_multiplier := 1.0 + get_run_bonus(&"kill_reward")
	add_money(roundi(float(reward) * reward_multiplier))
	mob_finished()


func _on_mob_damage_received(
	_mob: Node2D,
	amount: int,
	context: AttackContext
) -> void:
	if context == null or amount <= 0:
		return
	if context.root_tower_instance_id > 0:
		damage_by_tower_instance[context.root_tower_instance_id] = (
			int(damage_by_tower_instance.get(context.root_tower_instance_id, 0))
			+ amount
		)
	if not context.root_tower_type.is_empty():
		damage_by_tower_type[context.root_tower_type] = (
			int(damage_by_tower_type.get(context.root_tower_type, 0)) + amount
		)


func _on_mob_eliminated(
	_mob: Node2D,
	_reward: int,
	context: AttackContext,
	_elimination_kind: StringName
) -> void:
	if context == null:
		return
	if context.root_tower_instance_id > 0:
		eliminations_by_tower_instance[context.root_tower_instance_id] = (
			int(eliminations_by_tower_instance.get(
				context.root_tower_instance_id,
				0
			)) + 1
		)
	if not context.root_tower_type.is_empty():
		eliminations_by_tower_type[context.root_tower_type] = (
			int(eliminations_by_tower_type.get(context.root_tower_type, 0)) + 1
		)

func mob_finished() -> void:
	mobs_alive = maxi(mobs_alive - 1, 0)

	if not spawning_active and mobs_left_to_spawn == 0 and mobs_alive == 0:
		end_round()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(manual_targeting_tower):
		if manual_targeting_tower != null:
			manual_targeting_tower = null
		return
	if (
		event.is_action_pressed("ui_cancel")
		or (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_RIGHT
			and event.pressed
		)
	):
		get_viewport().set_input_as_handled()
		cancel_manual_tower_targeting()
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		get_viewport().set_input_as_handled()
		var targeting_tower := manual_targeting_tower
		if targeting_tower.confirm_manual_target_position(get_global_mouse_position()):
			finish_manual_tower_targeting(targeting_tower)

func _unhandled_input(event: InputEvent) -> void:
	if is_selecting_path_relic_tower():
		return
	if event.is_action_pressed("ui_cancel") and not game_ended:
		get_viewport().set_input_as_handled()
		pause_menu.open_menu(owned_shop_items)
		return

	if shop_open:
		return

	if (
		place_mode
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		finalize_tower_placement()
		return

	if event is InputEventMouseButton and event.pressed and not build_mode:
		close_all_tower_menus()

func can_place_tower(pos: Vector2) -> bool:
	if not is_instance_valid(tower_to_place):
		return false

	var tower_id: StringName = tower_to_place.tower_id
	for cell in get_tower_build_cells(pos, tower_id):
		if not is_build_cell_in_playable_area(cell):
			return false
		if is_build_cell_blocked_by_path(cell):
			return false
		if is_build_cell_occupied(cell):
			return false

	var space_state = get_world_2d().direct_space_state
	var shape_node := tower_to_place.get_node("clickarea/CollisionShape2D")
	var shape: Shape2D = shape_node.shape
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = BUILD_BLOCKER_COLLISION_MASK
	var clickarea := tower_to_place.get_node("clickarea")
	params.transform = Transform2D(0, pos + clickarea.position)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var result = space_state.intersect_shape(params)
	return result.is_empty()

func finalize_tower_placement() -> void:
	if not is_instance_valid(tower_to_place):
		return
	var pos := tower_to_place.position
	if not can_place_tower(pos):
		return
	place_mode = false
	tower_to_place.position = pos
	tower_to_place.get_node("towerconfirm").visible = true
	tower_list.deselect_all()


func world_to_build_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / PLACEMENT_SNAP_SIZE),
		floori(world_position.y / PLACEMENT_SNAP_SIZE)
	)


func get_tower_footprint(tower_id: StringName) -> Vector2i:
	return GameStats.get_tower(tower_id).get("footprint_cells", Vector2i.ONE)


func get_tower_build_position(world_position: Vector2, tower_id: StringName) -> Vector2:
	var footprint_size := Vector2(get_tower_footprint(tower_id)) * BUILD_CELL_SIZE
	var snap_step := Vector2.ONE * PLACEMENT_SNAP_SIZE
	var snapped_origin := (world_position - footprint_size * 0.5).snapped(snap_step)
	return snapped_origin + footprint_size * 0.5


func get_tower_build_cells(tower_position: Vector2, tower_id: StringName) -> Array[Vector2i]:
	var footprint_size := Vector2(get_tower_footprint(tower_id)) * BUILD_CELL_SIZE
	var footprint_cells := Vector2i(
		roundi(footprint_size.x / PLACEMENT_SNAP_SIZE),
		roundi(footprint_size.y / PLACEMENT_SNAP_SIZE)
	)
	var origin_world := tower_position - footprint_size * 0.5
	var origin_cell := world_to_build_cell(origin_world + Vector2(0.01, 0.01))
	var cells: Array[Vector2i] = []
	for y_offset in footprint_cells.y:
		for x_offset in footprint_cells.x:
			cells.append(origin_cell + Vector2i(x_offset, y_offset))
	return cells


func get_build_cell_center(cell: Vector2i) -> Vector2:
	return (
		Vector2(cell) * PLACEMENT_SNAP_SIZE
		+ Vector2.ONE * PLACEMENT_SNAP_SIZE * 0.5
	)


func is_build_cell_in_playable_area(cell: Vector2i) -> bool:
	var cell_top_left := Vector2(cell) * PLACEMENT_SNAP_SIZE
	var cell_bottom_right := cell_top_left + Vector2.ONE * PLACEMENT_SNAP_SIZE
	var playable_right := get_playable_right_edge()
	var viewport_size := get_viewport_rect().size
	return (
		cell_top_left.x >= 0.0
		and cell_top_left.y >= 0.0
		and cell_bottom_right.x <= playable_right
		and cell_bottom_right.y <= viewport_size.y
	)


func get_playable_right_edge() -> float:
	return playable_map_width


func is_world_position_in_playable_area(world_position: Vector2) -> bool:
	var viewport_size := get_viewport_rect().size
	return (
		world_position.x >= 0.0
		and world_position.y >= 0.0
		and world_position.x <= get_playable_right_edge()
		and world_position.y <= viewport_size.y
	)


func _align_sidebar_to_build_grid() -> void:
	var viewport_width := get_viewport_rect().size.x
	var available_map_width := maxf(viewport_width - MIN_SIDEBAR_WIDTH, 0.0)
	playable_map_width = floorf(available_map_width / BUILD_CELL_SIZE) * BUILD_CELL_SIZE
	sidebar.offset_left = -(viewport_width - playable_map_width)
	print("Viewport:", viewport_width)
	print("Playable:", playable_map_width)
	print("Sidebar:", sidebar.offset_left)

func is_build_cell_blocked_by_path(cell: Vector2i) -> bool:
	var path_node := $path as Path2D
	if path_node.curve == null:
		return false
	var cell_center := get_build_cell_center(cell)
	var closest_local := path_node.curve.get_closest_point(path_node.to_local(cell_center))
	var closest_global := path_node.to_global(closest_local)
	return cell_center.distance_to(closest_global) <= PATH_NO_BUILD_RADIUS


func get_path_cell_positions_near(
	origin: Vector2,
	maximum_radius: float
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if maximum_radius <= 0.0:
		return positions
	var path_node := $path as Path2D
	if path_node.curve == null:
		return positions
	var minimum_cell := world_to_build_cell(
		origin - Vector2.ONE * maximum_radius
	)
	var maximum_cell := world_to_build_cell(
		origin + Vector2.ONE * maximum_radius
	)
	var centerline_snap_distance := PLACEMENT_SNAP_SIZE * 0.75
	for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
		for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not is_build_cell_in_playable_area(cell):
				continue
			var cell_center := get_build_cell_center(cell)
			if origin.distance_to(cell_center) > maximum_radius:
				continue
			var closest_local := path_node.curve.get_closest_point(
				path_node.to_local(cell_center)
			)
			var closest_global := path_node.to_global(closest_local)
			if cell_center.distance_to(closest_global) > centerline_snap_distance:
				continue
			positions.append(cell_center)
	return positions


func is_build_cell_occupied(cell: Vector2i) -> bool:
	if not occupied_build_cells.has(cell):
		return false
	var occupying_tower = occupied_build_cells[cell]
	if is_instance_valid(occupying_tower) and not occupying_tower.is_queued_for_deletion():
		return true
	occupied_build_cells.erase(cell)
	return false


func reserve_tower_build_cells(tower: Node2D) -> void:
	var cells := get_tower_build_cells(tower.position, tower.tower_id)
	for cell in cells:
		occupied_build_cells[cell] = tower
	tower.set_meta("build_cells", cells)


func release_tower_build_cells(tower: Node2D) -> void:
	var cells: Array = tower.get_meta("build_cells", [])
	for cell in cells:
		if occupied_build_cells.get(cell) == tower:
			occupied_build_cells.erase(cell)

func _on_tower_confirmed(tower: Node2D) -> void:
	reserve_tower_build_cells(tower)
	money -= pending_tower_cost
	if pending_tower_is_contraband and tower.tower_id == contraband_tower_id:
		contraband_tower_id = &""
		populate_tower_list()
	update_money()
	pending_tower_type = &""
	pending_tower_cost = 0
	pending_tower_is_contraband = false
	build_mode = false
	tower_to_place = null
	update_play_pause_button()
	show_tower_details(tower)
	call_deferred("refresh_placed_tower_stats")

func _on_tower_cancelled(tower: Node2D) -> void:
	clear_tower_details(tower)
	pending_tower_type = &""
	pending_tower_cost = 0
	pending_tower_is_contraband = false
	build_mode = false
	tower_to_place = null
	update_play_pause_button()


func _on_tower_sold(tower: Node2D) -> void:
	release_tower_build_cells(tower)
	call_deferred("refresh_placed_tower_stats")

func start_build_tower() -> void:
	if game_ended or shop_open or build_mode or pending_tower_type.is_empty():
		return
	close_all_tower_menus()

	place_mode = true
	build_mode = true
	update_play_pause_button()
	tower_to_place = TOWER_SCENE.instantiate()
	tower_to_place.main = self
	tower_to_place.tower_id = pending_tower_type
	tower_to_place.purchase_price = pending_tower_cost
	tower_to_place.tower_confirmed.connect(_on_tower_confirmed)
	tower_to_place.tower_cancelled.connect(_on_tower_cancelled)
	tower_to_place.tower_sold.connect(_on_tower_sold)
	add_child(tower_to_place)
	show_tower_details(tower_to_place)


func can_select_tower() -> bool:
	return not game_ended and not shop_open and not build_mode

@warning_ignore("unused_parameter")
func _on_item_list_item_selected(index: int) -> void:
	if game_ended or shop_open or is_selecting_path_relic_tower():
		tower_list.deselect_all()
		return
	
	var selected_tower_id := get_sidebar_tower_id(index)
	if selected_tower_id.is_empty():
		tower_list.deselect_all()
		return

	var selected_is_contraband := index == CONTRABAND_SLOT_INDEX
	if build_mode:
		if selected_tower_id == pending_tower_type:
			cancel_pending_tower_placement()
			return
		cancel_pending_tower_placement()

	var cost := get_tower_build_cost(selected_tower_id, selected_is_contraband)
	
	if money >= cost:
		pending_tower_type = selected_tower_id
		pending_tower_cost = cost
		pending_tower_is_contraband = selected_is_contraband
		start_build_tower()
		tower_list.select(index)
	else:
		tower_list.deselect_all()

func _on_restartbutton_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
	
func _on_quitbutton_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _on_speed_button_pressed() -> void:
	game_speed = 2.0 if is_equal_approx(game_speed, 1.0) else 1.0
	Engine.time_scale = game_speed
	update_speed_button()


func update_speed_button() -> void:
	var speed_text := "%dx" % int(game_speed)
	speed_button.text = speed_text
	speed_button.tooltip_text = "Game Speed: %s" % speed_text


func _on_pause_button_pressed() -> void:
	if game_ended or shop_open or is_selecting_path_relic_tower():
		return
	if round_active:
		pause_menu.open_menu(owned_shop_items)
	else:
		start_round()


func update_play_pause_button() -> void:
	if game_ended:
		pause_button.disabled = true
		return
	if round_active:
		pause_button.text = "II"
		pause_button.tooltip_text = "Pause"
		pause_button.disabled = false
	else:
		pause_button.text = "▶"
		pause_button.tooltip_text = "Start Round %d" % mini(
			round_number + 1,
			max_rounds
		)
		pause_button.disabled = (
			shop_open or build_mode or is_selecting_path_relic_tower()
		)
