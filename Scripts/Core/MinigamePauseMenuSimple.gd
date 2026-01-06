extends CanvasLayer
## MinigamePauseMenuSimple - Simple pause menu behavior
## This script is attached to programmatically created pause menus

var is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if visible:
		hide_menu()
	else:
		show_menu()


func show_menu() -> void:
	visible = true
	is_paused = true
	get_tree().paused = true
	
	# Focus resume button
	var resume_btn = get_node_or_null("Panel/MarginContainer/VBox/ResumeButton")
	if resume_btn:
		resume_btn.grab_focus()


func hide_menu() -> void:
	visible = false
	is_paused = false
	get_tree().paused = false
