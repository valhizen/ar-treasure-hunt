# prologue_intro.gd
# Eerie intro text, then sound + visual indicator pointing to PikPik
# Attach to a Node in PrologueMap

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

@export_category("Audio")
@export var pikpik_sound: AudioStream
@export var sound_volume_db: float = 0.0
@export var max_hear_distance: float = 500.0
@export var stop_distance: float = 100.0

@onready var player: Node2D = get_node_or_null(player_path) if player_path else get_parent().get_node_or_null("MainCharacter")
@onready var pikpik: Node2D = get_node_or_null(pikpik_path) if pikpik_path else get_parent().get_node_or_null("PikPik")
@onready var quest_ui = get_node_or_null(quest_ui_path) if quest_ui_path else get_parent().get_node_or_null("QuestUI")

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
var indicator_active: bool = false

signal intro_finished
signal sound_played


func _ready() -> void:
	# Check if intro has already played
	if _has_intro_played():
		# Skip intro, just set up indicator if needed
		call_deferred("_skip_to_gameplay")
	else:
		call_deferred("_start_intro")


func _has_intro_played() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _mark_intro_played() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string("played")
		file.close()


func _skip_to_gameplay() -> void:
	# Player already has control, just set up the indicator and sound if PikPik not found yet
	_start_pikpik_sound()
	_create_indicator()
	intro_finished.emit()


func _start_intro() -> void:
	_set_player_control(false)
	
	await get_tree().create_timer(delay_before_start).timeout
	
	_create_ui()
	_show_next_line()


func _create_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	# Dark overlay
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(overlay)
	
	# Text - positioned at bottom of screen
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
	
	# Eerie style
	text_label.add_theme_font_size_override("font_size", 26)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	text_label.add_theme_constant_override("shadow_offset_x", 2)
	text_label.add_theme_constant_override("shadow_offset_y", 2)
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
	if not pikpik_sound:
		return
	
	sound_player = AudioStreamPlayer.new()
	sound_player.stream = pikpik_sound
	sound_player.bus = "SFX"
	sound_player.volume_db = -20.0
	add_child(sound_player)
	
	sound_player.finished.connect(_on_sound_finished)
	sound_player.play()
	sound_playing = true


func _on_sound_finished() -> void:
	if sound_playing and sound_player:
		sound_player.play()


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
	# Mark intro as played so it won't play again
	_mark_intro_played()
	
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.0, fade_time)
	tween.tween_callback(_finish)


func _finish() -> void:
	_set_player_control(true)
	
	if quest_ui and quest_ui.has_method("add_quest"):
		var objectives: Array[String] = ["Investigate the sound"]
		quest_ui.add_quest("find_pikpik", "A Familiar Voice", objectives)
	
	_create_indicator()
	
	canvas_layer.queue_free()
	
	intro_finished.emit()


func _create_indicator() -> void:
	if not pikpik or not player:
		return
	
	indicator = Node2D.new()
	indicator.name = "PikPikIndicator"
	get_parent().add_child(indicator)
	
	indicator_arrow = Polygon2D.new()
	indicator_arrow.polygon = PackedVector2Array([
		Vector2(20, 0),
		Vector2(-10, -12),
		Vector2(-5, 0),
		Vector2(-10, 12),
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
	
	indicator_active = true


func _process(delta: float) -> void:
	if not pikpik or not player:
		return
	
	var player_pos = player.global_position
	var pikpik_pos = pikpik.global_position
	var direction = (pikpik_pos - player_pos).normalized()
	var distance = player_pos.distance_to(pikpik_pos)
	
	if sound_playing and sound_player:
		if distance < stop_distance:
			_stop_pikpik_sound()
		else:
			var volume_factor = 1.0 - clamp(distance / max_hear_distance, 0.0, 1.0)
			var target_db = lerp(-30.0, sound_volume_db, volume_factor)
			sound_player.volume_db = target_db
	
	if not indicator_active or not indicator:
		return
	
	if distance < stop_distance:
		_remove_indicator()
		return
	
	var offset_distance = 80.0
	indicator.global_position = player_pos + direction * offset_distance
	indicator.rotation = direction.angle()


func _remove_indicator() -> void:
	if indicator:
		indicator_active = false
		var tween = create_tween()
		tween.tween_property(indicator, "modulate:a", 0.0, 0.5)
		tween.tween_callback(indicator.queue_free)
		indicator = null


func _set_player_control(enabled: bool) -> void:
	if not player:
		return
	if "can_move" in player:
		player.can_move = enabled
	elif "movement_enabled" in player:
		player.movement_enabled = enabled


func _input(event: InputEvent) -> void:
	if canvas_layer and current_line < intro_lines.size() and event.is_action_pressed("ui_accept"):
		current_line = intro_lines.size()
		_show_sound_moment()


func on_pikpik_found() -> void:
	_stop_pikpik_sound()
	player.point_light_2d.enabled = false
	_remove_indicator()
	if quest_ui and quest_ui.has_method("complete_objective"):
		quest_ui.complete_objective("find_pikpik", 0)


## Call this to reset the intro (for testing or new game)
static func reset_intro() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
