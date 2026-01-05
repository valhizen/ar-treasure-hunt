@tool
extends Area2D
class_name MinigameTrigger
## MinigameTrigger - Place this at minigame entry points (temples, buildings, etc.)
## Player can interact with this to start a minigame

#region Signals
signal player_entered_zone
signal player_exited_zone
signal interaction_available
signal minigame_launching(minigame_id: String)
#endregion

#region Configuration
@export_category("Minigame")
## The minigame data resource (preferred method)
@export var minigame_data: MinigameData = null

## Or use direct ID (fallback if no MinigameData)
@export var minigame_id: String = ""

@export_category("Interaction")
## Input action for interaction
@export var interact_action: String = "interact"
## Show prompt when player is in range
@export var show_prompt: bool = true
## Custom prompt text (leave empty for default)
@export var prompt_text: String = ""

@export_category("Visual Feedback")
## Sprite to highlight when player is near
@export var highlight_sprite: Sprite2D = null
## Highlight color when player can interact
@export var highlight_color: Color = Color(1.2, 1.2, 1.0, 1.0)
## Show floating indicator
@export var show_indicator: bool = true
@export var indicator_offset: Vector2 = Vector2(0, -32)

@export_category("Requirements Display")
## Show lock icon if minigame is locked
@export var show_lock_when_locked: bool = true
#endregion

#region State
var player_in_zone: bool = false
var can_interact: bool = false
var current_player: Node = null
var prompt_label: Label = null
var indicator_sprite: Sprite2D = null
var original_sprite_modulate: Color = Color.WHITE
#endregion


func _ready() -> void:
	# Setup collision
	collision_layer = 0
	collision_mask = 2  # Assuming player is on layer 2
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("[MinigameTrigger] Collision mask: ", collision_mask)
	print("[MinigameTrigger] Looking for 'interact' action: ", InputMap.has_action(interact_action))
	# Create UI elements
		# Make sure signals are connected
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("[MinigameTrigger] Connected body_entered signal")
	
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
		print("[MinigameTrigger] Connected body_exited signal")
	
	# Debug info
	print("[MinigameTrigger] Monitoring: ", monitoring)
	print("[MinigameTrigger] Monitorable: ", monitorable)
	if not Engine.is_editor_hint():
		_create_prompt_label()
		_create_indicator()
		
		# Store original modulate
		if highlight_sprite:
			original_sprite_modulate = highlight_sprite.modulate
	
	# Register minigame if using MinigameData
	if minigame_data and not Engine.is_editor_hint():
		_register_minigame()


func _create_prompt_label() -> void:
	"""Create the interaction prompt label"""
	if not show_prompt:
		return
	
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-50, -60)
	prompt_label.size = Vector2(100, 30)
	prompt_label.visible = false
	
	# Style
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 2)
	
	add_child(prompt_label)


func _create_indicator() -> void:
	"""Create floating indicator sprite"""
	if not show_indicator:
		return
	
	indicator_sprite = Sprite2D.new()
	indicator_sprite.position = indicator_offset
	indicator_sprite.visible = false
	# You can assign a texture here or leave it for manual assignment
	add_child(indicator_sprite)


func _register_minigame() -> void:
	"""Register this minigame with the MinigameManager"""
	var manager = get_node_or_null("/root/MinigameManager")
	if manager and minigame_data:
		manager.register_minigame(
			minigame_data.minigame_id,
			minigame_data.to_registry_entry()
		)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Check for interaction input
	if player_in_zone and can_interact:
		if Input.is_action_just_pressed(interact_action):
			_start_minigame()


func _on_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint():
		return
	
	if body.is_in_group("player"):
		player_in_zone = true
		current_player = body
		player_entered_zone.emit()
		
		# Check if can interact
		can_interact = _check_can_interact()
		
		# Show visual feedback
		_show_interaction_ui()
		
		if can_interact:
			interaction_available.emit()


