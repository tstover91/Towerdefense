extends SceneTree

const EnemyScript = preload("res://prototype/prototype_enemy.gd")

var failure_count := 0
var requested_summons := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := Node2D.new()
	get_root().add_child(host)

	var soldier := _make_enemy(host, EnemyScript.TYPE_SOLDIER, 1)
	var runner := _make_enemy(host, EnemyScript.TYPE_RUNNER, 2)
	var giant := _make_enemy(host, EnemyScript.TYPE_GIANT, 3)
	_assert(soldier.max_health == 65, "Soldier establishes the fixed-health baseline")
	_assert(runner.max_health == 42, "Runner remains below Soldier durability")
	_assert(giant.max_health == 480, "Giant remains near 7.4 Soldier health")

	var armored := _make_enemy(host, EnemyScript.TYPE_ARMORED, 4)
	_assert(armored.apply_damage(8) == 3, "armor removes five damage from a rapid hit")
	_assert(armored.apply_damage(28, &"ballistic", true) == 28, "piercing damage bypasses armor")

	var shielded := _make_enemy(host, EnemyScript.TYPE_SHIELDED, 5)
	for _hit in 3:
		_assert(shielded.apply_damage(180) == 0, "each shield charge negates one complete heavy hit")
	_assert(shielded.shield_charges == 0, "three hits exhaust the personal shield")
	_assert(shielded.apply_damage(8) == 8, "health takes damage after the shield is exhausted")

	var wounded := _make_enemy(host, EnemyScript.TYPE_GIANT, 10)
	var healer := _make_enemy(host, EnemyScript.TYPE_HEALER, 10)
	wounded.health -= 100
	healer._process_healing(0.25)
	_assert(wounded.health == wounded.max_health - 90, "Healer restores ten health per quarter-second tick")
	var scaled_wounded := _make_enemy(host, EnemyScript.TYPE_SOLDIER, 11, 1.60)
	var scaled_healer := _make_enemy(host, EnemyScript.TYPE_HEALER, 11, 1.60)
	_assert(scaled_wounded.max_health == 104, "late-wave scaling raises Soldier health by sixty percent")
	scaled_wounded.health -= 30
	scaled_healer._process_healing(0.25)
	_assert(scaled_wounded.health == scaled_wounded.max_health - 14, "late-wave scaling raises healing output by sixty percent")

	var witch := _make_enemy(host, EnemyScript.TYPE_WITCH, 20)
	witch.summon_requested.connect(_on_summon_requested)
	witch._process_summoning(2.5)
	_assert(requested_summons == 2, "Witch requests its first pair of Swarmlings")
	_assert(witch.summons_created == 2, "Witch tracks its finite summon budget")

	var golem := _make_enemy(host, EnemyScript.TYPE_GOLEM, 30)
	_assert(golem.max_health == 3200, "Golem body has fifty-Soldier-scale health")
	_assert(golem.get_release_count() == 2, "Golem splits into two children")
	_assert(golem.get_release_type() == EnemyScript.TYPE_GOLEMITE, "Golem releases Golemites")
	var golemite := _make_enemy(host, EnemyScript.TYPE_GOLEMITE, 30)
	_assert(golemite.max_health == 640, "each Golemite carries one fifth of the parent health")

	if failure_count > 0:
		quit(1)
		return
	print("PROTOTYPE_ENEMY_ROSTER_SMOKE_OK")
	quit(0)


func _make_enemy(host: Node2D, enemy_type: StringName, formation_id: int, health_scale := 1.0) -> Node2D:
	var enemy: Node2D = EnemyScript.new()
	host.add_child(enemy)
	enemy.position = Vector2(100.0, 100.0)
	enemy.setup_combat(enemy_type, health_scale, 48.0, formation_id, 0)
	return enemy


func _on_summon_requested(_summoner: Node2D, _enemy_type: StringName, count: int) -> void:
	requested_summons += count


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Prototype enemy roster smoke failed: %s" % description)
	failure_count += 1
