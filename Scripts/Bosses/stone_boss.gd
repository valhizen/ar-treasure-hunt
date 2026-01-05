extends BossBase

## Stone Boss - A challenging boss with projectile attacks, shield, and devastating shockwaves

# === STONE BOSS SPECIFIC ===
@export_category("Stone Boss Attacks")
@export var projectile_damage: float = 15.0
@export var projectile_speed: float = 300.0
@export var projectiles_per_volley: int = 3
@export var projectile_spread: float = 20.0
@export var projectile_cooldown: float = 3.5

@export_category("Shield Ability")
@export var shield_duration: float = 2.5
@export var shield_damage_reduction: float = 0.8
@export var shield_cooldown: float = 8.0
@export var shield_health_threshold: float = 0.6

@export_category("Shockwave")
@export var shockwave_damage: float = 20.0
@export var shockwave_radius: float = 200.0

@export_category("Distance Control")
@export var min_distance_from_player: float = 50.0
@export var preferred_attack_distance: float = 70.0

@export_category("Phase System")
@export var phase_2_threshold: float = 0.5
@export var phase_2_speed_mult: float = 1.3
@export var phase_2_attack_speed_mult: float = 0.75

# Node references
@onready var projectile_spawner: Marker2D = $ProjectileSpwanner if has_node("ProjectileSpwanner") else null
@onready var player_detector: Area2D = $PlayerDetector if has_node("PlayerDetector") else null

# Internal state
enum BossPhase { PHASE_1, PHASE_2 }
var current_phase: BossPhase = BossPhase.PHASE_1
var is_shielded: bool = false
var can_use_projectile: bool = true
var can_use_shield: bool = true
var original_speed: float
var original_cooldown: float
var shield_timer: float = 0.0
var attacks_since_shield: int = 0

signal phase_changed(new_phase: int)
signal shield_activated
signal shield_deactivated
signal shockwave_triggered
signal projectile_fired


func _boss_ready() -> void:
	boss_name = "STONE TITAN"
	original_speed = move_speed
	original_cooldown = attack_cooldown
	
	if not projectile_spawner:
		projectile_spawner = Marker2D.new()
		projectile_spawner.name = "ProjectileSpawner"
		projectile_spawner.position = Vector2(40, -20)
		add_child(projectile_spawner)
	
	if player_detector:
		if not player_detector.body_entered.is_connected(_on_player_entered_detection):
			player_detector.body_entered.connect(_on_player_entered_detection)
	
	# Setup hurtbox - make sure it doesn't block movement
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
		hurtbox.collision_layer = 0
		if not hurtbox.is_in_group("enemy_hurtbox"):
			hurtbox.add_to_group("enemy_hurtbox")
		if not hurtbox.is_in_group("boss_hurtbox"):
			hurtbox.add_to_group("boss_hurtbox")


