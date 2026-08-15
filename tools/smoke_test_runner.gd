extends Node


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--smoke-script="):
			continue
		var script_path := argument.trim_prefix("--smoke-script=")
		var smoke_script := load(script_path) as GDScript
		if smoke_script == null:
			push_error("Unable to load smoke test: %s" % script_path)
			get_tree().quit(1)
			return
		var smoke_test := smoke_script.new() as Node
		if smoke_test == null:
			push_error("Smoke test must extend Node: %s" % script_path)
			get_tree().quit(1)
			return
		add_child(smoke_test)
		return
	push_error("Missing --smoke-script argument.")
	get_tree().quit(1)
