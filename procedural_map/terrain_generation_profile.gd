class_name TerrainGenerationProfile
extends Resource

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
