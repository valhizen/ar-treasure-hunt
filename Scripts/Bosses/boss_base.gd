extends CharacterBody2D
class_name BossBase

## Base class for all boss enemies with improved AI and raycasting

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var attack_hitbox: Area2D = $AttackHitbox

# === BOSS STATS ===
@export_category("Boss Stats")
@export var boss_name: String = "Boss"
@export var max_health: float = 200.0
@export var move_speed: float = 80.0
@export var attack_damage: float = 20.0
@export var attack_range: float = 60.0
@export var detection_range: float = 400.0
@export var attack_cooldown: float = 1.5
@export var aggro_range: float = 500.0

@export_category("Combat Timing")
@export var attack_windup: float = 0.3  # Time before hitbox activates
@export var attack_active: float = 0.2   # How long hitbox stays active
@export var hit_stun_time: float = 0.3   # Stun duration when hit

@export_category("Movement")
@export var use_gravity: bool = false
@export var gravity_strength: float = 980.0
@export var knockback_resistance: float = 0.5  # 0 = full knockback, 1 = no knockback

@export_category("Raycast Detection")
@export var use_raycast: bool = true
@export var raycast_length: float = 500.0
@export var require_line_of_sight: bool = false

# State Machine
enum State { IDLE, WALK, CHASE, ATTACK, TAKE_HIT, DEATH, SPECIAL }
var current_state: State = State.IDLE
var previous_state: State = State.IDLE

# Internal
var current_health: float
var player: Node2D = null
var can_attack: bool = true
var is_dead: bool = false
var facing_left: bool = false
var attack_hitbox_offset_x: float = 0.0
var has_seen_player: bool = false

# Raycasting
var player_raycast: RayCast2D = null
var can_see_player: bool = false

# Camera reference for shake
var camera: ShakeableCamera = null

# Signals
signal boss_defeated
signal health_changed(current: float, max_health: float)
signal boss_entered_arena
signal attack_started
signal attack_ended


func _ready() -> void:
	add_to_group("boss")
	current_health = max_health
	
	_setup_raycast()
	_setup_hitboxes()
	_setup_animations()
	_find_camera()
	
	# Override in child classes for custom setup
	_boss_ready()
	
	_change_state(State.IDLE)


func _boss_ready() -> void:
	# Override in child classes
	pass


func _setup_raycast() -> void:
	if use_raycast:
		player_raycast = RayCast2D.new()
		player_raycast.name = "PlayerRaycast"
		player_raycast.enabled = true
		player_raycast.target_position = Vector2(raycast_length, 0)
		player_raycast.collision_mask = 1  # Adjust to your player layer
		player_raycast.collide_with_areas = false
		player_raycast.collide_with_bodies = true
		add_child(player_raycast)


func _setup_hitboxes() -> void:
	if attack_hitbox:
		attack_hitbox_offset_x = abs(attack_hitbox.position.x)
		attack_hitbox.monitoring = false
		if not attack_hitbox.area_entered.is_connected(_on_attack_hit):
			attack_hitbox.area_entered.connect(_on_attack_hit)
	
	if hurtbox:
		if not hurtbox.area_entered.is_connected(_on_hurtbox_hit):
			hurtbox.area_entered.connect(_on_hurtbox_hit)


func _setup_animations() -> void:
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)


func _find_camera() -> void:
	# Try to find camera in tree
	await get_tree().process_frame
	var cams = get_tree().get_nodes_in_group("camera")
	if cams.size() > 0 and cams[0] is ShakeableCamera:
		camera = cams[0]
	else:
		# Try to find any Camera2D and check if it has shake method
		var viewport_camera = get_viewport().get_camera_2d()
		if viewport_camera and viewport_camera.has_method("shake"):
			camera = viewport_camera


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Apply gravity if enabled
	if use_gravity:
		velocity.y += gravity_strength * delta
	
	# Update raycast to point at player
	_update_raycast()
	
	# Find player if not found
	if not player or not is_instance_valid(player):
		_find_player()
	
	# State machine
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.WALK:
			_state_walk(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.TAKE_HIT:
			_state_take_hit(delta)
		State.DEATH:
			_state_death(delta)
		State.SPECIAL:
			_state_special(delta)
	
	move_and_slide()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]


func _update_raycast() -> void:
	if not use_raycast or not player_raycast or not player:
		return
	
	var dir_to_player = (player.global_position - global_position).normalized()
	player_raycast.target_position = dir_to_player * raycast_length
	player_raycast.force_raycast_update()
	
	# Check if we can see the player
	if player_raycast.is_colliding():
		var collider = player_raycast.get_collider()
		can_see_player = collider == player or (collider and collider.is_in_group("player"))
	else:
		can_see_player = false


func _get_distance_to_player() -> float:
	if not player or not is_instance_valid(player):
		return INF
	return global_position.distance_to(player.global_position)


func _get_horizontal_distance_to_player() -> float:
	if not player or not is_instance_valid(player):
		return INF
	return abs(player.global_position.x - global_position.x)


func _is_player_in_range(range_dist: float) -> bool:
	return _get_distance_to_player() <= range_dist


func _can_detect_player() -> bool:
	if not player or not is_instance_valid(player):
		return false
	
	if not _is_player_in_range(detection_range):
		return false
	
	if require_line_of_sight and use_raycast:
		return can_see_player
	
	return true


# === STATE FUNCTIONS ===

