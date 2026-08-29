class_name TowerBuildButtonVisual
extends Button

@onready var tower_icon: TextureRect = find_child("TowerIcon", true, false) as TextureRect
@onready var price_label: Label = find_child("PriceLabel", true, false) as Label

var configured_texture: Texture2D
var configured_display_name := ""
var configured_cost := 0
var has_configuration := false


func _ready() -> void:
	_apply_configuration()


func configure(
	tower_texture: Texture2D,
	display_name: String,
	cost: int,
	slot_index: int
) -> void:
	configured_texture = tower_texture
	configured_display_name = display_name
	configured_cost = cost
	has_configuration = true
	tooltip_text = "Drag %s onto the map · $%d" % [display_name, cost]
	set_meta("slot_index", slot_index)
	if is_node_ready():
		_apply_configuration()


func _apply_configuration() -> void:
	if not has_configuration:
		return
	if tower_icon == null or price_label == null:
		push_error("TowerBuildButtonVisual requires descendants named TowerIcon and PriceLabel.")
		return
	tower_icon.texture = configured_texture
	price_label.text = "$%d" % configured_cost


func set_selected(is_selected: bool) -> void:
	button_pressed = is_selected


func set_affordable(is_affordable: bool) -> void:
	disabled = not is_affordable
	self_modulate = Color.WHITE if is_affordable else Color(0.55, 0.53, 0.52, 0.62)
