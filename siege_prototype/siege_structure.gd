class_name SiegeStructure
extends Node2D

signal health_changed(structure: Node, previous_health: float, current_health: float)
signal structure_destroyed(structure: Node)
signal structure_restored(structure: Node)

const COLOR_OUTLINE := Color("3b3b38")
const COLOR_WALL := Color("575754")
const COLOR_WALL_LIGHT := Color("92928b")
const COLOR_CANNON := Color("dc503f")
const COLOR_CORE := Color("e9b949")
const COLOR_CORE_INSET := Color("294d55")
const COLOR_MORTAR := Color("77909a")
const COLOR_ARCHER := Color("5f8fc4")
const COLOR_WIZARD := Color("9d64bb")
const COLOR_AIR_DEFENSE := Color("d17a3f")
const COLOR_TEXT := Color("f2efe4")
const COLOR_RUBBLE := Color("4a4541")
const COLOR_DAMAGE := Color("792d28")
const COLOR_HEALTH := Color("62bd69")
const COLOR_HEALTH_BACK := Color("252522")

var structure_id: StringName
var kind: StringName
var wall_formation_id: StringName
var level := 1
var grid_cell := Vector2i.ZERO
var footprint := Vector2i.ONE
var max_health := 1.0
var health := 1.0
var integrity_value := 0
var blocks_movement := true
var counts_for_objective := false
var destroyed := false
var definition: Dictionary = {}
var cell_size := 48.0


func configure(blueprint_entry: Dictionary, structure_definition: Dictionary) -> void:
	structure_id = StringName(blueprint_entry.get("id", &""))
	kind = StringName(blueprint_entry.get("kind", &""))
	wall_formation_id = StringName(blueprint_entry.get("wall_formation_id", &""))
	level = int(blueprint_entry.get("level", structure_definition.get("reference_level", 1)))
	grid_cell = Vector2i(blueprint_entry.get("cell", Vector2i.ZERO))
	footprint = Vector2i(blueprint_entry.get("footprint", Vector2i.ONE))
	definition = structure_definition.duplicate(true)
	max_health = maxf(float(definition.get("max_health", 1.0)), 1.0)
	health = max_health
	integrity_value = maxi(int(definition.get("integrity_value", 0)), 0)
	blocks_movement = bool(definition.get("blocks_movement", true))
	counts_for_objective = bool(definition.get("counts_for_objective", false))
	destroyed = false
	name = String(structure_id)
	queue_redraw()


func upgrade_to(next_level: int, structure_definition: Dictionary) -> void:
	level = maxi(next_level, 1)
	definition = structure_definition.duplicate(true)
	max_health = maxf(float(definition.get("max_health", 1.0)), 1.0)
	health = max_health
	destroyed = false
	queue_redraw()


func set_layout_metrics(next_board_origin: Vector2, next_cell_size: float) -> void:
	cell_size = maxf(next_cell_size, 1.0)
	position = next_board_origin + Vector2(grid_cell) * cell_size
	queue_redraw()


func apply_damage(amount: float) -> float:
	if destroyed or amount <= 0.0:
		return 0.0
	var previous_health := health
	health = maxf(health - amount, 0.0)
	var applied := previous_health - health
	health_changed.emit(self, previous_health, health)
	if health <= 0.0:
		destroyed = true
		structure_destroyed.emit(self)
	queue_redraw()
	return applied


func restore_full_health() -> void:
	var was_destroyed := destroyed
	var previous_health := health
	destroyed = false
	health = max_health
	if not is_equal_approx(previous_health, health):
		health_changed.emit(self, previous_health, health)
	if was_destroyed:
		structure_restored.emit(self)
	queue_redraw()


func occupies_cell(cell: Vector2i) -> bool:
	return (
		cell.x >= grid_cell.x
		and cell.y >= grid_cell.y
		and cell.x < grid_cell.x + footprint.x
		and cell.y < grid_cell.y + footprint.y
	)


func get_occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in footprint.x:
		for y in footprint.y:
			result.append(grid_cell + Vector2i(x, y))
	return result


