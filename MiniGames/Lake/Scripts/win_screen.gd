extends CanvasLayer

var win_panel: PanelContainer
var win_label: Label
var continue_label: Label

var time_label: Label
var kills_label: Label
var score_label: Label

var is_showing: bool = false
var game_manager: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("win_screen")

	# Find GameManager (NO AUTOLOAD)
	game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		push_error("WinScreen: GameManager not found")

	# ─── Overlay ───
	win_panel = PanelContainer.new()
	add_child(win_panel)

	win_panel.anchor_left = 0
	win_panel.anchor_top = 0
	win_panel.anchor_right = 1
	win_panel.anchor_bottom = 1

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0.1, 0.2, 0.9)
	win_panel.add_theme_stylebox_override("panel", panel_style)

	# ─── Center VBox ───
	var vbox := VBoxContainer.new()
	win_panel.add_child(vbox)

	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -250
	vbox.offset_top = -200
	vbox.offset_right = 250
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 20)

	# ─── Title ───
	win_label = Label.new()
	win_label.text = "MISSION COMPLETE!"
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.add_theme_font_size_override("font_size", 56)
	win_label.add_theme_color_override("font_color", Color(0.2, 1, 0.3))
	vbox.add_child(win_label)

	# ─── Info Labels ───
	time_label = _make_info_label("Time: 00:00")
	kills_label = _make_info_label("Kills: 0")
	score_label = _make_info_label("Score: 0", 36)

	vbox.add_child(time_label)
	vbox.add_child(kills_label)
	vbox.add_child(score_label)

	hide_win_screen()

func _make_info_label(text: String, size: int = 24) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	return label

# ─────────────────────────────────────
# SHOW WIN SCREEN
# ─────────────────────────────────────
func show_win_screen() -> void:
	if not game_manager:
		return

	is_showing = true
	win_panel.visible = true
	get_tree().paused = true

	_update_stats()

func hide_win_screen() -> void:
	is_showing = false
	win_panel.visible = false
	get_tree().paused = false

# ─────────────────────────────────────
# SCORE LOGIC
# ─────────────────────────────────────
func _update_stats() -> void:
	var duration: float = game_manager.game_duration
	var kills: int = game_manager.fish_killed

	# Format time
	var minutes: int = int(duration) / 60
	var seconds: int = int(duration) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]

	kills_label.text = "Kills: %d" % kills

	var final_score: int = _calculate_score(duration, kills)
	score_label.text = "SCORE: %d" % final_score

func _calculate_score(time_sec: float, kills: int) -> int:
	var kill_score: int = kills * 50
	var time_bonus: int = int(max(0.0, 5000.0 - time_sec * 25.0))
	return kill_score + time_bonus

# ─────────────────────────────────────
func continue_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
