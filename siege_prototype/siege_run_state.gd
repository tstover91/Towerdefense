class_name SiegeRunState
extends RefCounted

const FIRST_TOWN_HALL := 2
const LAST_TOWN_HALL := 7
const BATTLES_PER_TOWN_HALL := 2

var town_hall := 2
var battle_index := 0
var currency := 16
var completed := false
var blueprint: Array[Dictionary] = []
var precombat_blueprint: Array[Dictionary] = []


func begin_combat(current_blueprint: Array[Dictionary]) -> void:
	precombat_blueprint = current_blueprint.duplicate(true)


func record_victory(reward: int, current_blueprint: Array[Dictionary]) -> Dictionary:
	currency += maxi(reward, 0)
	blueprint = current_blueprint.duplicate(true)
	var previous_th := town_hall
	if battle_index == 0:
		battle_index = 1
	elif town_hall < LAST_TOWN_HALL:
		town_hall += 1
		battle_index = 0
	else:
		completed = true
	return {"tier_advanced": town_hall != previous_th, "completed": completed}


func record_defeat() -> Array[Dictionary]:
	blueprint = precombat_blueprint.duplicate(true)
	return blueprint.duplicate(true)


func spend(amount: int) -> bool:
	if amount < 0 or currency < amount:
		return false
	currency -= amount
	return true


func get_round_number() -> int:
	return (town_hall - FIRST_TOWN_HALL) * BATTLES_PER_TOWN_HALL + battle_index + 1


func get_total_rounds() -> int:
	return (LAST_TOWN_HALL - FIRST_TOWN_HALL + 1) * BATTLES_PER_TOWN_HALL


func get_battle_letter() -> String:
	return "B" if battle_index == 1 else "A"
