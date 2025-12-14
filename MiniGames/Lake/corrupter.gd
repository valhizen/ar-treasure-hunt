extends StaticBody2D

@onready var color_rect: ColorRect = $ColorRect
@onready var health: float = 100

func _ready() -> void:
	add_to_group("corrupters")

func take_damage(dmg: float) -> void:
	health -= dmg
	print(health)
	
	if health <= 0:
		color_rect.color = Color.RED
		health = 0
