class_name SiegeWallPlanPreview
extends Control

const WALL_COLOR := Color("d7a948")
const WALL_EDGE := Color("f3d77b")
const EXISTING_WALL_COLOR := Color("716b5c")
const EXISTING_WALL_EDGE := Color("aaa18a")
const BACKGROUND := Color(0.05, 0.05, 0.05, 0.45)

var cells: Array[Vector2i] = []
var required_wall_cells: Array[Vector2i] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_cells(value: Array) -> void:
	set_plan(value, [])


func set_plan(value: Array, required_value: Array) -> void:
	cells.clear()
	for cell in value:
		cells.append(Vector2i(cell))
	required_wall_cells.clear()
	for cell in required_value:
		required_wall_cells.append(Vector2i(cell))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	var all_cells: Array[Vector2i] = cells.duplicate()
	for cell in required_wall_cells:
		if not all_cells.has(cell):
			all_cells.append(cell)
	if all_cells.is_empty():
		return
	var minimum := all_cells[0]
	var maximum := all_cells[0]
	for cell in all_cells:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	var dimensions := Vector2(maximum - minimum + Vector2i.ONE)
	var tile_size := minf((size.x - 16.0) / dimensions.x, (size.y - 16.0) / dimensions.y)
	var drawing_size := dimensions * tile_size
	var origin := (size - drawing_size) * 0.5
	for cell in cells:
		var local_cell := Vector2(cell - minimum)
		var rect := Rect2(origin + local_cell * tile_size, Vector2.ONE * tile_size).grow(-1.0)
		draw_rect(rect, WALL_COLOR, true)
		draw_rect(rect, WALL_EDGE, false, 1.0)
	for cell in required_wall_cells:
		var local_cell := Vector2(cell - minimum)
		var rect := Rect2(origin + local_cell * tile_size, Vector2.ONE * tile_size).grow(-1.0)
		draw_rect(rect, EXISTING_WALL_COLOR, true)
		draw_rect(rect, EXISTING_WALL_EDGE, false, 1.0)
