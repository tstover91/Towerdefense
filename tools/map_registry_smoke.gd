extends Node

const MapData = preload("res://map_database.gd")
const MAIN_SCENE = preload("res://main.tscn")


func _ready() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var map_ids := MapData.get_map_ids()
	assert(not map_ids.is_empty(), "At least one map must be registered")
	assert(map_ids.has(MapData.DEFAULT_MAP_ID), "Default map must be registered")
	for map_id in map_ids:
		var map := MapData.instantiate_map(map_id)
		assert(map != null, "Map scene must instantiate: %s" % map_id)
		add_child(map)
		assert(map.map_id == map_id, "Map scene ID must match its registry key")
		assert(not map.display_name.is_empty(), "Map requires a display name")
		assert(map.get_build_bounds().has_area(), "Map requires build bounds")
		assert(map.build_mask != null, "Map requires a paintable BuildMask layer")
		assert(not map.build_mask.visible, "BuildMask must be hidden during play")
		var paths := map.get_enemy_paths()
		assert(not paths.is_empty(), "Map requires an enemy path")
		for path in paths:
			assert(path.curve != null and path.curve.point_count >= 2)
			assert(not map.get_path_id(path).is_empty())
		map.queue_free()

	var mask_map := MapData.instantiate_map(MapData.DEFAULT_MAP_ID)
	add_child(mask_map)
	assert(mask_map.native_build_bounds == Rect2(0.0, 0.0, 1152.0, 640.0))
	mask_map.build_mask.set_cell(Vector2i(4, 5), 0, Vector2i.ZERO, 0)
	assert(mask_map.is_point_blocked_by_build_mask(Vector2(72.0, 88.0)))
	assert(not mask_map.is_point_blocked_by_build_mask(Vector2(88.0, 88.0)))
	mask_map.queue_free()

	SessionState.select_map(MapData.DEFAULT_MAP_ID)
	var gameplay = MAIN_SCENE.instantiate()
	add_child(gameplay)
	assert(gameplay.get_active_map() != null)
	assert(gameplay.get_active_map().map_id == MapData.DEFAULT_MAP_ID)
	var active_path: Path2D = gameplay.get_primary_enemy_path()
	assert(active_path != null)
	assert(gameplay.get_node("MapContainer").is_ancestor_of(active_path))
	var secondary_path := Path2D.new()
	secondary_path.name = "secondary"
	secondary_path.curve = active_path.curve.duplicate()
	active_path.get_parent().add_child(secondary_path)
	gameplay.round_number = 1
	gameplay.next_spawn_path_index = 0
	gameplay._create_mob(&"normal", 0.0)
	gameplay._create_mob(&"normal", 0.0)
	assert(active_path.get_child_count() == 1)
	assert(secondary_path.get_child_count() == 1)
	var primary_mob = active_path.get_child(0).get_child(0)
	assert(gameplay.get_path_id_for_requester(primary_mob) == &"primary")
	gameplay.clear_all_path_followers()

	print("Map registry smoke checks passed.")
	gameplay.queue_free()
	get_tree().quit(0)
