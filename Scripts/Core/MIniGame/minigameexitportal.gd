@tool
extends Area2D
class_name MinigameExitPortal
## MinigameExitPortal - Place inside minigames to allow player to exit
## Can be configured to require confirmation or allow instant exit
## Optionally specify a target_scene to transition directly to that scene

#region Signals
signal player_entered_portal
signal player_exited_portal
signal exit_requested
signal exit_confirmed
signal exit_cancelled
#endregion

#region Configuration
@export_category("Exit Behavior")
## How the exit works
@export_enum("Instant", "Confirm", "Interact") var exit_mode: int = 2
## Input action for interaction (only for Interact mode)
@export var interact_action: String = "interact"
## Show warning if minigame not complete
@export var warn_if_incomplete: bool = true
## Optional: Direct scene path to transition to (leave empty for default behavior)
@export_file("*.tscn") var target_scene: String = ""

@export_category("Visual")
@export var show_prompt: bool = true
@export var prompt_text: String = ""
@export var portal_color: Color = Color(0.5, 0.8, 1.0, 0.5)
@export var active_color: Color = Color(0.8, 1.0, 0.8, 0.8)

@export_category("Animation")
@export var animate_portal: bool = true
@export var pulse_speed: float = 2.0
#endregion

#region State
var player_in_portal: bool = false
var current_player: Node = null
var prompt_label: Label = null
var portal_visual: Sprite2D = null
var confirmation_ui: Control = null
var anim_time: float = 0.0
#endregion


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Player layer
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if not Engine.is_editor_hint():
		_create_ui()


func _create_ui() -> void:
	"""Create UI elements"""
	# Prompt label
	if show_prompt:
		prompt_label = Label.new()
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.position = Vector2(-60, -50)
		prompt_label.size = Vector2(120, 30)
		prompt_label.visible = false
		prompt_label.add_theme_font_size_override("font_size", 14)
		prompt_label.add_theme_color_override("font_color", Color.WHITE)
		prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
		prompt_label.add_theme_constant_override("outline_size", 2)
		add_child(prompt_label)
	
	# Confirmation dialog (for Confirm mode)
	if exit_mode == 1:  # Confirm
		_create_confirmation_dialog()


func _create_confirmation_dialog() -> void:
	"""Create confirmation UI"""
	confirmation_ui = Control.new()
	confirmation_ui.set_anchors_preset(Control.PRESET_CENTER)
	confirmation_ui.visible = false
	
	var panel = PanelContainer.new()
	panel.position = Vector2(-100, -60)
	panel.custom_minimum_size = Vector2(200, 120)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = "Exit minigame?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	
	var yes_btn = Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(60, 30)
	yes_btn.pressed.connect(_on_confirm_yes)
	
	var no_btn = Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(60, 30)
	no_btn.pressed.connect(_on_confirm_no)
	
	hbox.add_child(yes_btn)
	hbox.add_child(no_btn)
	vbox.add_child(label)
	vbox.add_child(hbox)
	panel.add_child(vbox)
	confirmation_ui.add_child(panel)
	
	add_child(confirmation_ui)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Animate portal
	if animate_portal and portal_visual:
		anim_time += delta * pulse_speed
		var pulse = (sin(anim_time) + 1.0) * 0.5
		portal_visual.modulate.a = 0.3 + pulse * 0.4
	
	# Check for interact input
	if player_in_portal and exit_mode == 2:  # Interact mode
		if Input.is_action_just_pressed(interact_action):
			_request_exit()


func _on_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint():
		return
	
	if body.is_in_group("player"):
		player_in_portal = true
		current_player = body
		player_entered_portal.emit()
		
		_show_prompt()
		
		# Instant exit mode
		if exit_mode == 0:
			_request_exit()


func _on_body_exited(body: Node2D) -> void:
	if Engine.is_editor_hint():
		return
	
	if body.is_in_group("player"):
		player_in_portal = false
		current_player = null
		player_exited_portal.emit()
		
		_hide_prompt()
		_hide_confirmation()


func _show_prompt() -> void:
	"""Show interaction prompt"""
	if not prompt_label:
		return
	
	var text = prompt_text
	if text.is_empty():
		match exit_mode:
			0:  # Instant
				text = "Exiting..."
			1:  # Confirm
				text = "Exit Portal"
			2:  # Interact
				var key = _get_interact_key()
				text = "[%s] Exit" % key
	
	prompt_label.text = text
	prompt_label.visible = true


func _hide_prompt() -> void:
	"""Hide interaction prompt"""
	if prompt_label:
		prompt_label.visible = false