func _state_idle(_delta: float) -> void:
	velocity.x = 0
	
	if _can_detect_player():
		has_seen_player = true
		_face_player()
		
		if _is_player_in_range(attack_range) and can_attack:
			_change_state(State.ATTACK)
		else:
			_change_state(State.CHASE)


func _state_walk(_delta: float) -> void:
	# Patrol behavior - override in child classes
	_change_state(State.IDLE)


func _state_chase(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		_change_state(State.IDLE)
		return
	
	_face_player()
	
	var h_dist = _get_horizontal_distance_to_player()
	
	# Attack if in range
	if h_dist <= attack_range and can_attack:
		_change_state(State.ATTACK)
		return
	
	# Lost player
	if not _can_detect_player() and not has_seen_player:
		_change_state(State.IDLE)
		return
	
	# Move toward player
	var dir = sign(player.global_position.x - global_position.x)
	velocity.x = dir * move_speed


func _state_attack(_delta: float) -> void:
	velocity.x = 0
	# Attack logic handled in _do_attack


func _state_take_hit(_delta: float) -> void:
	# Knockback handled by velocity set in take_damage
	pass


func _state_death(_delta: float) -> void:
	velocity.x = 0


func _state_special(_delta: float) -> void:
	# Override in child classes for special attacks
	pass


# === FACING ===

func _face_player() -> void:
	if not player or not is_instance_valid(player):
		return
	
	var dir = player.global_position.x - global_position.x
	_set_facing(dir < 0)


func _set_facing(look_left: bool) -> void:
	facing_left = look_left
	animated_sprite.flip_h = look_left
	
	if attack_hitbox:
		attack_hitbox.position.x = -attack_hitbox_offset_x if look_left else attack_hitbox_offset_x


# === STATE CHANGE ===

func _change_state(new_state: State) -> void:
	# Exit current state
	_on_state_exit(current_state)
	
	previous_state = current_state
	current_state = new_state
	
	# Enter new state
	_on_state_enter(new_state)


func _on_state_exit(state: State) -> void:
	match state:
		State.ATTACK:
			if attack_hitbox:
				attack_hitbox.monitoring = false
			attack_ended.emit()


func _on_state_enter(state: State) -> void:
	match state:
		State.IDLE:
			_play_animation("idle")
		State.WALK:
			_play_animation("walk")
		State.CHASE:
			_play_animation("walk")
		State.ATTACK:
			_do_attack()
		State.TAKE_HIT:
			_play_animation("take_hit")
		State.DEATH:
			_play_animation("death")


func _play_animation(anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)


# === COMBAT ===

func _do_attack() -> void:
	if not can_attack:
		_change_state(State.IDLE)
		return
	
	can_attack = false
	attack_started.emit()
	_face_player()
	
	# Play attack animation
	_play_animation("attack_1")
	
	# Windup delay before hitbox activates
	await get_tree().create_timer(attack_windup).timeout
	
	if current_state == State.ATTACK and not is_dead:
		# Activate hitbox
		if attack_hitbox:
			attack_hitbox.monitoring = true
		
		# Camera shake on attack
		if camera:
			camera.boss_attack_shake()
		
		# Keep hitbox active
		await get_tree().create_timer(attack_active).timeout
		
		if attack_hitbox:
			attack_hitbox.monitoring = false
	
	# Cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	print("[%s] HP: %.0f / %.0f" % [boss_name, current_health, max_health])
	
	# Apply knockback with resistance
	if knockback_dir != Vector2.ZERO:
		var kb_strength = 150.0 * (1.0 - knockback_resistance)
		velocity.x = knockback_dir.x * kb_strength
	
	# Camera shake
	if camera:
		camera.shake(0.3)
	
	if current_health <= 0:
		_die()
	else:
		_change_state(State.TAKE_HIT)
		await get_tree().create_timer(hit_stun_time).timeout
		if not is_dead and current_state == State.TAKE_HIT:
			_change_state(State.CHASE if player else State.IDLE)


func _die() -> void:
	is_dead = true
	_change_state(State.DEATH)
	
	# Camera shake for death
	if camera:
		camera.boss_death_shake()
	
	# Disable collision
	if attack_hitbox:
		attack_hitbox.monitoring = false
	if hurtbox:
		hurtbox.monitoring = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	print("[%s] DEFEATED!" % boss_name)
	boss_defeated.emit()


# === CALLBACKS ===

func _on_animation_finished() -> void:
	match current_state:
		State.ATTACK:
			_change_state(State.CHASE if player else State.IDLE)
		State.TAKE_HIT:
			_change_state(State.CHASE if player else State.IDLE)
		State.DEATH:
			_on_death_animation_finished()


func _on_death_animation_finished() -> void:
	await get_tree().create_timer(1.0).timeout
	queue_free()


func _on_attack_hit(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		var target = area.get_parent()
		if target.has_method("take_damage"):
			var kb_dir = Vector2(sign(target.global_position.x - global_position.x), -0.3).normalized()
			target.take_damage(attack_damage, kb_dir)
			
			# Extra camera shake when player is hit
			if camera:
				camera.damage_shake()


func _on_hurtbox_hit(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		var attacker = area.get_parent()
		var kb_dir = Vector2(sign(global_position.x - attacker.global_position.x), 0)
		take_damage(10, kb_dir)  # Default damage, can be overridden


# === UTILITY ===

func heal(amount: float) -> void:
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func set_aggro(target: Node2D) -> void:
	player = target
	has_seen_player = true
	if current_state == State.IDLE:
		_change_state(State.CHASE)