func get_blueprint_entry() -> Dictionary:
	var entry := {
		"id": structure_id,
		"kind": kind,
		"level": level,
		"cell": grid_cell,
		"footprint": footprint,
	}
	if wall_formation_id != &"":
		entry["wall_formation_id"] = wall_formation_id
	return entry


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(footprint) * cell_size)
	if destroyed:
		_draw_rubble(rect)
		return
	match kind:
		&"command_core":
			_draw_command_core(rect)
		&"cannon":
			_draw_cannon(rect)
		&"mortar":
			_draw_mortar(rect)
		&"archer_tower":
			_draw_archer_tower(rect)
		&"wizard_tower":
			_draw_wizard_tower(rect)
		&"air_defense":
			_draw_air_defense(rect)
		&"wall":
			_draw_wall(rect)
		_:
			draw_rect(rect.grow(-cell_size * 0.12), COLOR_TEXT, true)
	if health < max_health:
		_draw_health_bar(rect)
	if kind != &"wall":
		var label_position := Vector2(rect.position.x + cell_size * 0.10, rect.end.y - cell_size * 0.12)
		draw_string(ThemeDB.fallback_font, label_position, "L%d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1.0, clampi(roundi(cell_size * 0.28), 9, 15), COLOR_TEXT)


func _draw_wall(rect: Rect2) -> void:
	var body := rect.grow(-cell_size * 0.10)
	draw_rect(body, COLOR_WALL, true)
	draw_rect(body, COLOR_OUTLINE, false, maxf(cell_size * 0.055, 1.0))
	draw_line(Vector2(body.position.x, body.get_center().y), Vector2(body.end.x, body.get_center().y), COLOR_WALL_LIGHT, maxf(cell_size * 0.035, 1.0))
	var seam_x := body.position.x + body.size.x * 0.5
	draw_line(Vector2(seam_x, body.position.y), Vector2(seam_x, body.get_center().y), COLOR_WALL_LIGHT, maxf(cell_size * 0.035, 1.0))


func _draw_cannon(rect: Rect2) -> void:
	var center := rect.get_center()
	var scale := minf(rect.size.x, rect.size.y)
	draw_rect(rect.grow(-scale * 0.06), COLOR_CANNON, true)
	draw_circle(center, scale * 0.24, COLOR_CORE_INSET)
	draw_line(center, center + Vector2.LEFT * scale * 0.36, COLOR_TEXT, maxf(scale * 0.10, 2.0), true)
	draw_circle(center, scale * 0.11, COLOR_TEXT)


func _draw_mortar(rect: Rect2) -> void:
	var center := rect.get_center()
	var scale := minf(rect.size.x, rect.size.y)
	draw_rect(rect.grow(-scale * 0.06), COLOR_MORTAR, true)
	draw_circle(center, scale * 0.27, COLOR_OUTLINE)
	draw_circle(center, scale * 0.15, COLOR_HEALTH_BACK)


func _draw_archer_tower(rect: Rect2) -> void:
	var scale := minf(rect.size.x, rect.size.y)
	var body := rect.grow(-scale * 0.06)
	var center := rect.get_center()
	draw_rect(body, COLOR_ARCHER, true)
	draw_rect(body, COLOR_OUTLINE, false, maxf(scale * 0.04, 1.0))
	draw_line(center + Vector2(-scale * 0.20, scale * 0.18), center + Vector2(0.0, -scale * 0.23), COLOR_TEXT, maxf(scale * 0.055, 1.0), true)
	draw_line(center + Vector2(scale * 0.20, scale * 0.18), center + Vector2(0.0, -scale * 0.23), COLOR_TEXT, maxf(scale * 0.055, 1.0), true)


func _draw_wizard_tower(rect: Rect2) -> void:
	var scale := minf(rect.size.x, rect.size.y)
	var body := rect.grow(-scale * 0.06)
	var center := rect.get_center()
	draw_rect(body, COLOR_WIZARD, true)
	draw_rect(body, COLOR_OUTLINE, false, maxf(scale * 0.04, 1.0))
	draw_circle(center, scale * 0.18, COLOR_TEXT)
	draw_circle(center, scale * 0.09, COLOR_WIZARD.darkened(0.35))


func _draw_air_defense(rect: Rect2) -> void:
	var center := rect.get_center()
	var scale := minf(rect.size.x, rect.size.y)
	var body := rect.grow(-scale * 0.06)
	draw_rect(body, COLOR_AIR_DEFENSE, true)
	draw_rect(body, COLOR_OUTLINE, false, maxf(scale * 0.04, 1.0))
	for offset_x in [-0.18, 0.18]:
		draw_line(center + Vector2(scale * offset_x, scale * 0.23), center + Vector2(scale * offset_x, -scale * 0.22), COLOR_TEXT, maxf(scale * 0.075, 1.0), true)


func _draw_command_core(rect: Rect2) -> void:
	var scale := minf(rect.size.x, rect.size.y)
	var body := rect.grow(-scale * 0.05)
	draw_rect(body, COLOR_CORE, true)
	draw_rect(body, COLOR_OUTLINE, false, maxf(scale * 0.04, 2.0))
	var inset := body.grow(-scale * 0.20)
	draw_rect(inset, COLOR_CORE_INSET, true)
	draw_circle(rect.get_center(), scale * 0.18, COLOR_TEXT)
	draw_circle(rect.get_center(), scale * 0.10, COLOR_CANNON)
	draw_line(rect.get_center(), rect.get_center() + Vector2.LEFT * scale * 0.25, COLOR_CANNON, maxf(scale * 0.07, 2.0), true)


func _draw_rubble(rect: Rect2) -> void:
	var body := rect.grow(-cell_size * 0.17)
	draw_rect(body, COLOR_RUBBLE, true)
	draw_line(body.position, body.end, COLOR_DAMAGE, maxf(cell_size * 0.08, 2.0), true)
	draw_line(Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), COLOR_DAMAGE, maxf(cell_size * 0.08, 2.0), true)


func _draw_health_bar(rect: Rect2) -> void:
	var width := rect.size.x * 0.72
	var height := maxf(cell_size * 0.09, 3.0)
	var bar := Rect2(Vector2((rect.size.x - width) * 0.5, cell_size * 0.04), Vector2(width, height))
	draw_rect(bar, COLOR_HEALTH_BACK, true)
	var fill := bar
	fill.size.x *= health / max_health
	draw_rect(fill, COLOR_HEALTH, true)
