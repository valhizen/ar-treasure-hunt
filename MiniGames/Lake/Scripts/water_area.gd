extends Area2D

@export var fish_scene: PackedScene
@export var spawn_count: int = 10
@export var min_spawn_distance: float = 100
@export var spawn_interval: float = 3
@export var max_fish: int = 40

var player: Node2D = null
var active_fish: Array = []
var spawn_timer: float = 0.0
var first_time: bool = true

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if not player:
		return
	
	# Clean up dead fish from array
	active_fish = active_fish.filter(func(fish): return is_instance_valid(fish))
	
	# Spawn fish periodically
	spawn_timer += delta
	if spawn_timer >= spawn_interval and active_fish.size() < max_fish:
		_spawn_fish()
		spawn_timer = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.just_entered_water = true
		
		# Player entered water, spawn initial fish
		if first_time: 
			for i in spawn_count:
				_spawn_fish()
				first_time = false

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.just_exited_water = true

func _spawn_fish() -> void:
	if not fish_scene or not player:
		return
	
	var spawn_pos = _get_valid_spawn_position()
	if spawn_pos == Vector2.ZERO:
		return
	
	var fish = fish_scene.instantiate()
	fish.global_position = spawn_pos
	get_parent().add_child(fish)
	active_fish.append(fish)

func _get_valid_spawn_position() -> Vector2:
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape:
		return Vector2.ZERO
	
	var shape = collision_shape.shape
	var attempts = 20
	
	for i in attempts:
		var random_pos = Vector2.ZERO
		
		# Generate random position within the water area
		if shape is RectangleShape2D:
			var rect_size = shape.size
			random_pos = Vector2(
				randf_range(-rect_size.x / 2, rect_size.x / 2),
				randf_range(-rect_size.y / 2, rect_size.y / 2)
			)
		elif shape is CircleShape2D:
			var angle = randf() * TAU
			var distance = randf() * shape.radius
			random_pos = Vector2(cos(angle), sin(angle)) * distance
		
		var world_pos = global_position + random_pos
		
		# Check if far enough from player
		if player and world_pos.distance_to(player.global_position) >= min_spawn_distance:
			return world_pos
	
	return Vector2.ZERO
