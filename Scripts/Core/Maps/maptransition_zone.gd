extends Area2D
class_name MapTransitionZone
## MapTransitionZone - Triggers map transitions when player enters
## Place at map edges to connect maps

#region Configuration
## Target map to transition to
@export var target_map: String = ""

## Spawn point name in target map (optional)
@export var target_spawn_point: String = ""

## How to activate
@export_enum("on_enter", "on_interact") var activation_mode: String = "on_enter"

## Interaction prompt (if activation_mode is on_interact)
@export var prompt_text: String = "Press E to travel"

## Show interaction prompt
@export var show_prompt: bool = true

## Require all minigames completed to pass (optional)
@export var require_all_minigames: bool = false

## Minimum minigames required (0 = no requirement)
@export var min_minigames_required: int = 0

## Message if blocked
@export var blocked_message: String = "Complete more tasks before traveling."
#endregion

#region Node References
@onready var prompt_label: Label = $PromptLabel if has_node("PromptLabel") else null
@onready var blocked_label: Label = $BlockedLabel if has_node("BlockedLabel") else null
#endregion

#region State
var player_in_zone: bool = false
var is_blocked: bool = false
#endregion

#region Lifecycle
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_prompts()


func _input(event: InputEvent) -> void:
	if not player_in_zone:
		return
	
	if activation_mode == "on_interact":
		if event.is_action_pressed("interact"):
			_try_transition()
#endregion

#region Setup
func _setup_prompts() -> void:
	"""Setup prompt labels"""
	if show_prompt and prompt_label == null:
		prompt_label = Label.new()
		prompt_label.text = prompt_text
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.position = Vector2(0, -40)
		prompt_label.hide()
		add_child(prompt_label)
	
	if blocked_label == null:
		blocked_label = Label.new()
		blocked_label.text = blocked_message
		blocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blocked_label.position = Vector2(0, -40)
		blocked_label.add_theme_color_override("font_color", Color.RED)
		blocked_label.hide()
		add_child(blocked_label)
#endregion

#region Trigger Logic
func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	
	player_in_zone = true
	
	# Check requirements
	is_blocked = not _check_requirements()
	
	if activation_mode == "on_enter":
		_try_transition()
	else:
		_show_appropriate_prompt()


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	
	player_in_zone = false
	_hide_all_prompts()


func _try_transition() -> void:
	"""Attempt to transition to target map"""
	if target_map.is_empty():
		push_error("[MapTransitionZone] No target_map set!")
		return
	
	# Check if map is unlocked
	if not PlayerData.is_map_unlocked(target_map):
		_show_blocked("This area is not yet accessible.")
		return
	
	# Check custom requirements
	if not _check_requirements():
		_show_blocked(blocked_message)
		return
	
	# Transition!
	_hide_all_prompts()
	_perform_transition()


func _perform_transition() -> void:
	"""Actually perform the transition"""
	print("[MapTransitionZone] Transitioning to %s (spawn: %s)" % [target_map, target_spawn_point])
	
	# Save current position
	var current_map = get_tree().current_scene
	if current_map and current_map.has_method("save_current_position"):
		current_map.save_current_position()
	
	# Change map
	GameManager.change_map(target_map, Vector2.ZERO, target_spawn_point)
#endregion

#region Requirements Check
func _check_requirements() -> bool:
	"""Check if player meets requirements to pass"""
	var current_map_id = GameManager.current_map
	
	# Check minimum minigames
	if min_minigames_required > 0:
		var completed = PlayerData.get_completed_minigame_count(current_map_id)
		if completed < min_minigames_required:
			return false
	
	# Check all minigames requirement
	if require_all_minigames:
		# This requires knowing total minigames for the map
		# You'd need to configure this or get it from MinigameManager
		var minigames = MinigameManager.get_minigames_for_map(current_map_id)
		var completed = PlayerData.get_completed_minigame_count(current_map_id)
		if completed < minigames.size():
			return false
	
	return true
#endregion

#region Prompt Display
func _show_appropriate_prompt() -> void:
	"""Show the right prompt based on state"""
	if is_blocked:
		_show_blocked(blocked_message)
	elif show_prompt and prompt_label:
		prompt_label.show()
		if blocked_label:
			blocked_label.hide()


func _show_blocked(message: String) -> void:
	"""Show blocked message"""
	if blocked_label:
		blocked_label.text = message
		blocked_label.show()
	if prompt_label:
		prompt_label.hide()
	
	# Hide after delay
	await get_tree().create_timer(2.0).timeout
	if blocked_label:
		blocked_label.hide()


func _hide_all_prompts() -> void:
	"""Hide all prompts"""
	if prompt_label:
		prompt_label.hide()
	if blocked_label:
		blocked_label.hide()
#endregion

#region Utility
func _is_player(body: Node2D) -> bool:
	"""Check if body is the player"""
	return body.is_in_group("player") or body.name == "Player"
#endregion