func _on_body_exited(body: Node2D) -> void:
	if Engine.is_editor_hint():
		return
	
	if body.is_in_group("player"):
		player_in_zone = false
		current_player = null
		can_interact = false
		player_exited_zone.emit()
		
		# Hide visual feedback
		_hide_interaction_ui()


func _check_can_interact() -> bool:
	"""Check if player can interact with this trigger"""
	# If using MinigameData, check if unlocked
	if minigame_data:
		return minigame_data.is_unlocked()
	
	# Otherwise, always allow
	return true


func _show_interaction_ui() -> void:
	"""Show interaction prompt and highlight"""
	# Update prompt text
	if prompt_label:
		var text = prompt_text if not prompt_text.is_empty() else _get_default_prompt()
		prompt_label.text = text
		prompt_label.visible = true
	
	# Highlight sprite
	if highlight_sprite:
		highlight_sprite.modulate = highlight_color
	
	# Show indicator
	if indicator_sprite:
		indicator_sprite.visible = true
	
	# Show lock if needed
	if not can_interact and show_lock_when_locked:
		if prompt_label:
			prompt_label.text = "🔒 " + _get_lock_reason()


func _hide_interaction_ui() -> void:
	"""Hide interaction prompt and reset highlight"""
	if prompt_label:
		prompt_label.visible = false
	
	if highlight_sprite:
		highlight_sprite.modulate = original_sprite_modulate
	
	if indicator_sprite:
		indicator_sprite.visible = false


func _get_default_prompt() -> String:
	"""Get default prompt text"""
	var action_key = _get_interact_key_name()
	var mg_name = ""
	
	if minigame_data:
		mg_name = minigame_data.display_name
	else:
		mg_name = minigame_id.capitalize().replace("_", " ")
	
	return "[%s] Enter %s" % [action_key, mg_name]


func _get_interact_key_name() -> String:
	"""Get the key name for the interact action"""
	var events = InputMap.action_get_events(interact_action)
	if events.size() > 0:
		return events[0].as_text().split(" ")[0]
	return "E"


func _get_lock_reason() -> String:
	"""Get reason why minigame is locked"""
	if not minigame_data:
		return "Locked"
	
	var player_data = get_node_or_null("/root/PlayerData")
	if not player_data:
		return "Locked"
	
	if minigame_data.required_keys > 0 and player_data.total_keys < minigame_data.required_keys:
		return "Need %d keys" % minigame_data.required_keys
	
	for item_id in minigame_data.required_items:
		if not player_data.has_item(item_id):
			return "Need %s" % item_id
	
	for prereq in minigame_data.prerequisite_minigames:
		if not player_data.is_minigame_completed(prereq):
			return "Complete %s first" % prereq
	
	return "Locked"


func _start_minigame() -> void:
	"""Start the minigame"""
	var mg_id = minigame_data.minigame_id if minigame_data else minigame_id
	
	if mg_id.is_empty():
		push_error("[MinigameTrigger] No minigame ID configured!")
		return
	
	var player_pos = current_player.global_position if current_player else global_position
	var player_facing = Vector2.DOWN
	
	# Try to get player facing direction
	if current_player and current_player.has_method("get_facing_direction"):
		player_facing = current_player.get_facing_direction()
	
	minigame_launching.emit(mg_id)
	print("[MinigameTrigger] Launching minigame: %s" % mg_id)
	
	# Use MinigameManager to start
	var manager = get_node_or_null("/root/MinigameManager")
	if manager:
		manager.start_minigame(mg_id, player_pos, player_facing)
	else:
		push_error("[MinigameTrigger] MinigameManager not found!")


#region Editor Helpers
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if not minigame_data and minigame_id.is_empty():
		warnings.append("No MinigameData or minigame_id configured!")
	
	if minigame_data and minigame_data.scene_path.is_empty():
		warnings.append("MinigameData has no scene_path!")
	
	# Check for collision shape
	var has_shape = false
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			has_shape = true
			break
	
	if not has_shape:
		warnings.append("No collision shape! Add a CollisionShape2D child.")
	
	return warnings
#endregion
