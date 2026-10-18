extends SceneTree

const TowerScript = preload("res://prototype/prototype_tower.gd")

var failure_count := 0


func _init() -> void:
	_check_gunslinger_curve()
	_check_anti_materiel_curve()
	_check_flamespitter_curve()
	_check_bombardment_curve()
	_check_atomic_strike_curve()
	if failure_count > 0:
		quit(1)
		return
	print("PROTOTYPE_TOWER_BALANCE_SMOKE_OK")
	quit(0)


func _check_gunslinger_curve() -> void:
	var tower = _make_tower(TowerScript.TYPE_GUNSLINGER)
	_assert(TowerScript.get_build_cost(TowerScript.TYPE_GUNSLINGER) == 150, "Gunslinger has the cheap Steel starter price")
	_assert(_range_curve(TowerScript.TYPE_GUNSLINGER) == [2.5, 2.6, 2.7, 2.9, 3.1], "Gunslinger keeps compact general-purpose range")
	_assert(_collect_upgrade_costs(tower) == [50, 250, 525, 975], "Gunslinger follows the five-level normalized price curve")
	_assert(_dps_curve(TowerScript.TYPE_GUNSLINGER) == [10.0, 13.33, 26.0, 55.0, 90.0], "Gunslinger redistributes its existing maximum power across five levels")
	_assert(_pierce_curve(TowerScript.TYPE_GUNSLINGER) == [0, 0, 0, 1, 1], "Gunslinger gains one standard pierce on later levels")


func _check_anti_materiel_curve() -> void:
	var tower = _make_tower(TowerScript.TYPE_ANTI_MATERIEL)
	_assert(TowerScript.get_build_cost(TowerScript.TYPE_ANTI_MATERIEL) == 350, "Anti-Materiel is the heavier Steel investment")
	_assert(_range_curve(TowerScript.TYPE_ANTI_MATERIEL) == [3.3, 3.4, 3.5, 3.7, 4.0], "Anti-Materiel has deliberate long-range placement")
	_assert(_collect_upgrade_costs(tower) == [150, 550, 1225, 2275], "Anti-Materiel follows the five-level normalized price curve")
	_assert(_pierce_curve(TowerScript.TYPE_ANTI_MATERIEL) == [1, 1, 1, 1, 1], "Anti-Materiel always hits exactly one enemy after its primary target")
	_assert(_dps_curve(TowerScript.TYPE_ANTI_MATERIEL) == [12.73, 18.0, 32.97, 70.0, 116.13], "Anti-Materiel redistributes its existing maximum power across five levels")
	_assert(TowerScript.get_piercing_damage(100, 1) == 70, "the first pierced enemy receives the shared 70 percent damage")
	_assert(TowerScript.get_piercing_damage(100, 2) == 40, "shared pierce falloff reaches its 40 percent floor")


func _check_flamespitter_curve() -> void:
	var tower = _make_tower(TowerScript.TYPE_FLAMESPITTER)
	_assert(TowerScript.get_build_cost(TowerScript.TYPE_FLAMESPITTER) == 150, "Flamespitter has the Fire starter price")
	_assert(_range_curve(TowerScript.TYPE_FLAMESPITTER) == [1.8, 1.9, 2.0, 2.1, 2.2], "Flamespitter remains a short-range tower")
	_assert(_collect_upgrade_costs(tower) == [50, 250, 600, 1050], "Flamespitter follows the five-level area price curve")
	_assert(_stat_curve(TowerScript.TYPE_FLAMESPITTER, "cone_degrees") == [60.0, 65.0, 72.0, 82.0, 90.0], "Flamespitter's cone becomes meaningfully wider")
	_assert(_stat_curve(TowerScript.TYPE_FLAMESPITTER, "target_limit") == [3.0, 3.0, 4.0, 5.0, 6.0], "Flamespitter gains a controlled number of cone targets")
	_assert(_float_curves_match(_flame_dps_curve(), [5.0, 6.98, 13.04, 25.0, 41.67]), "Flamespitter redistributes its existing maximum crowd power")


