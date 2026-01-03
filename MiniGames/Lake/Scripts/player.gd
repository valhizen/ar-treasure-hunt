extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

# Movement
@export var swim_speed := 240.0
@export var swim_accel := 1000.0
@export var water_drag := 6.0

# Combat
@export var bullet_scene: PackedScene
@export var shoot_cooldown := 0.3
@export var bullet_spawn_offset := 20.0
var can_shoot := true
var last_aim_direction := Vector2.RIGHT

# Health
@export var max_health := 100.0
var health := 100.0
var damage_tween: Tween

func _ready():
	add_to_group("player")
	health = max_health

func _physics_process(delta):
	_handle_swimming(delta)
	_update_animation()
	move_and_slide()

# ----------------------------
# SWIMMING MOVEMENT (ONLY)
# ----------------------------
func _handle_swimming(delta):
	var input := Vector2(
		Input.get_axis("Left", "Right"),
		Input.get_axis("Up", "Down")
	)

	if input.length() > 1:
		input = input.normalized()

	velocity = velocity.move_toward(
		input * swim_speed,
		swim_accel * delta
	)

	# Water drag
	velocity *= exp(-water_drag * delta)

# ----------------------------
# ANIMATION
# ----------------------------
func _update_animation():
	if velocity.length() < 5:
		sprite.play("idle")
	else:
		sprite.play("swimming")

	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

# ----------------------------
# COMBAT
# ----------------------------
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_shoot()

func _shoot():
	if not can_shoot or not bullet_scene:
		return

	can_shoot = false

	var dir := (get_global_mouse_position() - global_position).normalized()
	last_aim_direction = dir

	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position + dir * bullet_spawn_offset
	bullet.set_direction(dir)

	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

# ----------------------------
# DAMAGE
# ----------------------------
func take_damage(amount: float):
	sound.play()

	health -= amount
	health = max(0, health)
	_flash()

	if health <= 0:
		_die()

func _flash():
	if damage_tween and damage_tween.is_running():
		return

	damage_tween = create_tween()
	damage_tween.tween_property(sprite, "modulate", Color(5,5,5), 0.05)
	damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _die():
	set_physics_process(false)
	print("Player died")
	# Show death screen
	var death_screen = get_tree().get_first_node_in_group("death_screen")
	if death_screen and death_screen.has_method("show_death_screen"):
		death_screen.show_death_screen()
	else:
		# Fallback if death screen not found
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()
