extends Node2D

const GameStats = preload("res://stat_database.gd")
const MOB_SCENE = preload("res://mob.tscn")
const SPAWN_STYLES := {
	&"steady": {
		"minimum_group_size": 3,
		"maximum_group_size": 5,
		"interval": 0.8,
		"gap_after_group": 1.2,
	},
	&"stream": {
		"minimum_group_size": 5,
		"maximum_group_size": 8,
		"gap_after_group": 1.5,
	},
	&"burst": {
		"minimum_group_size": 3,
		"maximum_group_size": 5,
		"interval": 0.1,
		"gap_after_group": 2.0,
	},
	&"spaced": {
		"minimum_group_size": 2,
		"maximum_group_size": 3,
		"interval": 1.4,
		"gap_after_group": 1.0,
	},
}
const WAVE_STYLE_UNLOCKS := {
	&"pulses": 3,
	&"simultaneous_batch": 4,
	&"convoy": 6,
	&"sandwich": 7,
	&"escorted_elite": 9,
}
const TOWER_SCENES := {
	&"scout": preload("res://tower.tscn"),
}
const ITEM_TOWER_IDS := [&"scout"]

signal money_changed(new_amount: int)

@onready var spawntimer = $SpawnTimer
@onready var tower_list = $MainUI/ItemList
var lives: int
var place_mode := false
var build_mode = false
var tower_to_place : Node2D = null
var money: int
var pending_tower_type: StringName = &""
var pending_tower_cost := 0
var round_number := 0
var mobs_left_to_spawn := 0
var mobs_alive := 0
var spawn_schedule: Array[Dictionary] = []
var enemy_rng := RandomNumberGenerator.new()
var current_wave_spawn_style: StringName = &"standard"
var round_active := false
var round_was_perfect := true
var game_ended := false
var max_rounds: int
var mode_id: StringName = "easy"

func _ready():
	enemy_rng.randomize()
	var mode: Dictionary = GameStats.get_mode(mode_id)
	money = mode["starting_cash"]
	lives = mode["starting_lives"]
	max_rounds = mode["max_rounds"]
	update_money()
	update_lives()
	update_round_count()
	spawntimer.timeout.connect(_spawn_mob)

func _process(_delta):
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

func update_lives():
	$MainUI/livesdisplay.text = str(lives)

func update_money():
	$MainUI/moneydisplay.text = str(money)
	money_changed.emit(money)

func add_money(amount: int):
	money += amount
	update_money()

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		update_money()
		return true
	return false

func _on_startbutton_pressed() -> void:
	if not game_ended and not round_active and not build_mode:
		close_all_tower_menus()
		start_round()


func close_all_tower_menus() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		tower.set_selected(false)

func start_round() -> void:
	if round_active or round_number >= max_rounds:
		return
	round_number += 1
	update_round_count()
	var wave_queue := build_wave_queue(round_number)
	spawn_schedule = build_spawn_schedule(wave_queue, round_number)
	mobs_left_to_spawn = spawn_schedule.size()
	round_was_perfect = true
	round_active = true
	$MainUI/startbutton.disabled = true
	spawntimer.one_shot = true
	spawntimer.start(0.5)
	
func update_round_count() -> void:
	$MainUI/roundcount.text = "Round %d/%d" % [round_number, max_rounds]
	
func end_round() -> void:
	if game_ended:
		return
	
	round_active = false
	add_money(calculate_end_round_reward())

	if round_number >= max_rounds:
		victory()
	else:
		$MainUI/startbutton.disabled = false


func calculate_end_round_reward() -> int:
	var mode: Dictionary = GameStats.get_mode(mode_id)
	var base_reward: int = mode["wave_bonus_base"] + (
		(round_number - 1) * mode["wave_bonus_growth"]
	)
	var clear_reward := 0

	if round_was_perfect:
		clear_reward = floori(base_reward * mode["clear_bonus_multiplier"])

	return base_reward + clear_reward
	
func _spawn_mob():
	if spawn_schedule.is_empty():
		mobs_left_to_spawn = 0
		spawntimer.stop()
		return

	var spawn_event: Dictionary = spawn_schedule.pop_front()
	var enemy_id: StringName = spawn_event["enemy_id"]
	_create_mob(enemy_id, 0.0)
	mobs_left_to_spawn = spawn_schedule.size()

	if spawn_schedule.is_empty():
		spawntimer.stop()
	else:
		var delay_after: float = spawn_event["delay_after"]
		spawntimer.start(delay_after)


func _create_mob(enemy_id: StringName, start_progress: float) -> void:
	if game_ended:
		return

	var mob = MOB_SCENE.instantiate()
	mob.enemy_id = enemy_id
	mob.wave_number = round_number
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
	_create_mob(enemy_id, path_progress)


