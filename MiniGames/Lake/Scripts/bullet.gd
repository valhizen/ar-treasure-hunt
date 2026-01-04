extends Area2D

@export var speed: float = 400.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

@onready var sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

var direction: Vector2 = Vector2.RIGHT
var traveled_distance: float = 0.0

func _ready() -> void:
	sound.play()
	
	# Set collision layers
	collision_layer = 8  # Layer 4 (bullet layer)
	collision_mask = 5   # Layer 1 (world) + Layer 3 (enemies) = 1 + 4 = 5
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	traveled_distance += speed * delta

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	# Rotate sprite to match direction
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	# Hit a wall/environment or enemy fish
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Destroy bullet on any collision
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Hit an enemy area
	if area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage)
		queue_free()
