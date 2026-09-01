extends Node

const AUDITED_EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]
const EXCLUDED_DIRECTORIES: Array[String] = [
	"res://.git",
	"res://.godot",
	"res://addons",
	"res://balance_reports",
]

var audited_count := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_audit")


func run_audit() -> void:
	var resource_paths: Array[String] = []
	_collect_resource_paths("res://", resource_paths)
	resource_paths.sort()
	for resource_path in resource_paths:
		audited_count += 1
		var resource := load(resource_path)
		if (
			resource == null
			or (
				resource is GDScript
				and not (resource as GDScript).can_instantiate()
			)
		):
			failures.append(resource_path)
	if not failures.is_empty():
		push_error(
			"Unable to load %d project resources: %s" % [
				failures.size(), ", ".join(failures)
			]
		)
		get_tree().quit(1)
		return
	print("Resource load audit passed for %d scripts, scenes, and resources." % audited_count)
	get_tree().quit(0)


func _collect_resource_paths(
	directory_path: String,
	resource_paths: Array[String]
) -> void:
	if directory_path in EXCLUDED_DIRECTORIES:
		return
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failures.append(directory_path)
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if entry_name.begins_with("."):
			entry_name = directory.get_next()
			continue
		var entry_path := directory_path.path_join(entry_name)
		if directory.current_is_dir():
			_collect_resource_paths(entry_path, resource_paths)
		elif entry_name.get_extension() in AUDITED_EXTENSIONS:
			resource_paths.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()