func _get_interact_key() -> String:
	"""Get key name for interact action"""
	var events = InputMap.action_get_events(interact_action)
	if events.size() > 0:
		return events[0].as_text().split(" ")[0]
	return "E"


func _request_exit() -> void:
	"""Request to exit the minigame"""
	exit_requested.emit()
	
	if exit_mode == 1:  # Confirm mode
		_show_confirmation()
	else:
		_do_exit()


func _show_confirmation() -> void:
	"""Show exit confirmation dialog"""
	if confirmation_ui:
		confirmation_ui.visible = true
		# Pause the minigame
		get_tree().paused = true


func _hide_confirmation() -> void:
	"""Hide confirmation dialog"""
	if confirmation_ui:
		confirmation_ui.visible = false


func _on_confirm_yes() -> void:
	"""Player confirmed exit"""
	_hide_confirmation()
	get_tree().paused = false
	exit_confirmed.emit()
	_do_exit()


func _on_confirm_no() -> void:
	"""Player cancelled exit"""
	_hide_confirmation()
	get_tree().paused = false
	exit_cancelled.emit()


func _do_exit() -> void:
	"""Actually exit the minigame"""
	print("[MinigameExitPortal] Exiting minigame...")
	
	# If a target scene is specified, go directly there
	if not target_scene.is_empty():
		# Use call_deferred to avoid issues during physics callbacks
		call_deferred("_exit_to_scene", target_scene)
		return
	
	# Default behavior: Get the minigame base (parent should be MinigameBase or have exit method)
	var minigame = _find_minigame_base()
	
	if minigame:
		# Let minigame handle exit (it might want to save partial progress)
		if minigame.has_method("player_exit"):
			minigame.player_exit()
		elif minigame.has_method("request_exit"):
			minigame.request_exit()
		else:
			# Direct exit through manager
			call_deferred("_exit_via_manager")
	else:
		# Fallback: exit via manager
		call_deferred("_exit_via_manager")




func _find_minigame_base() -> Node:
	"""Find the MinigameBase node"""
	# Check parent chain
	var current = get_parent()
	while current:
		if current.has_method("_initialize_minigame"):
			return current
		if current.is_in_group("minigame"):
			return current
		current = current.get_parent()
	
	# Check scene root
	var root = get_tree().current_scene
	if root and root.has_method("_initialize_minigame"):
		return root
	
	return null



func _exit_via_manager() -> void:
	"""Exit through MinigameManager"""
	var manager = get_node_or_null("/root/MinigameManager")
	if manager and manager.is_in_minigame:
		manager.exit_minigame(null)
		return
	
	# Fallback: try GameManager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		if game_manager.has_method("return_to_menu"):
			game_manager.return_to_menu()
			return
	
	# Last resort: direct scene change
	var tree = get_tree()
	if tree:
		push_warning("[MinigameExitPortal] No manager found, returning to main menu")
		tree.change_scene_to_file("res://Scenes/Core/MainMenu/main_menu.tscn")
	else:
		push_error("[MinigameExitPortal] Cannot exit - no tree or manager available")
func _exit_to_scene(scene_path: String) -> void:
	"""Transition directly to a specific scene"""
	print("[MinigameExitPortal] Transitioning to: ", scene_path)
	
	if not ResourceLoader.exists(scene_path):
		push_error("[MinigameExitPortal] Target scene not found: ", scene_path)
		_exit_via_manager()
		return
	
	# Check if tree is still valid
	var tree = get_tree()
	if tree == null:
		push_error("[MinigameExitPortal] Scene tree is null, cannot transition")
		return
	
	# Try using MinigameManager first (preserves state properly)
	var manager = get_node_or_null("/root/MinigameManager")
	if manager and manager.is_in_minigame:
		# Let MinigameManager handle the exit properly
		manager.saved_scene_path = scene_path
		manager.exit_minigame(null)
		return
	
	# Try using GameManager for smooth transitions
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("change_scene"):
		game_manager.change_scene(scene_path)
		return
	
	# Direct scene change as fallback
	var error = tree.change_scene_to_file(scene_path)
	if error != OK:
		push_error("[MinigameExitPortal] Failed to change scene: ", error)

#region Editor Helpers
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	var has_shape = false
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			has_shape = true
			break
	
	if not has_shape:
		warnings.append("No collision shape! Add a CollisionShape2D child.")
	
	# Warn if target scene doesn't exist
	if not target_scene.is_empty() and not ResourceLoader.exists(target_scene):
		warnings.append("Target scene not found: %s" % target_scene)
	
	return warnings
#endregion
