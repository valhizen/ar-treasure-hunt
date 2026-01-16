extends Node2D

@export var map_name: String = "patan"
@export var required_count: int = 3

@onready var block_collision = $BlockPortal/CollisionShape2D

func _ready():
	ProgressTracker.minigame_completed.connect(_on_any_minigame_completed)
	_check_portal()


func _check_portal():
	var count = ProgressTracker.get_count(map_name)
	var is_open = count >= required_count
	
	block_collision.disabled = is_open
	print("[Portal] %d/%d - %s" % [count, required_count, "OPEN" if is_open else "BLOCKED"])


func _on_any_minigame_completed(_name: String):
	_check_portal()
