# Transporter.gd
extends Area2D

# === DESTINATION (Set in Inspector) ===
@export_file("*.tscn") var target_scene: String = ""
@export var spawn_point_name: String = ""

# === INTERACTION ===
@export var interact_key: String = "E"
@export var interact_text: String = "Enter"

# === AUDIO ===
@export var ambient_sound: AudioStream
@export var sound_interval: float = 2.0
@export var interact_sound: AudioStream

# === VISUAL ===
@export var enable_glow: bool = true
@export var glow_color: Color = Color(1, 0.9, 0.5, 0.5)

# Internal variables
var player_in_range: bool = false
var prompt_label: Label
var sound_timer: Timer
var ambient_player: AudioStreamPlayer2D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_prompt()
	_setup_audio()

func _setup_prompt():
	prompt_label = Label.new()
	prompt_label.text = "[%s] %s" % [interact_key, interact_text]
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.visible = false
	prompt_label.z_index = 100
	prompt_label.position = Vector2(-40, -50)
	add_child(prompt_label)

func _setup_audio():
	ambient_player = AudioStreamPlayer2D.new()
	add_child(ambient_player)
	
	sound_timer = Timer.new()
	sound_timer.wait_time = sound_interval
	sound_timer.timeout.connect(_play_ambient)
	add_child(sound_timer)

func _play_ambient():
	if ambient_sound and player_in_range:
		ambient_player.stream = ambient_sound
		ambient_player.play()

func _input(event):
	if player_in_range and event.is_action_pressed("interact"):
		_interact()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		prompt_label.visible = true
		if ambient_sound:
			sound_timer.start()
			_play_ambient()

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false
		sound_timer.stop()

func _interact():
	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)
	else:
		push_warning("No target scene set!")
