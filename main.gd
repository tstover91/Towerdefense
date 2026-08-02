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
const SHOP_CHOICE_COUNT := 3
const TOWER_STAT_EFFECTS: Array[StringName] = [
	&"tower_damage_flat",
	&"tower_attack_speed",
	&"tower_range",
]
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
const TOWER_SCENES := {
	&"scout": preload("res://tower.tscn"),
	&"cannon": preload("res://cannon.tscn"),
}
const TOWER_ICONS := {
	&"scout": preload("res://icon.svg"),
	&"cannon": preload("res://icon.svg"),
}
const TOWER_ICON_COLORS := {
	&"scout": Color.WHITE,
	&"cannon": Color(0.45, 0.55, 0.62),
}
const ITEM_TOWER_IDS := [&"scout", &"cannon"]
const TOWER_SLOT_COUNT := 5
const AFFORDABLE_TOWER_COLOR := Color(0.35, 1.0, 0.35)
const UNAFFORDABLE_TOWER_COLOR := Color(1.0, 0.3, 0.3)

signal money_changed(new_amount: int)

@onready var spawntimer: Timer = $SpawnTimer
@onready var tower_list: ItemList = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerSelectionArea/ItemList
@onready var between_round_shop: Control = $MainUI/BetweenRoundShop
@onready var pause_menu: Control = $MainUI/PauseMenu
@onready var pause_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/SidebarHeader/PauseButton
@onready var money_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/moneydisplay
@onready var lives_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/livesdisplay
@onready var round_count_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/roundcount
@onready var round_timer_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/roundtimer
@onready var start_button: Button = $MainUI/HUDRoot/startbutton
@onready var tower_details_placeholder: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerDetailsPlaceholder
@onready var tower_stats_layout: VBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout
@onready var tower_name_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout/TowerNameLabel
@onready var tower_level_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout/TowerLevelLabel
@onready var tower_dps_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout/TowerDpsLabel
@onready var tower_upgrade_header: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout/UpgradeHeaderLabel
@onready var tower_upgrade_stats_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerDetailsPanel/DetailsMargin/DetailsLayout/TowerStatsLayout/UpgradeStatsLabel
var lives: int
var max_lives: int
var place_mode := false
var build_mode := false
var tower_to_place: Node2D = null
var money: int
var pending_tower_type: StringName = &""
var pending_tower_cost := 0
var round_number := 0
var mobs_left_to_spawn := 0
var mobs_alive := 0
var spawn_schedule: Array[Dictionary] = []
var enemy_rng := RandomNumberGenerator.new()
var shop_rng := RandomNumberGenerator.new()
var current_wave_spawn_style: StringName = &"standard"
var round_time_remaining := 0.0
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
var round_was_perfect := true
var game_ended := false
var max_rounds: int
var mode_id: StringName = &"easy"
var shop_open := false
var owned_shop_items: Dictionary = {}
var run_bonuses: Dictionary = {}
var displayed_tower: Node = null

func _ready() -> void:
	enemy_rng.randomize()
	shop_rng.randomize()
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
	between_round_shop.reward_chosen.connect(_on_shop_reward_chosen)
	between_round_shop.next_round_requested.connect(_on_shop_next_round_requested)
	start_button.text = "Start Run"


func populate_tower_list() -> void:
	tower_list.clear()
	for slot_index in TOWER_SLOT_COUNT:
		if slot_index < ITEM_TOWER_IDS.size():
			var tower_id: StringName = ITEM_TOWER_IDS[slot_index]
			var tower_stats := GameStats.get_tower(tower_id)
			tower_list.add_item(
				"$%d" % int(tower_stats["placement_cost"]),
				TOWER_ICONS.get(tower_id)
			)
			tower_list.set_item_icon_modulate(
				slot_index,
				TOWER_ICON_COLORS.get(tower_id, Color.WHITE)
			)
			continue

		var placeholder_icon: Texture2D = TOWER_ICONS[ITEM_TOWER_IDS[0]]
		tower_list.add_item("Empty Slot", placeholder_icon)
		tower_list.set_item_icon_modulate(slot_index, Color.TRANSPARENT)
		tower_list.set_item_disabled(slot_index, true)
		tower_list.set_item_selectable(slot_index, false)


