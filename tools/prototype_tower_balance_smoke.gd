extends SceneTree

const TowerScript = preload("res://prototype/prototype_tower.gd")

var failure_count := 0


func _init() -> void:
	_check_gun_curve()
	_check_mortar_curve()
	_check_beam_curve()
	if failure_count > 0:
		quit(1)
		return
	print("PROTOTYPE_TOWER_BALANCE_SMOKE_OK")
	quit(0)


func _check_gun_curve() -> void:
	var tower = _make_tower(TowerScript.TYPE_GUN)
	_assert(TowerScript.get_build_cost(TowerScript.TYPE_GUN) == 150, "gun has the cheap starter price")
	_assert(_range_curve(TowerScript.TYPE_GUN) == [2.5, 2.6, 2.8, 3.1], "gun keeps a compact general-purpose range")
	_assert(_collect_upgrade_costs(tower) == [50, 300, 900], "gun upgrades use the small, medium, capstone price curve")
	_assert(_dps_curve(TowerScript.TYPE_GUN) == [10.0, 13.33, 40.0, 100.0], "gun power is modest early and strongly backloaded")


func _check_mortar_curve() -> void:
	var tower = _make_tower(TowerScript.TYPE_MORTAR)
	_assert(TowerScript.get_build_cost(TowerScript.TYPE_MORTAR) == 350, "mortar costs more than two base guns")
	_assert(_range_curve(TowerScript.TYPE_MORTAR) == [3.3, 3.4, 3.6, 4.0], "mortar remains the longest-range tower without covering the board")
	_assert(_collect_upgrade_costs(tower) == [150, 600, 1800], "mortar splash growth has an appropriately expensive capstone")
	var curve := _dps_curve(TowerScript.TYPE_MORTAR)
	_assert(curve[1] < curve[0] * 1.4, "mortar's first upgrade is intentionally modest")
	_assert(curve[3] > curve[0] * 8.0, "mortar's final direct damage is a major jump before splash is counted")


func _check_beam_curve() -> void:
	var tower = _make_tower(TowerScript.TYPE_BEAM)
	_assert(TowerScript.get_build_cost(TowerScript.TYPE_BEAM) == 750, "beam is delayed as the endgame tower")
	_assert(_range_curve(TowerScript.TYPE_BEAM) == [2.8, 2.9, 3.1, 3.4], "beam must be placed deliberately despite its endgame power")
	_assert(_collect_upgrade_costs(tower) == [200, 700, 2700], "beam reserves most investment for its capstone")
	var max_dps := _beam_max_dps_curve()
	_assert(max_dps == [32.0, 40.0, 80.0, 200.0], "beam sustained DPS follows the accelerator-style curve")


func _make_tower(type: StringName):
	var tower = TowerScript.new()
	tower.configure(Vector2i.ZERO, Callable(), type)
	return tower


func _collect_upgrade_costs(tower) -> Array[int]:
	var costs: Array[int] = []
	while tower.can_upgrade():
		var cost: int = tower.get_next_upgrade_cost()
		costs.append(cost)
		tower.upgrade(cost)
	return costs


func _dps_curve(type: StringName) -> Array[float]:
	var tower = _make_tower(type)
	var result: Array[float] = []
	while true:
		result.append(snappedf(float(tower.get_damage()) / tower.get_attack_interval(), 0.01))
		if not tower.can_upgrade():
			break
		tower.upgrade(tower.get_next_upgrade_cost())
	return result


func _range_curve(type: StringName) -> Array[float]:
	var tower = _make_tower(type)
	var result: Array[float] = []
	while true:
		result.append(float(tower._get_stats()["range_cells"]))
		if not tower.can_upgrade():
			break
		tower.upgrade(tower.get_next_upgrade_cost())
	return result


func _beam_max_dps_curve() -> Array[float]:
	var tower = _make_tower(TowerScript.TYPE_BEAM)
	var result: Array[float] = []
	while true:
		var stats: Dictionary = tower._get_stats()
		var max_hit := tower.get_damage() + int(stats["ramp"]) * 3
		result.append(snappedf(float(max_hit) / tower.get_attack_interval(), 0.01))
		if not tower.can_upgrade():
			break
		tower.upgrade(tower.get_next_upgrade_cost())
	return result


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Prototype tower balance smoke failed: %s" % description)
	failure_count += 1
