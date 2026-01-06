extends CanvasLayer

var message_label: Label
var game_manager: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("win_screen")
	
	game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		push_error("WinScreen: GameManager not found")
	
	_create_label()

func _create_label() -> void:
	message_label = Label.new()
	add_child(message_label)
	
	message_label.text = "Find the exit!"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 52)
	message_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4))
	message_label.add_theme_constant_override("outline_size", 4)
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	
	message_label.anchor_left = 0
	message_label.anchor_top = 0.2
	message_label.anchor_right = 1
	message_label.anchor_bottom = 0.35
	message_label.visible = false

func show_win_screen() -> void:
	if not game_manager:
		return
	
	# Submit score first (no pause, so it works)
	var final_score = _calculate_score(game_manager.game_duration, game_manager.fish_killed)
	ScoreManager.submit_score("bkt_lake", final_score, {
		"time_taken": game_manager.game_duration,
		"fish_killed": game_manager.fish_killed,
		"corrupters_defused": 3,
		"success": true
	})
	print("[WinScreen] Score submitted: %d" % final_score)
	
	# Show message with fade out
	message_label.modulate.a = 1.0
	message_label.visible = true
	
	var tween = create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(message_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): message_label.visible = false)

func _calculate_score(time_sec: float, kills: int) -> int:
	var kill_score: int = kills * 50
	var time_bonus: int = int(max(0.0, 5000.0 - time_sec * 25.0))
	return kill_score + time_bonus
