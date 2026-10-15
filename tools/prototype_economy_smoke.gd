extends SceneTree

const EconomyScript = preload("res://prototype/prototype_economy.gd")

var failure_count := 0


func _init() -> void:
	var economy = EconomyScript.new()
	_assert(economy.credits == 500, "run starts with $500")
	_assert(economy.power_limit == 4, "run starts with four tower slots")
	_assert(economy.wall_limit == 5, "run starts with five Walls")
	_assert(economy.get_projected_interest(1) == 15, "wave one projects 3% interest")
	var total_base_income := 0
	for wave in range(1, 21):
		total_base_income += economy.get_wave_reward(wave)
	_assert(total_base_income == 29200, "twenty waves provide the intended guaranteed-income budget")
	for wall_index in economy.wall_limit:
		_assert(economy.try_build_wall(), "wall %d fits within the starting limit" % wall_index)
	_assert(not economy.try_build_wall(), "the wall limit rejects one extra wall")
	_assert(economy.used_walls == 5, "each wall consumes one Wall")
	for wall_index in economy.wall_limit:
		economy.release_wall()
	_assert(economy.used_walls == 0, "removing a wall restores one Wall")

	_assert(economy.try_build(100), "an affordable tower can be built")
	_assert(economy.credits == 400, "building deducts the exact tower cost")
	_assert(economy.used_power == 1, "building consumes one Power")
	_assert(economy.begin_wave(1) == 12, "interest locks from the wave-start balance")
	_assert(economy.try_spend(100), "credits may still be spent after the wave starts")
	_assert(economy.locked_interest == 12, "later spending does not alter locked interest")

	var wave_one: Dictionary = economy.complete_wave(1)
	_assert(int(wave_one["base_reward"]) == 200, "wave one pays its table reward")
	_assert(int(wave_one["interest_reward"]) == 12, "wave one pays locked interest")
	_assert(economy.credits == 512, "wave reward and interest reach the balance")
	_assert(not bool(wave_one["limits_increased"]), "wave one does not raise a capacity")
	_assert(int(wave_one["power_increase"]) == 0, "wave one does not add Power")
	_assert(int(wave_one["wall_increase"]) == 0, "wave one adds no Walls")
	_assert(economy.power_limit == 4, "tower capacity remains four after wave one")
	_assert(economy.wall_limit == 5, "Wall capacity remains five after wave one")
	var duplicate_wave_one: Dictionary = economy.complete_wave(1)
	_assert(int(duplicate_wave_one["base_reward"]) == 0, "a wave cannot pay twice")
	_assert(economy.credits == 512, "duplicate completion leaves credits unchanged")

	economy.begin_wave(2)
	var wave_two: Dictionary = economy.complete_wave(2)
	_assert(int(wave_two["base_reward"]) == 300, "wave two pays the second table reward")
	_assert(bool(wave_two["limits_increased"]), "wave two raises tower capacity")
	_assert(economy.power_limit == 6, "wave two adds two tower slots")
	_assert(economy.wall_limit == 5, "wave two does not add Walls")
	for wave in range(3, 19):
		economy.begin_wave(wave)
		economy.complete_wave(wave)
	_assert(economy.power_limit == 20, "tower capacity reaches twenty after wave eighteen")
	_assert(economy.wall_limit == 14, "Walls reach their final cap after wave eighteen")

	economy.credits = 10000
	_assert(economy.get_projected_interest(1) == 50, "interest caps at one quarter of the base reward")
	economy.release_power()
	_assert(economy.used_power == 0, "selling releases used Power")
	for power_index in economy.power_limit:
		_assert(economy.try_build(1), "tower %d fits within the Power limit" % power_index)
	_assert(not economy.try_build(1), "Power rejects one extra tower")
	_finish("PROTOTYPE_ECONOMY_SMOKE_OK")


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Prototype economy smoke failed: %s" % description)
	failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