func show_tower_details(tower: Node) -> void:
	if not is_instance_valid(tower) or not tower.has_method("get_sidebar_stats"):
		clear_tower_details()
		return

	displayed_tower = tower
	var stats: Dictionary = tower.get_sidebar_stats()
	var is_placed: bool = stats["is_placed"]
	var current_level: int = stats["level"]
	var maximum_level: int = stats["maximum_level"]
	var current_dps: float = stats["dps"]

	tower_details_placeholder.hide()
	tower_stats_layout.show()
	tower_name_label.text = stats["display_name"]
	var show_upgrade_info: bool = stats["show_upgrade_info"] and stats["has_next_level"]
	tower_level_label.visible = is_placed and not show_upgrade_info
	if tower_level_label.visible:
		tower_level_label.text = "Level %d/%d" % [current_level, maximum_level]
	tower_dps_label.visible = not show_upgrade_info
	tower_dps_label.text = "DPS: %.2f" % current_dps

	tower_upgrade_header.visible = show_upgrade_info
	tower_upgrade_stats_label.visible = show_upgrade_info
	if show_upgrade_info:
		var next_level: int = stats["next_level"]
		var next_dps: float = stats["next_dps"]
		tower_upgrade_header.text = "Next Upgrade"
		tower_upgrade_stats_label.text = (
			"Level %d/%d\nDPS: %.2f -> %.2f"
			% [
				next_level,
				maximum_level,
				current_dps,
				next_dps,
			]
		)


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
		var snap := get_global_mouse_position().snapped(Vector2(32, 32))
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
	for slot_index in ITEM_TOWER_IDS.size():
		var tower_id: StringName = ITEM_TOWER_IDS[slot_index]
		var placement_cost: int = GameStats.get_tower(tower_id)["placement_cost"]
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

func _on_startbutton_pressed() -> void:
	if not game_ended and not round_active and not build_mode and not shop_open:
		close_all_tower_menus()
		start_button.hide()
		start_round()


func close_all_tower_menus() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		tower.set_selected(false)

func start_round() -> void:
	if round_active or round_number >= max_rounds or shop_open:
		return
	round_number += 1
	spawn_schedule.clear()
	round_time_remaining = get_wave_duration(round_number)
	threat_per_second = get_wave_threat_rate(round_number)
	var mode: Dictionary = GameStats.get_mode(mode_id)
	spawn_threat = mode.get("starting_spawn_threat", 1.0)
	threat_chunk_elapsed = 0.0
	threat_continuous_ratio = mode.get("threat_continuous_ratio", 1.0)
	threat_chunk_ratio = mode.get("threat_chunk_ratio", 0.0)
	threat_chunk_interval = mode.get("threat_chunk_interval", 4.0)
	active_enemy_cap = mode.get("active_enemy_cap", 120)
	director_cooldown = 0.0
	spawning_active = true
	current_wave_spawn_style = choose_wave_spawn_style(round_number)
	if round_number == max_rounds:
		current_wave_spawn_style = &"boss_escort"
		spawn_schedule = build_timed_boss_opening()
	mobs_left_to_spawn = spawn_schedule.size()
	round_was_perfect = true
	round_active = true
	start_button.disabled = true
	spawntimer.one_shot = true
	update_round_count()
	
func update_round_count() -> void:
	round_count_display.text = "Round: %d/%d" % [round_number, max_rounds]
	if round_active and spawning_active:
		round_timer_display.text = "Spawning: %ds" % ceili(round_time_remaining)
	elif round_active:
		round_timer_display.text = "Clear remaining enemies"
	elif round_number == 0:
		round_timer_display.text = "Ready"
	else:
		round_timer_display.text = "Between rounds"
	
func end_round() -> void:
	if game_ended or not round_active:
		return
	
	round_active = false
	spawning_active = false
	spawn_schedule.clear()
	mobs_left_to_spawn = 0
	spawntimer.stop()
	add_money(calculate_end_round_reward())
	update_round_count()

	if round_number >= max_rounds:
		victory()
	else:
		open_between_round_shop()


func calculate_end_round_reward() -> int:
	var mode: Dictionary = GameStats.get_mode(mode_id)
	var base_reward: int = mode["wave_bonus_base"] + (
		(round_number - 1) * mode["wave_bonus_growth"]
	)
	var clear_reward := 0

	if round_was_perfect:
		clear_reward = floori(base_reward * mode["clear_bonus_multiplier"])

	var reward_multiplier := 1.0 + get_run_bonus(&"round_reward")
	return roundi(float(base_reward + clear_reward) * reward_multiplier)


