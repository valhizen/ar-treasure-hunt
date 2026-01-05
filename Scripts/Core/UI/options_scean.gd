extends Control
## OptionsScene - Simple audio settings menu

#region Scene References
@export_file("*.tscn") var return_scene_path: String = "res://Scenes/Core/MainMenu/main_menu.tscn"
#endregion

#region Styling
const COLOR_BG := Color(0.08, 0.08, 0.1, 0.98)
const COLOR_PANEL := Color(0.12, 0.12, 0.15, 1.0)
const COLOR_ACCENT := Color(0.45, 0.55, 0.8, 1.0)
const COLOR_TEXT := Color(0.85, 0.85, 0.9, 1.0)
const COLOR_DIM := Color(0.5, 0.5, 0.55, 1.0)
#endregion

#region UI References
var master_slider: HSlider
var master_label: Label
var music_slider: HSlider
var music_label: Label
var sfx_slider: HSlider
var sfx_label: Label

var back_button: Button
var apply_button: Button
#endregion

#region State
var settings: Dictionary = {}
#endregion


func _ready() -> void:
	_build_ui()
	_load_settings()
	_connect_signals()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BG
	add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 350)
	_style_panel(panel)
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(title)
	
	vbox.add_child(_spacer(15))
	
	# Audio Section
	vbox.add_child(_section_title("Audio"))
	vbox.add_child(_spacer(8))
	
	var audio_grid = GridContainer.new()
	audio_grid.columns = 3
	audio_grid.add_theme_constant_override("h_separation", 20)
	audio_grid.add_theme_constant_override("v_separation", 18)
	vbox.add_child(audio_grid)
	
	# Master
	audio_grid.add_child(_label("Master"))
	master_slider = _slider()
	audio_grid.add_child(master_slider)
	master_label = _value_label()
	audio_grid.add_child(master_label)
	
	# Music
	audio_grid.add_child(_label("Music"))
	music_slider = _slider()
	audio_grid.add_child(music_slider)
	music_label = _value_label()
	audio_grid.add_child(music_label)
	
	# SFX
	audio_grid.add_child(_label("SFX"))
	sfx_slider = _slider()
	audio_grid.add_child(sfx_slider)
	sfx_label = _value_label()
	audio_grid.add_child(sfx_label)
	
	vbox.add_child(_spacer(30))
	
	# Buttons
	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_box)
	
	back_button = _button("Back", false)
	btn_box.add_child(back_button)
	
	apply_button = _button("Apply", true)
	btn_box.add_child(apply_button)


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


func _section_title(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", COLOR_ACCENT)
	return l


func _label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.custom_minimum_size.x = 80
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", COLOR_TEXT)
	return l


func _value_label() -> Label:
	var l = Label.new()
	l.text = "100%"
	l.custom_minimum_size.x = 55
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", COLOR_DIM)
	return l


func _slider() -> HSlider:
	var s = HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = 1.0
	s.custom_minimum_size = Vector2(250, 25)
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.25)
	bg.set_corner_radius_all(4)
	bg.content_margin_top = 8
	bg.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", bg)
	
	var fill = StyleBoxFlat.new()
	fill.bg_color = COLOR_ACCENT
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	
	return s


func _button(text: String, primary: bool) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 45)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ACCENT if primary else Color(0.2, 0.2, 0.25)
	style.set_corner_radius_all(8)
	style.content_margin_left = 25
	style.content_margin_right = 25
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	b.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	
	var pressed = style.duplicate()
	pressed.bg_color = style.bg_color.darkened(0.1)
	b.add_theme_stylebox_override("pressed", pressed)
	
	return b


func _connect_signals() -> void:
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	back_button.pressed.connect(_on_back_pressed)
	apply_button.pressed.connect(_on_apply_pressed)


func _load_settings() -> void:
	if SaveManager:
		settings = SaveManager.load_settings()
	else:
		settings = {"master_volume": 1.0, "music_volume": 0.8, "sfx_volume": 1.0}
	
	master_slider.value = settings.get("master_volume", 1.0)
	music_slider.value = settings.get("music_volume", 0.8)
	sfx_slider.value = settings.get("sfx_volume", 1.0)
	_update_labels()


func _update_labels() -> void:
	master_label.text = "%d%%" % int(master_slider.value * 100)
	music_label.text = "%d%%" % int(music_slider.value * 100)
	sfx_label.text = "%d%%" % int(sfx_slider.value * 100)


func _set_volume(bus: String, val: float) -> void:
	var idx = AudioServer.get_bus_index(bus)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(val))


func _on_master_changed(val: float) -> void:
	settings["master_volume"] = val
	_update_labels()
	_set_volume("Master", val)


func _on_music_changed(val: float) -> void:
	settings["music_volume"] = val
	_update_labels()
	_set_volume("Music", val)


func _on_sfx_changed(val: float) -> void:
	settings["sfx_volume"] = val
	_update_labels()
	_set_volume("SFX", val)


func _on_back_pressed() -> void:
	if SaveManager:
		SaveManager.save_settings(settings)
	get_tree().change_scene_to_file(return_scene_path)


func _on_apply_pressed() -> void:
	if SaveManager:
		SaveManager.save_settings(settings)
	apply_button.text = "Saved!"
	var tween = create_tween()
	tween.tween_interval(0.8)
	tween.tween_callback(func(): apply_button.text = "Apply")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
