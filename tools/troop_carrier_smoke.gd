extends Node

const MOB_SCENE = preload("res://mob.tscn")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var path := Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	add_child(path)
	var follow := PathFollow2D.new()
	path.add_child(follow)
	var carrier := MOB_SCENE.instantiate()
	carrier.enemy_id = &"troop_carrier"
	carrier.wave_number = 20
	follow.add_child(carrier)
	carrier.set_path_follow(follow, 400.0)
	var requests: Array[Dictionary] = []
	carrier.spawn_requested.connect(func(
		enemy_id: StringName,
		progress: float,
		_variant: StringName,
		_requester: Node,
		request_kind: StringName
	) -> void:
		requests.append({
			"enemy_id": enemy_id,
			"progress": progress,
			"kind": request_kind,
		})
	)

	assert(carrier.summon_limit == 3)
	assert(carrier.split_count == 4)
	assert(carrier.passenger_capacity == 7)
	assert(carrier.get_leak_damage() == carrier.base_damage + 7)
	for expected_count in range(1, 4):
		carrier._process_summoning(4.0)
		assert(requests.size() == expected_count)
		assert(requests.back()["enemy_id"] == &"swarmling")
		assert(requests.back()["kind"] == &"summon")
		carrier.resolve_spawn_request(&"summon", true)
	carrier._process_summoning(20.0)
	assert(requests.size() == 3)
	assert(carrier.get_leak_damage() == carrier.base_damage + 4)

	carrier.die()
	assert(requests.size() == 7)
	for index in range(3, 7):
		assert(requests[index]["enemy_id"] == &"swarmling")
		assert(requests[index]["kind"] == &"split")

	print("Troop Carrier smoke test passed: finite deployments, destruction squad, and passenger leak damage.")
	get_tree().quit(0)
