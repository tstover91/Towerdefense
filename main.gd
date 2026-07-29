extends Node2D
 
@export var loop_path: bool = true  
@onready var spawntimer = $SpawnTimer
@onready var path_follow_template: PathFollow2D = $path/spawn
@onready var tower_list = $MainUI/ItemList
var lives : int = 25
var tower_scene := preload("res://tower.tscn")
var place_mode := false
var build_mode = false
var tower_to_place : Node2D = null
var tower_confirm : bool = false
var money : int = 100
var pending_tower_type := ""
var pending_tower_cost := 0

func _ready():
	spawntimer.timeout.connect(_spawn_mob)
	update_money()
	update_lives()

func _process(_delta):
	if place_mode and tower_to_place:
		var snap := get_global_mouse_position().snapped(Vector2(32, 32))
		var sprite = tower_to_place.get_node("Rotator")
		tower_to_place.position = snap
		if can_place_tower(snap):
			sprite.modulate = Color(1, 1, 1, 0.5)
		else:
			sprite.modulate = Color(1, 0, 0, 0.5)

func update_lives():
	$MainUI/livesdisplay.text = str(lives)

func update_money():
	$MainUI/moneydisplay.text = str(money)

func add_money(amount: int):
	money += amount
	update_money()

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		update_money()
		return true
	return false

func _spawn_mob():
	var mob = preload("res://mob.tscn").instantiate()
	mob.mob_killed.connect(_on_mob_killed)
	add_child(mob)
	var pf = path_follow_template.duplicate()
	$path.add_child(pf)
	mob.set_path_follow(pf)
	mob.reached_end.connect(_on_reached_end)

func _on_mob_killed(reward):
	add_money(reward)

func _on_reached_end():
	lives -= 1
	update_lives()

func _input(event):
	if place_mode and event is InputEventMouseButton and event.pressed:
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
	pending_tower_type = ""
	pending_tower_cost = 0
	build_mode = false
	tower_to_place = null

@warning_ignore("unused_parameter")
func _on_tower_cancelled(tower):
	pending_tower_type = ""
	pending_tower_cost = 0
	build_mode = false
	tower_to_place = null

func start_build_tower():
	if build_mode == false:
		place_mode = true
		build_mode = true
		tower_to_place = tower_scene.instantiate()
		tower_to_place.main = self
		tower_to_place.get_node("clickarea").set_process_input(false)
		tower_to_place.get_node("clickarea").set_physics_process(false)
		tower_to_place.get_node("clickarea").monitoring = false
		tower_to_place.get_node("clickarea").input_pickable = false
		tower_to_place.get_node("clickarea/CollisionShape2D").disabled = true
		tower_to_place.get_node("Tower/CollisionShape2D").disabled = true
		tower_to_place.connect("tower_confirmed", Callable(self, "_on_tower_confirmed"))
		tower_to_place.connect("tower_cancelled", Callable(self, "_on_tower_cancelled"))
		add_child(tower_to_place)

@warning_ignore("unused_parameter")
func _on_item_list_item_selected(index: int) -> void:
	var cost := 50  # or based on index later
	
	if money >= cost and build_mode == false:
		pending_tower_type = "arrow_tower"  # or based on index
		pending_tower_cost = cost
		start_build_tower()
	else:
		tower_list.deselect_all()