func _on_player_entered_detection(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		has_seen_player = true


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if is_dead:
		return
	
	if is_shielded:
		shield_timer -= delta
		if shield_timer <= 0:
			_deactivate_shield()
	
	_check_phase_transition()


func _check_phase_transition() -> void:
	if current_phase == BossPhase.PHASE_1:
		var hp_percent = current_health / max_health
		if hp_percent <= phase_2_threshold:
			_enter_phase_2()


func _enter_phase_2() -> void:
	current_phase = BossPhase.PHASE_2
	phase_changed.emit(2)
	
	move_speed = original_speed * phase_2_speed_mult
	attack_cooldown = original_cooldown * phase_2_attack_speed_mult
	projectiles_per_volley += 2
	
	animated_sprite.modulate = Color(1.3, 0.85, 0.85, 1.0)
	_activate_shield()
	
	print("[%s] PHASE 2!" % boss_name)


# === STATE OVERRIDES ===

func _state_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	
	if _can_detect_player():
		has_seen_player = true
		_face_player()
		
		var h_dist = _get_horizontal_distance_to_player()
		
		if h_dist < min_distance_from_player:
			var away_dir = sign(global_position.x - player.global_position.x)
			velocity.x = away_dir * move_speed * 0.6
			return
		
		var action = _choose_action()
		match action:
			"attack":
				if _is_player_in_range(attack_range) and can_attack:
					_change_state(State.ATTACK)
				else:
					_change_state(State.CHASE)
			"projectile":
				_change_state(State.SPECIAL)
			"shield":
				_activate_shield()
			_:
				_change_state(State.CHASE)


func _state_chase(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		_change_state(State.IDLE)
		return
	
	_face_player()
	
	var h_dist = _get_horizontal_distance_to_player()
	var dist = _get_distance_to_player()
	
	if h_dist < min_distance_from_player:
		var away_dir = sign(global_position.x - player.global_position.x)
		velocity.x = away_dir * move_speed * 0.6
		return
	
	if can_use_projectile and dist > attack_range * 2.5 and dist < detection_range:
		if randf() < 0.01:
			_change_state(State.SPECIAL)
			return
	
	if h_dist <= attack_range and h_dist >= min_distance_from_player and can_attack:
		velocity.x = 0
		_change_state(State.ATTACK)
		return
	
	if h_dist >= min_distance_from_player and h_dist <= preferred_attack_distance:
		velocity.x = 0
		if can_attack:
			_change_state(State.ATTACK)
		return
	
	if not _can_detect_player() and not has_seen_player:
		_change_state(State.IDLE)
		return
	
	if h_dist > preferred_attack_distance:
		var dir = sign(player.global_position.x - global_position.x)
		velocity.x = dir * move_speed
	else:
		velocity.x = 0


func _state_special(_delta: float) -> void:
	velocity = Vector2.ZERO


func _on_state_enter(state: State) -> void:
	match state:
		State.IDLE:
			_play_animation("idle")
		State.WALK, State.CHASE:
			_play_animation("idle")
		State.ATTACK:
			_do_attack()
		State.TAKE_HIT:
			_play_animation("idle")
		State.DEATH:
			_play_animation("death")
		State.SPECIAL:
			_do_projectile_attack()


# === ACTION SELECTION ===

func _choose_action() -> String:
	var hp_percent = current_health / max_health
	var dist = _get_distance_to_player()
	
	if can_use_shield and hp_percent < shield_health_threshold:
		if attacks_since_shield >= 3 or hp_percent < 0.3:
			attacks_since_shield = 0
			return "shield"
	
	if can_use_projectile and dist > attack_range * 2.5:
		if randf() < 0.4:
			return "projectile"
	
	if _is_player_in_range(attack_range) and can_attack:
		attacks_since_shield += 1
		return "attack"
	
	return "chase"


# === PROJECTILE ATTACK ===

func _do_projectile_attack() -> void:
	if not can_use_projectile:
		_change_state(State.CHASE)
		return
	
	can_use_projectile = false
	velocity = Vector2.ZERO
	_face_player()
	
	_play_animation("projectile_1")
	
	await get_tree().create_timer(0.4).timeout
	
	if is_dead or current_state != State.SPECIAL:
		can_use_projectile = true
		return
	
	_fire_projectile_volley()
	
	await get_tree().create_timer(0.6).timeout
	
	if not is_dead:
		_change_state(State.CHASE if player else State.IDLE)
	
	await get_tree().create_timer(projectile_cooldown).timeout
	can_use_projectile = true


func _fire_projectile_volley() -> void:
	if not player or not is_instance_valid(player):
		return
	
	var spawn_offset = Vector2(40, -15)
	if facing_left:
		spawn_offset.x = -spawn_offset.x
	
	var spawn_pos = global_position + spawn_offset
	if projectile_spawner:
		spawn_pos = projectile_spawner.global_position
	
	var base_dir = (player.global_position - spawn_pos).normalized()
	var base_angle = base_dir.angle()
	var spread_rad = deg_to_rad(projectile_spread)
	var half_spread = spread_rad * (projectiles_per_volley - 1) / 2.0
	
	for i in range(projectiles_per_volley):
		var angle_offset = 0.0
		if projectiles_per_volley > 1:
			angle_offset = -half_spread + (spread_rad * i)
		
		var proj_angle = base_angle + angle_offset
		var proj_dir = Vector2(cos(proj_angle), sin(proj_angle))
		
		_spawn_projectile(spawn_pos, proj_dir)
		
		if i < projectiles_per_volley - 1:
			await get_tree().create_timer(0.1).timeout
	
	projectile_fired.emit()
	if camera:
		camera.shake(0.15)


func _spawn_projectile(pos: Vector2, direction: Vector2) -> void:
	var proj = Area2D.new()
	proj.name = "StoneProjectile"
	proj.collision_layer = 0
	proj.collision_mask = 2
	proj.monitoring = true
	proj.monitorable = false
	
	var draw_node = Node2D.new()
	draw_node.name = "Visual"
	draw_node.draw.connect(func():
		draw_node.draw_circle(Vector2.ZERO, 8, Color(0.5, 0.45, 0.4))
		draw_node.draw_circle(Vector2(-2, -2), 4, Color(0.65, 0.6, 0.55))
	)
	proj.add_child(draw_node)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 6
	collision.shape = shape
	proj.add_child(collision)
	
	get_tree().current_scene.add_child(proj)
	proj.global_position = pos
	
	var vel = direction * projectile_speed
	var hit = false
	
	proj.area_entered.connect(func(area: Area2D):
		if hit: return
		if area.is_in_group("player_hurtbox"):
			hit = true
			var target = area.get_parent()
			if target and target.has_method("take_damage"):
				target.take_damage(projectile_damage, Vector2.ZERO)
			proj.queue_free()
	)
	
	proj.body_entered.connect(func(body: Node2D):
		if hit: return
		if body.is_in_group("player"):
			hit = true
			if body.has_method("take_damage"):
				body.take_damage(projectile_damage, Vector2.ZERO)
			proj.queue_free()
		elif not body.is_in_group("boss"):
			hit = true
			proj.queue_free()
	)
	
	var move_timer = Timer.new()
	move_timer.wait_time = 0.016
	move_timer.autostart = true
	proj.add_child(move_timer)
	
	var lifetime = 4.0
	move_timer.timeout.connect(func():
		if not is_instance_valid(proj) or hit:
			return
		proj.position += vel * 0.016
		draw_node.rotation += 0.2
		lifetime -= 0.016
		if lifetime <= 0:
			proj.queue_free()
	)


# === SHIELD ABILITY ===

func _activate_shield() -> void:
	if not can_use_shield or is_shielded:
		return
	
	is_shielded = true
	can_use_shield = false
	shield_timer = shield_duration
	
	shield_activated.emit()
	_play_animation("shield")
	_apply_shield_shader()


func _deactivate_shield() -> void:
	is_shielded = false
	shield_deactivated.emit()
	_remove_shield_shader()
	_trigger_shockwave()
	
	if not is_dead:
		_change_state(State.CHASE if player else State.IDLE)
	
	await get_tree().create_timer(shield_cooldown).timeout
	can_use_shield = true


func _apply_shield_shader() -> void:
	if not animated_sprite:
		return
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = SHIELD_SHADER_CODE
	mat.shader = shader
	mat.set_shader_parameter("shield_color", Color(0.3, 0.6, 1.0, 0.5))
	mat.set_shader_parameter("pulse_speed", 3.0)
	animated_sprite.material = mat


func _remove_shield_shader() -> void:
	if animated_sprite:
		animated_sprite.material = null


const SHIELD_SHADER_CODE = """
shader_type canvas_item;
uniform vec4 shield_color : source_color = vec4(0.3, 0.6, 1.0, 0.5);
uniform float pulse_speed = 3.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = sin(TIME * pulse_speed) * 0.3 + 0.7;
	vec4 result = mix(tex, shield_color, 0.35 * pulse);
	result.a = tex.a;
	COLOR = result;
}
"""


# === SHOCKWAVE ===

func _trigger_shockwave() -> void:
	shockwave_triggered.emit()
	
	if camera:
		camera.shake(0.35)
	
	# Find players in radius and damage them
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p):
			var dist = global_position.distance_to(p.global_position)
			if dist <= shockwave_radius:
				if p.has_method("take_damage"):
					p.take_damage(shockwave_damage, Vector2.ZERO)
	
	_spawn_shockwave_visual()


func _spawn_shockwave_visual() -> void:
	var shockwave = Node2D.new()
	shockwave.name = "Shockwave"
	get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = global_position
	
	var progress = {"v": 0.0}
	var max_r = shockwave_radius
	
	var drawer = Node2D.new()
	drawer.draw.connect(func():
		var p = progress.v
		var r = max_r * p
		var alpha = 1.0 - p
		var width = 20.0 * (1.0 - p * 0.5)
		if r > 5:
			drawer.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0.7, 0.5, 0.3, alpha), width, true)
			drawer.draw_arc(Vector2.ZERO, r * 0.75, 0, TAU, 32, Color(1.0, 0.7, 0.3, alpha * 0.6), width * 0.5, true)
	)
	shockwave.add_child(drawer)
	
	var tw = create_tween()
	tw.tween_method(func(val: float):
		progress.v = val
		drawer.queue_redraw()
	, 0.0, 1.0, 0.5)
	
	await tw.finished
	shockwave.queue_free()


