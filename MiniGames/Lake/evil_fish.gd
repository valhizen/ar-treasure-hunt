extends CharacterBody2D

@export var speed: float = 80.0
@export var detection_range: float = 300.0
@export var attack_range: float = 50.0
@export var patrol_radius: float = 100.0
@export var damage: float = 10.0
@export var health: float = 30.0

var player: Node2D = null
var spawn_position: Vector2
var patrol_target: Vector2
var state: String = "patrol"  # patrol, chase, attack

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	spawn_position = global_position
	patrol_target = _get_random_patrol_point()
	
	if not has_node("AttackTimer"):
		attack_timer = Timer.new()
		add_child(attack_timer)
		attack_timer.wait_time = 1.5
		attack_timer.one_shot = false
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Find player
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# State machine
	match state:
		"patrol":
			_patrol_behavior(delta)
			if distance_to_player < detection_range:
				state = "chase"
		
		"chase":
			_chase_behavior(delta)
			if distance_to_player < attack_range:
				state = "attack"
				attack_timer.start()
			elif distance_to_player > detection_range * 1.5:
				state = "patrol"
				patrol_target = _get_random_patrol_point()
		
		"attack":
			_attack_behavior(delta)
			if distance_to_player > attack_range:
				state = "chase"
				attack_timer.stop()
	
	move_and_slide()
	_update_sprite_direction()

func _patrol_behavior(_delta: float) -> void:
	var direction = (patrol_target - global_position).normalized()
	velocity = direction * speed * 0.5
	
	if global_position.distance_to(patrol_target) < 10:
		patrol_target = _get_random_patrol_point()

func _chase_behavior(_delta: float) -> void:
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed

func _attack_behavior(_delta: float) -> void:
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed * 0.3

func _get_random_patrol_point() -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(patrol_radius * 0.5, patrol_radius)
	return spawn_position + Vector2(cos(angle), sin(angle)) * distance

func _update_sprite_direction() -> void:
	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false

func _on_attack_timer_timeout() -> void:
	if state == "attack" and player:
		var distance = global_position.distance_to(player.global_position)
		if distance < attack_range:
			_deal_damage_to_player()

func _deal_damage_to_player() -> void:
	if player.has_method("take_damage"):
		player.take_damage(damage)

func take_damage(amount: float) -> void:
	health -= amount
	# Add visual feedback here (flash, etc.)
	if health <= 0:
		queue_free()
