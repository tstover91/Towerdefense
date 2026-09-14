class_name TerrainGenerationProfile
extends Resource

@export_group("Map Identity")
@export var profile_id: StringName = &"switchback"
@export var display_name := "Switchback"
@export_multiline var description := "A long road with vertical and westward sections."

@export var grid_size := Vector2i(36, 20)
@export_range(0.0, 1.0, 0.01) var minimum_field_ratio := 0.50
@export_range(0, 4, 1) var edge_clearance_columns := 1
@export_range(0, 8, 1) var safe_top_rows := 3
@export_range(0, 8, 1) var safe_bottom_rows := 2
@export_range(0, 3, 1) var field_border_between_blobs := 1
@export_range(0, 12, 1) var protected_right_columns := 7
@export_range(0, 10, 1) var protected_right_top_rows := 4
@export_range(0, 10, 1) var protected_right_bottom_rows := 4
@export_range(0, 12, 1) var exit_top_margin_rows := 6
@export_range(0, 12, 1) var exit_bottom_margin_rows := 6
@export_range(1, 16, 1) var candidate_seed_count := 8

@export_group("Road Layout")
@export_range(1, 4, 1) var entrance_count := 2
@export var entrance_unlock_rounds := PackedInt32Array([1, 5])
@export_range(0.1, 0.8, 0.01) var minimum_join_ratio := 0.35
@export_range(1, 12, 1) var initial_straight_columns := 3
@export_range(1, 64, 1) var scenic_route_attempts := 32
@export var checkpoint_ratios := PackedFloat32Array([0.28, 0.62])
@export_range(0, 4, 1) var checkpoint_jitter_columns := 2
@export_range(0.6, 0.95, 0.01) var final_approach_ratio := 0.82
@export_range(1, 8, 1) var minimum_vertical_shift_rows := 4
@export var allows_backtracking := true
@export var requires_backtracking := true
@export_range(1, 10, 1) var backtrack_min_columns := 3
@export_range(1, 12, 1) var backtrack_max_columns := 6
@export_range(1.0, 3.0, 0.05) var minimum_route_length_ratio := 1.35
@export_range(1.0, 4.0, 0.05) var maximum_route_length_ratio := 2.60

@export_group("Forest Blobs")
@export_range(0, 12, 1) var forest_blob_count := 4
@export_range(1, 200, 1) var forest_blob_min_size := 24
@export_range(1, 200, 1) var forest_blob_max_size := 36
@export_range(0.0, 1.0, 0.01) var forest_compactness := 0.82

@export_group("Mud Blobs")
@export_range(0, 12, 1) var mud_blob_count := 2
@export_range(1, 200, 1) var mud_blob_min_size := 12
@export_range(1, 200, 1) var mud_blob_max_size := 20
@export_range(0.0, 1.0, 0.01) var mud_compactness := 0.78

@export_group("Terrain Bands")
@export_range(0, 6, 1) var soft_band_count := 0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if profile_id.is_empty():
		errors.append("profile_id cannot be empty")
	if display_name.is_empty():
		errors.append("display_name cannot be empty")
	if entrance_unlock_rounds.size() < entrance_count:
		errors.append("entrance_unlock_rounds needs one value per entrance")
	if backtrack_min_columns > backtrack_max_columns:
		errors.append("backtrack_min_columns cannot exceed backtrack_max_columns")
	if minimum_route_length_ratio > maximum_route_length_ratio:
		errors.append("minimum route length cannot exceed maximum route length")
	var previous_ratio := 0.0
	for ratio in checkpoint_ratios:
		if ratio <= previous_ratio or ratio >= final_approach_ratio:
			errors.append("checkpoint ratios must increase before final_approach_ratio")
			break
		previous_ratio = ratio
	if requires_backtracking and not allows_backtracking:
		errors.append("required backtracking must also be allowed")
	return errors
