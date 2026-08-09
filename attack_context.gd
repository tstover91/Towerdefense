class_name AttackContext
extends RefCounted

## Immutable-by-convention ownership information carried by an attack.
## Damage values remain snapshotted by the attack objects themselves; metadata
## is available for future relic-specific snapshots.

var root_tower_instance_id := 0
var root_tower_type: StringName = &""
var immediate_source_instance_id := 0
var immediate_source_kind: StringName = &"unknown"
var attack_kind: StringName = &"direct"
var is_secondary := false
var generation := 0
var metadata: Dictionary = {}
var root_tower_ref: WeakRef
var immediate_source_ref: WeakRef


static func from_tower(
	tower: Node,
	immediate_source: Object = null,
	source_kind: StringName = &"tower",
	initial_attack_kind: StringName = &"direct",
	attack_metadata: Dictionary = {}
) -> AttackContext:
	var context := AttackContext.new()
	if is_instance_valid(tower):
		context.root_tower_instance_id = tower.get_instance_id()
		context.root_tower_type = StringName(tower.get("tower_id"))
		context.root_tower_ref = weakref(tower)
	var resolved_source: Object = immediate_source if immediate_source != null else tower
	if is_instance_valid(resolved_source):
		context.immediate_source_instance_id = resolved_source.get_instance_id()
		context.immediate_source_ref = weakref(resolved_source)
	context.immediate_source_kind = source_kind
	context.attack_kind = initial_attack_kind
	context.metadata = attack_metadata.duplicate(true)
	return context


static func legacy(
	tower_type: StringName,
	initial_attack_kind: StringName = &"legacy"
) -> AttackContext:
	var context := AttackContext.new()
	context.root_tower_type = tower_type
	context.immediate_source_kind = &"unknown"
	context.attack_kind = initial_attack_kind
	return context


func derive(
	immediate_source: Object,
	source_kind: StringName,
	derived_attack_kind: StringName,
	secondary := true,
	metadata_updates: Dictionary = {}
) -> AttackContext:
	var context := AttackContext.new()
	context.root_tower_instance_id = root_tower_instance_id
	context.root_tower_type = root_tower_type
	context.root_tower_ref = root_tower_ref
	if is_instance_valid(immediate_source):
		context.immediate_source_instance_id = immediate_source.get_instance_id()
		context.immediate_source_ref = weakref(immediate_source)
	context.immediate_source_kind = source_kind
	context.attack_kind = derived_attack_kind
	context.is_secondary = secondary
	context.generation = generation + (1 if secondary else 0)
	context.metadata = metadata.duplicate(true)
	for key in metadata_updates:
		context.metadata[key] = metadata_updates[key]
	return context


func get_root_tower() -> Node:
	if root_tower_ref == null:
		return null
	return root_tower_ref.get_ref() as Node


func get_immediate_source() -> Object:
	if immediate_source_ref == null:
		return null
	return immediate_source_ref.get_ref()
