# prologue_intro.gd
extends Node

const SAVE_PATH = "user://prologue_state.save"

@export_category("Timing")
@export var delay_before_start: float = 0.3
@export var time_per_line: float = 3.0
@export var fade_time: float = 0.6

@export_category("References")
@export var player_path: NodePath
@export var pikpik_path: NodePath
@export var quest_ui_path: NodePath
@export var portal_path: NodePath 

@export_category("Audio")
@export var pikpik_sound: AudioStream
@export var sound_volume_db: float = 0.0
@export var max_hear_distance: float = 500.0
@export var stop_distance: float = 100.0

@onready var player: Node2D = get_node_or_null(player_path) if player_path else get_parent().get_node_or_null("MainCharacter")
@onready var pikpik: Node2D = get_node_or_null(pikpik_path) if pikpik_path else get_parent().get_node_or_null("PikPik")
@onready var quest_ui = get_node_or_null(quest_ui_path) if quest_ui_path else get_parent().get_node_or_null("QuestUI")
@onready var portal: Node2D = get_node_or_null(portal_path) if portal_path else get_parent().get_node_or_null("Portal")

var sound_player: AudioStreamPlayer
var sound_playing: bool = false

var intro_lines: Array[String] = [
	"The air tastes like dust and silence.",
	"Walls split open. Streets cracked.",
	"Pieces of familiar places... scattered like broken memories.",
	"Your head feels empty.",
	"No voices. No people.",
	"Just the hum of wind through shattered windows.",
]

var current_line: int = 0
var canvas_layer: CanvasLayer
var overlay: ColorRect
var text_label: Label

var indicator: Node2D
var indicator_arrow: Polygon2D
var indicator_target: Node2D = null

signal intro_finished
signal sound_played
signal pikpik_interacted

var current_state = {
	"intro_played": false,
	"pikpik_found": false,
	"minigame_unlocked": false
}

# NEW: Flag to prevent multiple calls
var is_processing_pikpik_interaction: bool = false

func _ready() -> void:
	_load_state()
	
	if portal:
		_set_portal_active(false)

	# Hide PikPik if already found
	if current_state["pikpik_found"] and pikpik:
		pikpik.queue_free()  # Or pikpik.visible = false

	if current_state["intro_played"]:
		call_deferred("_handle_existing_save_state")
	else:
		call_deferred("_start_intro")

func _load_state() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var data = file.get_var()
		file.close()
		
		if typeof(data) == TYPE_DICTIONARY:
			current_state = data
		else:
			current_state["intro_played"] = true

func _save_state() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(current_state)
		file.close()

func _handle_existing_save_state() -> void:
	intro_finished.emit()
	
	if not current_state["pikpik_found"]:
		_start_pikpik_sound()
		# No indicator for PikPik - player explores on their own
	else:
		if portal and not current_state["minigame_unlocked"]:
			_create_indicator(portal)
		elif current_state["minigame_unlocked"]:
			_set_portal_active(true)
	
	if current_state["pikpik_found"] and player and "point_light_2d" in player:
		player.point_light_2d.enabled = false

func _start_intro() -> void:
	_set_player_control(false)
	await get_tree().create_timer(delay_before_start).timeout
	_create_ui()
	_show_next_line()

func _create_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(overlay)
	
	text_label = Label.new()
	text_label.anchor_left = 0.0
	text_label.anchor_right = 1.0
	text_label.anchor_top = 1.0
	text_label.anchor_bottom = 1.0
	text_label.offset_left = 50
	text_label.offset_right = -50
	text_label.offset_top = -150
	text_label.offset_bottom = -50
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 26)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	text_label.modulate.a = 0
	canvas_layer.add_child(text_label)

func _show_next_line() -> void:
	if current_line >= intro_lines.size():
		_show_sound_moment()
		return
	
	text_label.text = intro_lines[current_line]
	var tween = create_tween()
	tween.tween_property(text_label, "modulate:a", 1.0, fade_time)
	tween.tween_interval(time_per_line)
	tween.tween_property(text_label, "modulate:a", 0.0, fade_time)
	tween.tween_callback(_on_line_done)

func _on_line_done() -> void:
	current_line += 1
	_show_next_line()

func _show_sound_moment() -> void:
	await get_tree().create_timer(0.5).timeout
	_start_pikpik_sound()
	sound_played.emit()
	
	text_label.text = "..."
	text_label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(text_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.0)
	tween.tween_property(text_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): text_label.text = "Something... somewhere nearby.")
	tween.tween_property(text_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(text_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_end_intro)

func _start_pikpik_sound() -> void:
	if not pikpik_sound or sound_playing: return
	
	sound_player = AudioStreamPlayer.new()
	sound_player.stream = pikpik_sound
	sound_player.bus = "SFX"
	sound_player.volume_db = -20.0
	add_child(sound_player)
	
	sound_player.finished.connect(func(): if sound_playing: sound_player.play())
	sound_player.play()
	sound_playing = true

func _stop_pikpik_sound() -> void:
	sound_playing = false
	if sound_player:
		var tween = create_tween()
		tween.tween_property(sound_player, "volume_db", -40.0, 0.5)
		tween.tween_callback(func():
			if sound_player:
				sound_player.stop()
				sound_player.queue_free()
				sound_player = null
		)

func _end_intro() -> void:
	current_state["intro_played"] = true
	_save_state()
	
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.0, fade_time)
	tween.tween_callback(_finish)

