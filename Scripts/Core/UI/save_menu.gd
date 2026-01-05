extends Control
## SaveLoadMenu - Save and Load game slots
## Can be used standalone or as overlay

#region Enums
enum Mode { SAVE, LOAD }
#endregion

#region Exports
@export var mode: Mode = Mode.SAVE
@export_file("*.tscn") var return_scene_path: String = "res://Scenes/Core/MainMenu/main_menu.tscn"
@export var is_overlay: bool = false  # If true, just hides instead of changing scene
#endregion

#region Styling
const COLOR_BG := Color(0.08, 0.08, 0.1, 0.98)
const COLOR_PANEL := Color(0.12, 0.12, 0.15, 1.0)
const COLOR_SLOT := Color(0.18, 0.18, 0.22, 1.0)
const COLOR_SLOT_EMPTY := Color(0.14, 0.14, 0.17, 1.0)
const COLOR_ACCENT := Color(0.45, 0.55, 0.8, 1.0)
const COLOR_TEXT := Color(0.85, 0.85, 0.9, 1.0)
const COLOR_DIM := Color(0.5, 0.5, 0.55, 1.0)
const COLOR_AUTOSAVE := Color(0.4, 0.7, 0.5, 1.0)
const COLOR_DANGER := Color(0.8, 0.3, 0.3, 1.0)
#endregion

#region UI References
var title_label: Label
var slot_container: VBoxContainer
var back_button: Button
var confirm_dialog: Control
var confirm_title: Label
var confirm_message: Label
var confirm_yes: Button
var confirm_no: Button
#endregion

#region State
var selected_slot: int = -1
var slot_buttons: Array[Button] = []
#endregion


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_populate_slots()
	_connect_signals()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BG
	add_child(bg)
	
	# Center
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 500)
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
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = "Save Game" if mode == Mode.SAVE else "Load Game"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(title_label)
	
	vbox.add_child(_spacer(10))
	
	# Slot container
	slot_container = VBoxContainer.new()
	slot_container.add_theme_constant_override("separation", 10)
	vbox.add_child(slot_container)
	
	vbox.add_child(_spacer(15))
	
	# Back button
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)
	
	back_button = _styled_button("Back", false)
	back_button.custom_minimum_size.x = 150
	btn_container.add_child(back_button)
	
	# Build confirmation dialog (hidden initially)
	_build_confirm_dialog()


func _build_confirm_dialog() -> void:
	"""Build the confirmation dialog overlay"""
	confirm_dialog = Control.new()
	confirm_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_dialog.visible = false
	add_child(confirm_dialog)
	
	# Dim background
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	confirm_dialog.add_child(dim)
	
	# Center
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_dialog.add_child(center)
	
	# Dialog panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 200)
	_style_panel(panel)
	center.add_child(panel)
	
	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	panel.add_child(margin)
	
	# Layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Title
	confirm_title = Label.new()
	confirm_title.text = "Confirm"
	confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_title.add_theme_font_size_override("font_size", 24)
	confirm_title.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(confirm_title)
	
	# Message
	confirm_message = Label.new()
	confirm_message.text = "Are you sure?"
	confirm_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_message.add_theme_font_size_override("font_size", 16)
	confirm_message.add_theme_color_override("font_color", COLOR_DIM)
	confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(confirm_message)
	
	vbox.add_child(_spacer(10))
	
	# Buttons
	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_box)
	
	confirm_no = _styled_button("Cancel", false)
	confirm_no.custom_minimum_size.x = 100
	btn_box.add_child(confirm_no)
	
	confirm_yes = _styled_button("Confirm", true)
	confirm_yes.custom_minimum_size.x = 100
	btn_box.add_child(confirm_yes)


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


func _styled_button(text: String, primary: bool) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	
	var color = COLOR_ACCENT if primary else Color(0.2, 0.2, 0.25)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.bg_color = color.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	
	var pressed = style.duplicate()
	pressed.bg_color = color.darkened(0.1)
	b.add_theme_stylebox_override("pressed", pressed)
	
	return b


func _populate_slots() -> void:
	"""Create slot buttons for each save"""
	# Clear existing
	for child in slot_container.get_children():
		child.queue_free()
	slot_buttons.clear()
	
	var max_slots = SaveManager.MAX_SAVE_SLOTS if SaveManager else 5
	var saves = SaveManager.get_all_saves() if SaveManager else []
	
	for i in range(max_slots):
		var save_info = saves[i] if i < saves.size() else {"exists": false}
		var slot_btn = _create_slot_button(i, save_info)
		slot_container.add_child(slot_btn)
		slot_buttons.append(slot_btn)


