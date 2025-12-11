extends  Node2D


@onready var main_character: Camera2D = $MainCharacter/Camera2D
func _ready() -> void:
	main_character.zoom = Vector2(6.0,6.0)
	pass
