# prologue_controller.gd
extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var pikpik: CharacterBody2D = $Pikpik
@onready var rubble_trigger: Area2D = $RubbleTrigger
@onready var camera: Camera2D = $Player/Camera2D
@onready var fade_overlay: ColorRect = $CanvasLayer/FadeOverlay
@onready var dialogue_label: Label = $CanvasLayer/NarratorLabel  # Optional for narration

# Dialogue Manager reference
var dialogue_resource := preload("res://Dialogue/prologue_dialogue.dialogue")

func _ready() -> void:
	# Setup initial state
	player.can_move = false
	pikpik.hide()
	fade_overlay.color = Color.BLACK
	
	# Connect signals
	rubble_trigger.body_entered.connect(_on_rubble_trigger_entered)
	pikpik.emerged_from_rubble.connect(_on_pikpik_emerged)
	pikpik.interaction_started.connect(_start_dialogue)
	
	# Start the prologue sequence
	start_prologue()

func start_prologue() -> void:
	# Optional: Show some narrator text first
	await show_narrator_text("You wake up on cold stone...")
	await get_tree().create_timer(1.5).timeout
	
	await show_narrator_text("Your head feels empty. No voices. No people.")
	await get_tree().create_timer(1.5).timeout
	
	# Fade in from black
	await fade_in(2.0)
	
	await get_tree().create_timer(1.0).timeout
	
	# Enable player movement
	player.enable_movement()

func show_narrator_text(text: String) -> void:
	if dialogue_label:
		dialogue_label.text = text
		dialogue_label.modulate.a = 0
		
		var tween := create_tween()
		tween.tween_property(dialogue_label, "modulate:a", 1.0, 0.5)
		await tween.finished
		
		await get_tree().create_timer(2.0).timeout
		
		tween = create_tween()
		tween.tween_property(dialogue_label, "modulate:a", 0.0, 0.5)
		await tween.finished

func fade_in(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, duration)
	await tween.finished

func fade_out(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, duration)
	await tween.finished

func _on_rubble_trigger_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Disable the trigger so it only fires once
		rubble_trigger.set_deferred("monitoring", false)
		
		# Stop player briefly
		player.disable_movement()
		
		# Camera shake or sound effect here
		await shake_camera(0.3, 5.0)
		
		# Pikpik emerges!
		await pikpik.emerge_from_rubble()

func _on_pikpik_emerged() -> void:
	await get_tree().create_timer(0.5).timeout
	player.enable_movement()

func shake_camera(duration: float, intensity: float) -> void:
	var original_offset := camera.offset
	var shake_timer := 0.0
	
	while shake_timer < duration:
		camera.offset = original_offset + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_timer += get_process_delta_time()
		await get_tree().process_frame
	
	camera.offset = original_offset

func _start_dialogue() -> void:
	player.disable_movement()
	pikpik.has_talked = true
	
	# Using Dialogue Manager
	DialogueManager.show_dialogue_balloon(dialogue_resource, "prologue_start")
	
	# Wait for dialogue to end
	await DialogueManager.dialogue_ended
	
	# After dialogue ends
	_on_dialogue_ended()

func _on_dialogue_ended() -> void:
	player.enable_movement()
	
	# Transition to main game or next scene
	await get_tree().create_timer(1.0).timeout
	# get_tree().change_scene_to_file("res://scenes/main_game.tscn")
