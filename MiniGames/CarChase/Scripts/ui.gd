extends CanvasLayer

var hud: Control
var coin_label: Label
var game_over: Control
var win_screen: Control
var win_score: Label

func _ready() -> void:
	_create_ui()
	game_over.visible = false
	win_screen.visible = false

func _create_ui():
	# Create HUD
	hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	
	# Coin Label (top-left)
	coin_label = _create_label("Coins: 0", 20, Vector2(20, 20))
	coin_label.add_theme_color_override("font_color", Color(1, 0.84, 0)) # Gold color
	hud.add_child(coin_label)
	
	# Game Over Screen
	game_over = _create_screen("GAME OVER", Color(0.8, 0.2, 0.2))
	game_over.name = "GameOver"
	add_child(game_over)
	
	# Win Screen
	win_screen = Control.new()
	win_screen.name = "Win"
	win_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win_screen)
	
	var win_panel = _create_panel(Color(0.2, 0.6, 0.3, 0.95))
	win_screen.add_child(win_panel)
	
	var win_label = _create_label("YOU WIN!", 48, Vector2(0, -80))
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.anchor_left = 0.5
	win_label.anchor_right = 0.5
	win_label.offset_left = -200
	win_label.offset_right = 200
	win_label.add_theme_color_override("font_color", Color(1, 1, 0.5))
	win_panel.add_child(win_label)
	
	win_score = _create_label("Coins Collected: 0", 28, Vector2(0, 0))
	win_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_score.anchor_left = 0.5
	win_score.anchor_right = 0.5
	win_score.offset_left = -200
	win_score.offset_right = 200
	win_panel.add_child(win_score)

func _create_label(text: String, font_size: int, pos: Vector2) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.position = pos
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label

func _create_panel(color: Color) -> Panel:
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -200
	panel.offset_bottom = 200
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = Color(1, 1, 1, 0.8)
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func _create_screen(title: String, color: Color) -> Control:
	var screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = _create_panel(color)
	screen.add_child(panel)
	
	var label = _create_label(title, 48, Vector2(0, -80))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -200
	label.offset_right = 200
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	
	var button = _create_button("Restart", Vector2(0, 40))
	button.pressed.connect(_on_button_pressed)
	panel.add_child(button)
	
	return screen

func _create_button(text: String, pos: Vector2) -> Button:
	var button = Button.new()
	button.text = text
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.offset_left = -100
	button.offset_right = 100
	button.offset_top = pos.y
	button.offset_bottom = pos.y + 50
	button.add_theme_font_size_override("font_size", 24)
	button.process_mode = Node.PROCESS_MODE_ALWAYS  # Works even when paused
	
	# Normal style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.3, 0.3, 0.4)
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.corner_radius_bottom_right = 10
	button.add_theme_stylebox_override("normal", normal_style)
	
	# Hover style
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.4, 0.4, 0.5)
	hover_style.corner_radius_top_left = 10
	hover_style.corner_radius_top_right = 10
	hover_style.corner_radius_bottom_left = 10
	hover_style.corner_radius_bottom_right = 10
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed style
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.2, 0.2, 0.3)
	pressed_style.corner_radius_top_left = 10
	pressed_style.corner_radius_top_right = 10
	pressed_style.corner_radius_bottom_left = 10
	pressed_style.corner_radius_bottom_right = 10
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	return button

func update_coins(value: int):
	coin_label.text = "Coins: %d" % value

func show_game_over():
	hud.visible = false
	game_over.visible = true

func show_win(coins: int):
	var total_score = coins * 100
	win_score.text = "Coins Collected: %d\nTotal Score: %d" % [coins, total_score]
	hud.visible = false
	win_screen.visible = true

func _on_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(get_tree().current_scene.scene_file_path)
