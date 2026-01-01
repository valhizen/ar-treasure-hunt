extends Node2D

signal corrupter_defused

@export var defuse_time: float = 10.0
@export var interaction_range: float = 100.0
@export var corrupted_color: Color = Color(1, 1, 1, 1)
@export var defused_color: Color = Color(1, 1, 1, 1)

var defuse_progress: float = 0.0
var is_defused: bool = false
var player_in_range: bool = false
var player: Node2D = null
var is_player_attacking: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var interaction_label: Label = $InteractionLabel
@onready var detection_area: Area2D = $DetectionArea

var corrupt_particles: CPUParticles2D
var clean_particles: CPUParticles2D

func _ready() -> void:
	# Add to corrupter group
	add_to_group("corrupter")

	# 🔁 Sprite setup (static image)
	sprite.stop()
	sprite.frame = 0
	sprite.modulate = corrupted_color
	
	_setup_corrupt_particles()
	_setup_clean_particles()

	corrupt_particles.emitting = true
	clean_particles.emitting = false

	# Setup progress bar
	if not has_node("ProgressBar"):
		progress_bar = ProgressBar.new()
		add_child(progress_bar)
		progress_bar.position = Vector2(-40, -60)
		progress_bar.size = Vector2(80, 10)
		progress_bar.scale = Vector2(1, 0.25)

	progress_bar.max_value = defuse_time
	progress_bar.value = 0
	progress_bar.show_percentage = false
	progress_bar.visible = false

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	progress_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.6, 1, 1)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

	# Setup interaction label
	if not has_node("InteractionLabel"):
		interaction_label = Label.new()
		add_child(interaction_label)
		interaction_label.position = Vector2(-30, 40)

	interaction_label.text = "[E] Defuse"
	interaction_label.visible = false

	# Setup detection area
	if not has_node("DetectionArea"):
		detection_area = Area2D.new()
		add_child(detection_area)

		var collision_shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = interaction_range
		collision_shape.shape = circle
		detection_area.add_child(collision_shape)

	detection_area.body_entered.connect(_on_detection_area_entered)
	detection_area.body_exited.connect(_on_detection_area_exited)

	# Find player
	player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if is_defused:
		return

	if player:
		var distance = global_position.distance_to(player.global_position)
		player_in_range = distance <= interaction_range
		_check_player_attacking()

	interaction_label.visible = player_in_range and not is_defused and not is_player_attacking

	if player_in_range and Input.is_action_pressed("interact") and not is_player_attacking:
		_defuse(delta)
	else:
		if defuse_progress > 0 and not Input.is_action_pressed("interact"):
			progress_bar.visible = false

		if is_player_attacking and progress_bar.visible:
			progress_bar.visible = false
			interaction_label.text = "[E] Defuse"

func _defuse(delta: float) -> void:
	if is_player_attacking:
		return

	defuse_progress += delta
	progress_bar.value = defuse_progress
	progress_bar.visible = true
	interaction_label.text = "[E] Defuse"

	if defuse_progress >= defuse_time:
		_complete_defuse()

func _check_player_attacking() -> void:
	if not player:
		is_player_attacking = false
		return

	is_player_attacking = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if "can_shoot" in player:
		is_player_attacking = is_player_attacking or not player.can_shoot

	if Input.is_action_pressed("ui_accept") and is_player_attacking:
		is_player_attacking = true

func _complete_defuse() -> void:
	is_defused = true

	# 🔁 COLOR CHANGE VIA SPRITE MODULATE
	sprite.modulate = defused_color

	progress_bar.visible = false
	interaction_label.visible = false

	corrupter_defused.emit()
	
	# Stop corruption effect
	if corrupt_particles:
		corrupt_particles.emitting = false

	# Play clean sparkle effect
	if clean_particles:
		clean_particles.restart()
		clean_particles.emitting = true

	print("Corrupter defused!")

func _on_detection_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_detection_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		progress_bar.visible = false

func _setup_corrupt_particles() -> void:
	corrupt_particles = CPUParticles2D.new()
	add_child(corrupt_particles)

	corrupt_particles.position = Vector2.ZERO
	corrupt_particles.emitting = false
	corrupt_particles.one_shot = false

	# 🔥 MUCH MORE VISIBLE
	corrupt_particles.amount = 140
	corrupt_particles.lifetime = 2.2

	# 🌀 Full swirl
	corrupt_particles.spread = 360
	corrupt_particles.gravity = Vector2.ZERO

	# 🌊 Slow but heavy motion
	corrupt_particles.initial_velocity_min = 12
	corrupt_particles.initial_velocity_max = 45

	# 🌀 Strong rotation (key for swirl feeling)
	corrupt_particles.angular_velocity_min = -420
	corrupt_particles.angular_velocity_max = 420

	# 🌫 Larger particles = more presence
	corrupt_particles.scale_amount_min = 1.2
	corrupt_particles.scale_amount_max = 2.2

	# 💜 CORRUPTION COLOR (PURPLE)
	corrupt_particles.color = Color(0.6, 0.1, 0.8, 0.75)


func _setup_clean_particles() -> void:
	clean_particles = CPUParticles2D.new()
	add_child(clean_particles)

	clean_particles.position = Vector2.ZERO
	clean_particles.emitting = false
	clean_particles.one_shot = false
	clean_particles.amount = 30
	clean_particles.lifetime = 1.0

	clean_particles.spread = 360
	clean_particles.gravity = Vector2(0, 50)

	clean_particles.initial_velocity_min = 40
	clean_particles.initial_velocity_max = 90

	clean_particles.scale_amount_min = 0.8
	clean_particles.scale_amount_max = 1.4

	clean_particles.color = Color(0.6, 0.9, 1.0, 1.0) # clean blue sparkle