func build_wave_queue(wave: int) -> Array[StringName]:
	var queue: Array[StringName] = []
	var available: Array[StringName] = []
	var mode: Dictionary = GameStats.get_mode(mode_id)
	var threat_budget_base: int = mode.get("threat_budget_base", 5)
	var threat_budget_growth: int = mode.get("threat_budget_growth", 2)
	var threat_budget_curve: float = mode.get("threat_budget_curve", 0.0)
	var remaining_budget := (
		threat_budget_base
		+ wave * threat_budget_growth
		+ floori(float(wave * wave) * threat_budget_curve)
	)

	for enemy_key in GameStats.ENEMIES:
		var enemy_id := StringName(enemy_key)
		var stats: Dictionary = GameStats.get_enemy(enemy_id)
		if stats.get("boss", false):
			continue
		if stats.get("first_wave", 1) <= wave:
			available.append(enemy_id)

	while remaining_budget > 0:
		var affordable: Array[StringName] = []
		for enemy_id in available:
			var stats: Dictionary = GameStats.get_enemy(enemy_id)
			if stats.get("threat_cost", 1) <= remaining_budget:
				affordable.append(enemy_id)

		if affordable.is_empty():
			break

		var chosen := choose_weighted_enemy(affordable)
		queue.append(chosen)
		remaining_budget -= GameStats.get_enemy(chosen).get("threat_cost", 1)

	shuffle_enemy_queue(queue)

	if wave == max_rounds:
		queue.append(&"brute")

	return queue


func build_spawn_schedule(
	enemy_queue: Array[StringName],
	wave: int
) -> Array[Dictionary]:
	var has_boss: bool = not enemy_queue.is_empty() and enemy_queue.back() == &"brute"

	if has_boss:
		enemy_queue.pop_back()
		current_wave_spawn_style = &"boss_escort"
		return build_boss_escort_schedule(enemy_queue)

	var available_styles: Array[StringName] = [&"standard"]
	for style_name in WAVE_STYLE_UNLOCKS:
		if wave >= WAVE_STYLE_UNLOCKS[style_name]:
			available_styles.append(style_name)

	current_wave_spawn_style = available_styles[
		enemy_rng.randi_range(0, available_styles.size() - 1)
	]

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
		var group_size := mini(enemy_rng.randi_range(3, 5), enemy_queue.size())
		var group := take_front_group(enemy_queue, group_size)
		append_enemy_group(schedule, group, 0.15, 1.6, &"pulses")
	return schedule


func build_simultaneous_batch_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var group_size := mini(enemy_rng.randi_range(3, 6), enemy_queue.size())
		var group := take_front_group(enemy_queue, group_size)
		append_enemy_group(schedule, group, 0.05, 1.8, &"simultaneous_batch")
	return schedule


func build_convoy_schedule(enemy_queue: Array[StringName]) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var group: Array[StringName] = [take_strongest_enemy(enemy_queue)]
		var escort_count := mini(3, enemy_queue.size())
		for _index in escort_count:
			group.append(take_weakest_enemy(enemy_queue))
		append_enemy_group(schedule, group, 0.25, 1.7, &"convoy")
	return schedule


func build_escorted_elite_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var elite := take_strongest_enemy(enemy_queue)
		var escorts: Array[StringName] = []
		var escort_count := mini(4, enemy_queue.size())
		for _index in escort_count:
			escorts.append(take_weakest_enemy(enemy_queue))

		var group: Array[StringName] = []
		var front_count := ceili(escorts.size() / 2.0)
		for _index in front_count:
			group.append(escorts.pop_front())
		group.append(elite)
		group.append_array(escorts)
		append_enemy_group(schedule, group, 0.2, 1.8, &"escorted_elite")
	return schedule


func build_sandwich_schedule(enemy_queue: Array[StringName]) -> Array[Dictionary]:
	if enemy_queue.size() < 3:
		return build_standard_schedule(enemy_queue)

	var first_elite := take_strongest_enemy(enemy_queue)
	var last_elite := take_strongest_enemy(enemy_queue)
	var group: Array[StringName] = [first_elite]
	group.append_array(enemy_queue)
	group.append(last_elite)

	var schedule: Array[Dictionary] = []
	append_enemy_group(schedule, group, 0.45, 0.0, &"sandwich")
	return schedule


func build_boss_escort_schedule(enemy_queue: Array[StringName]) -> Array[Dictionary]:
	var escorts: Array[StringName] = []
	var escort_count := mini(4, enemy_queue.size())
	for _index in escort_count:
		escorts.append(take_weakest_enemy(enemy_queue))

	var schedule := build_standard_schedule(enemy_queue)
	if not schedule.is_empty():
		schedule.back()["delay_after"] = 3.0

	var boss_group: Array[StringName] = []
	var front_count := ceili(escorts.size() / 2.0)
	for _index in front_count:
		boss_group.append(escorts.pop_front())
	boss_group.append(&"brute")
	boss_group.append_array(escorts)
	append_enemy_group(schedule, boss_group, 0.2, 0.0, &"boss_escort")
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


