class_name PerformanceOverlay
extends PanelContainer

const UPDATE_INTERVAL := 0.5
const RECENT_SAMPLE_COUNT := 10

@onready var stats_label: Label = $Margin/StatsLabel

var _update_elapsed := 0.0
var _recent_fps: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_display()


func _process(delta: float) -> void:
	if not visible:
		return
	_update_elapsed += delta
	if _update_elapsed < UPDATE_INTERVAL:
		return
	_update_elapsed = 0.0
	_update_display()


func set_tracker_visible(enabled: bool) -> void:
	visible = enabled
	_update_elapsed = UPDATE_INTERVAL
	if enabled:
		_recent_fps.clear()
		_update_display()


func is_tracker_visible() -> bool:
	return visible


func _update_display() -> void:
	var current_fps := float(Engine.get_frames_per_second())
	_recent_fps.append(current_fps)
	if _recent_fps.size() > RECENT_SAMPLE_COUNT:
		_recent_fps.pop_front()

	var average_fps := 0.0
	var recent_low := current_fps
	for sample in _recent_fps:
		average_fps += sample
		recent_low = minf(recent_low, sample)
	if not _recent_fps.is_empty():
		average_fps /= float(_recent_fps.size())

	var frame_time_ms := 0.0
	if current_fps > 0.0:
		frame_time_ms = 1000.0 / current_fps

	stats_label.text = (
		"FPS %d   AVG %d   LOW %d\n%.1f ms   ENEMIES %d   SHOTS %d   UNITS %d\nFX %d   RESOLVERS %d   HOOKS %d   SAUCERS %d   NODES %d"
		% [
			roundi(current_fps),
			roundi(average_fps),
			roundi(recent_low),
			frame_time_ms,
			get_tree().get_node_count_in_group(&"mobs"),
			get_tree().get_node_count_in_group(&"tower_projectiles"),
			get_tree().get_node_count_in_group(&"spawned_units"),
			get_tree().get_node_count_in_group(&"tower_attack_visuals"),
			get_tree().get_node_count_in_group(&"tower_attack_resolvers"),
			get_tree().get_node_count_in_group(&"fisherman_hooks"),
			get_tree().get_node_count_in_group(&"saucer_flyers"),
			get_tree().get_node_count(),
		]
	)
