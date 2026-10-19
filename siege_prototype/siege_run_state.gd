class_name SiegeRunState
extends RefCounted

const LAST_TOWN_HALL := 3

var town_hall := 1
var battle_index := 0
var currency := 4
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
	return (town_hall - 1) * 2 + battle_index + 1


func get_battle_letter() -> String:
	return "B" if battle_index == 1 else "A"
