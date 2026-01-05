extends Node2D

func _ready() -> void:
	var character = get_node("MainCharacter")
	character.platformer = true

func _process(delta: float) -> void:
	pass