func open_between_round_shop() -> void:
	if shop_open or game_ended:
		return
	cancel_pending_tower_placement()
	close_all_tower_menus()
	shop_open = true
	start_button.disabled = true
	between_round_shop.open_shop(
		round_number,
		max_rounds,
		roll_shop_offers(),
		owned_shop_items
	)


func roll_shop_offers() -> Array[StringName]:
	var available: Array[StringName] = []
	for item_key in GameStats.SHOP_ITEMS:
		available.append(StringName(item_key))
	assert(
		available.size() >= SHOP_CHOICE_COUNT,
		"The shop needs at least %d items." % SHOP_CHOICE_COUNT
	)

	var offers: Array[StringName] = []
	while offers.size() < SHOP_CHOICE_COUNT:
		var index := shop_rng.randi_range(0, available.size() - 1)
		offers.append(available.pop_at(index))
	return offers


func _on_shop_reward_chosen(item_id: StringName) -> void:
	if not shop_open:
		return
	apply_shop_item(item_id)
	between_round_shop.confirm_reward_choice(item_id, owned_shop_items)


func _on_shop_next_round_requested() -> void:
	if not shop_open:
		return
	shop_open = false
	between_round_shop.hide()
	start_round()


func apply_shop_item(item_id: StringName) -> void:
	var item := GameStats.get_shop_item(item_id)
	var effect: StringName = item["effect"]
	var value: float = item["value"]
	owned_shop_items[item_id] = int(owned_shop_items.get(item_id, 0)) + 1
	run_bonuses[effect] = float(run_bonuses.get(effect, 0.0)) + value

	if effect == &"maximum_health":
		max_lives += roundi(value)
		lives = mini(lives + roundi(value), max_lives)
		update_lives()

	if effect in TOWER_STAT_EFFECTS:
		refresh_placed_tower_stats()


func refresh_placed_tower_stats() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.is_placed:
			tower.load_level_stats()
			tower.update_menu_buttons()
	refresh_tower_details()


func get_run_bonus(effect: StringName) -> float:
	return float(run_bonuses.get(effect, 0.0))


func cancel_pending_tower_placement() -> void:
	if is_instance_valid(tower_to_place):
		clear_tower_details(tower_to_place)
		tower_to_place.queue_free()
	tower_to_place = null
	place_mode = false
	build_mode = false
	pending_tower_type = &""
	pending_tower_cost = 0
	tower_list.deselect_all()
	start_button.disabled = round_active or game_ended or shop_open
	
func _spawn_mob():
	if not spawning_active or spawn_schedule.is_empty():
		mobs_left_to_spawn = 0
		spawntimer.stop()
		return
	if mobs_alive >= active_enemy_cap:
		spawntimer.start(0.2)
		return

	var spawn_event: Dictionary = spawn_schedule.front()
	var enemy_id: StringName = spawn_event["enemy_id"]
	var spawn_cost := get_enemy_spawn_cost(enemy_id)
	if spawn_threat < spawn_cost:
		spawntimer.start(0.1)
		return

	spawn_schedule.pop_front()
	spawn_threat -= spawn_cost
	_create_mob(enemy_id, 0.0)
	mobs_left_to_spawn = spawn_schedule.size()

	if spawn_schedule.is_empty():
		spawntimer.stop()
		director_cooldown = spawn_event["delay_after"]
	else:
		var delay_after: float = spawn_event["delay_after"]
		spawntimer.start(delay_after)


func _create_mob(enemy_id: StringName, start_progress: float) -> void:
	if game_ended:
		return

	var mob = MOB_SCENE.instantiate()
	mob.enemy_id = enemy_id
	mob.wave_number = round_number
	mob.health_multiplier = get_enemy_health_multiplier(round_number)
	mob.mob_killed.connect(_on_mob_killed)
	mob.reached_end.connect(_on_mob_reached_end)
	mob.spawn_requested.connect(_on_mob_spawn_requested)
	var pf := PathFollow2D.new()
	$path.add_child(pf)
	pf.loop = false
	pf.add_child(mob)
	mob.set_path_follow(pf, start_progress)
	mobs_alive += 1


