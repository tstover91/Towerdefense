class_name PrototypeEconomy
extends RefCounted

const STARTING_CREDITS := 500
const STARTING_CAPACITY := 5
const INTEREST_RATE := 0.05
const INTEREST_REWARD_CAP_RATIO := 0.50
const BASE_WAVE_REWARD := 120
const WAVE_REWARD_INCREMENT := 20
const CAPACITY_UNLOCK_WAVES: Array[int] = [2, 4, 6, 8]

var credits := STARTING_CREDITS
var used_capacity := 0
var maximum_capacity := STARTING_CAPACITY
var locked_interest := 0
var locked_wave := 0
var last_base_reward := 0
var last_interest_reward := 0
var rewarded_waves: Dictionary = {}


func can_afford(cost: int) -> bool:
	return credits >= maxi(cost, 0)


func can_build(cost: int) -> bool:
	return can_afford(cost) and used_capacity < maximum_capacity


func try_spend(cost: int) -> bool:
	var safe_cost := maxi(cost, 0)
	if credits < safe_cost:
		return false
	credits -= safe_cost
	return true


func try_build(cost: int) -> bool:
	if not can_build(cost) or not try_spend(cost):
		return false
	used_capacity += 1
	return true


func release_capacity() -> void:
	used_capacity = maxi(used_capacity - 1, 0)


func add_credits(amount: int) -> void:
	credits += maxi(amount, 0)


func get_wave_reward(wave: int) -> int:
	return BASE_WAVE_REWARD + maxi(wave - 1, 0) * WAVE_REWARD_INCREMENT


func get_projected_interest(wave: int) -> int:
	var base_reward := get_wave_reward(wave)
	return mini(
		floori(float(credits) * INTEREST_RATE),
		floori(float(base_reward) * INTEREST_REWARD_CAP_RATIO)
	)


func begin_wave(wave: int) -> int:
	if locked_wave == wave:
		return locked_interest
	locked_wave = wave
	locked_interest = get_projected_interest(wave)
	return locked_interest


func complete_wave(wave: int) -> Dictionary:
	if wave <= 0 or rewarded_waves.has(wave):
		return {
			"base_reward": 0,
			"interest_reward": 0,
			"capacity_increased": false,
		}
	rewarded_waves[wave] = true
	var base_reward := get_wave_reward(wave)
	var interest_reward := locked_interest if locked_wave == wave else 0
	last_base_reward = base_reward
	last_interest_reward = interest_reward
	add_credits(base_reward + interest_reward)
	var capacity_increased := CAPACITY_UNLOCK_WAVES.has(wave)
	if capacity_increased:
		maximum_capacity += 1
	locked_wave = 0
	locked_interest = 0
	return {
		"base_reward": base_reward,
		"interest_reward": interest_reward,
		"capacity_increased": capacity_increased,
	}


func get_state(next_wave: int, wave_active: bool) -> Dictionary:
	var interest_display := (
		locked_interest
		if wave_active and locked_wave == next_wave
		else get_projected_interest(next_wave)
	)
	return {
		"credits": credits,
		"used_capacity": used_capacity,
		"maximum_capacity": maximum_capacity,
		"interest": interest_display,
		"interest_locked": wave_active and locked_wave == next_wave,
		"next_wave_reward": get_wave_reward(next_wave),
		"last_base_reward": last_base_reward,
		"last_interest_reward": last_interest_reward,
	}