func _check_bombardment_curve() -> void:
	var tower = _make_tower(TowerScript.TYPE_BOMBARDMENT)
	_assert(TowerScript.get_build_cost(TowerScript.TYPE_BOMBARDMENT) == 350, "Bombardment is the heavier Fire investment")
	_assert(_collect_upgrade_costs(tower) == [150, 550, 1400, 2450], "Bombardment follows the five-level area price curve")
	_assert(_stat_curve(TowerScript.TYPE_BOMBARDMENT, "shells") == [1.0, 1.0, 1.0, 2.0, 3.0], "Bombardment gains its staggered barrage at later levels")
	_assert(_stat_curve(TowerScript.TYPE_BOMBARDMENT, "stun") == [0.0, 0.0, 0.0, 0.0, 0.4], "only level-five Bombardment receives a short stun")
	var dps := _bombardment_dps_curve()
	_assert(dps[1] < dps[0] * 1.5, "Bombardment's first upgrade remains modest")
	_assert(_float_curves_match(dps, [10.0, 13.33, 26.0, 52.38, 87.5]), "Bombardment redistributes its existing maximum barrage power")


func _check_atomic_strike_curve() -> void:
	var tower = _make_tower(TowerScript.TYPE_ATOMIC_STRIKE)
	_assert(TowerScript.get_build_cost(TowerScript.TYPE_ATOMIC_STRIKE) == 500, "Atomic Strike starts as the expensive Steel-Fire hybrid")
	_assert(_collect_upgrade_costs(tower) == [200, 800, 2000, 3500], "Atomic Strike follows the five-level hybrid price curve")
	_assert(_range_curve(TowerScript.TYPE_ATOMIC_STRIKE) == [3.4, 3.5, 3.6, 3.8, 4.0], "Atomic Strike gains deliberate late range")
	_assert(_stat_curve(TowerScript.TYPE_ATOMIC_STRIKE, "splash_cells") == [1.1, 1.2, 1.3, 1.4, 1.5], "Atomic Strike grows one controlled blast")
	_assert(_dps_curve(TowerScript.TYPE_ATOMIC_STRIKE) == [8.0, 11.46, 21.11, 40.0, 64.29], "Atomic Strike redistributes its existing maximum blast power")
	_assert(_stat_curve(TowerScript.TYPE_ATOMIC_STRIKE, "hazard_duration") == [0.0, 0.0, 0.0, 0.0, 3.0], "only level-five Atomic Strike leaves ground fire")
	_assert(not bool(TowerScript.TYPE_DATA[TowerScript.TYPE_ATOMIC_STRIKE]["ignores_armor"]), "Atomic Strike does not bypass armor")


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


func _pierce_curve(type: StringName) -> Array[int]:
	var tower = _make_tower(type)
	var result: Array[int] = []
	while true:
		result.append(tower.get_pierce_count())
		if not tower.can_upgrade():
			break
		tower.upgrade(tower.get_next_upgrade_cost())
	return result


func _stat_curve(type: StringName, stat_name: String) -> Array[float]:
	var tower = _make_tower(type)
	var result: Array[float] = []
	while true:
		result.append(float(tower._get_stats().get(stat_name, 0.0)))
		if not tower.can_upgrade():
			break
		tower.upgrade(tower.get_next_upgrade_cost())
	return result


func _flame_dps_curve() -> Array[float]:
	var tower = _make_tower(TowerScript.TYPE_FLAMESPITTER)
	var result: Array[float] = []
	while true:
		var stats: Dictionary = tower._get_stats()
		var damage := float(tower.get_damage())
		if bool(stats.get("continuous", false)):
			result.append(damage / float(stats["tick_interval"]))
		else:
			var ticks := int(stats["spray_ticks"])
			var cycle_duration := float(maxi(ticks - 1, 0)) * float(stats["tick_interval"]) + float(stats["spray_gap"])
			result.append(damage * float(ticks) / cycle_duration)
		if not tower.can_upgrade():
			break
		tower.upgrade(tower.get_next_upgrade_cost())
	return result


func _bombardment_dps_curve() -> Array[float]:
	var tower = _make_tower(TowerScript.TYPE_BOMBARDMENT)
	var result: Array[float] = []
	while true:
		result.append(float(tower.get_damage() * tower.get_shell_count()) / tower.get_attack_interval())
		if not tower.can_upgrade():
			break
		tower.upgrade(tower.get_next_upgrade_cost())
	return result


func _float_curves_match(actual: Array[float], expected: Array[float]) -> bool:
	if actual.size() != expected.size():
		return false
	for index in actual.size():
		if absf(actual[index] - expected[index]) > 0.01:
			return false
	return true


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Prototype tower balance smoke failed: %s" % description)
	failure_count += 1
