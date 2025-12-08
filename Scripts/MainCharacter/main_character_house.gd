extends  Node2D


@onready var main_character: Camera2D = $MainCharacter/Camera2D
func _ready() -> void:
	main_character.zoom = Vector2(2.0,2.0)
	pass
