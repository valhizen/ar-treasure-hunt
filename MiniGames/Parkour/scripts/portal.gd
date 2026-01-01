extends Area2D
@onready var coins: Label = $"../MainCharacter/Coins"
@onready var main_character: CharacterBody2D = $"../MainCharacter"

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.name == "MainCharacter":
		get_tree().paused = true
		coins.text = "You Collected: " + str(main_character.coins_collected) + " Coins \nGame Over!"
		print("You Collected: ", main_character.coins_collected, " Coins")
		print("Game Over!")
