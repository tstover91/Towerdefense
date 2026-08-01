extends Node2D

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENES := {
	&"scout": preload("res://tower.tscn"),
}
const ITEM_TOWER_IDS := [&"scout"]

signal money_changed(new_amount: int)
 
@export var loop_path: bool = true  
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
var round_active := false
var round_was_perfect := true
var game_ended := false
var max_rounds: int
var mode_id: StringName = "easy"

func _ready():
	var mode: Dictionary = GameStats.get_mode(mode_id)
	money = mode["starting_cash"]
	lives = mode["starting_lives"]
	max_rounds = mode["max_rounds"]
	update_money()
	update_lives()
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
	mobs_left_to_spawn = 5 + round_number * 2
	round_was_perfect = true
	round_active = true
	$MainUI/startbutton.disabled = true
	spawntimer.start()
	
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
	if mobs_left_to_spawn <= 0:
		spawntimer.stop()
		return
	var mob = preload("res://mob.tscn").instantiate()
	mob.mob_killed.connect(_on_mob_killed)
	mob.reached_end.connect(_on_mob_reached_end)
	var pf := PathFollow2D.new()
	$path.add_child(pf)
	pf.add_child(mob)
	pf.loop = false
	mob.set_path_follow(pf)
	mobs_left_to_spawn -= 1
	mobs_alive += 1

	if mobs_left_to_spawn <= 0:
		spawntimer.stop()

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

func get_tower_shape(tower: Node) -> Shape2D:
	var shape_node := tower.get_node_or_null("clickarea/CollisionShape2D")
	if shape_node:
		return shape_node.shape
	return null

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
