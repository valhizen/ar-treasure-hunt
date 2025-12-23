@tool  # Makes it work in editor for preview
extends Area2D
class_name MinigameTrigger
## MinigameTrigger - Place on map to trigger minigames
## Easy to configure in Inspector - just select minigame from dropdown!

#region Configuration
## Select which minigame this trigger starts
@export_enum("coin_collection", "bkt_lake", "pottery_game", "temple_puzzle", "maze_game") var minigame_id: String = "coin_collection"

## Display name shown in prompt
@export var display_name: String = "Play Minigame"

## The actual scene path (auto-filled based on minigame_id, or set manually)
@export_file("*.tscn") var minigame_scene_path: String = ""

## How to activate
@export_enum("on_interact", "on_enter") var activation_mode: String = "on_interact"

## Input action for interaction
@export var interact_action: String = "ui_accept"

## Show prompt when player is in range
@export var show_prompt: bool = true

## Prompt text (use {key} for input hint)
@export var prompt_text: String = "Press E to play"

## Disable trigger after minigame is completed once
@export var one_time_only: bool = false

## Preview color in editor
@export var editor_color: Color = Color(0.2, 0.8, 0.2, 0.3)
#endregion

#region Minigame Scene Mapping
# Add your minigames here - maps ID to scene path
const MINIGAME_SCENES: Dictionary = {
	"coin_collection": "res://Sceans/Minigames/bhaktapur/coin_collection.tscn",
	"bkt_lake": "res://Sceans/Minigames/bhaktapur/bkt_lake_minigame.tscn",
	"pottery_game": "res://Sceans/Minigames/bhaktapur/pottery_game.tscn",
	"temple_puzzle": "res://Sceans/Minigames/bhaktapur/temple_puzzle.tscn",
	"maze_game": "res://Sceans/Minigames/bhaktapur/maze_game.tscn",
	# Add more as needed
}
#endregion

#region State
var player_in_range: bool = false
var is_completed: bool = false
var is_active: bool = true
var player_ref: Node2D = null
#endregion

#region Node References
var prompt_label: Label = null
#endregion

#region Lifecycle
func _ready() -> void:
	if Engine.is_editor_hint():
		# Editor only - for visual preview
		queue_redraw()
		return
	
	# Runtime setup
	add_to_group("minigame_triggers")
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create prompt label
	_create_prompt_label()
	
	# Check if already completed
	_check_completion_status()
	
	# Auto-fill scene path if not set
	if minigame_scene_path.is_empty() and MINIGAME_SCENES.has(minigame_id):
		minigame_scene_path = MINIGAME_SCENES[minigame_id]
	
	print("[MinigameTrigger] Ready: %s -> %s" % [minigame_id, minigame_scene_path])


func _draw() -> void:
	# Editor preview
	if Engine.is_editor_hint():
		# Draw a colored circle to show trigger area
		var collision = get_node_or_null("CollisionShape2D")
		if collision and collision.shape:
			if collision.shape is CircleShape2D:
				draw_circle(Vector2.ZERO, collision.shape.radius, editor_color)
			elif collision.shape is RectangleShape2D:
				var size = collision.shape.size
				draw_rect(Rect2(-size/2, size), editor_color)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	
	if not is_active or not player_in_range:
		return
	
	if activation_mode == "on_interact":
		if event.is_action_pressed(interact_action) or event.is_action_pressed("interact"):
			_trigger_minigame()
#endregion

#region Setup
func _create_prompt_label() -> void:
	"""Create the interaction prompt"""
	if not show_prompt:
		return
	
	prompt_label = Label.new()
	prompt_label.text = prompt_text
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-50, -60)
	prompt_label.custom_minimum_size = Vector2(100, 0)
	prompt_label.hide()
	
	# Add outline for visibility
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 2)
	
	add_child(prompt_label)


func _check_completion_status() -> void:
	"""Check if this minigame was already completed"""
	if not one_time_only:
		return
	
	# Check with PlayerData if available
	if PlayerData:
		var map_name = _get_current_map_name()
		is_completed = PlayerData.is_minigame_completed(minigame_id, map_name)
		
		if is_completed:
			is_active = false
			print("[MinigameTrigger] %s already completed" % minigame_id)
#endregion

#region Trigger Logic
func _on_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint():
		return
	
	if not _is_player(body):
		return
	
	player_in_range = true
	player_ref = body
	
	if activation_mode == "on_enter" and is_active:
		_trigger_minigame()
	elif show_prompt and prompt_label and is_active:
		prompt_label.show()


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	
	player_in_range = false
	player_ref = null
	
	if prompt_label:
		prompt_label.hide()


func _trigger_minigame() -> void:
	"""Start the minigame"""
	if not is_active:
		return
	
	# Hide prompt
	if prompt_label:
		prompt_label.hide()
	
	# Get player position
	var entry_position = global_position
	if player_ref:
		entry_position = player_ref.global_position
	
	print("[MinigameTrigger] Starting minigame: %s" % minigame_id)
	
	# Use MinigameManager if available
	if MinigameManager:
		# Register this minigame if not already registered
		if not MinigameManager.minigame_registry.has(minigame_id):
			MinigameManager.register_minigame(minigame_id, {
				"id": minigame_id,
				"display_name": display_name,
				"scene_path": minigame_scene_path,
				"map": _get_current_map_name()
			})
		
		MinigameManager.start_minigame(minigame_id, entry_position)
	else:
		# Fallback: Direct scene change (no position saving)
		push_warning("[MinigameTrigger] MinigameManager not found, using direct scene change")
		get_tree().change_scene_to_file(minigame_scene_path)
#endregion

#region Utility
func _is_player(body: Node2D) -> bool:
	"""Check if body is the player"""
	return body.is_in_group("player") or body.name == "MainCharacter" or body.name == "Player"


func _get_current_map_name() -> String:
	"""Get current map name"""
	if GameManager and not GameManager.current_map.is_empty():
		return GameManager.current_map
	
	# Fallback: extract from scene
	var scene_path = get_tree().current_scene.scene_file_path
	return scene_path.get_file().get_basename()


func set_active(active: bool) -> void:
	"""Enable/disable this trigger"""
	is_active = active
	if not active and prompt_label:
		prompt_label.hide()


func mark_completed() -> void:
	"""Mark as completed (disables if one_time_only)"""
	is_completed = true
	if one_time_only:
		is_active = false
#endregion

#region Editor Helpers
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if minigame_scene_path.is_empty() and not MINIGAME_SCENES.has(minigame_id):
		warnings.append("No scene path set for minigame: %s" % minigame_id)
	
	var has_collision = false
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			has_collision = true
			break
	
	if not has_collision:
		warnings.append("No collision shape! Add a CollisionShape2D as child.")
	
	return warnings
#endregion