# === DAMAGE ===

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	
	var actual_damage = amount
	if is_shielded:
		actual_damage = amount * (1.0 - shield_damage_reduction)
		_flash_sprite(Color(0.5, 0.7, 1.0))
	else:
		_flash_sprite(Color.WHITE)
	
	current_health -= actual_damage
	health_changed.emit(current_health, max_health)
	
	if camera:
		camera.shake(0.15)
	
	if current_health <= 0:
		_die()
	elif not is_shielded:
		_change_state(State.TAKE_HIT)
		await get_tree().create_timer(hit_stun_time).timeout
		if not is_dead and current_state == State.TAKE_HIT:
			_change_state(State.CHASE if player else State.IDLE)


func _flash_sprite(color: Color) -> void:
	if animated_sprite:
		animated_sprite.modulate = color * 2.0
		var tw = create_tween()
		var target = Color(1.3, 0.85, 0.85) if current_phase == BossPhase.PHASE_2 else Color.WHITE
		tw.tween_property(animated_sprite, "modulate", target, 0.15)


func _on_animation_finished() -> void:
	match current_state:
		State.ATTACK:
			_change_state(State.CHASE if player else State.IDLE)
		State.TAKE_HIT:
			_change_state(State.CHASE if player else State.IDLE)
		State.DEATH:
			_on_death_animation_finished()


func _die() -> void:
	is_shielded = false
	_remove_shield_shader()
	super._die()


func _on_attack_hit(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(attack_damage, Vector2.ZERO)


func _on_hurtbox_hit(area: Area2D) -> void:
	if area.is_in_group("player_attack") or area.is_in_group("attack") or area.is_in_group("hitbox"):
		var damage_amt = 10.0
		var attacker = area.get_parent()
		if attacker and "attack_damage" in attacker:
			damage_amt = attacker.attack_damage
		take_damage(damage_amt, Vector2.ZERO)
