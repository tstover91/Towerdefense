class_name PrototypeEconomy
extends RefCounted

const STARTING_CREDITS := 500
const STARTING_POWER_LIMIT := 3
const STARTING_WALL_LIMIT := 5
const INTEREST_RATE := 0.05
const INTEREST_REWARD_CAP_RATIO := 0.50
# TDS pays both enemy bounties and a rising wave bonus. This prototype has no
# per-kill income, so this reward deliberately combines those two income lanes.
const BASE_WAVE_REWARD := 180
const WAVE_REWARD_STEP := 28
const WAVE_REWARD_EXPONENT := 1.03
const POWER_INCREASE_WAVES: Array[int] = [2, 4, 6, 9, 12, 15, 18]
const WALL_INCREASE_WAVES: Array[int] = [
	1, 2, 3, 4,
	5, 6, 7, 9,
	10, 12, 14,
	16, 18,
]

var credits := STARTING_CREDITS
var used_power := 0
var power_limit := STARTING_POWER_LIMIT
var used_walls := 0
var wall_limit := STARTING_WALL_LIMIT
var locked_interest := 0
var locked_wave := 0
var last_base_reward := 0
var last_interest_reward := 0
var rewarded_waves: Dictionary = {}


func can_afford(cost: int) -> bool:
	return credits >= maxi(cost, 0)


func can_build(cost: int, power_cost := 1) -> bool:
	return (
		can_afford(cost)
		and used_power + maxi(power_cost, 0) <= power_limit
	)


func can_build_wall() -> bool:
	return used_walls < wall_limit


func try_spend(cost: int) -> bool:
	var safe_cost := maxi(cost, 0)
	if credits < safe_cost:
		return false
	credits -= safe_cost
	return true


func try_build(cost: int, power_cost := 1) -> bool:
	var safe_power_cost := maxi(power_cost, 0)
	if not can_build(cost, safe_power_cost) or not try_spend(cost):
		return false
	used_power += safe_power_cost
	return true


func release_power(amount := 1) -> void:
	used_power = maxi(used_power - maxi(amount, 0), 0)


func try_build_wall() -> bool:
	if not can_build_wall():
		return false
	used_walls += 1
	return true


func release_wall() -> void:
	used_walls = maxi(used_walls - 1, 0)


func add_credits(amount: int) -> void:
	credits += maxi(amount, 0)


func get_wave_reward(wave: int) -> int:
	var completed_waves := maxi(wave - 1, 0)
	return floori(
		float(BASE_WAVE_REWARD)
		+ pow(float(completed_waves * WAVE_REWARD_STEP), WAVE_REWARD_EXPONENT)
	)


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
			"limits_increased": false,
			"power_increase": 0,
			"wall_increase": 0,
		}
	rewarded_waves[wave] = true
	var base_reward := get_wave_reward(wave)
	var interest_reward := locked_interest if locked_wave == wave else 0
	last_base_reward = base_reward
	last_interest_reward = interest_reward
	add_credits(base_reward + interest_reward)
	var power_increase := 1 if POWER_INCREASE_WAVES.has(wave) else 0
	var wall_increase := 1 if WALL_INCREASE_WAVES.has(wave) else 0
	power_limit += power_increase
	wall_limit += wall_increase
	locked_wave = 0
	locked_interest = 0
	return {
		"base_reward": base_reward,
		"interest_reward": interest_reward,
		"limits_increased": power_increase > 0 or wall_increase > 0,
		"power_increase": power_increase,
		"wall_increase": wall_increase,
	}


func get_state(next_wave: int, wave_active: bool) -> Dictionary:
	var interest_display := (
		locked_interest
		if wave_active and locked_wave == next_wave
		else get_projected_interest(next_wave)
	)
	return {
		"credits": credits,
		"used_power": used_power,
		"power_limit": power_limit,
		"used_walls": used_walls,
		"wall_limit": wall_limit,
		"interest": interest_display,
		"interest_locked": wave_active and locked_wave == next_wave,
		"next_wave_reward": get_wave_reward(next_wave),
		"last_base_reward": last_base_reward,
		"last_interest_reward": last_interest_reward,
	}