func take_weakest_enemy(enemy_queue: Array[StringName]) -> StringName:
	return take_enemy_by_threat(enemy_queue, false)


func take_enemy_by_threat(
	enemy_queue: Array[StringName],
	take_strongest: bool
) -> StringName:
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


func choose_weighted_enemy(available: Array[StringName]) -> StringName:
	var total_weight := 0
	for enemy_id in available:
		total_weight += GameStats.get_enemy(enemy_id).get("spawn_weight", 1)

	var roll := enemy_rng.randi_range(1, total_weight)
	for enemy_id in available:
		roll -= GameStats.get_enemy(enemy_id).get("spawn_weight", 1)
		if roll <= 0:
			return enemy_id

	return available[0]


func shuffle_enemy_queue(queue: Array[StringName]) -> void:
	for index in range(queue.size() - 1, 0, -1):
		var swap_index := enemy_rng.randi_range(0, index)
		var held := queue[index]
		queue[index] = queue[swap_index]
		queue[swap_index] = held

func _on_mob_reached_end(damage: int) -> void:
	round_was_perfect = false
	lives -= damage
	lives = max(lives, 0)
	update_lives()
	
	if lives == 0:
		defeat()
		return

	mob_finished()

func defeat():
	finish_game("Defeat!\nYou reached round %d." % round_number)

func victory():
	finish_game("Victory!\nYou completed all %d rounds." % max_rounds)

func finish_game(message: String):
	if game_ended:
		return
	game_ended = true
	round_active = false
	spawntimer.stop()
	place_mode = false
	build_mode = false

	if is_instance_valid(tower_to_place):
		tower_to_place.queue_free()
		tower_to_place = null
	
	$MainUI/startbutton.disabled = true
	$MainUI/ItemList.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$MainUI/endscreen/VBoxContainer/resultlabel.text = message
	$MainUI/endscreen.visible = true
	
	for pf in $path.get_children():
		pf.queue_free()

func _on_mob_killed(reward):
	add_money(reward)
	mob_finished()

func mob_finished() -> void:
	mobs_alive = max(mobs_alive - 1, 0)

	if mobs_left_to_spawn == 0 and mobs_alive == 0:
		end_round()

func _unhandled_input(event: InputEvent) -> void:
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

func finalize_tower_placement():
	var pos := tower_to_place.position
	if not can_place_tower(pos):
		return
	place_mode = false
	tower_to_place.position = pos.snapped(Vector2(32, 32))
	tower_to_place.get_node("towerconfirm").visible = true
	tower_list.deselect_all()

@warning_ignore("unused_parameter")
func _on_tower_confirmed(tower):
	money -= pending_tower_cost
	update_money()
	pending_tower_type = &""
	pending_tower_cost = 0
	build_mode = false
	tower_to_place = null
	$MainUI/startbutton.disabled = round_active or game_ended

@warning_ignore("unused_parameter")
func _on_tower_cancelled(tower):
	pending_tower_type = &""
	pending_tower_cost = 0
	build_mode = false
	tower_to_place = null
	$MainUI/startbutton.disabled = round_active or game_ended

func start_build_tower():
	if build_mode == false:
		close_all_tower_menus()

		place_mode = true
		build_mode = true
		$MainUI/startbutton.disabled = true
		var selected_scene: PackedScene = TOWER_SCENES[pending_tower_type]
		tower_to_place = selected_scene.instantiate()
		tower_to_place.main = self
		tower_to_place.tower_id = pending_tower_type
		tower_to_place.connect("tower_confirmed", Callable(self, "_on_tower_confirmed"))
		tower_to_place.connect("tower_cancelled", Callable(self, "_on_tower_cancelled"))
		add_child(tower_to_place)

@warning_ignore("unused_parameter")
func _on_item_list_item_selected(index: int) -> void:
	if game_ended:
		tower_list.deselect_all()
		return
	
	if index < 0 or index >= ITEM_TOWER_IDS.size():
		tower_list.deselect_all()
		return

	var selected_tower_id: StringName = ITEM_TOWER_IDS[index]
	var cost: int = GameStats.get_tower(selected_tower_id)["placement_cost"]
	
	if money >= cost and build_mode == false:
		pending_tower_type = selected_tower_id
		pending_tower_cost = cost
		start_build_tower()
	else:
		tower_list.deselect_all()

func _on_restartbutton_pressed() -> void:
	get_tree().reload_current_scene()
	
func _on_quitbutton_pressed() -> void:
	get_tree().quit()
