extends SceneTree

const EconomyScript = preload("res://prototype/prototype_economy.gd")

var failure_count := 0


func _init() -> void:
	var economy = EconomyScript.new()
	_assert(economy.credits == 500, "run starts with $500")
	_assert(economy.maximum_capacity == 5, "run starts with five tower slots")
	_assert(economy.get_projected_interest(1) == 25, "wave one projects 5% interest")

	_assert(economy.try_build(100), "an affordable tower can be built")
	_assert(economy.credits == 400, "building deducts the exact tower cost")
	_assert(economy.used_capacity == 1, "building consumes one capacity")
	_assert(economy.begin_wave(1) == 20, "interest locks from the wave-start balance")
	_assert(economy.try_spend(100), "credits may still be spent after the wave starts")
	_assert(economy.locked_interest == 20, "later spending does not alter locked interest")

	var wave_one: Dictionary = economy.complete_wave(1)
	_assert(int(wave_one["base_reward"]) == 120, "wave one pays its base reward")
	_assert(int(wave_one["interest_reward"]) == 20, "wave one pays locked interest")
	_assert(economy.credits == 440, "wave reward and interest reach the balance")
	_assert(economy.maximum_capacity == 5, "wave one does not unlock capacity")
	var duplicate_wave_one: Dictionary = economy.complete_wave(1)
	_assert(int(duplicate_wave_one["base_reward"]) == 0, "a wave cannot pay twice")
	_assert(economy.credits == 440, "duplicate completion leaves credits unchanged")

	economy.begin_wave(2)
	var wave_two: Dictionary = economy.complete_wave(2)
	_assert(int(wave_two["base_reward"]) == 140, "base reward rises by $20 per wave")
	_assert(bool(wave_two["capacity_increased"]), "wave two unlocks capacity")
	_assert(economy.maximum_capacity == 6, "capacity unlock adds one slot")

	economy.credits = 10000
	_assert(economy.get_projected_interest(1) == 60, "interest caps at half the base reward")
	economy.release_capacity()
	_assert(economy.used_capacity == 0, "selling releases used capacity")
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