func _on_mob_spawn_requested(enemy_id: StringName, path_progress: float) -> void:
	if mobs_alive >= active_enemy_cap:
		return
	_create_mob(enemy_id, path_progress)


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


func build_director_group() -> Array[Dictionary]:
	var available := get_available_enemies(round_number)
	if available.is_empty():
		return []

	var group_size := get_director_group_size(current_wave_spawn_style)
	var enemy_queue := build_role_based_enemy_queue(
		current_wave_spawn_style,
		group_size,
		available
	)

	match current_wave_spawn_style:
		&"pulses":
			return build_pulse_schedule(enemy_queue)
		&"simultaneous_batch":
			return build_simultaneous_batch_schedule(enemy_queue)
		&"convoy":
			return build_convoy_schedule(enemy_queue)
		&"sandwich":
			return build_sandwich_schedule(enemy_queue)
		&"escorted_elite":
			return build_escorted_elite_schedule(enemy_queue)
		_:
			return build_standard_schedule(enemy_queue)


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
	round_was_perfect = false
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
	shop_open = false
	between_round_shop.hide()
	place_mode = false
	build_mode = false
	close_all_tower_menus()
	clear_tower_details()

	if is_instance_valid(tower_to_place):
		tower_to_place.queue_free()
		tower_to_place = null
	
	start_button.disabled = true
	pause_button.disabled = true
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

func mob_finished() -> void:
	mobs_alive = maxi(mobs_alive - 1, 0)

	if not spawning_active and mobs_left_to_spawn == 0 and mobs_alive == 0:
		end_round()

func _unhandled_input(event: InputEvent) -> void:
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
	var space_state = get_world_2d().direct_space_state
	var shape_node := tower_to_place.get_node("clickarea/CollisionShape2D")
	var shape: Shape2D = shape_node.shape
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = 2
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
	tower_to_place.position = pos.snapped(Vector2(32, 32))
	tower_to_place.get_node("towerconfirm").visible = true
	tower_list.deselect_all()

func _on_tower_confirmed(tower: Node2D) -> void:
	money -= pending_tower_cost
	update_money()
	pending_tower_type = &""
	pending_tower_cost = 0
	build_mode = false
	tower_to_place = null
	start_button.disabled = round_active or game_ended
	show_tower_details(tower)

func _on_tower_cancelled(tower: Node2D) -> void:
	clear_tower_details(tower)
	pending_tower_type = &""
	pending_tower_cost = 0
	build_mode = false
	tower_to_place = null
	start_button.disabled = round_active or game_ended

func start_build_tower() -> void:
	if game_ended or shop_open or build_mode or pending_tower_type.is_empty():
		return
	close_all_tower_menus()

	place_mode = true
	build_mode = true
	start_button.disabled = true
	var selected_scene: PackedScene = TOWER_SCENES[pending_tower_type]
	tower_to_place = selected_scene.instantiate()
	tower_to_place.main = self
	tower_to_place.tower_id = pending_tower_type
	tower_to_place.tower_confirmed.connect(_on_tower_confirmed)
	tower_to_place.tower_cancelled.connect(_on_tower_cancelled)
	add_child(tower_to_place)
	show_tower_details(tower_to_place)


func can_select_tower() -> bool:
	return not game_ended and not shop_open and not build_mode

@warning_ignore("unused_parameter")
func _on_item_list_item_selected(index: int) -> void:
	if game_ended or shop_open:
		tower_list.deselect_all()
		return
	
	if index < 0 or index >= ITEM_TOWER_IDS.size():
		tower_list.deselect_all()
		return

	var selected_tower_id: StringName = ITEM_TOWER_IDS[index]
	if build_mode and selected_tower_id == pending_tower_type:
		cancel_pending_tower_placement()
		return

	var cost: int = GameStats.get_tower(selected_tower_id)["placement_cost"]
	
	if money >= cost and build_mode == false:
		pending_tower_type = selected_tower_id
		pending_tower_cost = cost
		start_build_tower()
	else:
		tower_list.deselect_all()

func _on_restartbutton_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
	
func _on_quitbutton_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _on_pause_button_pressed() -> void:
	if not game_ended:
		pause_menu.open_menu(owned_shop_items)
