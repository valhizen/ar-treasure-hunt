extends CanvasLayer
## PauseMenu - In-game pause menu
## Add as child to your game scene or use as autoload

#region Scene References
@export_file("*.tscn") var main_menu_path: String = "res://Scenes/Core/MainMenu/main_menu.tscn"
@export_file("*.tscn") var options_scene_path: String = "res://Scenes/Core/UI/options_scean.tscn"
@export_file("*.tscn") var save_menu_path: String = "res://Scenes/Core/UI/save_menu.tscn"
#endregion

#region Styling
const COLOR_DIM := Color(0.0, 0.0, 0.0, 0.7)
const COLOR_PANEL := Color(0.12, 0.12, 0.15, 1.0)
const COLOR_ACCENT := Color(0.45, 0.55, 0.8, 1.0)
const COLOR_TEXT := Color(0.85, 0.85, 0.9, 1.0)
const COLOR_DANGER := Color(0.8, 0.3, 0.3, 1.0)
#endregion

#region UI References
var dim_bg: ColorRect
var panel: PanelContainer
var resume_button: Button
var options_button: Button
var save_button: Button
var main_menu_button: Button
var quit_button: Button
var audio_player: AudioStreamPlayer
#endregion

#region State
var is_open: bool = false
#endregion


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100  # Make sure it's on top
	_build_ui()
	_connect_signals()
	hide_menu()


func _build_ui() -> void:
	# Dim background
	dim_bg = ColorRect.new()
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.color = COLOR_DIM
	add_child(dim_bg)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Panel
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 400)
	_style_panel(panel)
	center.add_child(panel)
	
	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_bottom", 35)
	panel.add_child(margin)
	
	# Main layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(title)
	
	vbox.add_child(_spacer(20))
	
	# Buttons
	resume_button = _button("Resume")
	vbox.add_child(resume_button)
	
	options_button = _button("Options")
	vbox.add_child(options_button)
	
	save_button = _button("Save Game")
	vbox.add_child(save_button)
	
	main_menu_button = _button("Main Menu")
	vbox.add_child(main_menu_button)
	
	vbox.add_child(_spacer(10))
	
	quit_button = _button("Quit Game", true)
	vbox.add_child(quit_button)
	
	# Audio player
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)


func _style_panel(p: PanelContainer) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(12)
	style.border_color = COLOR_ACCENT.darkened(0.3)
	style.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", style)


func _spacer(height: int) -> Control:
	var s = Control.new()
	s.custom_minimum_size.y = height
	return s


func _button(text: String, danger: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(250, 45)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	
	var color = COLOR_DANGER if danger else Color(0.2, 0.2, 0.25)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	b.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.bg_color = color.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	
	var pressed = style.duplicate()
	pressed.bg_color = color.darkened(0.1)
	b.add_theme_stylebox_override("pressed", pressed)
	
	return b


func _connect_signals() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	save_button.pressed.connect(_on_save_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)




func show_menu() -> void:
	"""Show pause menu"""
	if is_open:
		return
	
	is_open = true
	visible = true
	get_tree().paused = true
	
	# Animate in
	dim_bg.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.parallel().tween_property(dim_bg, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.15)
	
	resume_button.grab_focus()
	print("[PauseMenu] Opened")


func hide_menu() -> void:
	"""Hide pause menu"""
	if not is_open:
		visible = false
		return
	
	is_open = false
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.parallel().tween_property(dim_bg, "modulate:a", 0.0, 0.1)
	tween.parallel().tween_property(panel, "scale", Vector2(0.9, 0.9), 0.1)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
	)
	
	print("[PauseMenu] Closed")


#region Button Handlers
func _on_resume_pressed() -> void:
	print("[PauseMenu] Resume pressed")
	hide_menu()


func _on_options_pressed() -> void:
	print("[PauseMenu] Options pressed")
	# Option 1: Change scene (simpler but loses game state position)
	# get_tree().paused = false
	# get_tree().change_scene_to_file(options_scene_path)
	
	# Option 2: Show options as overlay (recommended)
	_show_options_overlay()


func _show_options_overlay() -> void:
	"""Show options as overlay instead of changing scene"""
	var options = load("res://Scenes/Core/UI/options_scean.tscn")
	if options:
		var options_instance = options.instantiate()
		options_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		# Override the back button to return to pause menu instead
		add_child(options_instance)
		panel.visible = false


func _on_save_pressed() -> void:
	print("[PauseMenu] Save pressed")
	# Open save menu
	var save_menu = load(save_menu_path)
	if save_menu:
		var save_instance = save_menu.instantiate()
		save_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		save_instance.mode = 0  # SAVE mode
		save_instance.tree_exited.connect(func(): panel.visible = true)
		add_child(save_instance)
		panel.visible = false
	else:
		# Quick save to slot 1
		if SaveManager:
			var success = SaveManager.save_game(1, "Manual Save")
			if success:
				save_button.text = "Saved!"
				await get_tree().create_timer(1.0).timeout
				save_button.text = "Save Game"


func _on_main_menu_pressed() -> void:
	print("[PauseMenu] Main Menu pressed")
	get_tree().paused = false
	is_open = false
	
	if GameManager:
		GameManager.return_to_main_menu()
	else:
		get_tree().change_scene_to_file(main_menu_path)


func _on_quit_pressed() -> void:
	print("[PauseMenu] Quit pressed")
	
	# Auto-save before quitting
	if SaveManager and GameManager:
		if GameManager.current_player:
			SaveManager.auto_save(GameManager.current_map, GameManager.current_player.global_position)
	
	get_tree().quit()
#endregion
