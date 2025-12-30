extends CharacterBody2D

@export var speed: float = 80.0
@export var detection_range: float = 300.0
@export var attack_range: float = 30.0
@export var damage: int = 10
@export var attack_cooldown: float = 1.0

var player: Node2D = null
var animated_sprite: AnimatedSprite2D = null
var can_attack: bool = true
var attack_timer: float = 0.0

func _ready():
	# Find the player node
	player = get_tree().get_first_node_in_group("player")

	# Get the AnimatedSprite2D node
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	

func _physics_process(delta):
	# Update attack cooldown timer
	if not can_attack:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			can_attack = true
			attack_timer = 0.0
	
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

func update_animation(direction: Vector2):
	if animated_sprite == null:
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
	if animated_sprite == null:
		return
	
	if animated_sprite.animation != "idle":
		animated_sprite.play("idle")

func check_line_of_sight() -> bool:
	if not player:
		return false
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	
	# Set collision mask to check only walls (layer 5)
	query.collision_mask = 1 << 4  # Layer 5; tf is dis shit
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	return result.is_empty()

func attack_player():
	var current_scene := get_tree().current_scene
	if  current_scene.name == "Game":
		player.striked()
	# Deal damage to player
	else:
		player.take_damage(damage)
		can_attack = false
		attack_timer = 0.0
