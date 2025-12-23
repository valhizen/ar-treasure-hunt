extends Control
## SaveMenu - Save/Load slot selection
## Attach to root SaveMenu node

#region Scene References
@export_file("*.tscn") var options_scene_path: String = "res://Sceans/MainMenu/OptionsScean.tscn"
@export_file("*.tscn") var main_menu_path: String = "res://Sceans/MainMenu/main_menu.tscn"
#endregion

#region Configuration
@export var slot_button_scene: PackedScene  # Optional: custom slot button
#endregion

#region State
var is_save_mode: bool = false  # true = saving, false = loading
var selected_slot: int = -1
#endregion

#region Node References
var slots_container: VBoxContainer
var title_label: Label
var back_button: Button
var confirm_dialog: ConfirmationDialog
#endregion

func _ready() -> void:
	# Check mode from SaveManager meta
	if SaveManager and SaveManager.has_meta("save_mode"):
		is_save_mode = SaveManager.get_meta("save_mode")
		SaveManager.remove_meta("save_mode")
	
	# Setup UI
	_setup_ui()
	_create_slot_buttons()
	_refresh_slots()
	
	print("[SaveMenu] Ready - Mode: %s" % ("SAVE" if is_save_mode else "LOAD"))


func _setup_ui() -> void:
	"""Create necessary UI elements if they don't exist"""
	# Title
	title_label = get_node_or_null("Title")
	if not title_label:
		title_label = Label.new()
		title_label.name = "Title"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 32)
		add_child(title_label)
		title_label.position = Vector2(size.x / 2 - 100, 30)
	
	title_label.text = "SAVE GAME" if is_save_mode else "LOAD GAME"
	
	# Slots container
	slots_container = get_node_or_null("SlotsContainer")
	if not slots_container:
		slots_container = VBoxContainer.new()
		slots_container.name = "SlotsContainer"
		add_child(slots_container)
		# Center it
		slots_container.set_anchors_preset(Control.PRESET_CENTER)
		slots_container.position = Vector2(size.x / 2 - 200, 100)
		slots_container.custom_minimum_size = Vector2(400, 0)
	
	# Back button
	back_button = get_node_or_null("BackButton")
	if not back_button:
		back_button = Button.new()
		back_button.name = "BackButton"
		back_button.text = "Back"
		back_button.custom_minimum_size = Vector2(100, 40)
		add_child(back_button)
		back_button.position = Vector2(20, size.y - 60)
	
	back_button.pressed.connect(_on_back_pressed)
	
	# Confirmation dialog
	confirm_dialog = get_node_or_null("ConfirmDialog")
	if not confirm_dialog:
		confirm_dialog = ConfirmationDialog.new()
		confirm_dialog.name = "ConfirmDialog"
		add_child(confirm_dialog)
	
	confirm_dialog.confirmed.connect(_on_confirm_action)


func _create_slot_buttons() -> void:
	"""Create buttons for save slots"""
	# Clear existing
	for child in slots_container.get_children():
		child.queue_free()
	
	# Wait a frame for queue_free
	await get_tree().process_frame
	
	# Create 5 slots (0 = auto, 1-4 = manual)
	for i in range(5):
		var button = Button.new()
		button.name = "Slot%d" % i
		button.custom_minimum_size = Vector2(400, 70)
		button.pressed.connect(_on_slot_pressed.bind(i))
		
		# Add hover effect
		button.mouse_entered.connect(func(): button.modulate = Color(1.2, 1.2, 1.2))
		button.mouse_exited.connect(func(): button.modulate = Color.WHITE)
		
		slots_container.add_child(button)


func _refresh_slots() -> void:
	"""Update slot buttons with save info"""
	if not SaveManager:
		return
	
	var saves = SaveManager.get_all_saves()
	
	for i in range(min(saves.size(), slots_container.get_child_count())):
		var button = slots_container.get_child(i) as Button
		if not button:
			continue
		
		var save_info = saves[i]
		var slot_name = "Auto-Save" if i == 0 else "Slot %d" % i
		
		if save_info.exists:
			button.text = "%s\n%s | %s\nTime: %s" % [
				slot_name,
				save_info.current_map.capitalize(),
				save_info.relative_time,
				save_info.play_time
			]
			button.disabled = false
			button.modulate.a = 1.0
		else:
			button.text = "%s\n[Empty]" % slot_name
			
			if is_save_mode:
				# Can save to empty slots
				button.disabled = false
				button.modulate.a = 0.8
			else:
				# Can't load empty slots
				button.disabled = true
				button.modulate.a = 0.4


#region Slot Actions
func _on_slot_pressed(slot_index: int) -> void:
	"""Handle slot button press"""
	selected_slot = slot_index
	
	if is_save_mode:
		_handle_save_slot(slot_index)
	else:
		_handle_load_slot(slot_index)


func _handle_save_slot(slot_index: int) -> void:
	"""Handle saving to a slot"""
	var saves = SaveManager.get_all_saves()
	var save_info = saves[slot_index] if slot_index < saves.size() else null
	
	if save_info and save_info.exists:
		# Confirm overwrite
		confirm_dialog.dialog_text = "Overwrite existing save?\n%s | %s" % [
			save_info.current_map,
			save_info.relative_time
		]
		confirm_dialog.popup_centered()
	else:
		# Save directly to empty slot
		_do_save(slot_index)


func _handle_load_slot(slot_index: int) -> void:
	"""Handle loading from a slot"""
	_do_load(slot_index)


func _on_confirm_action() -> void:
	"""Confirmation dialog confirmed"""
	if is_save_mode:
		_do_save(selected_slot)
	else:
		_do_load(selected_slot)


func _do_save(slot_index: int) -> void:
	"""Actually save to slot"""
	print("[SaveMenu] Saving to slot %d" % slot_index)
	
	if SaveManager:
		var slot_name = "Auto-Save" if slot_index == 0 else "Slot %d" % slot_index
		var success = SaveManager.save_game(slot_index, slot_name)
		
		if success:
			_show_message("Game Saved!")
			_refresh_slots()
		else:
			_show_message("Save Failed!")


func _do_load(slot_index: int) -> void:
	"""Actually load from slot"""
	print("[SaveMenu] Loading slot %d" % slot_index)
	
	if GameManager:
		var success = GameManager.load_specific_save(slot_index)
		if not success:
			_show_message("Load Failed!")
	else:
		# Fallback
		var save_data = SaveManager.load_game(slot_index)
		if save_data:
			if PlayerData:
				PlayerData.load_from_dictionary(save_data.player_data)
			get_tree().change_scene_to_file("res://Sceans/Maps/%s.tscn" % save_data.current_map)
#endregion

#region Navigation
func _on_back_pressed() -> void:
	"""Go back to options"""
	print("[SaveMenu] Back pressed")
	get_tree().change_scene_to_file(options_scene_path)
#endregion

#region Helpers
func _show_message(text: String) -> void:
	"""Show temporary message"""
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.position = Vector2(size.x / 2 - 80, 60)
	add_child(label)
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)
#endregion

#region Input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
#endregion