func _create_slot_button(slot_index: int, save_info: Dictionary) -> Button:
	"""Create a styled save slot button"""
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(400, 70)
	btn.add_theme_font_size_override("font_size", 14)
	
	var exists = save_info.get("exists", false)
	var is_auto = slot_index == 0
	
	# Build button text
	var slot_name: String
	var details: String
	
	if exists:
		slot_name = save_info.get("save_name", "Save %d" % slot_index)
		if is_auto:
			slot_name = "Auto-Save"
		
		var map_name = save_info.get("current_map", "Unknown").capitalize()
		var play_time = save_info.get("play_time", "00:00:00")
		var relative = save_info.get("relative_time", "")
		details = "%s  •  %s  •  %s" % [map_name, play_time, relative]
	else:
		slot_name = "Auto-Save" if is_auto else "Slot %d" % slot_index
		details = "[Empty]"
	
	btn.text = "%s\n%s" % [slot_name, details]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Style based on state
	var bg_color: Color
	var border_color: Color
	
	if exists:
		bg_color = COLOR_SLOT
		border_color = COLOR_AUTOSAVE if is_auto else COLOR_ACCENT.darkened(0.3)
	else:
		bg_color = COLOR_SLOT_EMPTY
		border_color = Color(0.2, 0.2, 0.25)
	
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(8)
	style.border_color = border_color
	style.set_border_width_all(1)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.bg_color = bg_color.lightened(0.1)
	hover.border_color = COLOR_ACCENT
	hover.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	
	var pressed = style.duplicate()
	pressed.bg_color = bg_color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	# Text colors
	btn.add_theme_color_override("font_color", COLOR_TEXT if exists else COLOR_DIM)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT)
	
	# Disable empty slots in load mode
	if mode == Mode.LOAD and not exists:
		btn.disabled = true
		btn.modulate.a = 0.5
	
	# Connect signal
	btn.pressed.connect(func(): _on_slot_pressed(slot_index, save_info))
	
	return btn


func _connect_signals() -> void:
	back_button.pressed.connect(_on_back_pressed)
	confirm_yes.pressed.connect(_on_confirm_yes)
	confirm_no.pressed.connect(_on_confirm_no)


func _on_slot_pressed(slot_index: int, save_info: Dictionary) -> void:
	"""Handle slot button press"""
	selected_slot = slot_index
	var exists = save_info.get("exists", false)
	
	match mode:
		Mode.SAVE:
			if exists:
				_show_confirm("Overwrite Save?", "This will replace the existing save in Slot %d." % slot_index)
			else:
				_perform_save(slot_index)
		
		Mode.LOAD:
			if exists:
				_show_confirm("Load Save?", "Load save from Slot %d?\nUnsaved progress will be lost." % slot_index)


func _show_confirm(title: String, message: String) -> void:
	"""Show confirmation dialog"""
	confirm_title.text = title
	confirm_message.text = message
	confirm_dialog.visible = true
	confirm_yes.grab_focus()


func _hide_confirm() -> void:
	"""Hide confirmation dialog"""
	confirm_dialog.visible = false
	selected_slot = -1


func _on_confirm_yes() -> void:
	"""Confirmed action"""
	_hide_confirm()
	
	match mode:
		Mode.SAVE:
			_perform_save(selected_slot)
		Mode.LOAD:
			_perform_load(selected_slot)


func _on_confirm_no() -> void:
	"""Cancelled action"""
	_hide_confirm()


func _perform_save(slot_index: int) -> void:
	"""Execute save"""
	if not SaveManager:
		push_error("[SaveLoadMenu] SaveManager not found")
		return
	
	var save_name = "Auto-Save" if slot_index == 0 else "Save %d" % slot_index
	var success = SaveManager.save_game(slot_index, save_name)
	
	if success:
		print("[SaveLoadMenu] Saved to slot %d" % slot_index)
		# Show feedback
		var btn = slot_buttons[slot_index]
		var original_text = btn.text
		btn.text = "Saved!"
		await get_tree().create_timer(0.8).timeout
		_populate_slots()  # Refresh
	else:
		print("[SaveLoadMenu] Save failed")


func _perform_load(slot_index: int) -> void:
	"""Execute load"""
	if not SaveManager:
		push_error("[SaveLoadMenu] SaveManager not found")
		return
	
	get_tree().paused = false
	
	if GameManager:
		var success = GameManager.load_specific_save(slot_index)
		if success:
			print("[SaveLoadMenu] Loaded slot %d" % slot_index)
			queue_free()  # Remove this menu
		else:
			print("[SaveLoadMenu] Load failed")
	else:
		# Fallback: load data and change scene
		var save_data = SaveManager.load_game(slot_index)
		if save_data:
			if PlayerData:
				PlayerData.load_from_dictionary(save_data.get("player_data", {}))
			var map_path = "res://Scenes/Core/Maps/%s.tscn" % save_data.get("current_map", "bhaktapur")
			get_tree().change_scene_to_file(map_path)
			queue_free()


func _on_back_pressed() -> void:
	if is_overlay:
		queue_free()
	else:
		get_tree().change_scene_to_file(return_scene_path)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if confirm_dialog.visible:
			_hide_confirm()
		else:
			_on_back_pressed()


#region Public Methods
func set_mode(new_mode: Mode) -> void:
	"""Change mode and refresh"""
	mode = new_mode
	if title_label:
		title_label.text = "Save Game" if mode == Mode.SAVE else "Load Game"
	_populate_slots()


func refresh() -> void:
	"""Refresh the slot display"""
	_populate_slots()
#endregion