func _finish() -> void:
	_set_player_control(true)
	
	if quest_ui and quest_ui.has_method("add_quest"):
		var objectives: Array[String] = ["Investigate the sound"]
		quest_ui.add_quest("find_pikpik", "A Familiar Voice", objectives)
	
	# No indicator - player uses sound to find PikPik
	
	canvas_layer.queue_free()
	
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		save_manager.auto_save("prologue_scene", player.global_position)
	
	intro_finished.emit()

func _create_indicator(target: Node2D) -> void:
	if not target or not player: return
	
	_remove_indicator()
	
	indicator_target = target
	
	indicator = Node2D.new()
	indicator.name = "ObjectiveIndicator"
	get_parent().add_child(indicator)
	
	indicator_arrow = Polygon2D.new()
	indicator_arrow.polygon = PackedVector2Array([
		Vector2(20, 0), Vector2(-10, -12), Vector2(-5, 0), Vector2(-10, 12)
	])
	indicator_arrow.color = Color(1.0, 0.9, 0.4, 0.9)
	indicator.add_child(indicator_arrow)
	
	var glow = Polygon2D.new()
	glow.polygon = indicator_arrow.polygon
	glow.color = Color(1.0, 0.8, 0.2, 0.3)
	glow.scale = Vector2(1.5, 1.5)
	glow.z_index = -1
	indicator.add_child(glow)
	
	var tween = create_tween().set_loops()
	tween.tween_property(glow, "scale", Vector2(1.8, 1.8), 0.5)
	tween.tween_property(glow, "scale", Vector2(1.3, 1.3), 0.5)

func _process(delta: float) -> void:
	if not player: return

	if sound_playing and sound_player and pikpik and not current_state["pikpik_found"]:
		var dist = player.global_position.distance_to(pikpik.global_position)
		if dist >= stop_distance:
			var vol = 1.0 - clamp(dist / max_hear_distance, 0.0, 1.0)
			sound_player.volume_db = lerp(-30.0, sound_volume_db, vol)

	if indicator and is_instance_valid(indicator) and indicator_target:
		var t_pos = indicator_target.global_position
		var p_pos = player.global_position
		var dist = p_pos.distance_to(t_pos)
		
		if dist < stop_distance:
			indicator.visible = false
		else:
			indicator.visible = true
			var dir = (t_pos - p_pos).normalized()
			indicator.global_position = p_pos + dir * 80.0
			indicator.rotation = dir.angle()

func _remove_indicator() -> void:
	if indicator and is_instance_valid(indicator):
		indicator.queue_free()
	indicator = null
	indicator_target = null

# CRITICAL: Triple-check before processing interaction
func on_pikpik_found() -> void:
	# First barrier: Check if already found
	if current_state["pikpik_found"]:
		print("PikPik already found. Ignoring interaction.")
		return
	
	# Second barrier: Check if currently processing
	if is_processing_pikpik_interaction:
		print("Already processing PikPik interaction. Ignoring duplicate call.")
		return
	
	# Lock the interaction
	is_processing_pikpik_interaction = true
	
	print("PikPik found! Processing interaction...")
	
	_stop_pikpik_sound()
	_remove_indicator()
	
	# Update state IMMEDIATELY
	current_state["pikpik_found"] = true
	_save_state()
	
	# Hide/remove PikPik
	if pikpik:
		pikpik.queue_free()  # Or use pikpik.visible = false if you need it later
	
	if player and "point_light_2d" in player:
		player.point_light_2d.enabled = false
		
	if quest_ui and quest_ui.has_method("complete_objective"):
		quest_ui.complete_objective("find_pikpik", 0)
		quest_ui.add_quest("enter_portal", "The Way Out", ["Complete the Minigame", "Enter Portal"])

	if portal:
		print("Pointing to portal...")
		_create_indicator(portal)
	
	pikpik_interacted.emit()
	
	# Unlock after a brief delay (optional safety)
	await get_tree().create_timer(0.5).timeout
	is_processing_pikpik_interaction = false

func unlock_portal() -> void:
	if not current_state["minigame_unlocked"]:
		current_state["minigame_unlocked"] = true
		_save_state()
		
		_set_portal_active(true)
		print("Portal Unlocked!")

func _set_portal_active(is_active: bool) -> void:
	if not portal: return
	
	var collider = portal.get_node_or_null("CollisionShape2D")
	if not collider:
		var area = portal.get_node_or_null("MinigameExitPortal")
		if area: collider = area.get_node_or_null("CollisionShape2D")
			
	if collider:
		collider.set_deferred("disabled", !is_active)
	
	if is_active:
		portal.modulate = Color(1, 1, 1, 1)
	else:
		portal.modulate = Color(0.5, 0.5, 0.5, 0.5)

func _set_player_control(enabled: bool) -> void:
	if not player: return
	if "can_move" in player: player.can_move = enabled
	elif "movement_enabled" in player: player.movement_enabled = enabled

func _input(event: InputEvent) -> void:
	if canvas_layer and current_line < intro_lines.size() and event.is_action_pressed("ui_accept"):
		current_line = intro_lines.size()
		_show_sound_moment()

static func reset_intro() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

# PUBLIC: Check if PikPik can be interacted with
func can_interact_with_pikpik() -> bool:
	return not current_state["pikpik_found"] and not is_processing_pikpik_interaction
