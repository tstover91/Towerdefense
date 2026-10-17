class_name PrototypeUIOverlay
extends Node2D

var board: Node2D


func configure(source_board: Node2D) -> void:
	board = source_board
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(board):
		board.draw_ui_overlay()
