extends SceneTree

const ModeSelectScene = preload("res://prototype/prototype_mode_select.tscn")
const SiegeScene = preload("res://siege_prototype/siege_main.tscn")

var failures: Array[String] = []


func _init() -> void:
	var selector := ModeSelectScene.instantiate()
	var siege := SiegeScene.instantiate()

	_assert(
		ProjectSettings.get_setting("application/run/main_scene", "")
		== "res://prototype/prototype_mode_select.tscn",
		"the project launches through the prototype mode selector"
	)
	_assert(
		int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)) == 4,
		"Android uses sensor-landscape orientation instead of sensor-portrait"
	)
	_assert(selector.name == "PrototypeModeSelect", "the selector scene instantiates")
	_assert(
		selector.get_node_or_null("Page/Content/ModeButtons/GridMazeButton") != null,
		"the selector exposes the existing grid-maze entry point"
	)
	_assert(
		selector.get_node_or_null("Page/Content/ModeButtons/SiegeButton") != null,
		"the selector exposes the isolated siege entry point"
	)
	_assert(
		ResourceLoader.exists("res://prototype/prototype_main.tscn", "PackedScene"),
		"the existing grid-maze scene remains available at its original path"
	)
	_assert(siege.name == "SiegePrototype", "the siege scene instantiates independently")
	_assert(siege.get_node_or_null("HUD/TopBar/BackButton") != null, "the siege scene can return to mode select")
	_assert(siege.get_node_or_null("SiegeBoard") != null, "the siege scene owns its independent fixed arena")
	_assert(
		selector.get_script() != siege.get_script(),
		"the selector and siege entry point use independent controllers"
	)

	selector.free()
	siege.free()

	if failures.is_empty():
		print("Prototype mode separation smoke passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _assert(condition: bool, description: String) -> void:
	if not condition:
		failures.append("Prototype mode separation failed: %s" % description)
