extends Area2D

@export var value := 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready():
	sprite.play("spin")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name != "Player":
		return
	
	body.collect_coin(value);

	# Optional sound
	if sound:
		sound.play()

	# Prevent double collection
	set_deferred("monitoring", false)
	sprite.visible = false

	# Small delay so sound can play
	await get_tree().create_timer(0.2).timeout
	queue_free()
