extends CharacterBody2D

@export var speed: float = 80.0
@export var detection_range: float = 300.0
@export var attack_range: float = 30.0
@export var damage: int = 10
@export var attack_cooldown: float = 1.0
@export var fear_range: float = 200.0
@export var fear_strength: float = 1.5

var is_dead := false
var player: Node2D = null
var animated_sprite: AnimatedSprite2D = null
var can_attack: bool = true
var attack_timer: float = 0.0

@onready var death_sfx: AudioStreamPlayer = $DeathSFX

func _ready():
	# Find the player node
	player = get_tree().get_first_node_in_group("player")
	# Get the AnimatedSprite2D node
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	add_to_group("enemy")
	
func _physics_process(delta):
	if is_dead:
		return
	
	# Update attack cooldown timer
	if not can_attack:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			can_attack = true
			attack_timer = 0.0
			
	var nearest_lantern = get_nearest_lantern()
	if nearest_lantern:
		var lantern_distance = global_position.distance_to(nearest_lantern.global_position)
		if lantern_distance <= fear_range:
			# RUN AWAY from lantern
			var flee_dir = (global_position - nearest_lantern.global_position).normalized()
			velocity = flee_dir * speed * fear_strength
			update_animation(flee_dir)
			move_and_slide()
			return  # lantern fear overrides everything
	
	if not player:
		velocity = Vector2.ZERO
		play_idle_animation()
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Check if player is in detection range
	if distance <= detection_range:
		# Check line of sight
		if check_line_of_sight():
			# Move toward player if not in attack range
			if distance > attack_range:
				var direction = (player.global_position - global_position).normalized()
				velocity = direction * speed
				update_animation(direction)
			else:
				# In attack range, stop and attack
				velocity = Vector2.ZERO
				play_idle_animation()
				
				# Attack if cooldown is ready
				if can_attack:
					attack_player()
		else:
			# Can't see player
			velocity = Vector2.ZERO
			play_idle_animation()
	else:
		# Out of range
		velocity = Vector2.ZERO
		play_idle_animation()
	
	move_and_slide()

func take_damage(_amount: int = 0):
	if is_dead:
		return
	die()

func die():
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Play death sound
	if death_sfx:
		death_sfx.pitch_scale = randf_range(0.9, 1.1)
		death_sfx.play()
	
	# Disable collision immediately
	collision_layer = 0
	collision_mask = 0
	
	if animated_sprite:
		animated_sprite.play("die")
		
		# Wait for exactly 6 frames at default framerate (assuming 10 FPS for sprite animation)
		# 6 frames / 10 FPS = 0.6 seconds
		await get_tree().create_timer(0.6).timeout
	else:
		# If no animated sprite, just wait a moment
		await get_tree().create_timer(0.6).timeout
	
	queue_free()

func update_animation(direction: Vector2):
	if animated_sprite == null or is_dead:
		return
	
	# Determine which direction is dominant
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			animated_sprite.play("run_right")
		else:
			animated_sprite.play("run_left")
	else:
		animated_sprite.play("run_up_down")

func play_idle_animation():
	if animated_sprite == null or is_dead:
		return
	
	if animated_sprite.animation != "idle":
		animated_sprite.play("idle")

func check_line_of_sight() -> bool:
	if not player:
		return false
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	
	# Set collision mask to check only walls (layer 5)
	query.collision_mask = 1 << 4  # Layer 5
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	return result.is_empty()

func attack_player():
	var current_scene := get_tree().current_scene
	if current_scene.name == "Game":
		player.striked()
	else:
		if player.has_method("take_damage"):
			player.take_damage(damage)
		can_attack = false
		attack_timer = 0.0
		
func get_nearest_lantern() -> Node2D:
	var lanterns = get_tree().get_nodes_in_group("lantern")
	var nearest: Node2D = null
	var min_dist := INF
	
	for lantern in lanterns:
		var d = global_position.distance_to(lantern.global_position)
		if d < min_dist:
			min_dist = d
			nearest = lantern
	
	return nearest
